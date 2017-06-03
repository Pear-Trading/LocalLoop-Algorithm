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

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertChains = $dbh->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");
my $statementInsertCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
my $statementInsertBranchedTransactions = $dbh->prepare("INSERT INTO BranchedTransactions (ChainId_FK, FromTransactionId_FK, ToTransactionId_FK) VALUES (?, ?, ?)");

my $selectChainsId = $dbh->prepare("SELECT ChainInfoId_FK FROM Chains WHERE ChainId = ? AND TransactionId_FK = ?");
my $selectChainInfoId = $dbh->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM ChainInfo WHERE ChainInfoId = ?");

my $selectLoopInfoFromStartEndTransaction = $dbh->prepare("SELECT LoopId, MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM LoopInfo WHERE FirstTransactionId_FK = ? AND LastTransactionId_FK = ?");

my $selectLoopCountSingle = $dbh->prepare("SELECT COUNT(*) FROM Loops WHERE LoopId_FK = ? AND TransactionId_FK = ?");

my $selectLoopsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Loops");
my $selectLoopInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM LoopInfo");

sub selectLoopInfo {
  my ($fromTransactionId, $toTransactionId) = @_;
  
  if ( ! defined $fromTransactionId ) {
    die "fromTransactionId cannot be undefined";
  }
  elsif ( ! defined $toTransactionId ) {
    die "toTransactionId cannot be undefined";
  }
  
  $selectLoopInfoFromStartEndTransaction->execute($fromTransactionId, $toTransactionId);
  return $selectLoopInfoFromStartEndTransaction->fetchrow_array();
}

sub loopsExists {
  my ($loopId, $transactionId) = @_;
  
  if ( ! defined $loopId) {
    die "loopId cannot be undefined";
  }
  elsif ( ! defined $transactionId) {
    die "transactionId cannot be undefined";
  }
  
  $selectLoopCountSingle->execute($loopId, $transactionId);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectLoopCountSingle->fetchrow_array();
  
  return $returnedVal;
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


my $matchId = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();
my $afterCurrent = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction->new();
my $extendedOnto = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();
my $chainDynamicRestrictions = [$matchId, $extendedOnto, $afterCurrent];

my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

my $disallowSelectedLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops->new();
my $disallowTransactionsInLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops->new();
my $loopDynamicRestrictions = [$disallowSelectedLoops, $disallowTransactionsInLoops];

#Static restrictions are not needed for this.
my $hash = {
  chainDynamicRestrictionsArray => $chainDynamicRestrictions,
  chainHeuristicArray => $heuristics,
  loopHeuristicArray => $heuristics,
  loopDynamicRestrictionsArray => $loopDynamicRestrictions,
  transactionOrder => Pear::LocalLoop::Algorithm::TransactionOrder::EarliestTransactionFirst->new(),
};

my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new($hash);

say "Test 1 - Generates no loops, with deletion test of tables Chains and ChainInfo";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value
  #Transaction with from user id 3 and to user id 4 is perposefully missing,
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 4, 1, 10);
  
  #Simulate a previous pass in an attempt to maliciously break the algorithm.
  #This is to attempt to trick the algorithm into thinking a loop does exist as this data is present
  #Hence why it should clear the tables before processing. test of Chains and ChainInfo deletion.
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  $statementInsertCurrentStatsId->execute(3, 10, 3, 30, 3);
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 2, 2);
  $statementInsertChains->execute(1, 3, 3);


  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");
  
  my $returnedValue = undef;
  my $exception = exception { $returnedValue = $main->_loopGeneration($settings, 1) };
  is ($exception, undef ,"No exception thrown");

  isnt ($returnedValue, undef, "It generated at least an empty array ref.");  
  is (scalar @$returnedValue, 0, "The array ref is of size 0.");

  is(numLoopInfoRows(), 0, "There are no loop info rows after execution.");  
  is(numLoopsRows(), 0, "There is no loop rows after execution.");
}



say "Test 2 - Generate 1 loop, with deletion test of tables Chains, ChainInfo and BranchedTransactions";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #More malicious attempts to break the algorithm.
  #This is to attempt to trick the algorithm into thinking a loop does exist as this data is present
  #hence why it should clear the tables before processing. Test of Chains, ChainInfo and 
  #BranchedTransactions deletion.
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 100, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 200, 2);
  $statementInsertCurrentStatsId->execute(3, 10, 3, 300, 3); #Random total value to again notice if we break it.
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 2, 2);
  $statementInsertChains->execute(1, 3, 3);
  #In a real life senario as this would not be added as it does not branch. However in this testing we
  #can use the branched transactions table to potentially prevent a chain from linking to the finish,
  #as it blocks the extension of the from transaction to the to transaction on the specified chain.
  #ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
  $statementInsertBranchedTransactions->execute(1, 3, 4);

  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");
  
  my $returnedValue = undef;
  my $exception = exception { $returnedValue = $main->_loopGeneration($settings, 1) };
  is ($exception, undef ,"No exception thrown");

  isnt ($returnedValue, undef, "It generated at least an empty array ref.");  
  is (scalar @$returnedValue, 1, "The array ref is of size 1.");
  
  is(numLoopInfoRows(), 1, "There is 1 loop info row after execution.");  
  is(numLoopsRows(), 4, "There are 4 loop rows after execution.");

  my ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectLoopInfo(1, 4);
  is ($minimumValue, 10, "Correct minumum value returned.");
  is ($length, 4, "Correct length returned.");
  is ($totalValue, 40, "Correct total value returned.");
  is ($numberOfMinimumValues, 4, "Correct number of minimum values returned.");
  ok (loopsExists($loopId, 1), "Transaction 1 is in loop $loopId.");
  ok (loopsExists($loopId, 2), "Transaction 2 is in loop $loopId.");
  ok (loopsExists($loopId, 3), "Transaction 3 is in loop $loopId.");
  ok (loopsExists($loopId, 4), "Transaction 4 is in loop $loopId.");
}

say "Test 3 - Generate 1 loop - with random transactions and deletion test of table CandidateTransactions";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value
  #Lots of random branching and overlappingto test the system.
  $statementInsertProcessedTransactions->execute( 1,  1,  2, 10); # Loop transaction.
  $statementInsertProcessedTransactions->execute( 2,  2, 10, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 3, 10, 11, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 4, 11, 15, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 5,  2,  3,  8); # Loop transaction.
  $statementInsertProcessedTransactions->execute( 6,  3, 15, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 7, 15, 20, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 8, 15, 17, 10); # Random transaction
  $statementInsertProcessedTransactions->execute( 9,  3,  4, 10); # Loop transaction.
  $statementInsertProcessedTransactions->execute(10,  4, 20, 10); # Random transaction
  $statementInsertProcessedTransactions->execute(11, 20, 21, 10); # Random transaction
  $statementInsertProcessedTransactions->execute(12, 21, 20, 10); # Random transaction
  $statementInsertProcessedTransactions->execute(13,  4,  1, 10); # Loop transaction.
  
  
  #More malicious attempts to break the algorithm.
  #This is to attempt to trick the algorithm into thinking a loop does exist as this data is present
  #hence why it should clear the tables before processing. Test of CandidateTransactions deletion.
  #Enter a "first" transaction right at the end to see if it gets selected as first transactions (ones with
  #the chain id and from transaction id being null) get selected to be first regardless.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCandidateTransactions->execute(1, undef, undef, 13, 10, 1, 10, 1);

  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");
  
  my $returnedValue = undef;
  my $exception = exception { $returnedValue = $main->_loopGeneration($settings, 1) };
  is ($exception, undef ,"No exception thrown");

  isnt ($returnedValue, undef, "It generated at least an empty array ref.");  
  is (scalar @$returnedValue, 1, "The array ref is of size 1.");

  is(numLoopInfoRows(), 1, "There is 1 loop info row after execution.");  
  is(numLoopsRows(), 4, "There are 4 loop rows after execution.");

  my ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectLoopInfo(1, 13);
  ok (@{$returnedValue}[0] == $loopId , "Loop id is in the returned array.");
  is ($minimumValue, 8, "Correct minumum value returned.");
  is ($length, 4, "Correct length returned.");
  is ($totalValue, 38, "Correct total value returned.");
  is ($numberOfMinimumValues, 1, "Correct number of minimum values returned.");
  ok (loopsExists($loopId,  1), "Transaction 1 is in loop $loopId.");
  ok (loopsExists($loopId,  5), "Transaction 5 is in loop $loopId.");
  ok (loopsExists($loopId,  9), "Transaction 9 is in loop $loopId.");
  ok (loopsExists($loopId, 13), "Transaction 13 is in loop $loopId.");
}


say "Test 4 - Generates more than 2 loops";
{
  delete_table_data();
  
  #TransactionId, FromUserId, ToUserId, Value
  #Lots of random branching and overlappingto test the system.
  $statementInsertProcessedTransactions->execute(1,  1,  2, 10); # Loop 1, 2 and 3
  $statementInsertProcessedTransactions->execute(2,  2,  3, 10); # Loop 1 and 3
  $statementInsertProcessedTransactions->execute(3,  2, 10, 10); # Loop 2
  $statementInsertProcessedTransactions->execute(4,  3,  4, 10); # Loop 1
  $statementInsertProcessedTransactions->execute(5,  3, 20, 12); # Loop 3
  $statementInsertProcessedTransactions->execute(6, 10,  1, 10); # Loop 2  
  $statementInsertProcessedTransactions->execute(7, 20,  1, 10); # Loop 3  
  $statementInsertProcessedTransactions->execute(8,  4,  1,  8); # Loop 1

  is(numLoopInfoRows(), 0, "There is no loop info rows before execution.");
  is(numLoopsRows(), 0, "There is no loop rows before execution.");
  
  my $returnedValue = undef;
  my $exception = exception { $returnedValue = $main->_loopGeneration($settings, 1) };
  is ($exception, undef ,"No exception thrown");

  isnt ($returnedValue, undef, "It generated at least an empty array ref.");  
  is (scalar @$returnedValue, 3, "The array ref is of size 1.");

  is(numLoopInfoRows(), 3, "There are 3 loop info rows after execution.");  
  is(numLoopsRows(), 11, "There is 11 loop rows after execution.");

  my ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = (undef, undef, undef, undef, undef);
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectLoopInfo(1, 8);
  ok ((@{$returnedValue}[0] == $loopId || @{$returnedValue}[1] == $loopId || @{$returnedValue}[2] == $loopId), "Loop id is in the returned array.");
  is ($minimumValue, 8, "Correct minumum value returned.");
  is ($length, 4, "Correct length returned.");
  is ($totalValue, 38, "Correct total value returned.");
  is ($numberOfMinimumValues, 1, "Correct number of minimum values returned.");
  ok (loopsExists($loopId, 1), "Transaction 1 is in loop $loopId.");
  ok (loopsExists($loopId, 2), "Transaction 2 is in loop $loopId.");
  ok (loopsExists($loopId, 4), "Transaction 4 is in loop $loopId.");
  ok (loopsExists($loopId, 8), "Transaction 8 is in loop $loopId.");
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = (undef, undef, undef, undef, undef);
  
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectLoopInfo(1, 6);
  ok ((@{$returnedValue}[0] == $loopId || @{$returnedValue}[1] == $loopId || @{$returnedValue}[2] == $loopId), "Loop id is in the returned array.");
  is ($minimumValue, 10, "Correct minumum value returned.");
  is ($length, 3, "Correct length returned.");
  is ($totalValue, 30, "Correct total value returned.");
  is ($numberOfMinimumValues, 3, "Correct number of minimum values returned.");
  ok (loopsExists($loopId, 1), "Transaction 1 is in loop $loopId.");
  ok (loopsExists($loopId, 3), "Transaction 3 is in loop $loopId.");
  ok (loopsExists($loopId, 6), "Transaction 6 is in loop $loopId.");
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = (undef, undef, undef, undef, undef);
  
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectLoopInfo(1, 7);
  ok ((@{$returnedValue}[0] == $loopId || @{$returnedValue}[1] == $loopId || @{$returnedValue}[2] == $loopId), "Loop id is in the returned array.");
  is ($minimumValue, 10, "Correct minumum value returned.");
  is ($length, 4, "Correct length returned.");
  is ($totalValue, 42, "Correct total value returned.");
  is ($numberOfMinimumValues, 3, "Correct number of minimum values returned.");
  ok (loopsExists($loopId, 1), "Transaction 1 is in loop $loopId.");
  ok (loopsExists($loopId, 2), "Transaction 2 is in loop $loopId.");
  ok (loopsExists($loopId, 5), "Transaction 5 is in loop $loopId.");
  ok (loopsExists($loopId, 7), "Transaction 3 is in loop $loopId.");
  ($loopId, $minimumValue, $length, $totalValue, $numberOfMinimumValues) = (undef, undef, undef, undef, undef);
}

done_testing();

