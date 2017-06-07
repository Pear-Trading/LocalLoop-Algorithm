use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops;
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops;
use Pear::LocalLoop::Algorithm::TransactionOrder::EarliestTransactionFirst;
use Path::Class::File;
use Data::Dumper;
use v5.10;

use FindBin;

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


my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

my $disallowSelectedLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops->new();
my $disallowTransactionsInLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops->new();
my $loopDynamicRestrictions = [$disallowSelectedLoops, $disallowTransactionsInLoops];

#Static restrictions, chain dynamic restrictions and transaction ordering are not needed.
my $hash = {
  loopHeuristicArray => $heuristics,
  loopDynamicRestrictionsArray => $loopDynamicRestrictions,
};

my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new($hash);
$none->init();
$disallowSelectedLoops->init();
$disallowTransactionsInLoops->init();
$none->initAfterStaticRestrictions();
$disallowSelectedLoops->initAfterStaticRestrictions();
$disallowTransactionsInLoops->initAfterStaticRestrictions();

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertLoopInfoId = $dbh->prepare("INSERT INTO LoopInfo (LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $statementInsertLoops = $dbh->prepare("INSERT INTO Loops (LoopId_FK, TransactionId_FK) VALUES (?, ?)");

my $statementSelectLoopActive = $dbh->prepare("SELECT Active FROM LoopInfo WHERE LoopId = ?");

my $selectLoopsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Loops");
my $selectLoopInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM LoopInfo");

sub selectLoopActive {
  my ($loopId) = @_;
  
  if ( ! defined $loopId ) {
    die "loopId cannot be undefined";
  }
  
  $statementSelectLoopActive->execute($loopId);
  return @{$statementSelectLoopActive->fetchrow_arrayref()}[0];
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


say "Test 1 - Empty table";
{
  delete_table_data();
  
  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 0, "There is no loop info rows after execution.");  
  is(numLoopsRows(), 0, "There is no loop rows after execution.");
  
}



say "Test 2 - 2 possible loops, 1 loop selected, all loops initially inactive and all loops included";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  $statementInsertProcessedTransactions->execute( 3,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  ##LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 0, 1, 2, 8, 2, 18, 1, 1); 
  $statementInsertLoopInfoId->execute(2, 0, 1, 4, 8, 3, 28, 2, 1); 

  ##LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  
  $statementInsertLoops->execute(2, 1);
  $statementInsertLoops->execute(2, 3);
  $statementInsertLoops->execute(2, 4);

  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows before execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows after execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows after execution.");
  
  is (selectLoopActive(1), 1, "LoopId = 1 is active.");
  is (selectLoopActive(2), 0, "LoopId = 2 isn't active.");

}



say "Test 3 - 2 possible loops, 1 loop selected, all loops initially inactive and best loop not included";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  $statementInsertProcessedTransactions->execute( 3,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  ##LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 0, 1, 2, 8, 2, 18, 1, 0); 
  $statementInsertLoopInfoId->execute(2, 0, 1, 4, 8, 3, 28, 2, 1); 

  ##LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  
  $statementInsertLoops->execute(2, 1);
  $statementInsertLoops->execute(2, 3);
  $statementInsertLoops->execute(2, 4);

  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows before execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows after execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows after execution.");
  
  is (selectLoopActive(1), 1, "LoopId = 1 is active.");
  is (selectLoopActive(2), 0, "LoopId = 2 isn't active.");

}



say "Test 4 - 2 possible loops, 1 loop selected, all loops initially active";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  $statementInsertProcessedTransactions->execute( 3,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  ##LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 1, 1, 2, 8, 2, 18, 1, 1); 
  $statementInsertLoopInfoId->execute(2, 1, 1, 4, 8, 3, 28, 2, 1); 

  ##LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  
  $statementInsertLoops->execute(2, 1);
  $statementInsertLoops->execute(2, 3);
  $statementInsertLoops->execute(2, 4);

  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows before execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows after execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows after execution.");
  
  is (selectLoopActive(1), 1, "LoopId = 1 is active.");
  is (selectLoopActive(2), 0, "LoopId = 2 isn't active.");

}



say "Test 5 - 2 possible loops, 1 loop selected, best loop inactive";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  1,  8);
  $statementInsertProcessedTransactions->execute( 3,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  ##LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 0, 1, 2, 8, 2, 18, 1, 1); 
  $statementInsertLoopInfoId->execute(2, 1, 1, 4, 8, 3, 28, 2, 1); 

  ##LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  
  $statementInsertLoops->execute(2, 1);
  $statementInsertLoops->execute(2, 3);
  $statementInsertLoops->execute(2, 4);

  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows before execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 2, "There are 2 loop info rows after execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows after execution.");
  
  is (selectLoopActive(1), 1, "LoopId = 1 is active.");
  is (selectLoopActive(2), 0, "LoopId = 2 isn't active.");

}



say "Test 6 - 3 possible loops, 2 loops selected, 2 loops overlap and 1 doesn't";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10);
  $statementInsertProcessedTransactions->execute( 2,  2,  3,  8);
  $statementInsertProcessedTransactions->execute( 3,  1,  3, 10);
  $statementInsertProcessedTransactions->execute( 4,  3,  1, 10);
  
  $statementInsertProcessedTransactions->execute( 5,  4,  5, 10);
  $statementInsertProcessedTransactions->execute( 6,  5,  6, 12);
  $statementInsertProcessedTransactions->execute( 7,  6,  4, 10);

  ##LoopId, Active, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included
  $statementInsertLoopInfoId->execute(1, 0, 1, 4,  8, 3, 28, 1, 1); 
  $statementInsertLoopInfoId->execute(2, 0, 3, 4, 10, 2, 20, 2, 1); 
  $statementInsertLoopInfoId->execute(3, 0, 5, 7, 10, 3, 32, 2, 1);

  ##LoopId_FK, TransactionId_FK
  $statementInsertLoops->execute(1, 1);
  $statementInsertLoops->execute(1, 2);
  $statementInsertLoops->execute(1, 4);
 
  $statementInsertLoops->execute(2, 3);
  $statementInsertLoops->execute(2, 4);
  
  $statementInsertLoops->execute(3, 5);
  $statementInsertLoops->execute(3, 6);
  $statementInsertLoops->execute(3, 7);
  
  is(numLoopInfoRows(), 3, "There are 3 loop info rows before execution.");  
  is(numLoopsRows(), 8, "There are 8 loop rows before execution.");

  my $exception = exception { $main->_loopSelection($settings); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numLoopInfoRows(), 3, "There are 3 loop info rows after execution.");  
  is(numLoopsRows(), 8, "There are 8 loop rows after execution.");
  
  is (selectLoopActive(1), 1, "LoopId = 1 is active.");
  is (selectLoopActive(2), 0, "LoopId = 2 isn't active.");
  is (selectLoopActive(3), 1, "LoopId = 1 is active.");
}
  
done_testing();

