use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainGenerationContext;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet"

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


my $testModule = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();

my $statementInsertProcessedTransactions = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");
my $statementInsertCurrentChainStats = $dbh->prepare("INSERT INTO CurrentChainsStats (ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues) VALUES (?, ?, ?, ?, ?)");
my $statementInsertCurrentChains = $dbh->prepare("INSERT INTO CurrentChains (ChainId, TransactionId_FK, ChainStatsId_FK) VALUES (?, ?, ?)");
my $statementInsertBranchedTransactions = $dbh->prepare("INSERT INTO BranchedTransactions (ChainId_FK, FromTransactionId_FK, ToTransactionId_FK) VALUES (?, ?, ?)");

sub transactionIdIncluded {
  my ($id) = @_;
  
  my ($hasIncludedId) = $dbh->selectrow_array("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = ? AND Included = 1", undef, ($id));
  
  return $hasIncludedId;
}

sub initialise {
  delete_table_data();
  
  #It does not matter what values are in here as they are ignored, this is only needed for referential integrity
  #in CurrentChains.
  #ChainStatsId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
  $statementInsertCurrentChainStats->execute(1, 10, 1, 10, 1);
}

my $ignore = -1;

sub newChainGenerationContext {
  my ($currentChainId, $currentTransactionId) = @_;
  return Pear::LocalLoop::Algorithm::ChainGenerationContext->new({
    userIdWhichCreatesALoop => $ignore,
    currentChainId => $currentChainId,
    currentTransactionId => $currentTransactionId,
  });
}

#TODO description.


say "Test 1 - No chains present (no restrictions), not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1);
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1);
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (can link to yourself)."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5."); 
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 2 - No chains present (no restrictions), transaction id undef";
initialise();
#use first restriction, chainId and transactionId, 
dies_ok { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, undef)); } "Exception thrown, transaction id missing.";



say "Test 3 - No chains present (no restrictions), chain id undef";
initialise();
#use first restriction, chainId and transactionId, 
dies_ok { $testModule->applyDynamicRestriction(0, newChainGenerationContext(undef, 1)); } "Exception thrown,  chain id id missing.";



say "Test 4 - No chains present (no restrictions), use first restriction id undef";
initialise();
#use first restriction, chainId and transactionId, 
dies_ok { $testModule->applyDynamicRestriction(undef, newChainGenerationContext(1, 1)); } "Exception thrown, first undef.";



say "Test 5 - 1 chain present, selection start/middle, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1);
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1);
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (can link to yourself)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (disabled from the next link in chain)."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5."); 
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 6 - 1 chain present, selection start/middle, pre-disable two, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); # Disable this to see if it gets re-enabled (in chain)
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); # Disable this to see if it gets re-enabled (not in chain)
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (can link to yourself)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (not included and disabled anyway)."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5 (not included).");
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 7 - 1 chain present, selection start/middle, pre-disable all, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0);
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0);
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),0,"Can't link to id 1 (not included)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (not included)."); 
is (transactionIdIncluded(3),0,"Can't link to id 3 (not included)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (not included).");
is (transactionIdIncluded(5),0,"Can't link to id 5 (not included).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (not included)."); 



say "Test 8 - 1 chain present, selection last transaction, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to yourself)."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 9 - 1 chain present, selection last transaction two disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3 (not included)."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6 (not included)."); 



say "Test 10 - 1 chain present, selection last transaction, all disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),0,"Can't link to id 1 (not included)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (not included)."); 
is (transactionIdIncluded(3),0,"Can't link to id 3 (not included)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (not included).");
is (transactionIdIncluded(5),0,"Can't link to id 5 (not included).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (not included)."); 
  
  
  
say "Test 11 - 2 chains, selection start/middle transaction, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to yourself)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (next transaction on chain 1).");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6 (it branched to this previously)."); 



say "Test 12 - 2 chains, selection start/middle transaction, some disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0); # Disabled for testing, should remain disabled
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); # Disabled for testing, should remain disabled
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),0,"Can't link to id 1 (it was not included)."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to yourself)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (next transaction on chain 1).");
is (transactionIdIncluded(5),0,"Can't link to id 5 (it was not included).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (it branched to this previously and was not included)."); 



say "Test 13 - 2 chains, selection start/middle transaction, all disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(0, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),0,"Can't link to id 1 (it was not included)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (it was not included)."); 
is (transactionIdIncluded(3),0,"Can't link to id 3 (it was not included)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (next transaction on chain 1 and was not included).");
is (transactionIdIncluded(5),0,"Can't link to id 5 (it was not included).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (it branched to this previously and was not included)."); 



# All now with first restriction.
say "Test 14 - 1 chain present, selection start/middle, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1);
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1);
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (can link to yourself)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (disabled from the next link in chain)."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5."); 
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 15 - 1 chain present, selection start/middle, pre-disable two, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); # Disable this to see if it gets re-enabled (in chain)
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);# Disable this to see if it gets re-enabled (not in chain)
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (can link to yourself)."); 
is (transactionIdIncluded(2),0,"Can't still link to id 2 (not included, but was reset, then was excluded)."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),1,"Can link to id 6 (was disabled but was reset)."); 



say "Test 16 - 1 chain present, selection start/middle, pre-disable all, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0);
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0);
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 1)); };
is ($exception, undef ,"No exception thrown");

is (transactionIdIncluded(1),1,"Can link to id 1 (not included, but was reset, can link to self)."); 
is (transactionIdIncluded(2),0,"Can't link to id 2 (not included, but was reset, then was disabled again)."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (not included, but was reset)."); 
is (transactionIdIncluded(4),1,"Can link to id 4 (not included, but was reset).");
is (transactionIdIncluded(5),1,"Can link to id 5 (not included, but was reset).");
is (transactionIdIncluded(6),1,"Can link to id 6 (not included, but was reset)."); 



say "Test 17 - 1 chain present, selection last transaction, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to yourself)."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),1,"Can link to id 6."); 



say "Test 18 - 1 chain present, selection last transaction two disabled, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (not included, but reset, can link to self)."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),1,"Can link to id 6 (not included, but reset)."); 



say "Test 19 - 1 chain present, selection last transaction, all disabled, first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 1, 1);
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1 (not included, but was reset, can link to self)."); 
is (transactionIdIncluded(2),1,"Can link to id 2 (not included, but was reset)."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (not included, but was reset)."); 
is (transactionIdIncluded(4),1,"Can link to id 4 (not included, but was reset).");
is (transactionIdIncluded(5),1,"Can link to id 5 (not included, but was reset).");
is (transactionIdIncluded(6),1,"Can link to id 6 (not included, but was reset)."); 
  
  
  
say "Test 20 - 2 chains, selection start/middle transaction, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 1);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 1); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 1);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to yourself)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (next transaction on chain 1).");
is (transactionIdIncluded(5),1,"Can link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6 (it branched to this previously)."); 



say "Test 21 - 2 chains, selection start/middle transaction, some disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0); # Disabled for testing, should remain disabled
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 1); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 1);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 1);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); # Disabled for testing, should remain disabled
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1 (it was not included, but was reset)."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (can link to self)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (not included, but was reset, but is the next transaction on chain 1 so was disabled).");
is (transactionIdIncluded(5),1,"Can link to id 5 (it was not included, but was reset).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (not included, but was reset, but branched to this previously so was disabled )."); 



say "Test 22 - 2 chains, selection start/middle transaction, all disabled, not first restriction";
initialise();
#Only the 1st (transaction id) and 5th (included) matter in this, the rest can be ignored.
#TransactionId, FromUserId, ToUserId, Value, Included
$statementInsertProcessedTransactions->execute(1, 1, 2, 10, 0);
$statementInsertProcessedTransactions->execute(2, 2, 3, 10, 0); 
$statementInsertProcessedTransactions->execute(3, 3, 4, 10, 0);
$statementInsertProcessedTransactions->execute(4, 4, 5, 10, 0);
$statementInsertProcessedTransactions->execute(5, 5, 6, 10, 0); 
$statementInsertProcessedTransactions->execute(6, 6, 1, 10, 0);
#Only the 1st (chain id) and 2nd (transaction id) params matter.
#ChainId, TransactionId_FK, ChainStatsId_FK
$statementInsertCurrentChains->execute(1, 2, 1);
$statementInsertCurrentChains->execute(1, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(1, 4, 1);
$statementInsertCurrentChains->execute(1, 5, 1);
$statementInsertCurrentChains->execute(2, 2, 1); 
$statementInsertCurrentChains->execute(2, 3, 1); #Branch at 3 
$statementInsertCurrentChains->execute(2, 6, 1);
#It started off as chain 1 but branched at transaction id 3 to transaction id 6.
#ChainId_FK, FromTransactionId_FK, ToTransactionId_FK
$statementInsertBranchedTransactions->execute(1, 3, 6);

#use first restriction, chainId and transactionId, 
my $exception = exception { $testModule->applyDynamicRestriction(1, newChainGenerationContext(1, 3)); };
is ($exception, undef ,"No exception thrown");

#Does not apply any restictions as it's the end of the chain.
is (transactionIdIncluded(1),1,"Can link to id 1 (it was not included, but was reset)."); 
is (transactionIdIncluded(2),1,"Can link to id 2 (it was not included, but was reset)."); 
is (transactionIdIncluded(3),1,"Can link to id 3 (it was not included, but was reset)."); 
is (transactionIdIncluded(4),0,"Can't link to id 4 (not included, but was reset, but is the next transaction on chain 1 so was disabled).");
is (transactionIdIncluded(5),1,"Can link to id 5 (it was not included, but was reset).");
is (transactionIdIncluded(6),0,"Can't link to id 6 (not included, but was reset, but branched to this previously so was disabled )."); 
  

done_testing();
