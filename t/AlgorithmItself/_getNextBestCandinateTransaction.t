use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_getNextBestCandidateTransaction"

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

#None is used as it's simple and has little dependencies on the consistency of the data in the database.
#So it's easier to create these tests.
my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

#Only the heuristics are needed for this.
my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({ chainHeuristicArray => $heuristics });

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertCurrentChains = $dbh->prepare("INSERT INTO CurrentChains (ChainId, TransactionId_FK, ChainStatsId_FK) VALUES (?, ?, ?)");
my $statementInsertCandidateTransactions = $dbh->prepare("INSERT INTO CandidateTransactions (CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $selectCandidateTransactionsId = $dbh->prepare("SELECT COUNT(CandidateTransactionsId) FROM CandidateTransactions WHERE CandidateTransactionsId = ?");
my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(CandidateTransactionsId) FROM CandidateTransactions");

sub candidateTransactionIdExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectCandidateTransactionsId->execute($id);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectCandidateTransactionsId->fetchrow_array();
  
  return ($returnedVal);
}

sub numCandidateTransactionRows {
  $selectAllIdsCount->execute();
  my ($num) = $selectAllIdsCount->fetchrow_array();
  
  return $num;
}


#The only things that matter are:
#ProcessedTransactions:
#- TransactionId (Unique)
#CurrentChains:
#- ChainId and TransactionId_FK (Unique)
#CurrentChainsStats:
#- ChainStatsId (Unique for the above)
#CandidateTransactions:
#- CandidateTransactionsId (Unique)
#- ChainId_FK (Null or not null).
#- TransactionFrom_FK (Null or not null).
#- TransactionTo_FK (heuristic order sensitive).


say "Test 1 - Empty table";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  is (numCandidateTransactionRows(),0,"There is no rows before invocation.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");


  is (numCandidateTransactionRows(),0,"There is still no rows after invocation.");
  is ($hasRow, 0, "It has returned no row."); 
  is ($chainId, undef, "chainId is undef as it has no candidates transactions to return");
  is ($transactionFrom, undef, "transactionFrom is undef as it has no candidates transactions to return");
  is ($transactionTo, undef, "transactionTo is undef as it has no candidates transactions to return");
  is ($minimumValue, undef, "minimumValue is undef as itIt has no candidates transactions to return");
  is ($length, undef, "length is undef as it has no candidates transactions to return");
  is ($totalValue, undef, "totalValue is undef as it has no candidates transactions to return");
  is ($numOfMinValues, undef, "numOfMinValues is undef as it has no candidates transactions to return");
}


say "Test 2 - 1 Null candidate transaction";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(1, undef, undef, 1, 10, 1, 10, 1);
  
  is (numCandidateTransactionRows(),1,"There is one transaction candidate before invocation.");
  is (candidateTransactionIdExists(1), 1, "Candidate transaction id 1 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(),0,"There are zero rows after invocation.");
  is (candidateTransactionIdExists(1), 0,"Candidate transaction id 1 has been removed.");
  is ($hasRow, 1, "It has returned a row.");  
  is ($chainId, undef, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 1, "transactionTo is the same value we passed in.");
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 1, "length is the same value we passed in.");
  is ($totalValue, 10, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
}


say "Test 3 - 2 Null candidate transactions";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 20);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(1, undef, undef, 1, 10, 1, 10, 1);
  $statementInsertCandidateTransactions->execute(2, undef, undef, 2, 20, 1, 20, 1);
  
  is (numCandidateTransactionRows(),2,"There is two transaction candidates before invocation.");
  is (candidateTransactionIdExists(1), 1, "Candidate transaction id 1 has been inserted.");
  is (candidateTransactionIdExists(2), 1, "Candidate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(),1,"There is one row after invocation.");
  #It does not matter which one returns.
  if ($transactionTo == 1) {
    is (candidateTransactionIdExists(1), 0,"Candidate transaction id 1 has been removed.");
    is (candidateTransactionIdExists(2), 1,"Candidate transaction id 2 still exists.");
    is ($hasRow, 1, "It has returned a row."); 
    is ($chainId, undef, "chainId is undef as it's a first trasaction.");
    is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
    is ($transactionTo, 1, "transactionTo is the same value we passed in.");
    is ($minimumValue, 10, "minimumValue is the same value we passed in.");
    is ($length, 1, "length is the same value we passed in.");
    is ($totalValue, 10, "totalValue is the same value we passed in.");
    is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
  }
  elsif ($transactionTo == 2) {
    is (candidateTransactionIdExists(1), 1,"Candidate transaction id 1 still exists.");
    is (candidateTransactionIdExists(2), 0,"Candidate transaction id 2 has been removed.");
    is ($hasRow, 1, "It has returned a row.");  
    is ($chainId, undef, "chainId is undef as it's a first trasaction.");
    is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
    is ($transactionTo, 2, "transactionTo is the same value we passed in.");
    is ($minimumValue, 20, "minimumValue is the same value we passed in.");
    is ($length, 1, "length is the same value we passed in.");
    is ($totalValue, 20, "totalValue is the same value we passed in.");
    is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
  }
  else {
    #It's has to return either 1 or 2!
    fail("transactionTo id was neither 1 or 2.");
  }
}


say "Test 4- 1 Null and one not null candidate transaction, null returns first.";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 20);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainStatsId_FK
  $statementInsertCurrentChains->execute(1, 1, 1);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  #Have the other in the lowest CandidateTransactionsId, so we can tell if it's just returning the lowest 
  #CandidateTransactionsId value.
  $statementInsertCandidateTransactions->execute(2,     1,     1, 3, 10, 2, 20, 2);
  $statementInsertCandidateTransactions->execute(3, undef, undef, 2, 20, 1, 20, 1);
  
  is (numCandidateTransactionRows(),2,"There is two transaction candidates before invocation.");
  is (candidateTransactionIdExists(2), 1, "Candidate transaction id 1 has been inserted.");
  is (candidateTransactionIdExists(3), 1, "Candidate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(),1,"There is one row after invocation.");
  is (candidateTransactionIdExists(2), 1,"Candidate transaction id 2 still exists.");
  is (candidateTransactionIdExists(3), 0,"Candidate transaction id 3 has been removed.");
  is ($hasRow, 1, "It has returned a row."); 
  is ($chainId, undef, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 2, "transactionTo is the same value we passed in.");
  is ($minimumValue, 20, "minimumValue is the same value we passed in.");
  is ($length, 1, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");

}


say "Test 5 - 1 not null candidate transaction.";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 20);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  
  #ChainId, TransactionId_FK, ChainStatsId_FK
  $statementInsertCurrentChains->execute(1, 1, 1);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(2, 1, 1, 3, 10, 2, 20, 2);
  
  is (numCandidateTransactionRows(),1,"There is two transaction candidates before invocation.");
  is (candidateTransactionIdExists(2), 1, "Candidate transaction id 1 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(),0,"There is zero rows after invocation.");
  is (candidateTransactionIdExists(2), 0,"Candidate transaction id 2 has been removed.");
  is ($hasRow, 1, "It has returned a row."); 
  is ($chainId, 1, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, 1, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 3, "transactionTo is the same value we passed in.");
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 2, "numOfMinValues is the same value we passed in.");
}


say "Test 6 - 2 not null candidate transactions, selection be by heuristic.";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 20);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentStatsId->execute(1, 10, 1, 10, 1);
  $statementInsertCurrentStatsId->execute(2, 20, 1, 20, 1);
  
  #ChainId, TransactionId_FK, ChainStatsId_FK
  $statementInsertCurrentChains->execute(1, 1, 1);
  $statementInsertCurrentChains->execute(2, 2, 2);
  
  #CandidateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandidateTransactions->execute(1, 2, 2, 4, 10, 2, 30, 1); 
  #This will be selected first, swap ordering so we know it's the heuristic function selecting it (lowest transaction to id.).
  $statementInsertCandidateTransactions->execute(2, 1, 1, 3, 10, 2, 20, 2); 

  is (numCandidateTransactionRows(),2,"There is two transaction candidates before invocation.");
  is (candidateTransactionIdExists(1), 1, "Candidate transaction id 1 has been inserted.");
  is (candidateTransactionIdExists(2), 1, "Candidate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandidateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandidateTransactionRows(),1,"There is one row after invocation.");
  is (candidateTransactionIdExists(1), 1,"Candidate transaction id 1 still exists.");
  is (candidateTransactionIdExists(2), 0,"Candidate transaction id 1 has been removed.");
  is ($hasRow, 1, "It has returned a row."); 
  is ($chainId, 1, "chainId is the same value we passed in.");
  is ($transactionFrom, 1, "transactionFrom is the same value we passed in.");
  is ($transactionTo, 3, "transactionTo is the same value we passed in.");
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 2, "numOfMinValues is the same value we passed in.");
}

done_testing();
