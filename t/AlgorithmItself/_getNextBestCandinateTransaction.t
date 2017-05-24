use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::AlgorithmItself::_getNextBestCandinateTransaction"

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

#None is used as it's simple and has little dependencies on the consistency of the data in the database.
#So it's easier to create these tests.
my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

#Only the heuristics are needed for this.
my $settings = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new({ heuristicArray => $heuristics });

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");
my $statementInsertCurrentStatsId = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertCurrentChains = $dbh->prepare("INSERT INTO CurrentChains (ChainId, TransactionId_FK, ChainStatsId_FK) VALUES (?, ?, ?)");
my $statementInsertCandinateTransactions = $dbh->prepare("INSERT INTO CandinateTransactions (CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

my $selectCandinateTransactionsId = $dbh->prepare("SELECT COUNT(CandinateTransactionsId) FROM CandinateTransactions WHERE CandinateTransactionsId = ?");
my $selectAllIdsCount = $dbh->prepare("SELECT COUNT(CandinateTransactionsId) FROM CandinateTransactions");

sub candinateTransactionIdExists {
  my ($id) = @_;
  
  if ( ! defined $id ) {
    die "inputted id cannot be undefined";
  }
  
  $selectCandinateTransactionsId->execute($id);
  
  #1 == exists, 0 == doesn't exist.
  my ($returnedVal) = $selectCandinateTransactionsId->fetchrow_array();
  
  return ($returnedVal);
}

sub numCandinateTransactionRows {
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
#CandinateTransactions:
#- CandinateTransactionsId (Unique)
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
  
  is (numCandinateTransactionRows(),0,"There is no rows before invocation.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");


  is (numCandinateTransactionRows(),0,"There is still no rows after invocation.");
  is ($hasRow, 0, "It has returned no row."); 
  is ($chainId, undef, "chainId is undef as it has no candinates transactions to return");
  is ($transactionFrom, undef, "transactionFrom is undef as it has no candinates transactions to return");
  is ($transactionTo, undef, "transactionTo is undef as it has no candinates transactions to return");
  is ($minimumValue, undef, "minimumValue is undef as itIt has no candinates transactions to return");
  is ($length, undef, "length is undef as it has no candinates transactions to return");
  is ($totalValue, undef, "totalValue is undef as it has no candinates transactions to return");
  is ($numOfMinValues, undef, "numOfMinValues is undef as it has no candinates transactions to return");
}


say "Test 2 - 1 Null candinate transaction";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 10);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandinateTransactions->execute(1, undef, undef, 1, 10, 1, 10, 1);
  
  is (numCandinateTransactionRows(),1,"There is one transaction candinate before invocation.");
  is (candinateTransactionIdExists(1), 1, "Candinate transaction id 1 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandinateTransactionRows(),0,"There are zero rows after invocation.");
  is (candinateTransactionIdExists(1), 0,"Candinate transaction id 1 has been removed.");
  is ($hasRow, 1, "It has returned a row.");  
  is ($chainId, undef, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 1, "transactionTo is the same value we passed in.");
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 1, "length is the same value we passed in.");
  is ($totalValue, 10, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");
}


say "Test 3 - 2 Null candinate transactions";
{
  delete_table_data();
  #Any transactions will do as long as they are unique
  #TransactionId, FromUserId, ToUserId, Value
  $statementInsertProcessedTransactions->execute(1, 1, 2, 10);
  $statementInsertProcessedTransactions->execute(2, 1, 3, 20);
  $statementInsertProcessedTransactions->execute(3, 2, 3, 10);
  $statementInsertProcessedTransactions->execute(4, 3, 4, 10);
  $statementInsertProcessedTransactions->execute(5, 4, 1, 10);
  
  #CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandinateTransactions->execute(1, undef, undef, 1, 10, 1, 10, 1);
  $statementInsertCandinateTransactions->execute(2, undef, undef, 2, 20, 1, 20, 1);
  
  is (numCandinateTransactionRows(),2,"There is two transaction candinates before invocation.");
  is (candinateTransactionIdExists(1), 1, "Candinate transaction id 1 has been inserted.");
  is (candinateTransactionIdExists(2), 1, "Candinate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandinateTransactionRows(),1,"There is one row after invocation.");
  #It does not matter which one returns.
  if ($transactionTo == 1) {
    is (candinateTransactionIdExists(1), 0,"Candinate transaction id 1 has been removed.");
    is (candinateTransactionIdExists(2), 1,"Candinate transaction id 2 still exists.");
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
    is (candinateTransactionIdExists(1), 1,"Candinate transaction id 1 still exists.");
    is (candinateTransactionIdExists(2), 0,"Candinate transaction id 2 has been removed.");
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


say "Test 4- 1 Null and one not null candinate transaction, null returns first.";
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
  
  #CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  #Have the other in the lowest CandinateTransactionsId, so we can tell if it's just returning the lowest 
  #CandinateTransactionsId value.
  $statementInsertCandinateTransactions->execute(2,     1,     1, 3, 10, 2, 20, 2);
  $statementInsertCandinateTransactions->execute(3, undef, undef, 2, 20, 1, 20, 1);
  
  is (numCandinateTransactionRows(),2,"There is two transaction candinates before invocation.");
  is (candinateTransactionIdExists(2), 1, "Candinate transaction id 1 has been inserted.");
  is (candinateTransactionIdExists(3), 1, "Candinate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandinateTransactionRows(),1,"There is one row after invocation.");
  is (candinateTransactionIdExists(2), 1,"Candinate transaction id 2 still exists.");
  is (candinateTransactionIdExists(3), 0,"Candinate transaction id 3 has been removed.");
  is ($hasRow, 1, "It has returned a row."); 
  is ($chainId, undef, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, undef, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 2, "transactionTo is the same value we passed in.");
  is ($minimumValue, 20, "minimumValue is the same value we passed in.");
  is ($length, 1, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 1, "numOfMinValues is the same value we passed in.");

}


say "Test 5 - 1 not null candinate transaction.";
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
  
  #CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandinateTransactions->execute(2, 1, 1, 3, 10, 2, 20, 2);
  
  is (numCandinateTransactionRows(),1,"There is two transaction candinates before invocation.");
  is (candinateTransactionIdExists(2), 1, "Candinate transaction id 1 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandinateTransactionRows(),0,"There is zero rows after invocation.");
  is (candinateTransactionIdExists(2), 0,"Candinate transaction id 2 has been removed.");
  is ($hasRow, 1, "It has returned a row."); 
  is ($chainId, 1, "chainId is undef as it's a first trasaction.");
  is ($transactionFrom, 1, "transactionFrom is undef as as it's a first trasaction");
  is ($transactionTo, 3, "transactionTo is the same value we passed in.");
  is ($minimumValue, 10, "minimumValue is the same value we passed in.");
  is ($length, 2, "length is the same value we passed in.");
  is ($totalValue, 20, "totalValue is the same value we passed in.");
  is ($numOfMinValues, 2, "numOfMinValues is the same value we passed in.");
}


say "Test 6 - 2 not null candinate transactions, selection be by heuristic.";
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
  
  #CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  #Only params 1 - 4 matter.
  $statementInsertCandinateTransactions->execute(1, 2, 2, 4, 10, 2, 30, 1); 
  #This will be selected first, swap ordering so we know it's the heuristic function selecting it (lowest transaction to id.).
  $statementInsertCandinateTransactions->execute(2, 1, 1, 3, 10, 2, 20, 2); 

  is (numCandinateTransactionRows(),2,"There is two transaction candinates before invocation.");
  is (candinateTransactionIdExists(1), 1, "Candinate transaction id 1 has been inserted.");
  is (candinateTransactionIdExists(2), 1, "Candinate transaction id 2 has been inserted.");

  # return [$hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numberOfMinimumValues];
  my ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues);
  my $exception = exception { 
    ($hasRow, $chainId, $transactionFrom, $transactionTo, $minimumValue, $length, $totalValue, $numOfMinValues) = 
        @{$main->_getNextBestCandinateTransaction($settings)};
  };
  is ($exception, undef ,"No exception thrown");

  is (numCandinateTransactionRows(),1,"There is one row after invocation.");
  is (candinateTransactionIdExists(1), 1,"Candinate transaction id 1 still exists.");
  is (candinateTransactionIdExists(2), 0,"Candinate transaction id 1 has been removed.");
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
