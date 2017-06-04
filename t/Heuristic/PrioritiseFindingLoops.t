use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainGenerationContext;
use Pear::LocalLoop::Algorithm::LoopGenerationContext;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops;
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
my $testModule = Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops->new();

#Test to make sure this works the below module.
my $testModuleRestriction = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();

my $insertStatementProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");


sub transactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM ProcessedTransactions_ViewIncluded WHERE TransactionId = ?", undef, ($id));
  
  return $hasIncludedId;
}


my $INGORE = -1;
my $INGORE_USER_ID = $INGORE;
my $INGORE_CHAIN_ID = $INGORE;
my $FIRST = 1;
my $NOT_FIRST = 0;

sub testWithRestriction {
  my ($first, $userId, $transactionId) = @_;
  
  #The first and second param of newChainGenerationContext is not needed so are set to -1.
  $testModuleRestriction->applyChainDynamicRestriction($first, newChainGenerationContext($INGORE_USER_ID, $INGORE_CHAIN_ID, $transactionId));  
  $testModule->applyChainHeuristic($NOT_FIRST, newChainGenerationContext($userId, $INGORE_CHAIN_ID, $transactionId));
}

sub testThisModule {
  my ($first, $userId, $transactionId) = @_; 
  
  $testModule->applyChainHeuristic($first, newChainGenerationContext($userId, $INGORE_CHAIN_ID, $transactionId));
}

sub newChainGenerationContext {
  my ($userIdToLoopWith, $currentChainId, $currentTransactionId) = @_;
  return Pear::LocalLoop::Algorithm::ChainGenerationContext->new({
    userIdWhichCreatesALoop => $userIdToLoopWith,
    currentChainId => $currentChainId,
    currentTransactionId => $currentTransactionId,
  });
}


#This ignores whether the user id's match up on a link so a transaction with user 1 to user 2 and a transaction 
#with user 4 to user 1 can successfully link together. As long as the first transactions from user is the same 
#as the considered transactions to user.
#To make correct linking the dynamic restriction AllowOnlyTransactionsWhichFromUserMatchesOurToUser is needed.

#Test "Heuristic::PrioritiseFindingLoops" alone without "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 
say "Test 1 - Empty table - Not first applied";
{
  delete_table_data();

  #First applied, user id, transaction id.
  #Both are -1 as they don't exist, should execute ok.
  my $exception = exception { testThisModule($NOT_FIRST, -1, -1); };
  is ($exception, undef ,"No exception thrown");
}



say "Test 2 - Empty table - First applied";
{
  delete_table_data();

  #First applied, user id, transaction id.
  #Both are -1 as they don't exist, should execute ok.
  my $exception = exception { testThisModule($FIRST, -1, -1); };
  is ($exception, undef ,"No exception thrown");  
}


sub initialiseData1 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 1);
}


say "Test 3 - No transactions with the end from user id - Not first applied";
{
  initialiseData1();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}


say "Test 4 - No transactions with the end from user id - First applied";
{
  initialiseData1();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}



sub initialiseData2 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 0);
  $insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 0);
}


say "Test 5 - No transactions with the end from user id, some excluded - Not first applied";
{
  initialiseData2();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}


say "Test 6 - No transactions with the end from user id - First applied";
{
  initialiseData2();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); #Reset 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4."); #Reset
}



sub initialiseData3 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 0);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 0);
  $insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0);
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 0);
}


say "Test 7 - No transactions with the end from user id, all excluded - Not first applied";
{
  initialiseData3();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}


say "Test 8 - No transactions with the end from user id - First applied";
{
  initialiseData3();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); #Reset 
  is (transactionIdIncluded(2),1,"Can link to id 2."); #Reset 
  is (transactionIdIncluded(3),1,"Can link to id 3."); #Reset
  is (transactionIdIncluded(4),1,"Can link to id 4."); #Reset 
}



sub initialiseData4 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 4, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
}

say "Test 9 - One transactions with the end from user id - Not first applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 10 - One transactions with the end from user id - First applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 1, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 11 - One transactions with the end from user id, different current transaction - Not first applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 1, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 12 - One transactions with the end from user id, different current transaction - First applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 1, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 13 - One transactions with the end from user id, different current transaction and end - Not first applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 4, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}

say "Test 14 - One transactions with the end from user id, different current transaction and end - First applied";
{
  initialiseData4();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 4, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}


sub initialiseData5 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 4, 10, 0); #Exclude this transaction
  $insertStatementProcessedTransactions->execute(4, 4, 1, 10, 1);
}


say "Test 15 - One transactions with the end from user id, end point excluded - Not first applied";
{
  initialiseData5();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 4, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 16 - One transactions with the end from user id, end point excluded - First applied";
{
  initialiseData5();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 4, 2); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}



sub initialiseData6 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 1);
}


say "Test 17 - Two transactions with the end from user id, both included - Not first applied";
{
  initialiseData6();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 18 - Two transactions with the end from user id, both included - First applied";
{
  initialiseData6();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}



sub initialiseData7 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 0); #Exclude this transaction
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 1);
}


say "Test 19 - Two transactions with the end from user id, one excluded - Not first applied";
{
  initialiseData7();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 20 - Two transactions with the end from user id, one excluded - First applied";
{
  initialiseData7();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); #Re-enabled.
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}



sub initialiseData8 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 1); 
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 0); #Exclude this transaction
}


say "Test 21 - Two transactions with the end from user id, the other excluded - Not first applied";
{
  initialiseData8();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3.");
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}

say "Test 22 - Two transactions with the end from user id, the other excluded - First applied";
{
  initialiseData8();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); 
  is (transactionIdIncluded(4),1,"Can link to id 4."); #Reset
}



sub initialiseData9 {
  delete_table_data();
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 0); #Both candidates excluded.
  $insertStatementProcessedTransactions->execute(4, 4, 5, 10, 0); 
}


say "Test 23 - Two transactions with the end from user id, both excluded - Not first applied";
{
  initialiseData9();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),1,"Can link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}

say "Test 24 - Two transactions with the end from user id, both excluded - First applied";
{
  initialiseData9();

  #First applied, user id, transaction id.
  my $exception = exception { testThisModule($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),1,"Can link to id 3."); #Reset
  is (transactionIdIncluded(4),1,"Can link to id 4."); #Reset
}


###########################################################################################################
#Test "Heuristic::PrioritiseFindingLoops" alone without "DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser" 


sub initialiseData10 {
  delete_table_data();
  #The heuristic will accept transaction 3 and 4, but due to the restriction only transaction 4 is allowed
  
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 2, 5, 10, 1); 
}


say "Test 25 - Two transactions with the end from user id, both excluded - Not first applied";
{
  initialiseData10();

  #First applied, user id, transaction id.
  my $exception = exception { testWithRestriction($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),1,"Can link to id 4.");
}

say "Test 26 - Two transactions with the end from user id, both excluded - First applied";
{
  initialiseData10();

  #First applied, user id, transaction id.
  my $exception = exception { testWithRestriction($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),1,"Can link to id 4."); 
}



sub initialiseData11 {
  delete_table_data();
  #Similar to the above test
  #The heuristic will accept transaction 3 and 4, but due to the restriction only transaction 4 is allowed.
  #However transaction 4 is excluded, so transaction 2 is left enabled.
  
  #TransactionId, FromUserId, ToUserId, Value, Included
  $insertStatementProcessedTransactions->execute(1, 1, 2, 10, 1);
  $insertStatementProcessedTransactions->execute(2, 2, 3, 10, 1);
  $insertStatementProcessedTransactions->execute(3, 3, 5, 10, 1);
  $insertStatementProcessedTransactions->execute(4, 2, 5, 10, 0);
}


say "Test 27 - Two transactions with the end from user id, both excluded - Not first applied";
{
  initialiseData11();

  #First applied, user id, transaction id.
  my $exception = exception { testWithRestriction($NOT_FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),1,"Can link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),0,"Can't link to id 4.");
}

say "Test 28 - Two transactions with the end from user id, both excluded - First applied";
{
  initialiseData11();

  #First applied, user id, transaction id.
  my $exception = exception { testWithRestriction($FIRST, 5, 1); };
  is ($exception, undef ,"No exception thrown");
  
  is (transactionIdIncluded(1),0,"Can't link to id 1."); 
  is (transactionIdIncluded(2),0,"Can't link to id 2."); 
  is (transactionIdIncluded(3),0,"Can't link to id 3.");
  is (transactionIdIncluded(4),1,"Can link to id 4."); 
}


########################################################################################################

my $insertStatementCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertChains = $dbh->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");

sub initialiseCand {
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 5, 10);
  $statementInsertProcessedTransactions->execute(5, 5, 6, 10);
  $statementInsertProcessedTransactions->execute(6, 4, 6, 10);
  
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

sub newLoopGenerationContext {
  my ($userId) = @_;
  
  if ( ! defined $userId ) {
    die "userId cannot be null";
  }
  
  return $loopGenerationContextInstance = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $userId,
  });
}

sub candidateTransactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM CandidateTransactions_ViewIncluded WHERE CandidateTransactionsId = ?", undef, ($id));
  
  return $hasIncludedId;
}


say "Test 29 - Empty table - not first applied";
{
  initialiseCand();

  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext($INGORE_USER_ID)); };
  is ($exception, undef ,"No exception thrown");
}



say "Test 30 - Empty table - First applied";
{
  initialiseCand();

  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext($INGORE_USER_ID)); };
  is ($exception, undef ,"No exception thrown");
}



say "Test 31 - First missing";
{
  initialiseCand();
  
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic(undef, newLoopGenerationContext($INGORE_USER_ID)); };
  isnt ($exception, undef ,"Exception thrown");
}



say "Test 32 - First missing";
{
  initialiseCand();

  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, undef); };
  isnt ($exception, undef ,"Exception thrown");
}



say "Test 33 - First missing";
{
  initialiseCand();

  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, undef); };
  isnt ($exception, undef ,"Exception thrown");
}


sub initialiseCand1 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 1);
}

say "Test 34 - No candidates with the user id that can form a loop, all active - not first applied";
{
  initialiseCand1();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),1,"id 1 remains included."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 remains included."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 remains included."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
}


say "Test 35 - No candidates with the user id that can form a loop, all active - first applied";
{
  initialiseCand1();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),1,"id 1 remains included."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 remains included."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 remains included."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
}



sub initialiseCand2 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 0);
}

say "Test 36 - No candidates with the user id that can form a loop, some excluded - not first applied";
{
  initialiseCand2();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 remains excluded."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 remains included."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 remains excluded."); 
}


say "Test 37 - No candidates with the user id that can form a loop, some excluded - first applied";
{
  initialiseCand2();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),1,"id 1 was reset and included again."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 remains included."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 was reset and included again."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 was reset and included again."); 
}


sub initialiseCand3 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 0);
}

say "Test 38 - No candidates with the user id that can form a loop, all excluded - not first applied";
{
  initialiseCand3();
  
  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 remains excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 remains excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 remains excluded."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 remains excluded."); 
}


say "Test 39 - No candidates with the user id that can form a loop, all excluded - first applied";
{
  initialiseCand3();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(7)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),1,"id 1 was reset and included again."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 was reset and included again."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 was reset and included again."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 was reset and included again."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 was reset and included again."); 
}


sub initialiseCand4 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 1);
}

say "Test 40 - One candidate with the user id that can form a loop, all included - not first applied";
{
  initialiseCand4();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(5)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 has been excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 has been excluded."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 has been excluded."); 
}


say "Test 41 - One candidate with the user id that can form a loop, all included - first applied";
{
  initialiseCand4();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(5)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 has been excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 has been excluded."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 has been excluded."); 
}



sub initialiseCand5 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 1);
}

say "Test 42 - One candidate with the user id that can form a loop, some included (candidate excluded) - not first applied";
{
  initialiseCand5();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(4)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 remains excluded."); 
  is (candidateTransactionIdIncluded(2),1,"id 2 remains included."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),1,"id 4 remains included."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
}


say "Test 43 - One candidate with the user id that can form a loop, some included (candidate excluded) - first applied";
{
  initialiseCand5();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(4)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 has been excluded."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 was reset and included again."); #Reset
  is (candidateTransactionIdIncluded(4),0,"id 4 has been excluded."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 has been excluded."); 
}


sub initialiseCand6 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 0);
}

say "Test 44 - One candidate with the user id that can form a loop, all excluded - not first applied";
{
  initialiseCand6();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(4)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 remains excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 remains excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 remains excluded."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 remains excluded."); 
}


say "Test 45 - One candidate with the user id that can form a loop, all excluded - first applied";
{
  initialiseCand6();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(4)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 was reset but then excluded again."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 was reset but then excluded again."); 
  is (candidateTransactionIdIncluded(3),1,"id 3 was reset and included again."); #Reset
  is (candidateTransactionIdIncluded(4),0,"id 4 was reset but then excluded again."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 was reset but then excluded again."); 
}



sub initialiseCand7 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(6, 1, 1, 6, 1, 1, 1, 1, 1);
}

say "Test 46 - Two candidates with the user id that can form a loop, all included - not first applied";
{
  initialiseCand7();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 has been excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 has been excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 has been excluded."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
  is (candidateTransactionIdIncluded(6),1,"id 6 remains included."); 
}


say "Test 47 - Two candidates with the user id that can form a loop, all included - first applied";
{
  initialiseCand7();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 has been excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 has been excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 has been excluded."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
  is (candidateTransactionIdIncluded(6),1,"id 6 remains included.");  
}



sub initialiseCand8 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 1);
  $insertStatementCandidateTransactions->execute(6, 1, 1, 6, 1, 1, 1, 1, 0);
}

say "Test 48 - Two candidates with the user id that can form a loop, some included (one end excluded) - not first applied";
{
  initialiseCand8();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 remains excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 has been excluded."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
  is (candidateTransactionIdIncluded(6),0,"id 6 remains excluded."); 
}


say "Test 49 - Two candidates with the user id that can form a loop, some included (one end excluded) - first applied";
{
  initialiseCand8();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 has been excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 emains excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 emains excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 has been excluded."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
  is (candidateTransactionIdIncluded(6),1,"id 6 was reset and is now included.");  
}


sub initialiseCand9 {
  initialiseCand();
  
  #Only the 1st (tuple id), 4th (to transaction) and 9th (included) attributes matter.
  #The 2nd and 3rd however must exist in their respective tables, though they are not taken into consideration.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  #                                              #        #              #
  $insertStatementCandidateTransactions->execute(1, 1, 1, 1, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(2, 1, 1, 2, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(3, 1, 1, 3, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(4, 1, 1, 4, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(5, 1, 1, 5, 1, 1, 1, 1, 0);
  $insertStatementCandidateTransactions->execute(6, 1, 1, 6, 1, 1, 1, 1, 0);
}

say "Test 48 - Two candidates with the user id that can form a loop, all excluded - not first applied";
{
  initialiseCand9();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($NOT_FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 remains excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 remains excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 remains excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 remains excluded."); 
  is (candidateTransactionIdIncluded(5),0,"id 5 remains excluded."); 
  is (candidateTransactionIdIncluded(6),0,"id 6 remains excluded."); 
}


say "Test 49 - Two candidates with the user id that can form a loop, all excluded - first applied";
{
  initialiseCand9();

  #First application, user id which forms a loop.
  my $exception = exception { $testModule->applyCandidateTransactionHeuristic($FIRST, newLoopGenerationContext(6)); };
  is ($exception, undef ,"No exception thrown");

  is (candidateTransactionIdIncluded(1),0,"id 1 was reset but then excluded."); 
  is (candidateTransactionIdIncluded(2),0,"id 2 was reset but then excluded."); 
  is (candidateTransactionIdIncluded(3),0,"id 3 was reset but then excluded."); 
  is (candidateTransactionIdIncluded(4),0,"id 4 was reset but then excluded."); 
  is (candidateTransactionIdIncluded(5),1,"id 5 remains included."); 
  is (candidateTransactionIdIncluded(6),1,"id 6 was reset and is now included.");  
}


done_testing();
