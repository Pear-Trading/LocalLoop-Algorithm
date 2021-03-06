use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_newCandidateTransactionsId"

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



my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertChains = $dbh->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");
my $statementInsertCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $selectProcessedTransactionsCountAll = $dbh->prepare("SELECT COUNT(*) FROM ProcessedTransactions");
my $selectChainInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo");
my $selectChainsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Chains");


sub initialise { 
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 5, 10);
  $statementInsertProcessedTransactions->execute(5, 5, 6, 10);
  $statementInsertProcessedTransactions->execute(6, 6, 1, 10);
  
  #It does not matter what these values are.
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 2, 1);
  $statementInsertChains->execute(1, 3, 1);
  $statementInsertChains->execute(1, 4, 1);
  $statementInsertChains->execute(1, 5, 1);
  $statementInsertChains->execute(1, 6, 1);

}

sub numProcessedTransactionsRows {
  $selectProcessedTransactionsCountAll->execute();
  my ($num) = $selectProcessedTransactionsCountAll->fetchrow_array();
  
  return $num;
}

sub numChainInfoRows {
  $selectChainInfoCountAll->execute();
  my ($num) = $selectChainInfoCountAll->fetchrow_array();
  
  return $num;
}

sub numChainsRows {
  $selectChainsCountAll->execute();
  my ($num) = $selectChainsCountAll->fetchrow_array();
  
  return $num;
}

sub checkConsistency {
  my ($beforeAfter) = @_;
  is(numProcessedTransactionsRows(), 6, "There are 6 processed transaction rows ".$beforeAfter." execution.");
  is(numChainInfoRows(), 1, "There is 1 chain info rows ".$beforeAfter." execution.");
  is(numChainsRows(), 6, "There are 6 chains rows ".$beforeAfter." execution.");
}


my $selectCandidateTransactionsId = $dbh->prepare("SELECT COUNT(CandidateTransactionsId) FROM CandidateTransactions WHERE CandidateTransactionsId = ?");

my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(CandidateTransactionsId) FROM CandidateTransactions");

sub candidateTransactionIdDoesntExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectCandidateTransactionsId->execute($id);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectCandidateTransactionsId->fetchrow_array();
  
  return (! $returnedVal);
}

sub numRows {
  $selectAllIdsCount->execute();
  my ($num) = $selectAllIdsCount->fetchrow_array();
  
  return $num;
}



#Goal create unique id's and allow for the number of transactions to dynamically change.

say "Test 1 - No candidate transactions in the table";
initialise();
is (numRows(),0,"There is no rows");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newCandidateTransactionsId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),0,"There still is no rows"); #Make sure nothing is added.



#This returns one plus the max value but as long as it returns any unique integer it does not matter.
say "Test 2 - Transactions exist - 1 Transaction";
initialise();
#2-4 params must exist in other tables. 5th+ params don't matter.
#CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
$statementInsertCandidateTransactions->execute(1, 1, 2, 3, 10, 10, 10, 10);
is (numRows(),1,"There is only 1 row");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newCandidateTransactionsId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),1,"There is still is only 1 row"); #Make sure nothing is added.



say "Test 3 - Transactions exist - 2 Transactions";
initialise();
#2-4 params must exist in other tables. 5th+ params don't matter.
#CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
$statementInsertCandidateTransactions->execute(3, 1, 2, 3, 10, 10, 10, 10);
$statementInsertCandidateTransactions->execute(6, 2, 3, 3, 10, 10, 10, 10);
is (numRows(),2,"There is only 2 rows");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newCandidateTransactionsId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),2,"There is still is only 2 rows"); #Make sure nothing is added.


done_testing();
