package Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ITransactionOrder');

my $TABLE_NAME_ORDER = Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier->uniqueTableName(__PACKAGE__, "Order");

sub initAfterStaticRestrictions {
  debugMethodStart();

  my $self = shift;
  
  $self->dbh->prepare("DROP TABLE IF EXISTS $TABLE_NAME_ORDER")->execute();
  
  $self->dbh->prepare(
    "CREATE TABLE $TABLE_NAME_ORDER (" . 
    "OrderId INTEGER PRIMARY KEY NOT NULL, " . 
    "TransactionId INTEGER UNIQUE NOT NULL, " . 
    "Used INTEGER NOT NULL DEFAULT 0" . 
    ")"
  )->execute();
  
  my $statementInsert = $self->dbh->prepare("INSERT INTO $TABLE_NAME_ORDER (OrderId, TransactionId) VALUES (?, ?)");
  
  my $statementSelect = $self->dbh->prepare("SELECT ProcessedTransactions.TransactionId FROM ProcessedTransactions ORDER BY ProcessedTransactions.Value DESC, ProcessedTransactions.TransactionId ASC");
  $statementSelect->execute();
  
  my $counter = 1;
  while (my ($id) = $statementSelect->fetchrow_array()) {
    $statementInsert->execute($counter, $id);
    $counter++;
  } 
  
  debugMethodEnd();
}


sub nextTransactionId {
  debugMethodStart();

  my ($self) = @_;
  my $dbh = $self->dbh;
  
  my $statement = $dbh->prepare("SELECT TransactionId FROM $TABLE_NAME_ORDER WHERE Used = 0 LIMIT 1");
  $statement->execute();
  
  my ($nextTransactionId) = $statement->fetchrow_array();

  #If we have not passed the last value.  
  if (defined $nextTransactionId) {
    $dbh->prepare("UPDATE $TABLE_NAME_ORDER SET Used = 1 WHERE TransactionId = ?")->execute($nextTransactionId);
  }
  
  debugMethodEnd();
  return $nextTransactionId;
}

1;
