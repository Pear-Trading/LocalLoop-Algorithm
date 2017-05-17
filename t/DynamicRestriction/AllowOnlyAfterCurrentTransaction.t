use Test::More;
use Test::Exception;
use Test::Fatal;
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction"

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


my $allowedAfterTest = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction->new();

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value, Included) VALUES (?, ?, ?, ?, ?)");

sub transactionIdIncluded {
  my ($id) = @_;
  
  my $hasIncludedId = @{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = ? AND Included = 1", undef, ($id))}[0];
  
  return $hasIncludedId;
}

#If it is the first restriction then set included in all of the transactions 
#before itself and itself to 0, any after itself set to 1.
#If it's not the first restriction then set included in all of the transactions 
#before itself and itself to 0.

#Tests with no modification to the included (all are included by default)
say "Test 1 - Transaction 1, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$allowedAfterTest->applyDynamicRestriction(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");

say "Test 2 - Transaction 2, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$allowedAfterTest->applyDynamicRestriction(2, 0); #id 2, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");

say "Test 3 - Transaction 2nd last, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$allowedAfterTest->applyDynamicRestriction(3, 0); #id 3, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");    

say "Test 4 - Transaction last, not first dynamic restriction";
delete_table_data();
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 1);
$allowedAfterTest->applyDynamicRestriction(4, 0); #id 4, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    


#Tests with modification to the included attribute, from here on.
say "Test 5 - Transaction 1, not first dynamic restriction with some not included";
delete_table_data();
#Similar to test one but some values are already not included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");

say "Test 6 - Transaction 1, not first dynamic restriction with some not included";
delete_table_data();
#Similar to test one but some values are already not included
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(1, 0); #id 1, not first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");



say "Test 7 - Transaction 1, first dynamic restriction";
delete_table_data();
#Set all included to zero they will reset
$insertStatement->execute(1, 1, 2, 10, 0); 
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(1, 1); #id 1, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),1,"Can link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");

say "Test 8 - Transaction 2, first dynamic restriction";
delete_table_data();
#Transaction id 4 will reset.
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 1);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(2, 1); #id 2, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),1,"Can link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");

say "Test 9 - Transaction 2nd last, first dynamic restriction";
delete_table_data();
#Transaction id 4 will reset again.
$insertStatement->execute(1, 1, 2, 10, 1);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 1);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(3, 1); #id 3, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),1,"Can link to id 4.");    

say "Test 10 - Transaction last, first dynamic restriction";
delete_table_data();
#All will be reset but they will be set to 0.
$insertStatement->execute(1, 1, 2, 10, 0);
$insertStatement->execute(2, 2, 3, 10, 0);
$insertStatement->execute(3, 3, 4, 10, 0);
$insertStatement->execute(4, 4, 1, 10, 0);
$allowedAfterTest->applyDynamicRestriction(4, 1); #id 4, first restriction
is (transactionIdIncluded(1),0,"Can't link to id 1."); 
is (transactionIdIncluded(2),0,"Can't link to id 2."); 
is (transactionIdIncluded(3),0,"Can't link to id 3."); 
is (transactionIdIncluded(4),0,"Can't link to id 4.");    

done_testing();