package Pear::LocalLoop::Algorithm::Main;

use Moo;
with 'MooX::Singleton';

use v5.10;
use DBI;
use Data::Dumper;
use Carp::Always;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;
use Pear::LocalLoop::Algorithm::Debug;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::ChainTransaction;
use Pear::LocalLoop::Algorithm::ChainGenerationContext;
use Pear::LocalLoop::Algorithm::LoopGenerationContext;


#FIXME move into a config file and dynamically read it in.
#Non-testing debug database.
my $dbConfig = {
  dsn => "dbi:SQLite:dbname=transactions.db",
  user => undef,
  pass => undef,
};

#Testing debug database.
my $dbTestConfig = {
#  dsn => "dbi:SQLite:dbname=transactions-test.db",
  dsn => "dbi:SQLite:dbname=:memory:",
  user => undef,
  pass => undef,
};

#Create new non-testing database interface handle.
sub _dbi {
  my $self = shift;
  my $handle = DBI->connect($dbConfig->{dsn},$dbConfig->{user},$dbConfig->{pass}) or die "Could not connect";
  return $handle;
};

#Create new Testing database interface handle.
#Note: with in memory databases this will generate a new database each time.
sub _dbi_test {
  my $self = shift;
  return DBI->connect($dbTestConfig->{dsn},$dbTestConfig->{user},$dbTestConfig->{pass});
};

#Main's handle to the database
has dbh => (
  is => 'ro',
  default => sub { return dbi(); },
  lazy => 1,
);

#Static functions to set or clear testing mode.
sub setTestingMode {
  $ENV{'MODE'} = "testing";
}

sub clearTestingMode {
  $ENV{'MODE'} = undef;
}

#Get database handle taking into consideration whether we are in testing mode or not.
sub dbi {
  my $mode = $ENV{'MODE'};
  if (defined $mode && $mode eq "testing") {
    return _dbi_test();
  }
  else {
    return _dbi();
  }
}



has _statementDeleteTuplesProcessedTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM ProcessedTransactions");
  },
  lazy => 1,
);

has _statementIntoTuplesFromOriginalTransactionsIntoProcessedTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) SELECT * FROM OriginalTransactions");
  },
  lazy => 1,
);

sub process {
  debugMethodStart();
  my ($self, $settings) = @_;
  
  #TODO add more checks for settings.
  if (! defined $settings) {
    die "Settings are undefined";
  }
  
  my $dbh = $self->dbh or die "Database does not exist";  
  
  debugMethodMiddle("Inputted settings:");
  say ("\n".Dumper($settings));
    
  #Disable auto commit to increase processing speed.
  $dbh->{AutoCommit} = 0;
  
  #Clear the previous processing transactions state and clone the original transactions.
  $self->_statementDeleteTuplesProcessedTransactions()->execute();
  $self->_statementIntoTuplesFromOriginalTransactionsIntoProcessedTransactions()->execute();
  
  $settings->init(); #Initialise the settings
    
  $settings->applyStaticRestrictions();
  $settings->initAfterStaticRestrictions(); #Initialise post static restrictions.
  
  $dbh->commit();
  
  debugMethodMiddle("Before loop");
  
  my $counter = 1;
  
  #Select a starting point for loop generation.
  for (my $nextTransactionId = $settings->nextTransactionId(); 
    defined $nextTransactionId; 
    $nextTransactionId = $settings->nextTransactionId(), $counter++)
  {
    say "$counter"; #Keep track of how well it's doing.
    
    debugMethodMiddle("TransactionLoop: $nextTransactionId");
    
    $self->_loopGeneration($settings, $nextTransactionId);
    
    #Incremented commit so state can be inspected, also if it crashes then loops will be safe.
    if (($counter % 250) == 0) {
      $dbh->commit();
    }
  }
  
  debugMethodMiddle("After loop");
  
  #This may be here or the last line in the for loop, depending on when you want the loops to be selected.
  $self->_loopSelection($settings);
  
  $dbh->commit();
  $dbh->{AutoCommit} = 1;
  
  debugMethodEnd();
}

has _statementSelectLoopIdWhereItsIncluded => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT LoopId FROM LoopInfo_ViewIncluded LIMIT 1");
  },
  lazy => 1,
);

has _statementUpdateLoopInfoSetActiveToOneWhereLoopIdSpecified => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Active = 1 WHERE LoopId = ?");
  },
  lazy => 1,
);

has _statementUpdateLoopInfoSetActiveToZeroWhereActiveIsNotZero => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Active = 0 WHERE Active != 0");
  },
  lazy => 1,
);

#Select loops given the settings.
sub _loopSelection {
  debugMethodStart();
  my ($self, $settings) = @_;
  my $dbh = $self->dbh;
  
  my $statementSelectOneIncludedLoopId = $self->_statementSelectLoopIdWhereItsIncluded();
  my $statementSetLoopToActive = $self->_statementUpdateLoopInfoSetActiveToOneWhereLoopIdSpecified();
  my $statementResetAllActiveLoops = $self->_statementUpdateLoopInfoSetActiveToZeroWhereActiveIsNotZero();
  
  $statementResetAllActiveLoops->execute();
  
  my $counter = 1;
  #Insert one loop at a time as the activating of a loop may break the other loops (consistency of the loops).
  my $loopId = undef; 
  do {
    say "$counter"; #Keeps track of progress
    
    $settings->applyLoopDynamicRestrictionsAndHeuristics();
    $statementSelectOneIncludedLoopId->execute();
    ($loopId) = $statementSelectOneIncludedLoopId->fetchrow_array();
    
    #Set a loop id to be active while it can fit in.
    if (defined $loopId) {
      $statementSetLoopToActive->execute($loopId);
    }
    
    $counter++;
  } while (defined $loopId); #Continue looping while loops can co-exist.
  
  debugMethodEnd();
}



has _statementDeleteTuplesCandidateTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM CandidateTransactions");
  },
  lazy => 1,
);

has _statementDeleteTuplesBranchedTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM BranchedTransactions");
  },
  lazy => 1,
);

has _statementDeleteTuplesChains => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM Chains");
  },
  lazy => 1,
);

has _statementDeleteTuplesChainInfo => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM ChainInfo");
  },
  lazy => 1,
);

has _statementSelectFromUserIdAndValueOfATransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT FromUserId, Value FROM ProcessedTransactions WHERE TransactionId = ?");
  },
  lazy => 1,
);

has _statementInsertIntoCandidateTransactionsAllParamsExceptIncludedAndHeuristic => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
  },
  lazy => 1,
);

has _statementSelectTheChainIdWhichCouldFormALoop => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT Result.ChainId FROM ProcessedTransactions, (SELECT Chains.ChainId AS ChainId, MAX(Chains.TransactionId_FK) AS MaxTransactionId FROM Chains GROUP BY Chains.ChainId) AS Result WHERE Result.MaxTransactionId = ProcessedTransactions.TransactionId AND ProcessedTransactions.ToUserId = ?");
  },
  lazy => 1,
);


has _statementSelectFirstAndLastTransactionsInASpecfiedChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId_FK), MAX(TransactionId_FK) FROM Chains WHERE ChainId = ? GROUP BY ChainId");
  },
  lazy => 1,
);

has _statementSelectChainInfoIdFromChainsGivenSpecifiedChainIdAndTransactionId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT ChainInfoId_FK FROM Chains WHERE ChainId = ? AND TransactionId_FK = ?");
  },
  lazy => 1,
);

has _statementSelectChainStatsGivenAChainInfoId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM ChainInfo WHERE ChainInfoId = ?");
  },
  lazy => 1,
);

has _statementInsertIntoLoopInfoNewTupleExcludingActiveIncludedAndHeuristic => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO LoopInfo (LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?)");
  },
  lazy => 1,
);

has _statementInsertIntoLoopsSpecifiedLoopIdWithAllOfTheTransactionsInAChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) SELECT ?, TransactionId_FK FROM Chains WHERE ChainId = ?");
  },
  lazy => 1,
);

#Generates loops based on the settings and transaction id selected.
sub _loopGeneration {
  debugMethodStart();
  #we assume the nextTransaction id is valid.
  my ($self, $settings, $nextTransactionId) = @_;
  
  debugMethodMiddle("NextTransactionId:$nextTransactionId");

  #Clear previous loop generation state.
  $self->_statementDeleteTuplesCandidateTransactions()->execute();  
  $self->_statementDeleteTuplesBranchedTransactions()->execute();
  $self->_statementDeleteTuplesChains()->execute();
  $self->_statementDeleteTuplesChainInfo()->execute();
  
  my $statementTransactionValue = $self->_statementSelectFromUserIdAndValueOfATransaction();
  $statementTransactionValue->execute($nextTransactionId); 
  my ($fromUserId, $transactionValue) = $statementTransactionValue->fetchrow_array();
  
  my $loopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $fromUserId,
  });
  
  debugMethodMiddle("Candidate fromUserId:$fromUserId value:$transactionValue");
  
  my $candidateId = $self->_newCandidateTransactionsId();
  my $statementInsertCandidate = $self->_statementInsertIntoCandidateTransactionsAllParamsExceptIncludedAndHeuristic();

  #Insert initial transaction.
  $statementInsertCandidate->execute($candidateId, undef, undef, $nextTransactionId, $transactionValue, 1, $transactionValue, 1);
  debugMethodMiddle("Inserted inital transaction candidate");
  
  my $extendedTransaction = undef;
  
  #Loop while it has not found a loop and has candidate transactions left then continue looping
  while ( ! ($extendedTransaction = $self->_candidateSelection($settings, $loopGenerationContext))->hasFinished($loopGenerationContext) ) {
    debugMethodMiddle("Loop generation while loop start");
    
    $self->_candidateInsertion($settings, $extendedTransaction, $loopGenerationContext);
    
    debugMethodMiddle("Loop generation while loop end");
  }
  
  #Insert all of the remaining candidate transactions, so equal candidates can be found.
  #This also can mean poor candidates can be added, however in the next section the filtering should take
  #care of this. Also as we have processed the loops we may as well store them it would a waste of resouces 
  #not to, as some other loop may become inactive which results in these poor loops becoming active.
  while ( ! $extendedTransaction->noCandidateTransactionsLeft() ) {
    $extendedTransaction = $self->_candidateSelection($settings, $loopGenerationContext);
  }
  

  #What chains are loops?
  my $statementLoops = $self->_statementSelectTheChainIdWhichCouldFormALoop();
  $statementLoops->execute($fromUserId);
  
  #Store a list as we can't have a select and insert statement executed at the same time on a SQLite database.
  my $chainIdsWhichAreLoops = [];
  while (my ($chainId) = $statementLoops->fetchrow_array()) {
    push(@$chainIdsWhichAreLoops, $chainId);
  }
  
  #say Dumper($chainIdsWhichAreLoops);
  
  
  my $statementGetChainMinMax = $self->_statementSelectFirstAndLastTransactionsInASpecfiedChain();
  my $statementGetChainInfoId = $self->_statementSelectChainInfoIdFromChainsGivenSpecifiedChainIdAndTransactionId();
  my $statementGetChainStats = $self->_statementSelectChainStatsGivenAChainInfoId();
  my $statementInsertStats = $self->_statementInsertIntoLoopInfoNewTupleExcludingActiveIncludedAndHeuristic();
  my $statementInsert = $self->_statementInsertIntoLoopsSpecifiedLoopIdWithAllOfTheTransactionsInAChain();
  
  #Generate a list of new loop ids.
  my $newLoopIds = [];
  #TODO think about how to detect duplicate loops.
  foreach my $chainId (@{$chainIdsWhichAreLoops}) {
    my $newUniqueLoopId = $self->_newLoopId();
    push(@$newLoopIds, $newUniqueLoopId);
    
    #Get first and last transaction.
    $statementGetChainMinMax->execute($chainId);
    my ($minTransactionId, $maxTransactionId) = $statementGetChainMinMax->fetchrow_array();
    
    #Get information about the chain that will be a loop.
    $statementGetChainInfoId->execute($chainId, $maxTransactionId);
    my ($chainStatsId) = $statementGetChainInfoId->fetchrow_array();
    $statementGetChainStats->execute($chainStatsId);
    my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementGetChainStats->fetchrow_array();
    
    #Insert the chain information into the loops tables.
    $statementInsertStats->execute($newUniqueLoopId, $minTransactionId, $maxTransactionId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
    #Copy a loop from the chains table into the loops table.
    $statementInsert->execute($newUniqueLoopId, $chainId);
  }
  

  debugMethodEnd();
  return $newLoopIds;
}


has _statementSelectProcessedTransactionValue => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT Value FROM ProcessedTransactions WHERE TransactionId = ?");
  },
  lazy => 1,
);

has _statementSelectAllIncludedTransactionsInProcessedTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT TransactionId FROM ProcessedTransactions_ViewIncluded");
  },
  lazy => 1,
);

has _statementSelectTheNumberOfTransactionsFromTheSamePointInTheChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT COUNT(ChainId_FK) FROM CandidateTransactions WHERE ChainId_FK = ? AND TransactionFrom_FK = ?");
  },
  lazy => 1,
);

#Given a selected candidate transaction insert the next candidate transactions using the from transaction and to transaction.
#Note: the test for this function is limited to that only the differences in the pass with 2 transactions (from and to)
#are tested. We assume if it can execute the same code path with just the one transaction (to) it will work
#when there is 2.
#If this function is changed structurally in which the assumption becomes false then update the test too.
sub _candidateInsertion {
  debugMethodStart();
  my ($self, $settings, $extendedTransaction, $loopGenerationContextInstance) = @_;
  
  my $userIdThatFormsALoop = $loopGenerationContextInstance->userIdWhichCreatesALoop();
 
  my $statementTransactionValue = $self->_statementSelectProcessedTransactionValue();
  my $statementInsertCandidate = $self->_statementInsertIntoCandidateTransactionsAllParamsExceptIncludedAndHeuristic();
  my $statementSelectIncludedTransactions = $self->_statementSelectAllIncludedTransactionsInProcessedTransactions();
  my $statementTransactionsExistFromSameChain = $self->_statementSelectTheNumberOfTransactionsFromTheSamePointInTheChain();

  
  #ChainTransaction instance or undef. Extended transaction will always be not null otherwise it would 
  #not be in this loop.
  my $toTransaction = $extendedTransaction->extendedTransaction();
  my $fromTransaction = $extendedTransaction->fromTransaction();
  
  
  my $transactionsToAnalyse = [$toTransaction]; 
  if (defined $fromTransaction) {
    debugMethodMiddle("WhileLoop PushedFromTransaction");
    push(@$transactionsToAnalyse, $fromTransaction);
  }
  
  #For a specified transaction insert the next candidate transactions.
  foreach my $chainTransaction (@{$transactionsToAnalyse}) {
    debugBraceStart("ForEachLoop 2Trans.");
    
    my $chainId = $chainTransaction->chainId();
    my $transactionId = $chainTransaction->transactionId();
    my $fromTo = $chainTransaction->fromTo();
    debugMethodMiddle("WhileLoop: ForEachLoop. ChainId:$chainId TransactionId:$transactionId From/To:$fromTo");

    
    #This is here to prevent the adding of any transactions to the candidates table if some already exist 
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
    my $chainGenerationContext = Pear::LocalLoop::Algorithm::ChainGenerationContext->new({
      currentChainId => $chainId,
      currentTransactionId => $transactionId, 
      userIdWhichCreatesALoop => $userIdThatFormsALoop,
    });

    $settings->applyChainDynamicRestrictionsAndHeuristics($chainGenerationContext);

    debugMethodMiddle("WhileLoop: ForEachLoop. Done heuristics");
    
    #Get the information about a transaction uptil its point in the chain
    my $statementChainInfoId = $self->_statementSelectChainInfoIdFromChainsGivenSpecifiedChainIdAndTransactionId();
    $statementChainInfoId->execute($chainId, $transactionId);
    my ($chainStatsId) = $statementChainInfoId->fetchrow_array();
    my $statementChainStats = $self->_statementSelectChainStatsGivenAChainInfoId();
    $statementChainStats->execute($chainStatsId);    
    my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = $statementChainStats->fetchrow_array();

    debugMethodMiddle("WhileLoop: ForEachLoop. BaseValue MinValue:$minimumValue Length:$length TotalValue:$totalValue NumOfMinValues:$numberOfMinimumValues");

    #Get all transactions that are applicable after all restriction and heuristics.
    $statementSelectIncludedTransactions->execute();
    
    #We assume they connected together.
    while (my ($candidateTransactionId) = $statementSelectIncludedTransactions->fetchrow_array()) {
      debugBraceStart("While loop best next trans.");
      debugMethodMiddle("WhileLoop: ForEachLoop. CandidateTransactionId:$candidateTransactionId");
      $statementTransactionValue->execute($candidateTransactionId);
      my ($candidateValue) = $statementTransactionValue->fetchrow_array();
      
      my $isValueLower = ($candidateValue < $minimumValue);
      my $isValueSame = ($candidateValue == $minimumValue);
      
      #Calculate stats of the candidate transaction
      my $thisMinimumValue = ($isValueLower ? $candidateValue : $minimumValue);
      my $thisLength = $length + 1;
      my $thisTotalValue = $totalValue + $candidateValue;
      my $thisNumberOfMinimumValues = ($isValueLower ? 1 : ($isValueSame ? ($numberOfMinimumValues + 1) : $numberOfMinimumValues));

      my $candidateId = $self->_newCandidateTransactionsId();
      
      debugMethodMiddle("WhileLoop: ForEachLoop. EnteredCandidateValues CandidateId:$candidateId chainId:$chainId fromTransaction:$transactionId toTransaction:$candidateTransactionId MinValue:$thisMinimumValue Length:$thisLength TotalValue:$thisTotalValue NumOfMinValues:$thisNumberOfMinimumValues");
      
      #Insert the new candidate transactions
      $statementInsertCandidate->execute($candidateId, $chainId, $transactionId, $candidateTransactionId, $thisMinimumValue, $thisLength, $thisTotalValue, $thisNumberOfMinimumValues);
      
      debugBraceEnd("While loop best next trans.");      
    }
    debugBraceEnd("ForEachLoop 2Trans.");
  }
  debugMethodEnd();
}



has _statementInsertIntoCurrentChainChainIdTransactionIdAndChainInfoId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");
  },
  lazy => 1,
);

has _statementInsertIntoChainInfoIdMinValueLengthTotalValueAndNumMinValues => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
  },
  lazy => 1,
);

has _statementSelectLastTransactionIdInAChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MAX(TransactionId_FK) FROM Chains WHERE ChainId = ? GROUP BY ChainId");
  },
  lazy => 1,
);

has _statementInserIntoBranchedTransactionChainIdFromTransactionIdAndToTransactionId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("INSERT INTO BranchedTransactions (ChainId_FK, FromTransactionId_FK, ToTransactionId_FK) VALUES (?, ?, ?)");
  },
  lazy => 1,
);

has _statementSelectTransactionIdAndChainInfoIdFromTheSpecifiedChainIdAndOnOrBeforeTheSpecifiedTrasactionId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT TransactionId_FK, ChainInfoId_FK FROM Chains WHERE ChainId = ? AND TransactionId_FK <= ?");
  },
  lazy => 1,
);


has _statementSelectCandidateTransactionInformationWhenItsAFirstTransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CandidateTransactions WHERE TransactionFrom_FK IS NULL AND ChainId_FK IS NULL");
  },
  lazy => 1,
);

has _statementDeleteCandidateTransactionBasedOnItsId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("DELETE FROM CandidateTransactions WHERE CandidateTransactionsId = ?");
  },
  lazy => 1,
);

has _statementSelectCandidateTransactionInformationWhenItsIncluded => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CandidateTransactions_ViewIncluded");
  },
  lazy => 1,
);

#Select which candinate transaction to extend from.
sub _candidateSelection {
  debugMethodStart();  
  my ($self, $settings, $loopGenerationContextInstance) = @_;
  
  my $statementInsertChains = $self->_statementInsertIntoCurrentChainChainIdTransactionIdAndChainInfoId();
  my $statementInsertChainStats = $self->_statementInsertIntoChainInfoIdMinValueLengthTotalValueAndNumMinValues();
  my $statementDelete = $self->_statementDeleteCandidateTransactionBasedOnItsId();
  
  #See if there are any first transactions will null from transaction and chain id.
  my $statementSelectNullFrom = $self->_statementSelectCandidateTransactionInformationWhenItsAFirstTransaction();
  $statementSelectNullFrom->execute();
  my $nullResult = $statementSelectNullFrom->fetchrow_arrayref();
  
  
  #There is at least one first transaction.
  if (defined $nullResult) {
    debugMethodMiddle("Has first transaction");
    my ($candidateTransactionId, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = @{$nullResult};
    
  #Delete the candidate from the database.
    my $numberRowsDeleted = $statementDelete->execute($candidateTransactionId);
    debugMethodMiddle("Deleted CandidateTransactionId:$candidateTransactionId");    
    
    #Add the first transaction into the database with a new chain id.
    my $chainId = $self->_newChainId();
    my $newChainInfoId = $self->_newChainInfoId();  
    $statementInsertChainStats->execute($newChainInfoId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
    $statementInsertChains->execute($chainId, $transactionTo, $newChainInfoId);
    
    debugMethodMiddle("FirstTransaction: ChainId:$chainId TransactionTo:$transactionTo MinVal:$minimumValue Length:$length TotalValue:$totalValue NumMinValues:$numberOfMinimumValues");
    
    my $extendedTransaction = Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => $transactionTo,
      chainId => $chainId,
      fromTo => 'to',
    });

    my $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
      firstTransaction => 1,
      extendedTransaction => $extendedTransaction,
    });
    
    debugMethodMiddle("Nulls Finished: " . Dumper($transactionsToAnalyseNext));
    debugMethodEnd();  
    return $transactionsToAnalyseNext;
  }
  #There is no first transactions
  else {
    debugMethodMiddle("Hasn't first transaction");
  
    $settings->applyChainHeuristicsCandidates($loopGenerationContextInstance);
  
    my $statementSelectRows = $self->_statementSelectCandidateTransactionInformationWhenItsIncluded();
    $statementSelectRows->execute();
    
    my $candinateTransactionRowRef = $statementSelectRows->fetchrow_arrayref();
    #say "Ref: " . Dumper ($candinateTransactionRowRef);
    
    #There are no rows left
    if (! defined $candinateTransactionRowRef) {
      debugMethodMiddle("No candidate transaction rows left.");
      my $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
        noCandidateTransactionsLeft => 1,
      });
      
      debugMethodMiddle("No row finished: " . Dumper($transactionsToAnalyseNext));
      debugMethodEnd();  
      return $transactionsToAnalyseNext;
    }
    #There are candidates left.
    else {
      debugMethodMiddle("Has a candidate transaction row.");
      my ($candidateTransactionId, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues) =
        @{$candinateTransactionRowRef};
      debugMethodMiddle("Row values: chainId:$chainId transFrom:$transactionFrom transTo:$transactionTo miniValue:$minimumValue Length:$length TotalValue:$totalValue numMinVals:$numberOfMinimumValues");
      
      #Delete the candidate from the database.
      $statementDelete->execute($candidateTransactionId);
      debugMethodMiddle("Deleted CandidateTransactionId:$candidateTransactionId");
      
      #Find the maximum transaction id to determine if the candidate is the last transaction or not.
      my $statementMaxTransactionIdForChain = $self->_statementSelectLastTransactionIdInAChain();
      $statementMaxTransactionIdForChain->execute($chainId);
      my ($highestTransactionId) = $statementMaxTransactionIdForChain->fetchrow_array();

      #For this specific transaction the chain id must remain consistent thoughout the analysis, otherwise the application of
      #DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet will break, So it's important it's before
      #the branch management.
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
        
        #Add tuple noting it has branched
        my $statementInsertBranch = $self->_statementInserIntoBranchedTransactionChainIdFromTransactionIdAndToTransactionId();
        $statementInsertBranch->execute($chainId, $transactionFrom, $transactionTo);
        
        #Select all transactions from a chain upto the point of branching
        my $statementChainsSelect = $self->_statementSelectTransactionIdAndChainInfoIdFromTheSpecifiedChainIdAndOnOrBeforeTheSpecifiedTrasactionId();
        $statementChainsSelect->execute($chainId, $transactionFrom);
        
        #Clone the chain upto the branching point.
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
      
      my $newChainInfoId = $self->_newChainInfoId();  
      
      #Adds the non branched transaction or final branched transaction.
      $statementInsertChainStats->execute($newChainInfoId, $minimumValue, $length, $totalValue, $numberOfMinimumValues);
      $statementInsertChains->execute($chainId, $transactionTo, $newChainInfoId);
      
      debugMethodMiddle("AnotherTransactionVals: ChainId:$chainId TransactionTo:$transactionTo MinVal:$minimumValue Length:$length TotalValue:$totalValue NumMinValues:$numberOfMinimumValues");
      
      my $transactionsToAnalyseNext = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
        extendedTransaction => $extendedTransaction,
        fromTransaction => $fromTransaction,
      });
      
      debugMethodMiddle("ReturnVals(FromAndTo): " . Dumper($transactionsToAnalyseNext));
      debugMethodEnd();         
      return $transactionsToAnalyseNext;
    }
  }
}



has _statementSelectMaxChainId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MAX(ChainId) FROM Chains");
  },
  lazy => 1,
);

# Return a unique identifer that can be used as part of the primary key in the Chains table.
sub _newChainId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainId = $self->_statementSelectMaxChainId();
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



has _statementSelectMaxChainInfoId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MAX(ChainInfoId) FROM ChainInfo");
  },
  lazy => 1,
);

# Return a unique identifer that can be used as the primary key in the ChainInfo table.
sub _newChainInfoId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainInfoId = $self->_statementSelectMaxChainInfoId();
  $statementMaxChainInfoId->execute();
  
  my ($maxId) = $statementMaxChainInfoId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("ChainInfoIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("ChainInfoIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}



has _statementSelectMaxCandidateTransactionsId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MAX(CandidateTransactionsId) FROM CandidateTransactions");
  },
  lazy => 1,
);

# Return a unique identifer that can be used as the primary key in the CandidateTransactions table.
sub _newCandidateTransactionsId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainInfoId = $self->_statementSelectMaxCandidateTransactionsId();
  $statementMaxChainInfoId->execute();
  
  my ($maxId) = $statementMaxChainInfoId->fetchrow_array();
  
  my $id = undef;
  if (defined $maxId) {
    $id = $maxId + 1;
    debugMethodMiddle("CandidateTransactionsIdExists = $id");
  }
  #No chains so there is no value
  else {
    $id = 1;
    debugMethodMiddle("CandidateTransactionsIdDoesn'tExist = $id");
  }
  
  debugMethodEnd();
  return $id;
}



has _statementSelectMaxLoopId => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MAX(LoopId) FROM LoopInfo");
  },
  lazy => 1,
);


# Return a unique identifer that can be used as the primary key in the LoopId table.
sub _newLoopId {
  debugMethodStart();
  
  my ($self) = @_;
  my $dbh = $self->dbh;

  my $statementMaxChainInfoId = $self->_statementSelectMaxLoopId();
  $statementMaxChainInfoId->execute();
  
  my ($maxId) = $statementMaxChainInfoId->fetchrow_array();
  
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
