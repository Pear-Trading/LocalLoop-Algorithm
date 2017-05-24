use Test::More;
use Test::Exception;
use Test::Fatal;
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst;
use Path::Class::File;
use v5.10;

use FindBin;

#This is a test for "Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst"

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


my $largestValueFirstTest = Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst->new();

my $insertStatement = $dbh->prepare("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) VALUES (?, ?, ?, ?)");

#Prioritises higher transaction values first then to break ties earliest transaction first

say "Test 1 - Basic ordering";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 13);
$insertStatement->execute(2, 2, 3, 12);
$insertStatement->execute(3, 3, 4, 11);
$insertStatement->execute(4, 4, 1, 10);
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef."); 

say "Test 2 - Mixed insertion ordering 1";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(2, 2, 3, 12);
$insertStatement->execute(4, 4, 1, 10);
$insertStatement->execute(3, 3, 4, 11);
$insertStatement->execute(1, 1, 2, 13);
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

say "Test 3 - Mixed insertion ordering 2";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(2, 2, 3, 11);
$insertStatement->execute(4, 4, 1, 13);
$insertStatement->execute(3, 3, 4, 10);
$insertStatement->execute(1, 1, 2, 12);
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

say "Test 4 - Ties";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(1, 1, 2, 12);
$insertStatement->execute(2, 2, 3, 11); #Tie - 2 goes first.
$insertStatement->execute(3, 3, 4, 11); #Tie
$insertStatement->execute(4, 4, 1, 10);
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

say "Test 5 - Ties - randomly inserted";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(4, 4, 1, 10);
$insertStatement->execute(1, 1, 2, 12);
$insertStatement->execute(3, 3, 4, 11); #Tie
$insertStatement->execute(2, 2, 3, 11); #Tie - 2 goes first.
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef.");

say "Test 6 - Ties - randomly inserted - Different id order";
delete_table_data();
#TransactionId, FromUserId, ToUserId, Value
$insertStatement->execute(2, 2, 3, 11);
$insertStatement->execute(3, 3, 4, 12); #Tie
$insertStatement->execute(4, 4, 1, 13);
$insertStatement->execute(1, 1, 2, 12); #Tie - 1 goes first
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),4,"Expected transaction id 4."); 
is ($largestValueFirstTest->nextTransactionId(),1,"Expected transaction id 1."); 
is ($largestValueFirstTest->nextTransactionId(),3,"Expected transaction id 3."); 
is ($largestValueFirstTest->nextTransactionId(),2,"Expected transaction id 2."); 
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef."); 

say "Test 7 - Empty table";
delete_table_data();
$largestValueFirstTest->initAfterStaticRestrictions();
is ($largestValueFirstTest->nextTransactionId(),undef,"Expected transaction id undef."); 

done_testing();
