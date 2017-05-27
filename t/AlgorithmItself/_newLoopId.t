use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_newLoopId"

Pear::LocalLoop::Algorithm::Main->setTestingMode();

my $main = Pear::LocalLoop::Algorithm::Main->new();
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
my $statementInsertLoopInfoId = $dbh->prepare("INSERT INTO LoopInfo (LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?)");
my $statementInsertLoops = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) VALUES (?, ?)");


my $selectLoopId = $dbh->prepare("SELECT COUNT(LoopId) FROM LoopInfo WHERE LoopId = ?");
my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(LoopId) FROM LoopInfo");

sub loopIdDoesntExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectLoopId->execute($id);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectLoopId->fetchrow_array();
  
  return (! $returnedVal);
}

sub numRows {
  $selectAllIdsCount->execute();
  my ($num) = $selectAllIdsCount->fetchrow_array();
  
  return $num;
}


#Goal create unique id's for the LoopInfo table

say "Test 1 - No loop info tuples in the table";
{
  delete_table_data();
  is (numRows(),0,"There is no tuples");

  my $integer = undef;
  my $exception = exception { $integer = $main->_newLoopId(); };
  is ($exception, undef ,"No exception thrown");

  isnt ($integer, undef, "Empty table returns not undef id."); 
  ok (loopIdDoesntExists($integer), "Returned id does not exist."); 
  is (numRows(),0,"There still is no tuples"); #Make sure nothing is added.
}


#This returns one plus the max value but as long as it returns any unique integer it does not matter.
say "Test 2 - 1 tuple";
{
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 1, 10);

  #LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertLoopInfoId->execute(1, 1, 2, 10, 2, 20, 2);

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  is (numRows(),1,"There is only 1 tuple");

  my $integer = undef;
  my $exception = exception { $integer = $main->_newLoopId(); };
  is ($exception, undef ,"No exception thrown");

  isnt ($integer, undef, "Non-empty table returns not undef id."); 
  ok (loopIdDoesntExists($integer), "Returned id does not exist."); 
  is (numRows(),1,"There is still is only 1 tuple"); #Make sure nothing is added.
}


say "Test 3 -  2 tuples";
{
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 1, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 3, 10);

  #LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertLoopInfoId->execute(6, 1, 2, 10, 2, 20, 2);
  $statementInsertLoopInfoId->execute(4, 3, 4, 10, 2, 20, 2);

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(6, 1);
  $statementInsertLoops->execute(6, 2);
  $statementInsertLoops->execute(4, 3);
  $statementInsertLoops->execute(4, 4);
  is (numRows(),2,"There is only 2 tuples");

  my $integer = undef;
  my $exception = exception { $integer = $main->_newLoopId(); };
  is ($exception, undef ,"No exception thrown");

  isnt ($integer, undef, "Non-empty table returns not undef id."); 
  ok (loopIdDoesntExists($integer), "Returned id does not exist."); 
  is (numRows(),2,"There is still is only 2 tuples"); #Make sure nothing is added.
}

done_testing();
