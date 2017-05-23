use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok lives_ok);
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

my $insertStatementProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");


sub transactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = ? AND Included = 1", undef, ($id));
  
  return $hasIncludedId;
}


sub testWithMatchIds {
  my ($id, $first) = @_;

  $testModuleRestriction->applyDynamicRestriction($id, undef, $first);  
  $testModule->applyHeuristic($id, undef, 0);
}

#Given a transaction id, only allow connections to the next transaction.

#Note this ignores that the id's don't match so say in test 3, 2 -> 3 can link to 4 -> 1 despite 3 and 4 being different.
#This must be restricted with the use of the "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 

#Test 1 to 14 is applying the heuristic to find a candinate transaction to connect to given our current transaction.
#Test 15+ is applying the heurstic to those candinate transactions to find the best candinate.

#Test "Heuristic::None" alone without "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 1 - Transaction 1, not first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(1, undef, 0); } "No exception was thrown"; #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 2 - Transaction 2, not first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(2, undef, 0); } "No exception was thrown"; #id 2, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 3 - Transaction 2, one not included, not first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(2, undef, 0); } "No exception was thrown"; #id 2, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");    

say "Test 4 - Transaction last, can't link to any, not first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 0);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 0);
lives_ok { $testModule->applyHeuristic(3, undef, 0); } "No exception was thrown"; #id 3, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    


# When the first restriction is enabled all of the included params are reset so will be the next transaction regardless.
say "Test 5 - Transaction 1, first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(1, undef, 1); } "No exception was thrown"; #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 6 - Transaction 2, first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(2, undef, 1); } "No exception was thrown"; #id 2, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 7 - Transaction 2, one not included, first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
lives_ok { $testModule->applyHeuristic(2, undef, 1); } "No exception was thrown"; #id 2, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    

say "Test 8 - Transaction last, can't link to any, first dynamic restriction";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 0);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 0);
lives_ok { $testModule->applyHeuristic(3, undef, 1); } "No exception was thrown"; #id 3, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");   


#Test with "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 9 - Transaction 1, all linkable included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 0); } "No exception was thrown"; #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 10 - Transaction 1, one linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 0); } "No exception was thrown"; #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 11 - Transaction 1, all linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 0); } "No exception was thrown"; #id 1, not first restriction
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
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 1); } "No exception was thrown"; #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 13 - Transaction 1, one linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 1); } "No exception was thrown"; #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");

say "Test 14 - Transaction 1, all linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);
lives_ok { testWithMatchIds(1, 1); } "No exception was thrown"; #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");


done_testing();
