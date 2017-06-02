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
use Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst;
use Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst;
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


my $rst = Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop->new();
my $staticRestrictions = [$rst];

my $matchId = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();
my $afterCurrent = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction->new();
my $extendedOnto = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();
my $dynamicRestrictions = [$matchId, $extendedOnto, $afterCurrent];

my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

my $disallowSelectedLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops->new();
my $disallowTransactionsInLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops->new();
my $loopDynamicRestrictions = [$disallowSelectedLoops, $disallowTransactionsInLoops];


my $settingsEarl = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({
  staticRestrictionsArray => $staticRestrictions,
  dynamicRestrictionsArray => $dynamicRestrictions,
  chainHeuristicArray => $heuristics,
  loopHeuristicArray => $heuristics,
  loopDynamicRestrictionsArray => $loopDynamicRestrictions,
  transactionOrder => Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst->new(),
});

my $statementInsertOriginalTransactions = $dbh->prepare("INSERT INTO OriginalTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $selectLoopActiveFromStartEndTransaction = $dbh->prepare("SELECT Active FROM LoopInfo WHERE FirstTransactionId_FK = ? AND LastTransactionId_FK = ?");

my $selectLoopsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Loops");
my $selectLoopInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM LoopInfo");
my $selectOriginalTransactionCount = $dbh->prepare("SELECT COUNT(*) FROM OriginalTransactions");
my $selectProcessedTransactionCount = $dbh->prepare("SELECT COUNT(*) FROM ProcessedTransactions");

sub selectLoopActive {
  my ($fromTransaction, $toTransaction) = @_;
  
  if ( ! defined $fromTransaction ) {
    die "fromTransaction cannot be undefined";
  }
  elsif ( ! defined $toTransaction ) {
    die "toTransaction cannot be undefined";
  }
  
  $selectLoopActiveFromStartEndTransaction->execute($fromTransaction, $toTransaction); 
  return $selectLoopActiveFromStartEndTransaction->fetchrow_array();
}

sub numOriginalTransactionsRows {
  $selectOriginalTransactionCount->execute();
  my ($num) = $selectOriginalTransactionCount->fetchrow_array();
  
  return $num;
}

sub numProcessedTrasactionRows {
  $selectProcessedTransactionCount->execute();
  my ($num) = $selectProcessedTransactionCount->fetchrow_array();
  
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


sub clear_tables {
  #This is designed so that if it fails to clear the tables the data will be retained between calls,
  #hence will likely make the algorithm produce unexpected behaviour.
  
  #Only clear the original transactions for the above reason (ignoring the exception below).
  $dbh->do("DELETE FROM OriginalTransactions");
  
  #This state is expected to be retained between calls, as this has not been implemented yet manually clear 
  #the tables.
  $dbh->do("DELETE FROM Loops"); 
  $dbh->do("DELETE FROM LoopInfo");
}

#As we are not doing a full deletion of tables in the database per test at the start delete everything
#so we have a known state to test with.
delete_table_data();

say "Test 1 - Empty table";
{
  clear_tables(); #Read comments in this function.

  is(numOriginalTransactionsRows(), 0, "There is no original transaction rows before execution.");  
  is(numProcessedTrasactionRows(), 0, "There is no processed transaction rows before execution.");  
  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");

  my $exception = exception { $main->process($settingsEarl); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numOriginalTransactionsRows(), 0, "There is no original transaction rows after execution.");  
  is(numProcessedTrasactionRows(), 0, "There is no processed transaction rows after execution.");  
  is(numLoopInfoRows(), 0, "There is no loop info rows after execution.");  
  is(numLoopsRows(), 0, "There is no loop rows after execution.");
  
}



say "Test 2 - 2 possible loops, both overlapping - order 1";
{
  clear_tables(); #Read comments in this function.
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertOriginalTransactions->execute( 1,  1,  2, 10); # Loop 1 and 2
  $statementInsertOriginalTransactions->execute( 2,  5,  6, 70); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 3,  2,  3,  8); # Loop 1
  $statementInsertOriginalTransactions->execute( 4,  6,  7, 50); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 5,  2,  1,  8); # Loop 2
  $statementInsertOriginalTransactions->execute( 6,  7,  8, 90); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 7,  3,  1, 10); # Loop 1


  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows before execution.");  
  is(numProcessedTrasactionRows(), 0, "There are 4 processed transaction rows before execution (based on previous test).");  
  is(numLoopInfoRows(), 0, "There is 0 loop info rows before execution.");  
  is(numLoopsRows(), 0, "There is 0 loop rows before execution.");

  my $exception = exception { $main->process($settingsEarl); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows after execution.");  
  is(numProcessedTrasactionRows(), 4, "There are 4 processed transaction rows after execution.");
  is(numLoopInfoRows(), 2, "There are 2 loop info rows after execution.");  
  is(numLoopsRows(), 5, "There are 5 loop rows after execution.");
  
  is (selectLoopActive(1, 5), 1, "LoopId starting at transaction 1 and ending at transaction 3 is active.");
  is (selectLoopActive(1, 7), 0, "LoopId starting at transaction 1 and ending at transaction 4 isn't active.");

}



say "Test 3 - 2 possible loops, both overlapping - order 2";
{
  clear_tables(); #Read comments in this function.
  
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertOriginalTransactions->execute( 1,  1,  2, 10); # Loop 1 and 2
  $statementInsertOriginalTransactions->execute( 2,  5,  6, 70); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 3,  2,  1,  8); # Loop 2
  $statementInsertOriginalTransactions->execute( 4,  6,  7, 50); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 5,  2,  3,  8); # Loop 1
  $statementInsertOriginalTransactions->execute( 6,  7,  8, 90); # Transaction to be removed by the static restrictions.
  $statementInsertOriginalTransactions->execute( 7,  3,  1, 10); # Loop 1

  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows before execution.");  
  is(numProcessedTrasactionRows(), 4, "There are 4 processed transaction rows before execution (based on previous test)."); 
  is(numLoopInfoRows(), 0, "There is 0 loop info rows before execution.");  
  is(numLoopsRows(), 0, "There is 0 loop rows before execution.");

  my $exception = exception { $main->process($settingsEarl); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows after execution.");  
  is(numProcessedTrasactionRows(), 4, "There are 4 processed transaction rows after execution.");
  
  #This is not present due to the selection ordering of None. So it starts at 1, then extends onto 2 then finished.
  #Previous it started at 1 extended onto 2, branched to 3 then finished. transaction 4 was a candinate so was added.
  is(numLoopInfoRows(), 1, "There are 1 loop info rows after execution.");  
  is(numLoopsRows(), 2, "There are 2 loop rows after execution.");
  
  is (selectLoopActive(1, 3), 1, "LoopId starting at transaction 1 and ending at transaction 3 is active.");
}



say "Test 4 - 3 possible loops, two overlapping one not";
{
  clear_tables(); #Read comments in this function.
  
  #It would be able to pick out loops 1 and 2 that start at transaction 1, as well as loop 3 that starts at transaction 5.
  #TransactionId, FromUserId, ToUserId, Value  
  $statementInsertOriginalTransactions->execute( 1,  1,  2, 10); # Loop 1 and 2
  $statementInsertOriginalTransactions->execute( 2,  2,  3,  8); # Loop 1
  $statementInsertOriginalTransactions->execute( 3,  2,  1,  8); # Loop 2
  $statementInsertOriginalTransactions->execute( 4,  3,  1, 10); # Loop 1
  $statementInsertOriginalTransactions->execute( 5,  4,  5, 10); # Loop 3
  $statementInsertOriginalTransactions->execute( 6,  5,  6, 10); # Loop 3
  $statementInsertOriginalTransactions->execute( 7,  6,  4, 10); # Loop 3

  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows before execution.");  
  is(numProcessedTrasactionRows(), 4, "There are 4 processed transaction rows before execution (based on previous test)."); 
  is(numLoopInfoRows(), 0, "There is 0 loop info rows before execution.");  
  is(numLoopsRows(), 0, "There is 0 loop rows before execution.");

  my $exception = exception { $main->process($settingsEarl); };
  is ($exception, undef, "No exeception thrown.");
  
  is(numOriginalTransactionsRows(), 7, "There are 7 original transaction rows after execution.");  
  is(numProcessedTrasactionRows(), 7, "There are 7 processed transaction rows after execution.");
  
  #This is not present due to the selection ordering of None. So it starts at 1, then extends onto 2 then finished.
  #Previous it started at 1 extended onto 2, branched to 3 then finished. transaction 4 was a candinate so was added.
  is(numLoopInfoRows(), 3, "There are 3 loop info rows after execution.");  
  is(numLoopsRows(), 8, "There are 8 loop rows after execution.");
  
  is (selectLoopActive(1, 3), 1, "LoopId starting at transaction 1 and ending at transaction 3 is active.");
  is (selectLoopActive(1, 4), 0, "LoopId starting at transaction 1 and ending at transaction 4 isn't active.");
  is (selectLoopActive(5, 7), 1, "LoopId starting at transaction 5 and ending at transaction 7 is active.");
}



  
done_testing();

