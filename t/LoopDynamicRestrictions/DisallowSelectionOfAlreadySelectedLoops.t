use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops"

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


my $testModule = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops->new();

my $insertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $insertLoopInfo = $dbh->prepare("INSERT INTO LoopInfo (LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $insertLoops = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) VALUES (?, ?)");

my $selectLoopInfo = $dbh->prepare("SELECT Active, Included FROM LoopInfo WHERE LoopId = ?");

my $selectCandinateTransactionCountAll = $dbh->prepare("SELECT COUNT(*) FROM CandinateTransactions");
my $selectCurrentChainsCountAll = $dbh->prepare("SELECT COUNT(*) FROM CurrentChains");
my $selectCurrentChainsStatsCountAll = $dbh->prepare("SELECT COUNT(*) FROM CurrentChainsStats");
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

sub numCandinateTransactionRows {
  $selectCandinateTransactionCountAll->execute();
  my ($num) = $selectCandinateTransactionCountAll->fetchrow_array();
  
  return $num;
}

sub numCurrentChainsRows {
  $selectCurrentChainsCountAll->execute();
  my ($num) = $selectCurrentChainsCountAll->fetchrow_array();
  
  return $num;
}

sub numCurrentChainsStatsRows {
  $selectCurrentChainsStatsCountAll->execute();
  my ($num) = $selectCurrentChainsStatsCountAll->fetchrow_array();
  
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


#Template
#LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
                            #                        #
#$insertLoopInfo->execute(1, ?, 1,  2,  10, 2, 20, 2, ?);
#$insertLoopInfo->execute(2, ?, 3,  5,  8,  3, 28, 2, ?);
#$insertLoopInfo->execute(3, ?, 6,  8,  10, 3, 32, 2, ?);
#$insertLoopInfo->execute(4, ?, 9,  10, 10, 2, 23, 1, ?);
#$insertLoopInfo->execute(5, ?, 11, 12, 9,  2, 19, 1, ?);
#$insertLoopInfo->execute(6, ?, 13, 16, 11, 4, 44, 4, ?);
#$insertLoopInfo->execute(7, ?, 17, 18, 15, 2, 31, 1, ?);
#$insertLoopInfo->execute(8, ?, 19, 20, 10, 2, 25, 1, ?);

say "Test 1 - Empty table - not first restriction.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(0); }; #not first restriction
is ($exception, undef ,"No exception thrown"); 



say "Test 2 - Empty table - first restriction.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(1); }; #first restriction
is ($exception, undef ,"No exception thrown");



say "Test 3 - Empty table - pass undef first pass variable.";
delete_table_data();

my $exception = exception { $testModule->applyLoopDynamicRestriction(); }; 
isnt ($exception, undef ,"Exception thrown for undef first restriction");



say "Test 4 - Not first dynamic restriction";
{
  delete_table_data();
  insertTransactions();
  
  #Active and Includes will alternates in pattern (0, 0), (0, 1), (1, 0), (1, 1).
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
                              #                        #
  $insertLoopInfo->execute(1, 0, 1,  2,  10, 2, 20, 2, 0);
  $insertLoopInfo->execute(2, 0, 3,  5,  8,  3, 28, 2, 1);
  $insertLoopInfo->execute(3, 1, 6,  8,  10, 3, 32, 2, 0);
  $insertLoopInfo->execute(4, 1, 9,  10, 10, 2, 23, 1, 1);
  $insertLoopInfo->execute(5, 0, 11, 12, 9,  2, 19, 1, 0);
  $insertLoopInfo->execute(6, 0, 13, 16, 11, 4, 44, 4, 1);
  $insertLoopInfo->execute(7, 1, 17, 18, 15, 2, 31, 1, 0);
  $insertLoopInfo->execute(8, 1, 19, 20, 10, 2, 25, 1, 1);
  insertLoops();

  is (numCandinateTransactionRows(), 0, "There was 0 candinate transaction rows before execution.");
  is (numCurrentChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numCurrentChainsStatsRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 20, "There was 20 loop rows before execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(0); }; #not first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandinateTransactionRows(), 0, "There was 0 candinate transaction rows after execution.");
  is (numCurrentChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numCurrentChainsStatsRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 20, "There was 20 loop rows after execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows after execution.");

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
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (included was set to 0 but was already 0)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has been set to 0.");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(5);
  is ($active, 0, "active has not changed.");
  is ($included, 0, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(6);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(7);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (included was set to 0 but was already 0)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(8);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has been set to 0.");
  ($active, $included) = (undef, undef);
}



say "Test 5 - First dynamic restriction";
{
  delete_table_data();
  insertTransactions();
  
  #Active and Includes will alternates in pattern (0, 0), (0, 1), (1, 0), (1, 1).
  #LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
                              #                        #
  $insertLoopInfo->execute(1, 0, 1,  2,  10, 2, 20, 2, 0);
  $insertLoopInfo->execute(2, 0, 3,  5,  8,  3, 28, 2, 1);
  $insertLoopInfo->execute(3, 1, 6,  8,  10, 3, 32, 2, 0);
  $insertLoopInfo->execute(4, 1, 9,  10, 10, 2, 23, 1, 1);
  $insertLoopInfo->execute(5, 0, 11, 12, 9,  2, 19, 1, 0);
  $insertLoopInfo->execute(6, 0, 13, 16, 11, 4, 44, 4, 1);
  $insertLoopInfo->execute(7, 1, 17, 18, 15, 2, 31, 1, 0);
  $insertLoopInfo->execute(8, 1, 19, 20, 10, 2, 25, 1, 1);
  insertLoops();

  is (numCandinateTransactionRows(), 0, "There was 0 candinate transaction rows before execution.");
  is (numCurrentChainsRows(), 0, "There was 0 current chains rows before execution.");
  is (numCurrentChainsStatsRows(), 0, "There was 0 current chains stats rows before execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows before execution.");
  is (numLoopsRows(), 20, "There was 20 loop rows before execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows before execution.");

  my $exception = exception { $testModule->applyLoopDynamicRestriction(1); }; #first restriction
  is ($exception, undef ,"No exception thrown"); 

  is (numCandinateTransactionRows(), 0, "There was 0 candinate transaction rows after execution.");
  is (numCurrentChainsRows(), 0, "There was 0 current chains rows after execution.");
  is (numCurrentChainsStatsRows(), 0, "There was 0 current chains stats rows after execution.");
  is (numBranchedTransactionsRows(), 0, "There was 0 branched transaction rows after execution.");
  is (numLoopsRows(), 20, "There was 20 loop rows after execution.");
  is (numLoopInfoRows(), 8, "There was 8 loop info rows after execution.");

  #Two occurances of everything to make sure it happens to more than 1 row.
  my ($active, $included) = (undef, undef);
  ($active, $included) = getLoopInfoActiveIncluded(1);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included was reset to 1 (by it being the first restriction)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(2);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed (it was reset to 1 but was already 1)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(3);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (it was reset to 1, but was disabled again because of the loop being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(4);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has been set to 0 (it was reset to 1, but it already was 1, then it was set 0).");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(5);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included was reset to 1 (by it being the first restriction)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(6);
  is ($active, 0, "active has not changed.");
  is ($included, 1, "included has not changed (it was reset to 1 but was already 1)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(7);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has not changed (it was reset to 1, but was disabled again because of the loop being active)");
  ($active, $included) = (undef, undef);
  
  ($active, $included) = getLoopInfoActiveIncluded(8);
  is ($active, 1, "active has not changed.");
  is ($included, 0, "included has been set to 0 (it was reset to 1, but it already was 1, then it was set 0).");
  ($active, $included) = (undef, undef);
}


done_testing();
