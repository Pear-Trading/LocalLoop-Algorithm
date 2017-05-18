use Test::More;
use Test::Exception;
use Test::Fatal;
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::Heuristic::None"

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


#Main purpose of this test.
my $testModule = Pear::LocalLoop::Algorithm::Heuristic::None->new();

#Test to make sure this works the below module.
my $testModuleRestriction = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");

sub transactionIdIncluded {
  my ($id) = @_;
  
  my $hasIncludedId = @{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = ? AND Included = 1", undef, ($id))}[0];
  
  return $hasIncludedId;
}

sub testWithMatchIds {
  my ($id, $first) = @_;

  $testModuleRestriction->applyDynamicRestriction($id, $first);  
  $testModule->applyHeuristic($id, 0);
}

#Given a transaction id, only allow connections to the next transaction.

#Note this ignores that the id's don't match so say in test 3, 2 -> 3 can link to 4 -> 1 despite 3 and 4 being different.
#This must be restricted with the use of the "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 

#Test "Heuristic::None" alone without "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 1 - Transaction 1, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 2 - Transaction 2, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(2, 0); #id 2, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 3 - Transaction 2, one not included, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(2, 0); #id 2, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");    

say "Test 4 - Transaction last, can't link to any, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 0);
$testModule->applyHeuristic(3, 0); #id 3, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    


# When the first restriction is enabled all of the included params are reset so will be the next transaction regardless.
say "Test 5 - Transaction 1, first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(1, 1); #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 6 - Transaction 2, first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(2, 1); #id 2, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 7 - Transaction 2, one not included, first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 4, 1, 10, 1);
$testModule->applyHeuristic(2, 1); #id 2, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    

say "Test 8 - Transaction last, can't link to any, first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 0);
$testModule->applyHeuristic(3, 1); #id 3, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");   


#Test with "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 9 - Transaction 1, all linkable included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 1);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 1);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 10 - Transaction 1, one linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 0);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 1);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 11 - Transaction 1, all linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 0);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 0);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

#Now with the first restriction setting, all reset so they ignore the inputted include values.
say "Test 12 - Transaction 1, all linkable included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 1);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 1);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 1); #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 13 - Transaction 1, one linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 0);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 1);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 1); #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 14 - Transaction 1, all linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatement->execute(3, 2, 3, 10, 0);
$insertStatement->execute(4, 3, 4, 10, 1);
$insertStatement->execute(5, 2, 3, 10, 0);
$insertStatement->execute(6, 4, 1, 10, 1);
$insertStatement->execute(7, 3, 4, 10, 1);
testWithMatchIds(1, 1); #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");


done_testing();
