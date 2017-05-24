use Test::More;
use Test::Exception;
use Test::Fatal qw(dies_ok exception);
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop"

Pear::LocalLoop::Algorithm::Main->setTestingMode();

my $main = Pear::LocalLoop::Algorithm::Main->new();
my $dbh = $main->dbh;


#Dump all pf the test tables and start again.
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

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");

say "Test 1 - No transactions that can be removed (all can be in a loop).";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 2, 3, 10); 
$insertStatement->execute(3, 3, 1, 10); 
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left."); 


say "Test 2 - One transaction to remove, 1 dangling to.";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 2, 3, 10); 
$insertStatement->execute(3, 3, 1, 10);
$insertStatement->execute(4, 1, 4, 10); #Dangling
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],4,"4 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 4", undef, ())}[0],0,"Dangling transaction removed.");


say "Test 3 - Two transactions to remove, 2 dangling to.";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 2, 3, 10); 
$insertStatement->execute(3, 3, 1, 10);
$insertStatement->execute(4, 2, 4, 10); #Dangling
$insertStatement->execute(5, 4, 5, 10); #Dangling
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],5,"5 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left."); 
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 4", undef, ())}[0],0,"1st Dangling transaction removed.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 5", undef, ())}[0],0,"2nd Dangling transaction removed.");


say "Test 4 - One transaction to remove, 1 dangling from.";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 4, 2, 10); #Dangling
$insertStatement->execute(3, 2, 3, 10); 
$insertStatement->execute(4, 3, 1, 10);
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],4,"4 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left.");  
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 2", undef, ())}[0],0,"Dangling transaction removed.");
 
 
say "Test 5 - Two transactions to remove, 2 dangling from.";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 5, 4, 10); #Dangling 
$insertStatement->execute(3, 4, 2, 10); #Dangling
$insertStatement->execute(4, 2, 3, 10);
$insertStatement->execute(5, 3, 1, 10);
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],5,"5 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left.");  
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 2", undef, ())}[0],0,"1st Dangling transaction removed.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 3", undef, ())}[0],0,"2nd Dangling transaction removed.");



say "Test 6 - Four transactions to remove, 2 dangling from and two dangling to.";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
#Create another chain that uses an id in another loop.
$insertStatement->execute(1, 1, 2, 10);
$insertStatement->execute(2, 5, 4, 10); #Dangling 
$insertStatement->execute(3, 4, 2, 10); #Dangling
$insertStatement->execute(4, 2, 3, 10);
$insertStatement->execute(5, 2, 6, 10); #Dangling 
$insertStatement->execute(6, 6, 7, 10); #Dangling 
$insertStatement->execute(7, 3, 1, 10);
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],7,"7 initial transactions."); 

my $exception = exception { $rst->applyStaticRestriction(); };
is ($exception, undef ,"No exception thrown");

is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions", undef, ())}[0],3,"3 transactions left.");  
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 2", undef, ())}[0],0,"1st Dangling transaction removed.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 3", undef, ())}[0],0,"2nd Dangling transaction removed.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 5", undef, ())}[0],0,"3rd Dangling transaction removed.");
is (@{$dbh->selectrow_arrayref("SELECT COUNT(*) FROM ProcessedTransactions WHERE TransactionId = 6", undef, ())}[0],0,"4th Dangling transaction removed.");


done_testing();
