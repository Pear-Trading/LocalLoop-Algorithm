use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_newChainId"

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

my $selectProcessedTransactionsCountAll = $dbh->prepare("SELECT COUNT(*) FROM ProcessedTransactions");
my $selectChainInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo");

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
  $statementInsertCurrentStatsId->execute(2, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(3, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(4, 10, 1, 10, 1);
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

sub checkConsistency {
  my ($beforeAfter) = @_;
  is(numProcessedTransactionsRows(), 6, "There are 6 processed transaction rows ".$beforeAfter." execution.");
  is(numChainInfoRows(), 4, "There is 4 chain info rows ".$beforeAfter." execution.");
}


my $selectChainId = $dbh->prepare("SELECT COUNT(ChainId) FROM Chains WHERE ChainId = ?");

my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(ChainId) FROM Chains");

sub chainIdDoesntExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectChainId->execute($id);
  
  #1+ == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectChainId->fetchrow_array();
  
  return (! $returnedVal);
}

sub numRows {
  $selectAllIdsCount->execute();
  my ($num) = $selectAllIdsCount->fetchrow_array();
  
  return $num;
}

#Goal create unique id's and allow for the number of chain ids to dynamically change.


say "Test 1 - No chains in the table";
initialise();
is (numRows(),0,"There is no rows");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Empty table returns not undef id."); 
ok (chainIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),0,"There still is no rows"); #Make sure nothing is added.



#This returns one plus the max value but as long as it returns any unique integer it does not matter.
say "Test 2 - 1 Chain in the table";
initialise();
#3rd param does not matter.
#ChainId, TransactionId_FK, ChainInfoId_FK
$statementInsertChains->execute(1, 1, 1);
$statementInsertChains->execute(1, 2, 1);
$statementInsertChains->execute(1, 3, 1);
is (numRows(),3,"There is only 3 rows");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (chainIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),3,"There is still is only 3 rows"); #Make sure nothing is added.



say "Test 3 - 2 Chains in the table";
initialise();
#3rd param does not matter.
#ChainId, TransactionId_FK, ChainInfoId_FK
$statementInsertChains->execute(1, 1, 1);
$statementInsertChains->execute(1, 2, 1);
$statementInsertChains->execute(1, 3, 1);
$statementInsertChains->execute(1, 4, 1);
$statementInsertChains->execute(1, 5, 1);
$statementInsertChains->execute(1, 6, 1);
$statementInsertChains->execute(2, 4, 1);
$statementInsertChains->execute(2, 5, 1);
$statementInsertChains->execute(2, 6, 1);
is (numRows(),9,"There is only 9 rows");
checkConsistency("before");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainId(); };
is ($exception, undef ,"No exception thrown");

checkConsistency("after");
isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (chainIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),9,"There is still is only 9 rows"); #Make sure nothing is added.


done_testing();
