use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Pear::LocalLoop::Algorithm::ChainGenerationContext;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser"

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


my $testModule = Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");

sub transactionIdIncluded {
  my ($id) = @_;
  
  my $hasIncludedId = @{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions_ViewIncluded WHERE TransactionId = ?", undef, ($id))}[0];
  
  return $hasIncludedId;
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



#It does not matter about the chain id param. So that is left undefined.

#Tests with no modification to the included (all are included by default)
say "Test 1 - Transaction 1, all included, not first dynamic restriction";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 1);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 1)); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 2 - Transaction 1, some not included, but none to link to, first dynamic restriction";
delete_table_data();
#Scattering of 0's and 0 on the only one 1 can link to. This gets reset and can now link to it.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 0);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(1, newChainGenerationContext($ignore, 1)); };
is ($exception, undef ,"No exception thrown"); #id 1, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 3 - Transaction 1, some not included, but none to link to, not first dynamic restriction";
delete_table_data();
#Scattering of 0's and 0 on the only one 1 can link to.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 0);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 1)); };
is ($exception, undef ,"No exception thrown"); #id 1, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 4 - Transaction 2, all included, not first dynamic restriction";
delete_table_data();
#More than one transaction can be linked to. All included by default.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 1);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 4 - Transaction 2, some not included, but none to link to 1/2, first dynamic restriction";
delete_table_data();
#More than one transaction can be linked to. One of them disabled by default, but it will reset.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 0);

my $exception = exception { $testModule->applyChainDynamicRestriction(1, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 5 - Transaction 2, some not included, but none to link to 2/2, first dynamic restriction";
delete_table_data();
#More than one transaction can be linked to. Both disabled by default, but it will reset
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 0);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(1, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 6 - Transaction 2, some not included, but one to link to 1/2, not first dynamic restriction";
delete_table_data();
#More than one transaction can be linked to. One of them disabled by default.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 0);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 7 - Transaction 2, some not included, but none to link to 2/2, not first dynamic restriction";
delete_table_data();
#More than one transaction can be linked to. Both disabled by default, but it will reset
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 1, 2, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 3, 5, 10, 0);
$insertStatement->execute(5, 4, 5, 10, 0);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, not first restriction

is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 8 - Transaction 2, backwards in time is valid, not first restriction";
delete_table_data();
#transactions back in time are valid as they will be discounted using another module.
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 3, 5, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 3, 5, 10, 1);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(0, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, non first restriction

is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



say "Test 9 - Transaction 2, backwards in time is valid, first restriction";
delete_table_data();
#transactions back in time are valid as they will be discounted using another module. They all will be reset
#and will show the text above,
#TransactionId, FromUserId, ToUserId, Value, Included
$insertStatement->execute(1, 3, 5, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 3, 5, 10, 1);
$insertStatement->execute(5, 4, 5, 10, 1);
$insertStatement->execute(6, 5, 1, 10, 1);

my $exception = exception { $testModule->applyChainDynamicRestriction(1, newChainGenerationContext($ignore, 2)); };
is ($exception, undef ,"No exception thrown"); #id 2, first restriction

is (transactionIdIncluded(1),1,"Can link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");
is (transactionIdIncluded(5),0,"Can't link to id 5.");
is (transactionIdIncluded(6),0,"Can't link to id 6.");



done_testing();
