use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::TransactionOrder::EarliestTransactionFirst;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::TransactionOrder::EarliestTransactionFirst"

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


my $earliestFirstTest = Pear::LocalLoop::Algorithm::TransactionOrder::EarliestTransactionFirst->new();

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");

say "Test 1 - Basic ordering";
# Random transaction values
# Neat ordered user ids.
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 9);
$insertStatement->execute(2, 2, 3, 10);
$insertStatement->execute(3, 3, 4, 13);
$insertStatement->execute(4, 4, 1, 11);

my $exception = exception { $earliestFirstTest->initAfterStaticRestrictions(); };
is ($exception, undef ,"No exception thrown");

is ($earliestFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($earliestFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($earliestFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($earliestFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($earliestFirstTest->nextTransactionId(),undef,"Expected transaction id undef."); 

say "Test 2 - Mixed insertion ordering 1";
# Random transaction values
# Neat ordered user ids.
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(2, 2, 3, 5);
$insertStatement->execute(4, 4, 1, 3);
$insertStatement->execute(3, 3, 4, 6);
$insertStatement->execute(1, 1, 2, 10);

my $exception = exception { $earliestFirstTest->initAfterStaticRestrictions(); };
is ($exception, undef ,"No exception thrown");

is ($earliestFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($earliestFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($earliestFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($earliestFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($earliestFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

say "Test 3 - Mixed insertion ordering 2";
# Random transaction values
# Random user ids.
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(2, 5, 6, 9);
$insertStatement->execute(4, 6, 2, 2);
$insertStatement->execute(3, 8, 4, 1);
$insertStatement->execute(1, 2, 4, 3);

my $exception = exception { $earliestFirstTest->initAfterStaticRestrictions(); };
is ($exception, undef ,"No exception thrown");

is ($earliestFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($earliestFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($earliestFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($earliestFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($earliestFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");   

say "Test 4 - Empty table";
delete_table_data();

my $exception = exception { $earliestFirstTest->initAfterStaticRestrictions(); };
is ($exception, undef ,"No exception thrown");

is ($earliestFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

done_testing();
