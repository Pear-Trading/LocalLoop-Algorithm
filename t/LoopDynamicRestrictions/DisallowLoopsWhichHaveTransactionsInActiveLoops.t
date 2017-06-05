use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops"

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


my $testModule = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops->new();
$testModule->init();

my $insertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $insertLoopInfo = $dbh->prepare("INSERT INTO LoopInfo (LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $insertLoops = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) VALUES (?, ?)");

my $selectLoopInfo = $dbh->prepare("SELECT Active, Included FROM LoopInfo WHERE LoopId = ?");

my $selectCandidateTransactionCountAll = $dbh->prepare("SELECT COUNT(*) FROM CandidateTransactions");
my $selectChainsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Chains");
my $selectChainInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo");
my $selectBranchedTransactionsCountAll = $dbh->prepare("SELECT COUNT(*) FROM BranchedTransactions");
my $selectLoopsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Loops");
my $selectLoopInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM LoopInfo");

sub insertTransactions {
  #TransactionId, FromUserId, ToUserId, Value
  #LoopId = 1
  $insertProcessedTransactions->execute(1, 1, 2, 10); #Perfect loop
  $insertProcessedTransactions->execute(2, 2, 1, 10);
  
  #LoopId = 2
  $insertProcessedTransactions->execute(3, 3, 4, 10);
  $insertProcessedTransactions->execute(4, 4, 5, 10);
  $insertProcessedTransactions->execute(5, 5, 3, 8);
  
  #LoopId = 3
  $insertProcessedTransactions->execute(6, 6, 7, 10);
  $insertProcessedTransactions->execute(7, 7, 8, 10);
  $insertProcessedTransactions->execute(8, 8, 6, 12);
  
  #LoopId = 4
  $insertProcessedTransactions->execute(9, 9, 10, 10);
  $insertProcessedTransactions->execute(10, 10, 9, 13);
  
  #LoopId = 5
  $insertProcessedTransactions->execute(11, 11, 12, 10);
  $insertProcessedTransactions->execute(12, 12, 11, 9);
  
  #LoopId = 6
  $insertProcessedTransactions->execute(13, 13, 14, 11);
  $insertProcessedTransactions->execute(14, 14, 15, 11);
  $insertProcessedTransactions->execute(15, 15, 16, 11);
  $insertProcessedTransactions->execute(16, 16, 13, 11);
  
  #LoopId = 7
  $insertProcessedTransactions->execute(17, 17, 18, 15);
  $insertProcessedTransactions->execute(18, 18, 17, 16);
  
  #LoopId = 8
  $insertProcessedTransactions->execute(19, 19, 20, 10);
  $insertProcessedTransactions->execute(20, 20, 19, 15);
  
}

sub insertLoops {
  #LoopId_FK, TransactionId_FK
  #LoopId = 1
  $insertLoops->execute(1, 1);
  $insertLoops->execute(1, 2);
  
  #LoopId = 2
  $insertLoops->execute(2, 3);
  $insertLoops->execute(2, 4);
  $insertLoops->execute(2, 5);
  
  #LoopId = 3
  $insertLoops->execute(3, 6);
  $insertLoops->execute(3, 7);
  $insertLoops->execute(3, 8);
  
  #LoopId = 4
  $insertLoops->execute(4, 9);
  $insertLoops->execute(4, 10);
  
  #LoopId = 5
  $insertLoops->execute(5, 11);
  $insertLoops->execute(5, 12);
  
  #LoopId = 6
  $insertLoops->execute(6, 13);
  $insertLoops->execute(6, 14);
  $insertLoops->execute(6, 15);
  $insertLoops->execute(6, 16);
  
  #LoopId = 7
  $insertLoops->execute(7, 17);
  $insertLoops->execute(7, 18);
  
  #LoopId = 8
  $insertLoops->execute(8, 19);
  $insertLoops->execute(8, 20);
}

sub getLoopInfoActiveIncluded {
  my ($loopId) = @_;
  $selectLoopInfo->execute($loopId);
  return $selectLoopInfo->fetchrow_array();
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

sub numLoopsRows {
  $selectLoopsCountAll->execute();
  my ($num) = $selectLoopsCountAll->fetchrow_array();
  
  return $num;
}

sub numLoopInfoRows {
  $selectLoopInfoCountAll->execute();
  my ($num) = $selectLoopInfoCountAll->fetchrow_array();
  
  return $num;
}


say "Test 1 - Empty table - pass undef first restriction variable.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(); }; 
isnt ($exception, undef ,"Exception thrown for undef first restriction");



say "Test 2 - Empty table - not first restriction.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(0); }; #not first restriction
is ($exception, undef ,"No exception thrown"); 



say "Test 3 - Empty table - first restriction.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(1); }; #first restriction
is ($exception, undef ,"No exception thrown"); 



sub initialiseData1 {

  delete_table_data();
  
  #Overlapping loops should not be disabled.
  #TransactionId, FromUserId, ToUserId, Value
  $insertProcessedTransactions->execute(1,  1,   2, 10); #LoopId = 1
  $insertProcessedTransactions->execute(2,  3,   4, 10); #LoopId = 2
  $insertProcessedTransactions->execute(3,  2,   1, 10); #LoopId = 1
  $insertProcessedTransactions->execute(4,  4,   5, 12); #LoopId = 2
  $insertProcessedTransactions->execute(5,  5,   3, 10); #LoopId = 2 and 3 
  $insertProcessedTransactions->execute(6,  3,   6, 10); #LoopId = 3
  $insertProcessedTransactions->execute(7,  6,   7,  8); #LoopId = 3
  $insertProcessedTransactions->execute(8,  9,  10, 15); #LoopId = 4
  $insertProcessedTransactions->execute(9,  7,   3, 10); #LoopId = 3
  $insertProcessedTransactions->execute(10, 10, 11, 10); #LoopId = 4
  $insertProcessedTransactions->execute(11, 11,  9,  5); #LoopId = 4

  #The active and included are what matter.
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
                              #                      #
  $insertLoopInfo->execute(1, 0, 1,  3, 10, 2, 20, 2, 0); #Not included and all transactions only used by itself
  $insertLoopInfo->execute(2, 0, 2,  5, 10, 3, 32, 2, 1); #Included and a transaction used by another loop
  $insertLoopInfo->execute(3, 0, 5,  9, 8, 4, 38, 1, 0); #Not included and a transaction used by another loop
  $insertLoopInfo->execute(4, 0, 8, 11,  5, 3, 30, 1, 1); #Included and all transactions only used by itself
  
  #LoopId_FK, TransactionId_FK
  #LoopId = 1
  $insertLoops->execute(1, 1);
  $insertLoops->execute(1, 3);
  #LoopId = 2
  $insertLoops->execute(2, 2);
  $insertLoops->execute(2, 4);
  $insertLoops->execute(2, 5);
  #LoopId = 3
  $insertLoops->execute(3, 5);
  $insertLoops->execute(3, 6);
  $insertLoops->execute(3, 7);
  $insertLoops->execute(3, 9);
  #LoopId = 4
  $insertLoops->execute(4, 8);
  $insertLoops->execute(4, 10);
  $insertLoops->execute(4, 11);
}



say "Test 4 - No loops active - not first restriction";
{
  initialiseData1();

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows before execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 12, "There was 12 loop rows before execution.");
  is (numLoopInfoRows(), 4, "There was 4 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(0); }; #not first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows after execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 12, "There was 12 loop rows after execution.");
  is (numLoopInfoRows(), 4, "There was 4 loop info rows after execution.");

  #Two occurances of everything to make sure it happens to more than 1 row.
  my ($active, $included) = (undef, undef);
  ($active, $included) = getLoopInfoActiveIncluded(1);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(2);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(3);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed");
  ($active, $included) = (undef, undef);
}



say "Test 5 - No loops active - first restriction";
{
  initialiseData1();

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows before execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 12, "There was 12 loop rows before execution.");
  is (numLoopInfoRows(), 4, "There was 4 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(1); }; #not first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows after execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 12, "There was 12 loop rows after execution.");
  is (numLoopInfoRows(), 4, "There was 4 loop info rows after execution.");

  #Two occurances of everything to make sure it happens to more than 1 row.
  my ($active, $included) = (undef, undef);
  ($active, $included) = getLoopInfoActiveIncluded(1);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has been set to 1");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(2);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed (it was set to 1 but was already 1)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(3);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has been set to 1");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed (it was set to 1 but was already 1)");
  ($active, $included) = (undef, undef);
}


sub initialiseData2 {

  delete_table_data();
  
  #Overlapping loops should not be disabled.
  #TransactionId, FromUserId, ToUserId, Value
  $insertProcessedTransactions->execute(1,  1,  2, 10); #LoopId = 1
  $insertProcessedTransactions->execute(2,  3,  4, 10); #LoopId = 2
  $insertProcessedTransactions->execute(3,  2,  1, 10); #LoopId = 1
  $insertProcessedTransactions->execute(4,  4,  5, 12); #LoopId = 2
  $insertProcessedTransactions->execute(5,  5,  3, 10); #LoopId = 2 and 3 
  $insertProcessedTransactions->execute(6,  3,  6, 10); #LoopId = 3
  $insertProcessedTransactions->execute(7,  6,  7,  8); #LoopId = 3
  $insertProcessedTransactions->execute(8,  7,  3, 10); #LoopId = 3 and 4
  $insertProcessedTransactions->execute(9,  3,  8, 10); #LoopId = 4
  $insertProcessedTransactions->execute(10, 8,  7,  5); #LoopId = 4
  
  $insertProcessedTransactions->execute(11, 13, 14, 10); #LoopId = 5
  $insertProcessedTransactions->execute(12, 14, 15, 12); #LoopId = 5
  $insertProcessedTransactions->execute(13, 15, 13, 10); #LoopId = 5 and 6
  $insertProcessedTransactions->execute(14, 13, 16, 10); #LoopId = 6
  $insertProcessedTransactions->execute(15, 16, 17,  8); #LoopId = 6
  $insertProcessedTransactions->execute(16, 17, 13, 10); #LoopId = 6 and 7
  $insertProcessedTransactions->execute(17, 13, 18, 10); #LoopId = 7
  $insertProcessedTransactions->execute(18, 18, 17,  5); #LoopId = 7
  
  $insertProcessedTransactions->execute(19, 20, 21, 10); #LoopId = 8
  $insertProcessedTransactions->execute(20, 21, 22, 9);  #LoopId = 8
  $insertProcessedTransactions->execute(21, 22, 20, 10); #LoopId = 8

  #The active and included are what matter.
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
                              #                        #
  $insertLoopInfo->execute(1, 0,  1,  3, 10, 2, 20, 2, 0); #Not included and all transactions only used by itself

  #This one determines what happens when the included for an active loop is 0.
  $insertLoopInfo->execute(2, 0,  2,  5, 10, 3, 32, 2, 0); #Not included but used a transaction is used in another active loop.
  $insertLoopInfo->execute(3, 1,  5,  8,  8, 4, 38, 1, 0); #Active loop which is not included.
  $insertLoopInfo->execute(4, 0,  8, 10,  5, 3, 25, 1, 1); #Included but used a transaction is used in another active loop.
  
  #This one determines what happens when the included for an active loop is 1.
  $insertLoopInfo->execute(5, 0, 11, 13, 10, 3, 32, 2, 1); #Included but used a transaction is used in another active loop.
  $insertLoopInfo->execute(6, 1, 13, 16,  8, 4, 38, 1, 1); #Active loop which is included.
  $insertLoopInfo->execute(7, 0, 16, 18,  5, 3, 25, 1, 0); #Not included but used a transaction is used in another active loop.
  
  $insertLoopInfo->execute(8, 0, 19, 21,  9, 3, 29, 1, 1); #Included and all transactions only used by itself
  
  #LoopId_FK, TransactionId_FK
  #LoopId = 1
  $insertLoops->execute(1, 1);
  $insertLoops->execute(1, 3);
  #LoopId = 2
  $insertLoops->execute(2, 2);
  $insertLoops->execute(2, 4);
  $insertLoops->execute(2, 5);
  #LoopId = 3
  $insertLoops->execute(3, 5);
  $insertLoops->execute(3, 6);
  $insertLoops->execute(3, 7);
  $insertLoops->execute(3, 8);
  #LoopId = 4
  $insertLoops->execute(4, 8);
  $insertLoops->execute(4, 9);
  $insertLoops->execute(4, 10);
  #LoopId = 5
  $insertLoops->execute(5, 11);
  $insertLoops->execute(5, 12);
  $insertLoops->execute(5, 13);
  #LoopId = 6
  $insertLoops->execute(6, 13);
  $insertLoops->execute(6, 14);
  $insertLoops->execute(6, 15);
  $insertLoops->execute(6, 16);
  #LoopId = 7
  $insertLoops->execute(7, 16);
  $insertLoops->execute(7, 17);
  $insertLoops->execute(7, 18);
  #LoopId = 8
  $insertLoops->execute(8, 19);
  $insertLoops->execute(8, 20);
  $insertLoops->execute(8, 21);
}

say "Test 6 - Some loops active - not first restriction";
{
  initialiseData2();

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows before execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 25, "There was 25 loop rows before execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(0); }; #not first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows after execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 25, "There was 25 loop rows after execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows after execution.");

  #Two occurances of everything to make sure it happens to more than 1 row.
  my ($active, $included) = (undef, undef);
  ($active, $included) = getLoopInfoActiveIncluded(1);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(2);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed (it was set to 0 by loop 3 being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(3);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (it was set to 0 by itself being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has been set to 0 as loop 3 is active");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(5);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has been set to 0 as loop 6 is active");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(6);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included been set to 0 as itself is active.");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(7);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed (it was set to 0 by loop 6 being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(8);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed");
  ($active, $included) = (undef, undef);
  
}



say "Test 7 - Some loops active - first restriction";
{
  initialiseData2();

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows before execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 25, "There was 25 loop rows before execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(1); }; #not first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandidateTransactionRows(), 0, "There was 0 candidate transaction rows after execution.");
  is (numChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numChainInfoRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 25, "There was 25 loop rows after execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows after execution.");

  #Two occurances of everything to make sure it happens to more than 1 row.
  my ($active, $included) = (undef, undef);
  ($active, $included) = getLoopInfoActiveIncluded(1);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has been reset to 1 by being the first restriction");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(2);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed (it was reset to 1 then set to 0 by loop 3 being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(3);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (it was reset to 1 then, it was set to 0 by itself being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has been set to 0 as loop 3 is active (it was reset to 1, but it was already 1, then set to 0)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(5);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has been set to 0 as loop 6 is active (it was reset to 1, but it was already 1, then set to 0)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(6);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included was reset to 1, but was already 1, then was set to 0 as itself is active.");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(7);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed (it was reset to 1 then set to 0 by loop 6being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(8);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed (it was reset to 1 but was already 1)");
  ($active, $included) = (undef, undef);
  
}



done_testing();
