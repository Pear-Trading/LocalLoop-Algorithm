use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainGenerationContext;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::Heuristic::None"

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


#Main purpose of this test.
my $testModule = Pear::LocalLoop::Algorithm::Heuristic::None->new();

#Test to make sure this works the below module.
my $testModuleRestriction = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();

my $insertStatementProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");


sub transactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = ? AND Included = 1", undef, ($id));
  
  return $hasIncludedId;
}


my $ignore = -1;


sub testWithMatchIds {
  my ($id, $first) = @_;
  
  #The first and second param of newChainGenerationContext is not needed so are set to -1.
  $testModuleRestriction->applyChainDynamicRestriction($first, newChainGenerationContext($ignore, $ignore, $id));  
  $testModule->applyHeuristic(0, newChainGenerationContext($ignore, $ignore, $id));
}

sub newChainGenerationContext {
  my ($userIdToLoopWith, $currentChainId, $currentTransactionId) = @_;
  return Pear::LocalLoop::Algorithm::ChainGenerationContext->new({
    userIdWhichCreatesALoop => $userIdToLoopWith,
    currentChainId => $currentChainId,
    currentTransactionId => $currentTransactionId,
  });
}

#Given a transaction id, only allow connections to the next transaction.

#Note this ignores that the id's don't match so say in test 3, 2 -> 3 can link to 4 -> 1 despite 3 and 4 being different.
#This must be restricted with the use of the "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 

#Test 1 to 14 is applying the heuristic to find a candinate transaction to connect to given our current transaction.
#Test 15+ is applying the heurstic to those candinate transactions to find the best candinate.

#Test "Heuristic::None" alone without "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 1 - Transaction 1, not first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.
my $exception = exception { $testModule->applyHeuristic(0, newChainGenerationContext($ignore, $ignore, 1)); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");



say "Test 2 - Transaction 2, not first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.
my $exception = exception { $testModule->applyHeuristic(0, newChainGenerationContext($ignore, $ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");



say "Test 3 - Transaction 2, one not included, not first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.
my $exception = exception { $testModule->applyHeuristic(0, newChainGenerationContext($ignore, $ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");    



say "Test 4 - Transaction last, can't link to any, not first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 0);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 0);

#The first and second param of newChainGenerationContext is not needed so are set to -1.
my $exception = exception { $testModule->applyHeuristic(0, newChainGenerationContext($ignore, $ignore, 3)); };
is ($exception, undef ,"No exception thrown"); #id 3, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    



# When the first restriction is enabled all of the included params are reset so will be the next transaction regardless.
say "Test 5 - Transaction 1, first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.
my $exception = exception { $testModule->applyHeuristic(1, newChainGenerationContext($ignore, $ignore, 1)); };
is ($exception, undef ,"No exception thrown"); #id 1, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");



say "Test 6 - Transaction 2, first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.

my $exception = exception { $testModule->applyHeuristic(1, newChainGenerationContext($ignore, $ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");



say "Test 7 - Transaction 2, one not included, first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);

#The first and second param of newChainGenerationContext is not needed so are set to -1.

my $exception = exception { $testModule->applyHeuristic(1, newChainGenerationContext($ignore, $ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    



say "Test 8 - Transaction last, can't link to any, first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 0);
$insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(4, 4, 1, 10, 0);

#The first and second param of newChainGenerationContext is not needed so are set to -1.

my $exception = exception { $testModule->applyHeuristic(1, newChainGenerationContext($ignore, $ignore, 3)); };
is ($exception, undef ,"No exception thrown"); #id 3, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");   



#Test with "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 9 - Transaction 1, all linkable included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 0); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");



say "Test 10 - Transaction 1, one linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 0); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");



say "Test 11 - Transaction 1, all linkable not included, not first dynamic restriction (user id match restriction applied)";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 0); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

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
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 1); };
is ($exception, undef ,"No exception thrown"); #id 1, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");



say "Test 13 - Transaction 1, one linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 1);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 1); };
is ($exception, undef ,"No exception thrown"); #id 1, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");



say "Test 14 - Transaction 1, all linkable not included, first dynamic restriction (user id match restriction applied)";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
$insertStatementProcessedTransactions->execute(2, 1, 2, 10, 1); #This is here so we know it skips over it.
$insertStatementProcessedTransactions->execute(3, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(4, 3, 4, 10, 1);
$insertStatementProcessedTransactions->execute(5, 2, 3, 10, 0);
$insertStatementProcessedTransactions->execute(6, 4, 1, 10, 1);
$insertStatementProcessedTransactions->execute(7, 3, 4, 10, 1);

my $exception = exception { testWithMatchIds(1, 1); };
is ($exception, undef ,"No exception thrown"); #id 1, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4."); 
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");
is (transactionIdIncluded(7),0,"Can't link to id 7.");


#####################################################################################

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertCurrentChains = $dbh->prepare("INSERT INTO CurrentChains (ChainId, TransactionId_FK, ChainStatsId_FK) VALUES (?, ?, ?)");
my $insertStatementCandinateTransactions = $dbh->prepare("INSERT INTO CandinateTransactions (CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

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
  #ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainStatsId_FK
  $statementInsertCurrentChains->execute(1, 1, 1);
  $statementInsertCurrentChains->execute(1, 2, 1);
  $statementInsertCurrentChains->execute(1, 3, 1);
  $statementInsertCurrentChains->execute(1, 4, 1);
  $statementInsertCurrentChains->execute(1, 5, 1);
  $statementInsertCurrentChains->execute(1, 6, 1);

}

sub candinateTransactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM CandinateTransactions WHERE CandinateTransactionsId = ? AND Included = 1", undef, ($id));
  
  return $hasIncludedId;
}


say "Test 15 - not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is discounted."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 16 - test 15 insertion order shuffled, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is discounted."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 17 - to transaction ids randomised, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #               #
$insertStatementCandinateTransactions->execute(4, 1, 1, 12, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 7,  1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(1, 1, 1, 88, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 4,  1, 1, 1, 1, 1);
my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction
is (candinateTransactionIdIncluded(1),0,"id 88 is discounted."); 
is (candinateTransactionIdIncluded(2),0,"id 7 is discounted."); 
is (candinateTransactionIdIncluded(3),1,"id 4 is included."); 
is (candinateTransactionIdIncluded(4),0,"id 12 is discounted."); 



say "Test 18 - best candinate not included, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction

is (candinateTransactionIdIncluded(1),0,"id 1 is not included anyway."); 
is (candinateTransactionIdIncluded(2),1,"id 2 is included."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 19 - other non best candinates not included, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);

my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is not included anyway."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is not included anyway."); 



say "Test 20 - none included, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);

my $exception = exception { $testModule->applyHeuristicCandinates(0); };
is ($exception, undef ,"No exception thrown"); #not first restriction

is (candinateTransactionIdIncluded(1),0,"id 1 is not included anyway."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is not included anyway."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is not included anyway."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is not included anyway."); 



#With first restriction
say "Test 21 - first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is discounted."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 22 - test 15 insertion order shuffled, first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is discounted."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 23 - to transaction ids randomised, first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #               #
$insertStatementCandinateTransactions->execute(4, 1, 1, 12, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 7,  1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(1, 1, 1, 88, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 4,  1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),0,"id 88 is discounted."); 
is (candinateTransactionIdIncluded(2),0,"id 7 is discounted."); 
is (candinateTransactionIdIncluded(3),1,"id 4 is included."); 
is (candinateTransactionIdIncluded(4),0,"id 12 is discounted."); 



say "Test 24 - best candinate not included, first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included (resetted)."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is discounted."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is discounted."); 



say "Test 25 - other non best candinates included, not first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is not included, but is reset and discounted anyway."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is discounted."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is not included, but is reset and discounted anyway."); 



say "Test 26 - none included, first dynamic restriction";
initialise();
#Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
#The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
#CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
#                                              #        #              #
$insertStatementCandinateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
$insertStatementCandinateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);

my $exception = exception { $testModule->applyHeuristicCandinates(1); };
is ($exception, undef ,"No exception thrown"); #first restriction

is (candinateTransactionIdIncluded(1),1,"id 1 is included (resetted)."); 
is (candinateTransactionIdIncluded(2),0,"id 2 is not included, but is reset and discounted anyway."); 
is (candinateTransactionIdIncluded(3),0,"id 3 is not included, but is reset and discounted anyway."); 
is (candinateTransactionIdIncluded(4),0,"id 4 is not included, but is reset and discounted anyway."); 



#####################################################################################

# my $statementInsertProcessedTransactions;
my $statementInsertLoopInfoId = $dbh->prepare("INSERT INTO LoopInfo (LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $statementInsertLoops = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) VALUES (?, ?)");

sub loopIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM LoopInfo WHERE LoopId = ? AND Included = 1", undef, ($id));
  
  return $hasIncludedId;
}

#NOTE: If the start and end transaction of a loop are the same the results are undefined. 
#(It'll return either one of them.)


say "Test 27 - Empty table - not first transaction";
{
  delete_table_data();

  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
}



say "Test 28 - Empty table - first transaction";
{
  delete_table_data();

  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); #first restriction
}


sub initialise1 {
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  
  $statementInsertProcessedTransactions->execute( 3,  3,  4, 10);
  $statementInsertProcessedTransactions->execute( 4,  4,  5, 12);
  $statementInsertProcessedTransactions->execute( 5,  5,  3, 10);
   
  $statementInsertProcessedTransactions->execute( 6,  6,  7, 10);
  $statementInsertProcessedTransactions->execute( 7,  7,  6, 10);
  
  $statementInsertProcessedTransactions->execute( 8,  8,  9, 10);
  $statementInsertProcessedTransactions->execute( 9,  9, 10, 10);
  $statementInsertProcessedTransactions->execute(10, 10,  8, 15);
  
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 0, 1,  2,  8, 2, 18, 1, 0);
  $statementInsertLoopInfoId->execute(2, 1, 3,  5, 10, 3, 32, 2, 0);
  $statementInsertLoopInfoId->execute(3, 1, 6,  7, 10, 2, 20, 2, 0);
  $statementInsertLoopInfoId->execute(4, 0, 8, 10, 10, 3, 35, 2, 0);
  
  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1,  1);
  $statementInsertLoops->execute(1,  2);
  $statementInsertLoops->execute(2,  3);
  $statementInsertLoops->execute(2,  4);
  $statementInsertLoops->execute(2,  5);
  $statementInsertLoops->execute(3,  6);
  $statementInsertLoops->execute(3,  7);
  $statementInsertLoops->execute(4,  8);
  $statementInsertLoops->execute(4,  9);
  $statementInsertLoops->execute(4, 10);
}


say "Test 29 - None included - not first";
{
  initialise1();
  
  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
  
  is (loopIdIncluded(1),0,"loop 1 is not included."); 
  is (loopIdIncluded(2),0,"loop 2 is not included."); 
  is (loopIdIncluded(3),0,"loop 3 is not included."); 
  is (loopIdIncluded(4),0,"loop 4 is not included."); 
}


say "Test 30 - None included - first";
{
  initialise1();
  
  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); #first restriction
  
  is (loopIdIncluded(1),1,"loop 1 is not included, but was reset."); 
  is (loopIdIncluded(2),0,"loop 2 is not included, but was reset but then was discounted."); 
  is (loopIdIncluded(3),0,"loop 3 is not included, but was reset but then was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 is not included, but was reset but then was discounted."); 
}

sub initialise2 {
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  
  $statementInsertProcessedTransactions->execute( 3,  3,  4, 10);
  $statementInsertProcessedTransactions->execute( 4,  4,  5, 12);
  $statementInsertProcessedTransactions->execute( 5,  5,  3, 10);
   
  $statementInsertProcessedTransactions->execute( 6,  6,  7, 10);
  $statementInsertProcessedTransactions->execute( 7,  7,  6, 10);
  
  $statementInsertProcessedTransactions->execute( 8,  8,  9, 10);
  $statementInsertProcessedTransactions->execute( 9,  9, 10, 10);
  $statementInsertProcessedTransactions->execute(10, 10,  8, 15);
  
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #Shuffle the order around, so prevent the selection of earlier loops by insertion order.
  $statementInsertLoopInfoId->execute(1, 1, 6,  7, 10, 2, 20, 2, 1); #3. We should ignore if loops are active and process it anyway.
  $statementInsertLoopInfoId->execute(2, 0, 1,  2,  8, 2, 18, 1, 1); #1
  $statementInsertLoopInfoId->execute(3, 0, 8, 10, 10, 3, 35, 2, 1); #4
  $statementInsertLoopInfoId->execute(4, 1, 3,  5, 10, 3, 32, 2, 1); #2. We should ignore if loops are active and process it anyway.

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1,  6);
  $statementInsertLoops->execute(1,  7);
  $statementInsertLoops->execute(2,  1);
  $statementInsertLoops->execute(2,  2);
  $statementInsertLoops->execute(3,  8);
  $statementInsertLoops->execute(3,  9);
  $statementInsertLoops->execute(3, 10);
  $statementInsertLoops->execute(4,  3);
  $statementInsertLoops->execute(4,  4);
  $statementInsertLoops->execute(4,  5);
}

say "Test 31 - All included - not first";
{
  initialise2();

  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
  
  is (loopIdIncluded(1),0,"loop 1 was included but was discounted."); 
  is (loopIdIncluded(2),1,"loop 2 still is included."); 
  is (loopIdIncluded(3),0,"loop 3 was included but was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
}

say "Test 32 - All included - first";
{
  initialise2();

  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); #first restriction
  
  is (loopIdIncluded(1),0,"loop 1 was included but was discounted."); 
  is (loopIdIncluded(2),1,"loop 2 still is included."); 
  is (loopIdIncluded(3),0,"loop 3 was included but was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
}


sub initialise3 {
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  
  $statementInsertProcessedTransactions->execute( 3,  3,  4, 10);
  $statementInsertProcessedTransactions->execute( 4,  4,  5, 12);
  $statementInsertProcessedTransactions->execute( 5,  5,  3, 10);
   
  $statementInsertProcessedTransactions->execute( 6,  6,  7, 10);
  $statementInsertProcessedTransactions->execute( 7,  7,  6, 10);
  
  $statementInsertProcessedTransactions->execute( 8,  8,  9, 10);
  $statementInsertProcessedTransactions->execute( 9,  9, 10, 10);
  $statementInsertProcessedTransactions->execute(10, 10,  8, 15);
  
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #Shuffle the order around, so prevent the selection of earlier loops by insertion order.
  $statementInsertLoopInfoId->execute(1, 1, 6,  7, 10, 2, 20, 2, 1); #3. We should ignore if loops are active and process it anyway.
  $statementInsertLoopInfoId->execute(2, 0, 1,  2,  8, 2, 18, 1, 0); #1
  $statementInsertLoopInfoId->execute(3, 0, 8, 10, 10, 3, 35, 2, 1); #4
  $statementInsertLoopInfoId->execute(4, 1, 3,  5, 10, 3, 32, 2, 1); #2. We should ignore if loops are active and process it anyway.

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1,  6);
  $statementInsertLoops->execute(1,  7);
  $statementInsertLoops->execute(2,  1);
  $statementInsertLoops->execute(2,  2);
  $statementInsertLoops->execute(3,  8);
  $statementInsertLoops->execute(3,  9);
  $statementInsertLoops->execute(3, 10);
  $statementInsertLoops->execute(4,  3);
  $statementInsertLoops->execute(4,  4);
  $statementInsertLoops->execute(4,  5);
}


say "Test 33 - Best loop not included - not first";
{
  initialise3();
  
  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
  
  is (loopIdIncluded(1),0,"loop 1 was included but was discounted."); 
  is (loopIdIncluded(2),0,"loop 2 not included and remained that way."); 
  is (loopIdIncluded(3),0,"loop 3 was included but was discounted."); 
  is (loopIdIncluded(4),1,"loop 4 remained included (selected)."); 
}


say "Test 34 - Best loop not included - first";
{
  initialise3();
  
  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); # first restriction
  
  is (loopIdIncluded(1),0,"loop 1 was included but was discounted."); 
  is (loopIdIncluded(2),1,"loop 2 not included but was reset and selected"); 
  is (loopIdIncluded(3),0,"loop 3 was included but was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
}


sub initialise4 {
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  $statementInsertProcessedTransactions->execute( 3,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  $statementInsertProcessedTransactions->execute( 5,  5,  6, 10);
  $statementInsertProcessedTransactions->execute( 6,  6,  5,  8);
  $statementInsertProcessedTransactions->execute( 7,  6,  7,  8);
  $statementInsertProcessedTransactions->execute( 8,  7,  5, 10);
  
  $statementInsertProcessedTransactions->execute( 9,  8,  9, 10);
  $statementInsertProcessedTransactions->execute(10,  9, 10, 10);
  $statementInsertProcessedTransactions->execute(11, 10,  8, 10);
  
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #Shuffle the order around, so prevent the selection of earlier loops by insertion order.
  #Active values are shuffled again to add more possible senarios.
  $statementInsertLoopInfoId->execute(1, 0, 1,  2,  8, 2, 18, 1, 0); # Duplicate of the loops below for first selection.
  $statementInsertLoopInfoId->execute(2, 1, 1,  4,  8, 3, 28, 2, 0); # ... but is disabled.
  $statementInsertLoopInfoId->execute(3, 0, 5,  6,  8, 2, 18, 1, 1); #1. Choice between these two.
  $statementInsertLoopInfoId->execute(4, 1, 5,  8,  8, 3, 28, 2, 1); #2.
  $statementInsertLoopInfoId->execute(5, 0, 9, 11, 10, 3, 30, 3, 1); 

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1,  1);
  $statementInsertLoops->execute(1,  2);
  
  $statementInsertLoops->execute(2,  1);
  $statementInsertLoops->execute(2,  3);
  $statementInsertLoops->execute(2,  4);
  
  $statementInsertLoops->execute(3,  5);
  $statementInsertLoops->execute(3,  6);
  
  $statementInsertLoops->execute(4,  5);
  $statementInsertLoops->execute(4,  6);
  $statementInsertLoops->execute(4,  8);
  
  $statementInsertLoops->execute(5,  9);
  $statementInsertLoops->execute(5, 10);
  $statementInsertLoops->execute(5, 11);
}


say "Test 35 - Best loops with same start transaction but different end transaction - not first";
{
  initialise4();
  
  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
  
  is (loopIdIncluded(1),0,"loop 1 not included and remained that way."); 
  is (loopIdIncluded(2),0,"loop 2 not included and remained that way."); 
  is (loopIdIncluded(3),1,"loop 3 was included and was selected."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
  is (loopIdIncluded(5),0,"loop 5 was included but was discounted."); 
}

say "Test 36 - Best loops with same start transaction but different end transaction - first";
{
  initialise4();
  
  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); #first restriction
  
  is (loopIdIncluded(1),1,"loop 1 not included but was reset and selected."); 
  is (loopIdIncluded(2),0,"loop 2 not included but was reset and discounted."); 
  is (loopIdIncluded(3),0,"loop 3 was included and was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
  is (loopIdIncluded(5),0,"loop 5 was included but was discounted."); 
}


sub initialise5 {
  delete_table_data();

  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 3,  1,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  $statementInsertProcessedTransactions->execute( 5,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 6,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 7,  1,  3,  8);
  $statementInsertProcessedTransactions->execute( 8,  3,  1, 10);
  
  $statementInsertProcessedTransactions->execute( 9,  8,  9, 10);
  $statementInsertProcessedTransactions->execute(10,  9, 10, 10);
  $statementInsertProcessedTransactions->execute(11, 10,  8, 10);
  
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #Shuffle the order around, so prevent the selection of earlier loops by insertion order.
  #Active values are shuffled again to add more possible senarios.
  $statementInsertLoopInfoId->execute(1, 1, 1,  4,  8, 2, 18, 1, 0); # Duplicate of the loops below for first selection.
  $statementInsertLoopInfoId->execute(2, 0, 3,  4,  8, 3, 28, 2, 0); # ... but is disabled.
  $statementInsertLoopInfoId->execute(3, 1, 5,  8,  8, 2, 18, 1, 1); #1. Choice between these two.
  $statementInsertLoopInfoId->execute(4, 0, 7,  8,  8, 3, 28, 2, 1); #2.
  $statementInsertLoopInfoId->execute(5, 1, 9, 11, 10, 3, 30, 3, 1); 

  #LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1,  1);
  $statementInsertLoops->execute(1,  2);
  $statementInsertLoops->execute(1,  4);
  
  $statementInsertLoops->execute(2,  3);
  $statementInsertLoops->execute(2,  4);
  
  $statementInsertLoops->execute(3,  5);
  $statementInsertLoops->execute(3,  6);
  $statementInsertLoops->execute(3,  8);
  
  $statementInsertLoops->execute(4,  7);
  $statementInsertLoops->execute(4,  8);
  
  $statementInsertLoops->execute(5,  9);
  $statementInsertLoops->execute(5, 10);
  $statementInsertLoops->execute(5, 11);
}


say "Test 37 - Best loops with different start transaction and same end transaction - not first";
{
  initialise5();
  
  my $exception = exception { $testModule->applyLoopHeuristic(0); };
  is ($exception, undef ,"No exception thrown"); #not first restriction
  
  is (loopIdIncluded(1),0,"loop 1 not included and remained that way."); 
  is (loopIdIncluded(2),0,"loop 2 not included and remained that way."); 
  is (loopIdIncluded(3),1,"loop 3 was included and was selected."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
  is (loopIdIncluded(5),0,"loop 5 was included but was discounted."); 
}


say "Test 38 - Best loops with different start transaction and same end transaction - first";
{
  initialise5();
  
  my $exception = exception { $testModule->applyLoopHeuristic(1); };
  is ($exception, undef ,"No exception thrown"); #first restriction
  
  is (loopIdIncluded(1),1,"loop 1 not included but was reset and selected."); 
  is (loopIdIncluded(2),0,"loop 2 not included but was reset and discounted."); 
  is (loopIdIncluded(3),0,"loop 3 was included and was discounted."); 
  is (loopIdIncluded(4),0,"loop 4 was included but was discounted."); 
  is (loopIdIncluded(5),0,"loop 5 was included but was discounted."); 
}



done_testing();

