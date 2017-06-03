use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::ChainTransaction;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Path::Class::File;
use Data::Dumper;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_getNextBestCandidateTransactionAnalysis"

Pear::LocalLoop::Algorithm::Main->setTestingMode();

my $main = Pear::LocalLoop::Algorithm::Main->instance();
my $dbh = $main->dbh;

#Dump all of the test tables.
my $sqlDropSchema = Path::Class::File->new("$FindBin::Bin/../../dropschema.sql")->slurp;
for (split ';', $sqlDropSchema){
  $dbh->do($_) or die $dbh->errstr;
}

my $sqlCreateDatabase = Path::Class::File->new("$FindBin::Bin/../../schema.sql")->slurp;
for (split ';', $sqlCreateDatabase){
  $dbh->do($_) or die $dbh->errstr;
}

my $sqlDeleteDataFromTables = Path::Class::File->new("$FindBin::Bin/../../emptytables.sql")->slurp;
sub delete_table_data {
  for (split ';', $sqlDeleteDataFromTables){
    $dbh->do($_) or die $dbh->errstr;
  }
}

#None is used as it's simple and has little dependencies on the consistency of the data in the database.
#So it's easier to create these tests.
my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

#Only the heuristics are needed for this.
my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({ chainHeuristicArray => $heuristics });

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertChains = $dbh->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");
my $statementInsertCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $selectChainsId = $dbh->prepare("SELECT ChainInfoId_FK FROM Chains WHERE ChainId = ? AND TransactionId_FK = ?");
my $selectChainInfoId = $dbh->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM ChainInfo WHERE ChainInfoId = ?");

my $selectCandidateTransactionsIdCountSingle = $dbh->prepare("SELECT COUNT(*) FROM CandidateTransactions WHERE CandidateTransactionsId = ?");
my $selectChainsIdCountSingle = $dbh->prepare("SELECT COUNT(*) FROM Chains WHERE ChainId = ? AND TransactionId_FK = ?");
my $selectChainInfoIdCountSingle = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo WHERE ChainInfoId = ?");
my $selectBranchedTransactionsIdCountSingle = $dbh->prepare("SELECT COUNT(*) FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? AND ToTransactionId_FK = ?");

my $selectCandidateTransactionCountAll = $dbh->prepare("SELECT COUNT(*) FROM CandidateTransactions");
my $selectChainsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Chains");
my $selectChainInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo");
my $selectBranchedTransactionsCountAll = $dbh->prepare("SELECT COUNT(*) FROM BranchedTransactions");

sub candidateTransactionIdExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectCandidateTransactionsIdCountSingle->execute($id);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectCandidateTransactionsIdCountSingle->fetchrow_array();
  
  return $returnedVal;
}

sub currentChainsIdExists {
  my ($chainId, $transactionId) = @_;
  
  if ( ! defined $chainId) {
    die "chainId cannot be undefined";
  }
  elsif ( ! defined $transactionId ) {
    die "transactionId cannot be undefined";
  }
  
  $selectChainsIdCountSingle->execute($chainId, $transactionId);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectChainsIdCountSingle->fetchrow_array();
  
  return $returnedVal;
}

sub chainStatsIdExists {
  my ($chainStatsId) = @_;
  
  if ( ! defined $chainStatsId) {
    die "chainStatsId cannot be undefined";
  }
  
  $selectChainInfoIdCountSingle->execute($chainStatsId);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectChainInfoIdCountSingle->fetchrow_array();
  
  return $returnedVal;
}

sub branchedTransactionsExists {
  my ($chainId, $fromTransactionId, $toTransactionId) = @_;
  
  if ( ! defined $chainId) {
    die "chainId cannot be undefined";
  }
  elsif ( ! defined $fromTransactionId ) {
    die "fromTransactionId cannot be undefined";
  }
  elsif ( ! defined $toTransactionId ) {
    die "toTransactionId cannot be undefined";
  }
  
  $selectBranchedTransactionsIdCountSingle->execute($chainId, $fromTransactionId, $toTransactionId);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectBranchedTransactionsIdCountSingle->fetchrow_array();
  
  return $returnedVal;
}

sub selectChains {
  my ($chainId, $transactionId) = @_;
  
  if ( ! defined $chainId) {
    die "chainId cannot be undefined";
  }
  elsif ( ! defined $transactionId ) {
    die "transactionId cannot be undefined";
  }
  
  $selectChainsId->execute($chainId, $transactionId);
  return $selectChainsId->fetchrow_array();
}

sub selectCurrentChainStats {
  my ($chainStatsId) = @_;
  
  if ( ! defined $chainStatsId) {
    die "chainStatsId cannot be undefined";
  }
  
  $selectChainInfoId->execute($chainStatsId);
  return $selectChainInfoId->fetchrow_array();
}


sub numCandidateTransactionRows {
  $selectCandidateTransactionCountAll->execute();
  my ($num) = $selectCandidateTransactionCountAll->fetchrow_array();
  
  return $num;
}

sub numChainsRows {
  $selectChainsCountAll->execute();
  my ($num) = $selectChainsCountAll->fetchrow_array();
  
  return $num;
}

sub numChainInfoRows {
  $selectChainInfoCountAll->execute();
  my ($num) = $selectChainInfoCountAll->fetchrow_array();
  
  return $num;
}

sub numBranchedTransactionsRows {
  $selectBranchedTransactionsCountAll->execute();
  my ($num) = $selectBranchedTransactionsCountAll->fetchrow_array();
  
  return $num;
}


#The only things that matter are:
#ProcessedTransactions:
#- TransactionId (Unique)
#Chains:
#- ChainId and TransactionId_FK (Unique)
#ChainInfo:
#- ChainInfoId (Unique for the above)
#CandidateTransactions:
#- CandidateTransactionsId (Unique)
#- ChainId_FK (Null or not null).
#- TransactionFrom_FK (Null or not null).
#- TransactionTo_FK (heuristic order sensitive).

sub compareExtendedTransactionWithTest {
  my ($compareExtendedTransactionGot, $compareExtendedTransactionExpected) = @_;

  isnt ($compareExtendedTransactionGot, undef, "Return value is not undefined.");  
  isnt ($compareExtendedTransactionExpected, undef, "Test value is not undefined.");
  
  my $equals = Pear::LocalLoop::Algorithm::ExtendedTransaction->equals($compareExtendedTransactionGot, $compareExtendedTransactionExpected);
  ok ($equals, "Returned value is correct."); 
  
  #If they are different print them out.
  if ( ! $equals ) {
    print "\n";
    diag("ExtendedTransactionGot:" . Dumper($compareExtendedTransactionGot));
    print "\n";
    diag("ExtendedTransactionExpected:" . Dumper($compareExtendedTransactionExpected));
  }
  
}


say "Test 1 - Empty table";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  is (numCandidateTransactionRows(),0,"There is no candidate transaction rows before invocation.");
  is (numChainsRows(),0,"There is no current chains rows before invocation.");
  is (numChainInfoRows(),0,"There is no current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  my $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
      noCandidateTransactionsLeft => 1,
      loopStartEndUserId => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
  is (numChainsRows(),0,"There is no current chains rows after invocation.");
  is (numChainInfoRows(),0,"There is no current chains stats rows after invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows after invocation.");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


say "Test 2 - First transaction selected (with nulls)";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(1, undef, undef, 1, 10, 1, 10, 1);
 
  is (numCandidateTransactionRows(),1,"There is one candidate transaction row before invocation.");
  is (numChainsRows(),0,"There is no current chains rows before invocation.");
  is (numChainInfoRows(),0,"There is no current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    loopStartEndUserId => $startLoopId,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
  is (candidateTransactionIdExists(1), 0,"Candidate transaction id 1 has been removed.");
    
  is (numChainsRows(),1,"There is one current chains row after invocation.");
  is (currentChainsIdExists(1, 1), 1,"Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),1,"One chains stats row has been added after invocation.");
  my ($chainStatsId) = selectChains(1, 1); #It exists above so is fine.
  is ($chainStatsId, 1, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsId);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 1, "length is the same value we passed in.");
  is ($totalValue, 10, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows after invocation.");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


say "Test 3 - Not first transaction selected (non-null), selection of transaction at the end of a chain, chain size 1.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(2, 1, 1, 3, 10, 2, 20, 2);
 
  is (numCandidateTransactionRows(),1,"There is 1 candidate transaction row before invocation.");
  is (numChainsRows(),1,"There is 1 current chains row before invocation.");
  is (numChainInfoRows(),1,"There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 3,
      chainId => 1,
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1, 
      fromTo => 'from',
    }),
    loopStartEndUserId => $startLoopId,
  });
  

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
    
  is (numChainsRows(),2,"There is 2 current chains rows after invocation.");
  is (currentChainsIdExists(1, 1), 1,"Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 3), 1,"Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),2,"One chains stats row has been added after invocation.");
  my ($chainStatsId) = selectChains(1, 3); #It exists above so is fine.
  is ($chainStatsId, 2, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsId);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 2, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows after invocation.");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


say "Test 4 - Not first transaction selected (non-null), selection of transaction at the end of a chain, chain size more than 1.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 3, 2);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(3, 1, 3, 4, 10, 3, 30, 3);
 
  is (numCandidateTransactionRows(),1,"There is one candidate transaction row before invocation.");
  is (numChainsRows(),2,"There is 2 current chains rows before invocation.");
  is (numChainInfoRows(),2,"There is 2 current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 4,
      chainId => 1,
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 3,
      chainId => 1, 
      fromTo => 'from',
    }),
    loopStartEndUserId => $startLoopId,
  });
  

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
    
  is (numChainsRows(), 3, "There is 2 current chains rows after invocation.");
  is (currentChainsIdExists(1, 1), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 3), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 4), 1, "Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),3,"One chains stats row has been added after invocation.");
  my ($chainStatsId) = selectChains(1, 4); #It exists above so is fine.
  is ($chainStatsId, 3, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsId);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 3, "length is the same value we passed in.");
  is ($totalValue, 30, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 3, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows after invocation.");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


say "Test 5 - Not first transaction selected (non-null), selection of transaction at start/middle of the chain, chain size 2.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 2, 4, 20);
  $statementInsertProcessedTransactions->execute(5, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(6, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 3, 2);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  #Actually another candidate transaction will be here from transacion 3 to 5, but we'll ignore that and 
  #force this.
  $statementInsertCandidateTransactions->execute(4, 1, 1, 4, 10, 2, 30, 1);
 
  is (numCandidateTransactionRows(),1,"There is one candidate transaction row before invocation.");
  is (numChainsRows(),2,"There is 2 current chains rows before invocation.");
  is (numChainInfoRows(),2,"There is 2 current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 4,
      chainId => 2, #As it branches the chain id increments.
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1, 
      fromTo => 'from',
    }),
    loopStartEndUserId => $startLoopId,
  });


  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
    
  is (numChainsRows(), 4, "There is 4 current chains rows after invocation.");
  is (currentChainsIdExists(1, 1), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 3), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(2, 1), 1, "Chain has been added."); #ChainId, TransactionId
  is (currentChainsIdExists(2, 4), 1, "Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),3,"One chains stats row has been added after invocation.");
  my ($chainStatsIdTx1) = selectChains(2, 1); #It exists above so is fine.
  is ($chainStatsIdTx1, 1, "The new branch reuses the old chainStatsId from the other chain.");
  my ($chainStatsIdTx4) = selectChains(2, 4); #It exists above so is fine, This will be 3
  is ($chainStatsIdTx4, 3, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsIdTx4);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 30, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(),1,"There is 1 branched transaction row after invocation.");
  #ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
  is (branchedTransactionsExists(1, 1, 4),1,"A branch has been created");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}



say "Test 6 - Not first transaction selected (non-null), select transaction at the start of the chain, chain size 3 or more.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 2, 4, 20);
  $statementInsertProcessedTransactions->execute(5, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(6, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  $statementInsertCurrentStatsId->execute(3, 10, 3, 30, 3);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 3, 2);
  $statementInsertChains->execute(1, 5, 3);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  #Actually another candidate transactions would be here too but we'll ignore that and force this one.
  $statementInsertCandidateTransactions->execute(4, 1, 1, 4, 10, 2, 30, 1);
 
  is (numCandidateTransactionRows(),1,"There is one candidate transaction row before invocation.");
  is (numChainsRows(),3,"There is 3 current chains rows before invocation.");
  is (numChainInfoRows(),3,"There is 3 current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 4,
      chainId => 2, #As it branches the chain id increments.
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1, 
      fromTo => 'from',
    }),
    loopStartEndUserId => $startLoopId,
  });


  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
    
  is (numChainsRows(), 5, "There is 5 current chains rows after invocation.");
  is (currentChainsIdExists(1, 1), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 3), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 5), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(2, 1), 1, "Chain has been added."); #ChainId, TransactionId
  is (currentChainsIdExists(2, 4), 1, "Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),4,"One chains stats row has been added after invocation.");
  my ($chainStatsIdTx1) = selectChains(2, 1); #It exists above so is fine.
  is ($chainStatsIdTx1, 1, "The new branch reuses the old chainStatsId from the other chain.");
  my ($chainStatsIdTx4) = selectChains(2, 4); #It exists above so is fine, This will be 4
  is ($chainStatsIdTx4, 4, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsIdTx4);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 30, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(), 1, "There is 1 branched transaction row after invocation.");
  #ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
  is (branchedTransactionsExists(1, 1, 4), 1, "A branch has been created");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


say "Test 7 - Not first transaction selected (non-null), select transaction in the middle of the chain, chain size 3 or more.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 2, 4, 20);
  $statementInsertProcessedTransactions->execute(5, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(6, 3, 1, 20);
  $statementInsertProcessedTransactions->execute(7, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  $statementInsertCurrentStatsId->execute(3, 10, 3, 30, 3);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 3, 2);
  $statementInsertChains->execute(1, 5, 3);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  #Actually another candidate transactions would be here too but we'll ignore that and force this one.
  $statementInsertCandidateTransactions->execute(4, 1, 3, 6, 10, 3, 40, 2);
 
  is (numCandidateTransactionRows(),1,"There is one candidate transaction row before invocation.");
  is (numChainsRows(),3,"There is 3 current chains rows before invocation.");
  is (numChainInfoRows(),3,"There is 3 current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(),0,"There is no branched transaction rows before invocation.");
  

  my $returnVal = undef;
  my $exception = exception { $returnVal = $main->_getNextBestCandidateTransactionAnalysis($settings, $startLoopId); };
  is ($exception, undef ,"No exception thrown");
  
  $expectedReturnVal = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 6,
      chainId => 2, #As it branches the chain id increments.
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 3,
      chainId => 1, 
      fromTo => 'from',
    }),
    loopStartEndUserId => $startLoopId,
  });


  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows after invocation.");
    
  is (numChainsRows(), 6, "There is 6 current chains rows after invocation.");
  is (currentChainsIdExists(1, 1), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 3), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(1, 5), 1, "Chain remains."); #ChainId, TransactionId. Already existed.
  is (currentChainsIdExists(2, 1), 1, "Chain has been added."); #ChainId, TransactionId
  is (currentChainsIdExists(2, 3), 1, "Chain has been added."); #ChainId, TransactionId
  is (currentChainsIdExists(2, 6), 1, "Chain has been added."); #ChainId, TransactionId
  
  is (numChainInfoRows(),4,"One chains stats row has been added after invocation.");
  my ($chainStatsIdTx1) = selectChains(2, 1); #It exists above so is fine.
  is ($chainStatsIdTx1, 1, "The new branch reuses the old chainStatsId from the other chain (Transaction 1).");
  my ($chainStatsIdTx3) = selectChains(2, 3); #It exists above so is fine.
  is ($chainStatsIdTx3, 2, "The new branch reuses the old chainStatsId from the other chain (Transaction 3).");
  my ($chainStatsIdTx4) = selectChains(2, 6); #It exists above so is fine, This will be 4
  is ($chainStatsIdTx4, 4, "A new chain stats row has been created.");
  my ($minimumValue, $length, $totalValue, $numOfMinValues) = selectCurrentChainStats($chainStatsIdTx4);
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 3, "length is the same value we passed in.");
  is ($totalValue, 40, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 2, "numOfMinValues is the same value we passed in.");
  
  is (numBranchedTransactionsRows(), 1, "There is 1 branched transaction rows after invocation.");
  #ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
  is (branchedTransactionsExists(1, 3, 6), 1, "A branch has been created");
  
  compareExtendedTransactionWithTest($returnVal, $expectedReturnVal);
}


done_testing();
