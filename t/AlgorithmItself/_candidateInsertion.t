use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::ChainTransaction;
use Pear::LocalLoop::Algorithm::LoopGenerationContext;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet;
use Path::Class::File;
use Data::Dumper;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_candidateInsertion"

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


my $matchId = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();
my $afterCurrent = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction->new();
my $extendedOnto = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();
my $chainDynamicRestrictions = [$matchId, $extendedOnto, $afterCurrent];

my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

#Static restrictions are not needed here, but then static restrictions will prevent some of these events from 
#occuring.
my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({   
  chainDynamicRestrictionsArray => $chainDynamicRestrictions,
  chainHeuristicArray => $heuristics, 
});

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO ChainInfo (ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertChains = $dbh->prepare("INSERT INTO Chains (ChainId, TransactionId_FK, ChainInfoId_FK) VALUES (?, ?, ?)");
my $statementInsertCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $selectCandidateTransactionsId = $dbh->prepare("SELECT MinimumValue, Length, TotalValue, NumberOfMinimumValues FROM CandidateTransactions WHERE TransactionFrom_FK = ? AND TransactionTo_FK = ?");


my $selectCandidateTransactionCountAll = $dbh->prepare("SELECT COUNT(*) FROM CandidateTransactions");
my $selectChainsCountAll = $dbh->prepare("SELECT COUNT(*) FROM Chains");
my $selectChainInfoCountAll = $dbh->prepare("SELECT COUNT(*) FROM ChainInfo");
my $selectBranchedTransactionsCountAll = $dbh->prepare("SELECT COUNT(*) FROM BranchedTransactions");


sub selectCandidateTransactions {
  #transactionFrom can be null.
  my ($transactionFrom, $transactionTo) = @_;

  if ( ! defined $transactionTo) {
    die "transactionTo cannot be undefined";
  }
  
  $selectCandidateTransactionsId->execute($transactionFrom, $transactionTo);
  return $selectCandidateTransactionsId->fetchrow_array();
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


say "Test 1 - First transaction with no possible transactions to extend onto.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 5, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 0,"There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");
}


say "Test 2 - First transaction with 1 possible transactions to extend onto.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 1,"There is 1 candidate transaction row after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 2);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 20, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues has been updated to account for the new transaction.");
      
  is (numChainsRows(), 1, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 3 - First transaction with 2 (or more) possible transactions to extend onto.";
{
  #Modify the settings to not include the heuristics as with "None" it results in only one enabled.
  #The dynamic restrictions would maintain the integrity of links
  my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({   
    chainDynamicRestrictionsArray => $chainDynamicRestrictions,
  });

  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 4, 20); #Change it to produce different results.
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 2, "There is 2 candidate transaction rows after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 2);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 20, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues has been updated to account for the new transaction.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 3);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 30, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 1, "numberOfMinimumValues has been updated to account for the new transaction.");
      
  is (numChainsRows(), 1, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 4 - First transaction with 1 possible transactions to extend onto, next candidate has value lower than the minimum value.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 8);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 1,"There is 1 candidate transaction row after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 2);
  is ($minimumValue, 8, "minimumValue has been reduced.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 18, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 1, "numberOfMinimumValues remains the same.");
      
  is (numChainsRows(), 1, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 5 - First transaction with 1 possible transactions to extend onto, next candidate has value the same as the minimum value.";
{
  #This is essentially test 2.
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 1,"There is 1 candidate transaction row after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 2);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 20, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues has been updated to account for the new transaction.");
      
  is (numChainsRows(), 1, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 6 - First transaction with 1 possible transactions to extend onto, next candidate has value the more than the minimum value.";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 12);
  $statementInsertProcessedTransactions->execute(3, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(4, 4, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    firstTransaction => 1,
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1,
      fromTo => 'to',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 1, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 1,"There is 1 candidate transaction row after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 2);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 22, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 1, "numberOfMinimumValues remains the same.");
      
  is (numChainsRows(), 1, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 1, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 7 - Not first transaction with 2 possible transactions to extend onto (1 for each transaction).";
{
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 12); #Above minimum value
  $statementInsertProcessedTransactions->execute(3, 2, 4, 10); #Same as minimum value
  $statementInsertProcessedTransactions->execute(4, 3, 5, 8); #Below minimum value
  $statementInsertProcessedTransactions->execute(5, 4, 5, 10);
  $statementInsertProcessedTransactions->execute(6, 5, 1, 10);
  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 22, 1);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 2, 2);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 2,
      chainId => 1,
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1, 
      fromTo => 'from',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 0, "There is no candidate transaction rows before invocation.");
  is (numChainsRows(), 2, "There is 1 current chains row before invocation.");
  is (numChainInfoRows(), 2, "There is 1 current chains stats row before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(), 2,"There is 2 candidate transaction rows after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 3);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 20, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues has been updated to account for the new transaction.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(2, 4);
  is ($minimumValue, 8, "minimumValue has reduced.");
  is ($length, 3, "length has been updated to account for the new transaction.");
  is ($totalValue, 30, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 1, "numberOfMinimumValues remains the same.");
      
  is (numChainsRows(), 2, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 2, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}


say "Test 8 - Not first transaction, existing candidate transaction prevents the consideration of another.";
{
  #Modify the settings to not include the heuristics, as with "None" it results in only 1 -> 3 being selected 
  #instead of both 1 -> 3 and 1 -> 4.
  #The dynamic restrictions would maintain the integrity of links
  my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({   
    chainDynamicRestrictionsArray => $chainDynamicRestrictions,
  });
  
  delete_table_data();
  my $startLoopId = 1;
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 2, 3, 10); 
  $statementInsertProcessedTransactions->execute(3, 2, 4, 10); 
  $statementInsertProcessedTransactions->execute(4, 2, 5, 10); #Does not consider this because of the candidate (tx.)
  $statementInsertProcessedTransactions->execute(5, 3, 6, 13); #Above minimum value

  
  #ChainInfoId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 10, 2, 20, 2);
  
  #ChainId, TransactionId_FK, ChainInfoId_FK
  $statementInsertChains->execute(1, 1, 1);
  $statementInsertChains->execute(1, 2, 2);
  
  #Purposefully don't add to transaction 1 -> 4, as we want to make sure this not included. 
  #It's already connected tx. 1 -> 2.
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCandidateTransactions->execute(1, 1, 1, 3, 10, 2, 20, 2);
  
  my $inputTransactionState = Pear::LocalLoop::Algorithm::ExtendedTransaction->new({
    extendedTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 2,
      chainId => 1,
      fromTo => 'to',
    }),
    fromTransaction => Pear::LocalLoop::Algorithm::ChainTransaction->new({
      transactionId => 1,
      chainId => 1, 
      fromTo => 'from',
    }),
  });
  
  my $inputLoopGenerationContext = Pear::LocalLoop::Algorithm::LoopGenerationContext->new({
    userIdWhichCreatesALoop => $startLoopId,
  });

  is (numCandidateTransactionRows(), 1, "There is 1 candidate transaction row before invocation.");
  is (numChainsRows(), 2, "There is 2 current chains rows before invocation.");
  is (numChainInfoRows(), 2, "There is 2 current chains stats rows before invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows before invocation.");

  my $exception = exception { $main->_candidateInsertion($settings, $inputTransactionState, $inputLoopGenerationContext); };
  is ($exception, undef ,"No exception thrown");

  #Importantly candidate transaction 1 -> 4 does not exist.
  is (numCandidateTransactionRows(), 2,"There is 2 candidate transaction rows after invocation.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  my ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(1, 3);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 2, "length has been updated to account for the new transaction.");
  is ($totalValue, 20, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues has been updated to account for the new transaction.");
  #SQL: TransactionFrom_FK, TransactionTo_FK
  ($minimumValue, $length, $totalValue, $numberOfMinimumValues) = selectCandidateTransactions(2, 5);
  is ($minimumValue, 10, "minimumValue remains the same.");
  is ($length, 3, "length has been updated to account for the new transaction.");
  is ($totalValue, 33, "totalValue has been updated to account for the new transaction.");
  is ($numberOfMinimumValues, 2, "numberOfMinimumValues remains the same.");
      
  is (numChainsRows(), 2, "There is 1 current chains row after invocation.");
  is (numChainInfoRows(), 2, "There is 1 current chains stats row after invocation.");
  is (numBranchedTransactionsRows(), 0, "There is no branched transaction rows after` invocation.");
}

done_testing();
exit;
