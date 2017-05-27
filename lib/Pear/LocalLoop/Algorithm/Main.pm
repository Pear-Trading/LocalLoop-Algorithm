package Pear::LocalLoop::Algorithm::Main;

use Moo;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::ChainTransaction;

#FIXME move into a config file and dynamically read it in.
my $dbConfig = {
  dsn => "dbi:SQLite:dbname=transactions.db",
  user => undef,
  pass => undef,
};

my $dbTestConfig = {
  dsn => "dbi:SQLite:dbname=transactions-test.db",
#  dsn => "dbi:SQLite:dbname=:memory:",
  user => undef,
  pass => undef,
};


#  return DBI->connect($dbConfig->{dsn},$dbConfig->{user},$dbConfig->{pass}) or die "Could not connect";
sub _dbi {
  my $self = shift;
  return DBI->connect($dbConfig->{dsn},$dbConfig->{user},$dbConfig->{pass});
};

sub _dbi_test {
  my $self = shift;
  return DBI->connect($dbTestConfig->{dsn},$dbTestConfig->{user},$dbTestConfig->{pass});
};


has dbh => (
  is => 'ro',
  default => sub { return dbi(); },
  lazy => 1,
);

sub setTestingMode {
  $ENV{'MODE'} = "testing";
}

sub clearTestingMode {
  $ENV{'MODE'} = undef;
}

sub dbi {
  my $mode = $ENV{'MODE'};
  if (defined $mode && $mode eq "testing") {
    return _dbi_test();
  }
  else {
    return _dbi();
  }
}

sub process {
  debugMethodStart();
  my ($self, $settings) = @_;
  
  #TODO add more checks for settings.
  if (! defined $settings) {
    die "Settings are undefined";
  }
  
  my $dbh = $self->dbh or die "Database does not exist";  
  
  $self->_initialSetup($settings);  
  $settings->applyStaticRestrictions();
  $settings->initAfterStaticRestrictions();
  
  debugMethodMiddle("Before loop");
  
  for (my $nextTransactionId = $settings->nextTransactionId(); 
    defined $nextTransactionId; 
    $nextTransactionId = $settings->nextTransactionId())
  {
    debugMethodMiddle("TransactionLoop: $nextTransactionId");
    $self->_loopGeneration($settings, $nextTransactionId);
    
  }
  
  #This may be here or the last line in the for loop, depending on when you want the loops to be selected.
  $self->_selectLoops($settings);
  
  debugMethodEnd();
}

#This is executed once per analysis.
sub _initialSetup {
  debugMethodStart();
  my ($self, $settings) = @_;
  my $dbh = $self->dbh;
  
  $dbh->do("DELETE FROM ProcessedTransactions");
  $dbh->do("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) SELECT * FROM OriginalTransactions"); 
  
  $settings->init();
  
  debugMethodEnd();
}

sub _selectLoops {
  debugMethodStart();
  my ($self, $settings) = @_;
  my $dbh = $self->dbh;
  
  my $statementSelectOneIncludedLoopId = $dbh->prepare("SELECT LoopId FROM LoopInfo WHERE Included != 0 LIMIT 1");
  my $statementSetLoopToActive = $dbh->prepare("UPDATE LoopInfo SET Active = 1 WHERE LoopId = ?");
  my $statementResetAllActiveLoops = $dbh->prepare("UPDATE LoopInfo SET Active = 0 WHERE Active != 0");
  
  $statementResetAllActiveLoops->execute();
  #Insert one loop at a time as the activating of a loop may break the other loops (consistency of the loops).
  my $loopId = undef; 
  do {
    $settings->applyLoopDynamicRestrictionsAndHeuristics();
    $statementSelectOneIncludedLoopId->execute();
    ($loopId) = $statementSelectOneIncludedLoopId->fetchrow_array();
    if (defined $loopId) {
      $statementSetLoopToActive->execute($loopId);
    }
  } while (defined $loopId); #Continue looping while loops can co-exist.
  
  debugMethodEnd();
}


sub _loopGeneration {
  debugMethodStart();
  #we assume the nextTransaction id is valid.
  my ($self, $settings, $nextTransactionId) = @_;
  my $dbh = $self->dbh;
  
  debugMethodMiddle("NextTransactionId:$nextTransactionId");

  $dbh->prepare("DELETE FROM CandinateTransactions")->execute();  
  $dbh->prepare("DELETE FROM BranchedTransactions")->execute();
  $dbh->prepare("DELETE FROM CurrentChains")->execute();
  $dbh->prepare("DELETE FROM CurrentChainsStats")->execute();

  
  my $statementTransactionValue = $dbh->prepare("SELECT FromUserId, Value FROM ProcessedTransactions WHERE TransactionId = ?");

  $statementTransactionValue->execute($nextTransactionId); 
  my ($fromUserId, $transactionValue) = $statementTransactionValue->fetchrow_array();
  
  debugMethodMiddle(" Candinate fromUserId:$fromUserId value:$transactionValue");
  
  my $candinateId = $self->_newCandinateTransactionsId();
  my $statementInsertCandinate = $dbh->prepare("INSERT INTO CandinateTransactions (CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
 

  #Insert initial transaction.
  $statementInsertCandinate->execute($candinateId, undef, undef, $nextTransactionId, $transactionValue, 1, $transactionValue, 1);
  debugMethodMiddle("InsertedInitalCandinate");
  
  my $extendedTransaction = undef;
  
  while ( ! ($extendedTransaction = $self->_getNextBestCandinateTransactionAnalysis($settings, $fromUserId))->hasFinished() ) {
    debugMethodMiddle("1st while loop start");
    $self->_selectNextBestCandinateTransactions($settings, $extendedTransaction);
    
    #sleep (10);
    debugMethodMiddle("1st while loop end");
  }
  
  #Insert all of the remaining candinate transactions, so equal candinates can be found.
  #This also can mean poor candinates can be added, however in the next section the filtering should take
  #care of this. Also as we have processed the loops we may as well store them it would a waste of resouces 
  #not to, as some other loop may become inactive which results in these poor loops becoming active.
  while ( ! $extendedTransaction->noCandinateTransactionsLeft() ) {
    $extendedTransaction = $self->_getNextBestCandinateTransactionAnalysis($settings, $fromUserId);
  }
  

  my $statementLoops = $dbh->prepare("SELECT Result.ChainId FROM ProcessedTransactions, (SELECT CurrentChains.ChainId AS ChainId, MAX(CurrentChains.TransactionId_FK) AS MaxTransactionId FROM CurrentChains GROUP BY CurrentChains.ChainId) AS Result WHERE Result.MaxTransactionId = ProcessedTransactions.TransactionId AND ProcessedTransactions.ToUserId = ?");
    
  $statementLoops->execute($fromUserId);
  
  #Store a list as we can't have a select and insert statement executed at the same time on a SQLite database.
  my $chainIdsWhichAreLoops = [];
  while (my ($chainId) = $statementLoops->fetchrow_array()) {
    push(@$chainIdsWhichAreLoops, $chainId);
  }
  
  #say Dumper($chainIdsWhichAreLoops);
  
  my $statementGetChainMinMax = $dbh->prepare("SELECT MIN(TransactionId_FK), MAX(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? GROUP BY ChainId");
  my $statementGetChainStatsId = $dbh->prepare("SELECT ChainStatsId_FK FROM CurrentChains WHERE ChainId = ? AND TransactionId_FK = ?");
  my $statementGetChainStats = $dbh->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CurrentChainsStats WHERE ChainStatsId = ?");

  
  my $statementInsertStats = $dbh->prepare("INSERT INTO LoopInfo (LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?)");
  my $statementInsert = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) SELECT ?, TransactionId_FK FROM CurrentChains WHERE ChainId = ?");
  
  
  my $newLoopIds = [];
  #TODO think about how to detect duplicate loops.
  foreach my $chainId (@{$chainIdsWhichAreLoops}) {
    my $newUniqueLoopId = $self->_newLoopId();
    push(@$newLoopIds, $newUniqueLoopId);
    
    $statementGetChainMinMax->execute($chainId);
    my ($minTransactionId, $maxTransactionId) = $statementGetChainMinMax->fetchrow_array();
    
    $statementGetChainStatsId->execute($chainId, $maxTransactionId);
    my ($chainStatsId) = $statementGetChainStatsId->fetchrow_array();
    
    $statementGetChainStats->execute($chainStatsId);
    my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementGetChainStats->fetchrow_array();
    
    $statementInsertStats->execute($newUniqueLoopId, $minTransactionId, $maxTransactionId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
    $statementInsert->execute($newUniqueLoopId, $chainId);
  }
  

  debugMethodEnd();
  return $newLoopIds;
}

#Note: the test for this function is limited to that only the differences in the pass with 2 transactions (from and to)
#are tested. We assume if it can execute the same code path with just the one transaction (to) it will work
#when there is 2.
#If this function is changed structurally in which the assumption becomes false then update the test too.
sub _selectNextBestCandinateTransactions {
  debugMethodStart();
  my ($self, $settings, $extendedTransaction) = @_;
  my $dbh = $self->dbh;
 
  my $statementTransactionValue = $dbh->prepare("SELECT Value FROM ProcessedTransactions WHERE TransactionId = ?");
  my $statementInsertCandinate = $dbh->prepare("INSERT INTO CandinateTransactions (CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
  my $statementSelectIncludedTransactions = $dbh->prepare("SELECT TransactionId FROM ProcessedTransactions_ViewIncluded");
  my $statementTransactionsExistFromSameChain = $dbh->prepare("SELECT COUNT(ChainId_FK) FROM CandinateTransactions WHERE ChainId_FK = ? AND TransactionFrom_FK = ?");

  
  #ChainTransaction instance or undef. Extended transaction will always be not null otherwise it would 
  #not be in this loop.
  my $toTransaction = $extendedTransaction->extendedTransaction();
  my $fromTransaction = $extendedTransaction->fromTransaction();
  
  
  my $transactionsToAnalyse = [$toTransaction]; 
  if (defined $fromTransaction) {
    debugMethodMiddle("WhileLoop PushedFromTransaction");
    push(@$transactionsToAnalyse, $fromTransaction);
  }
  
  foreach my $chainTransaction (@{$transactionsToAnalyse}) {
    debugBraceStart("ForEachLoop 2Trans.");
    my $chainId = $chainTransaction->chainId();
    my $transactionId = $chainTransaction->transactionId();
    my $fromTo = $chainTransaction->fromTo();
    debugMethodMiddle("WhileLoop: ForEachLoop. ChainId:$chainId TransactionId:$transactionId From/To:$fromTo");

    
    #This is here to prevent the adding of any transactions to the candinates table if some already exist 
    #in the table, hence if id is not undefined we must skip this until those transactions are used up.
    #To transactions don't need to be checked as they will not have any previous transactions in the table
    #from this new transsaction.      
    if ($fromTo eq "from") {
      debugMethodMiddle("WhileLoop: ForEachLoop. From Transaction");
      #See if any tuples exist.
      $statementTransactionsExistFromSameChain->execute($chainId, $transactionId);  
      my ($count) = $statementTransactionsExistFromSameChain->fetchrow_array();
      
      if ( 0 < $count ) {
        debugMethodMiddle("WhileLoop: ForEachLoop. Skipped loop");
        next; #Skip this 
      }
    }
    
    debugMethodMiddle("WhileLoop: ForEachLoop. Applying dynamic restrictions");
    $settings->applyDynamicRestrictionsAndHeuristics($transactionId, $chainId);

    debugMethodMiddle("WhileLoop: ForEachLoop. Done heuristics");
    
    my $statementChainStatsId = $dbh->prepare("SELECT ChainStatsId_FK FROM CurrentChains WHERE ChainId = ? AND TransactionId_FK = ?");
    $statementChainStatsId->execute($chainId, $transactionId);
    my ($chainStatsId) = $statementChainStatsId->fetchrow_array();
    
    my $statementChainStats = $dbh->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CurrentChainsStats WHERE ChainStatsId = ?");
    $statementChainStats->execute($chainStatsId);    
    my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementChainStats->fetchrow_array();

    debugMethodMiddle("WhileLoop: ForEachLoop. BaseValue MinValue:$minimumValue Length:$length TotalValue:$totalValue NumOfMinValues:$numberOfMinimumValues");

    #Get all transactions that are applicable after all restriction and heuristics.
    $statementSelectIncludedTransactions->execute();
    
    #We assume they connected together.
    while (my ($candinateTransactionId) = $statementSelectIncludedTransactions->fetchrow_array()) {
      debugBraceStart("While loop best next trans.");
      debugMethodMiddle("WhileLoop: ForEachLoop. CandinateTransactionId:$candinateTransactionId");
      $statementTransactionValue->execute($candinateTransactionId);
      my ($candinateValue) = $statementTransactionValue->fetchrow_array();
      
      my $isValueLower = ($candinateValue < $minimumValue);
      my $isValueSame = ($candinateValue == $minimumValue);
      
      my $thisMinimumValue = ($isValueLower ? $candinateValue : $minimumValue);
      my $thisLength = $length + 1;
      my $thisTotalValue = $totalValue + $candinateValue;
      my $thisNumberOfMinimumValues = ($isValueLower ? 1 : ($isValueSame ? ($numberOfMinimumValues + 1) : $numberOfMinimumValues));
      

      my $candinateId = $self->_newCandinateTransactionsId();
      
      debugMethodMiddle("WhileLoop: ForEachLoop. EnteredCandinateValues CandinateId:$candinateId chainId:$chainId fromTransaction:$transactionId toTransaction:$candinateTransactionId MinValue:$thisMinimumValue Length:$thisLength TotalValue:$thisTotalValue NumOfMinValues:$thisNumberOfMinimumValues");
      
      $statementInsertCandinate->execute($candinateId, $chainId, $transactionId, $candinateTransactionId, $thisMinimumValue, $thisLength, $thisTotalValue, $thisNumberOfMinimumValues);
      
      debugBraceEnd("While loop best next trans.");      
    }
    debugBraceEnd("ForEachLoop 2Trans.");
  }
  debugMethodEnd();
}

#TODO needs a better name.
sub _getNextBestCandinateTransactionAnalysis {
  debugMethodStart();  
  my ($self, $settings, $loopStartId) = @_;
  my $dbh = $self->dbh;
  
  my $statementInsertChains = $dbh->prepare("INSERT INTO CurrentChains (ChainId, TransactionId_FK, ChainStatsId_FK) VALUES (?, ?, ?)");
  my $statementInsertChainStats = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");

  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = @{$self->_getNextBestCandinateTransaction($settings)};
  
  my $transactionsToAnalyseNext = undef;
  
  if ($hasRow == 0) {
    debugMethodMiddle("No row");
    $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
      noCandinateTransactionsLeft => 1,
      loopStartEndUserId => $loopStartId,
    });
    
    debugMethodMiddle("ReturnVals(Finished): " . Dumper($transactionsToAnalyseNext));
    
    debugMethodEnd();  
    return $transactionsToAnalyseNext;
  }
  
  debugMethodMiddle("ReturnVals(Non-null): hasRow:$hasRow chainId:".(defined $chainId ? $chainId : "")." transFrom:".(defined $transactionFrom ? $transactionFrom : "")." transTo:$transactionTo miniValue:$minimumValue Length:$length TotalValue:$totalValue numMinVals:$numberOfMinimumValues");

  
  my $newChainStatsId = $self->_newChainStatsId();  
  
  if (! defined $transactionFrom) {
    $chainId = $self->_newChainId();
    $statementInsertChainStats->execute($newChainStatsId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
    $statementInsertChains->execute($chainId, $transactionTo, $newChainStatsId);
    
    debugMethodMiddle("FirstTransaction: ChainId:$chainId TransactionTo:$transactionTo MinVal:$minimumValue Length:$length TotalValue:$totalValue NumMinValues:$numberOfMinimumValues");
    
    my $extendedTransaction = Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => $transactionTo,
      chainId => $chainId,
      fromTo => 'to',
    });

    $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
      firstTransaction => 1,
      loopStartEndUserId => $loopStartId,
      extendedTransaction => $extendedTransaction,
    });
    debugMethodMiddle("ReturnVals(To): " . Dumper($transactionsToAnalyseNext));
  }
  else {
    debugMethodMiddle("AnotherTransaction: ChainId:$chainId TransactionTo:$transactionTo MinVal:$minimumValue Length:$length TotalValue:$totalValue NumMinValues:$numberOfMinimumValues");
      
    my $statementMaxTransactionIdForChain = $dbh->prepare("SELECT MAX(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? GROUP BY ChainId");
    $statementMaxTransactionIdForChain->execute($chainId);
    
    my ($highestTransactionId) = $statementMaxTransactionIdForChain->fetchrow_array();

    #For this specific transaction the chain id must remain consistent thoughout the analysis, otherwise the application of
    #DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet will break;
    my $fromTransaction = Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => $transactionFrom,
      chainId => $chainId, 
      fromTo => 'from',
    });
   
        
    #Adding of this transaction will create a branch in the chain.
    #Otherwise it will be equal as you can't have a the from transaction ever being higher because of MAX.
    if ($transactionFrom < $highestTransactionId) {
      my $branchChainId = $self->_newChainId();
      debugMethodMiddle("SeparateBranches: PreviousBranchId:$chainId NewBranchId:$branchChainId");
      
      my $statementInsertBranch = $dbh->prepare("INSERT INTO BranchedTransactions (ChainId_FK, FromTransactionId_FK, ToTransactionId_FK) VALUES (?, ?, ?)");
      $statementInsertBranch->execute($chainId, $transactionFrom, $transactionTo);
      
      #TODO add test.
      my $statementChainsSelect = $dbh->prepare("SELECT TransactionId_FK, ChainStatsId_FK FROM CurrentChains WHERE ChainId = ? AND TransactionId_FK <= ?");
      $statementChainsSelect->execute($chainId, $transactionFrom);
      
      while (my ($transactionId, $chainStatsId) = $statementChainsSelect->fetchrow_array()) {
        $statementInsertChains->execute($branchChainId, $transactionId, $chainStatsId);
      }
      
      #Change the added chain id to the branched one for the insertions below.
      $chainId = $branchChainId; 
    }

    #It does not matter that if the chain id was changed because of the creating a new branch above as
    #there will only be one entry per all of the branches.    
    my $extendedTransaction = Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => $transactionTo,
      chainId => $chainId,
      fromTo => 'to',
    });
    
    #Adds the non branched transaction or final branched transaction.
    $statementInsertChainStats->execute($newChainStatsId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
    $statementInsertChains->execute($chainId, $transactionTo, $newChainStatsId);
    
    debugMethodMiddle("AnotherTransactionVals: ChainId:$chainId TransactionTo:$transactionTo MinVal:$minimumValue Length:$length TotalValue:$totalValue NumMinValues:$numberOfMinimumValues");
    
    $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
      extendedTransaction => $extendedTransaction,
      fromTransaction => $fromTransaction,
      loopStartEndUserId => $loopStartId,
    });
    debugMethodMiddle("ReturnVals(FromAndTo): " . Dumper($transactionsToAnalyseNext));
  }

  debugMethodEnd();  
  return $transactionsToAnalyseNext;
}



sub _getNextBestCandinateTransaction {  
  debugMethodStart();  
  my ($self, $settings) = @_;
  
  my $dbh = $self->dbh;
  
  my $statementSelectNullFrom = $dbh->prepare("SELECT CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CandinateTransactions WHERE TransactionFrom_FK = NULL");
  $statementSelectNullFrom->execute();
  my ($candinateTransactionId, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementSelectNullFrom->fetchrow_array();
  
  my $statementDelete = $dbh->prepare("DELETE FROM CandinateTransactions WHERE CandinateTransactionsId = ?");
  
  #There is at least one first transaction.
  if (defined $candinateTransactionId) {
    my $numberRowsDeleted = $statementDelete->execute($candinateTransactionId);
    
    debugMethodMiddle("Deleted CandinateTransactionId:$candinateTransactionId");
    debugMethodMiddle("ReturnVals(Nulls): hasRow:1 chainId:$chainId transFrom:$transactionFrom transTo:$transactionTo miniValue:$minimumValue Length:$length TotalValue:$totalValue numMinVals:$numberOfMinimumValues");
    
    debugMethodEnd();
    #1 is it has a transaction.
    #Don't return CandinateTransactionsId as it's not needed and is just used to identify and remove one row.
    return [1, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  }
  else {
  
    $settings->applyHeuristicsCandinates();
    
    my $statementSelectRows = $dbh->prepare("SELECT CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CandinateTransactions_ViewIncluded");
    $statementSelectRows->execute();
    
    my ($candinateTransactionId, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementSelectRows->fetchrow_array();
    
    my $hasRow = (defined $transactionTo ? 1 : 0);
    if ($hasRow) {
      $statementDelete->execute($candinateTransactionId);
      debugMethodMiddle("Deleted CandinateTransactionId:$candinateTransactionId");
      debugMethodMiddle("ReturnVals(Non-null): hasRow:$hasRow chainId:".(defined $chainId ? $chainId : "")." transFrom:".(defined $transactionFrom ? $transactionFrom : "")." transTo:$transactionTo miniValue:$minimumValue Length:$length TotalValue:$totalValue numMinVals:$numberOfMinimumValues");
    }
    else {
      debugMethodMiddle("ReturnVals: Empty row");
    }
    

    #Don't return CandinateTransactionsId as it's not needed and is just used to identify and remove one row.
    debugMethodEnd();
    return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  }
}



sub _newChainId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainId = $dbh->prepare("SELECT MAX(ChainId) FROM CurrentChains");
  $statementMaxChainId->execute();
  
  my ($maxId) = $statementMaxChainId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("ChainIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("ChainIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}



sub _newChainStatsId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainStatsId = $dbh->prepare("SELECT MAX(ChainStatsId) FROM CurrentChainsStats");
  $statementMaxChainStatsId->execute();
  
  my ($maxId) = $statementMaxChainStatsId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("ChainStatsIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("ChainStatsIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}



sub _newCandinateTransactionsId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainStatsId = $dbh->prepare("SELECT MAX(CandinateTransactionsId) FROM CandinateTransactions");
  $statementMaxChainStatsId->execute();
  
  my ($maxId) = $statementMaxChainStatsId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("CandinateTransactionsIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("CandinateTransactionsIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}

sub _newLoopId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainStatsId = $dbh->prepare("SELECT MAX(LoopId) FROM LoopInfo");
  $statementMaxChainStatsId->execute();
  
  my ($maxId) = $statementMaxChainStatsId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("LoopIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("LoopIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}


1;
