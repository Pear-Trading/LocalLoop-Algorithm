use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_newChainStatsId"

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


my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");


my $selectCandidateTransactionsId = $dbh->prepare("SELECT COUNT(ChainStatsId) FROM CurrentChainsStats WHERE ChainStatsId = ?");
my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(ChainStatsId) FROM CurrentChainsStats");

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


#Goal create unique id's and allow for the number of stats tuples to dynamically change.

say "Test 1 - No candidate transactions in the table";
delete_table_data();
is (numRows(),0,"There is no tuples");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainStatsId(); };
is ($exception, undef ,"No exception thrown");

isnt ($integer, undef, "Empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),0,"There still is no tuples"); #Make sure nothing is added.



#This returns one plus the max value but as long as it returns any unique integer it does not matter.
say "Test 2 - 1 Tuple";
delete_table_data();
#Only the first param matters.
#ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
$statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1); 
is (numRows(),1,"There is only 1 tuple");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainStatsId(); };
is ($exception, undef ,"No exception thrown");

isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),1,"There is still is only 1 tuple"); #Make sure nothing is added.



say "Test 3 - Transactions exist - 2 Transaction";
delete_table_data();
#Only the first param matters.
#ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
$statementInsertCurrentStatsId->execute(2, 10,  1,  10,  1);   
$statementInsertCurrentStatsId->execute(5, 100, 11, 101, 11);  
is (numRows(),2,"There is only 2 tuples");

my $integer = undef;
my $exception = exception { $integer = $main->_newChainStatsId(); };
is ($exception, undef ,"No exception thrown");

isnt ($integer, undef, "Non-empty table returns not undef id."); 
ok (candidateTransactionIdDoesntExists($integer), "Returned id does not exist."); 
is (numRows(),2,"There is still is only 2 tuples"); #Make sure nothing is added.


done_testing();
