package Pear::LocalLoop::Algorithm::TransactionOrder::AbstractTransactionOrder;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ITransactionOrder');

has tableName => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier->uniqueTableName(ref($self), "Order");
  },
  lazy => 1, 
);

has statementDropTable => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameOrder = $self->tableName();
    return $self->dbh()->prepare("DROP TABLE IF EXISTS $tableNameOrder");
  },
  lazy => 1, 
);

has statementCreateTable => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    
    my $tableNameOrder = $self->tableName();
    return $self->dbh()->prepare(
      "CREATE TABLE $tableNameOrder (" . 
      "OrderId INTEGER PRIMARY KEY NOT NULL, " . 
      "TransactionId INTEGER UNIQUE NOT NULL, " . 
      "Used INTEGER NOT NULL DEFAULT 0" . 
      ")"
    );
  },
  lazy => 1, 
);

has statementInsertTransactionsIntoTable => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameOrder = $self->tableName();
    return $self->dbh()->prepare("INSERT INTO $tableNameOrder (OrderId, TransactionId) VALUES (?, ?)");
  },
  lazy => 1, 
);

has statementSelectInsertionOrder => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh->prepare($self->getOrderSqlString());
  },
  lazy => 1, 
);

sub getOrderSqlString {
  die "getOrderSqlString has not been implemented"; 
}



sub initAfterStaticRestrictions {
  debugMethodStart();
  my ($self) = @_;
  
  $self->statementDropTable()->execute();
  $self->statementCreateTable()->execute();
  
  my $statementInsert = $self->statementInsertTransactionsIntoTable();
  
  my $statementSelect = $self->statementSelectInsertionOrder();
  $statementSelect->execute();
  
  my $counter = 1;
  while (my ($id) = $statementSelect->fetchrow_array()) {
    $statementInsert->execute($counter, $id);
    $counter++;
  } 
  
  debugMethodEnd();
}



has statementSelectNextTransaction => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameOrder = $self->tableName();
    return $self->dbh()->prepare("SELECT TransactionId FROM $tableNameOrder WHERE Used = 0 LIMIT 1");
  },
  lazy => 1, 
);

has statementUpdateSetTransactionAsUsed => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameOrder = $self->tableName();
    return $self->dbh()->prepare("UPDATE $tableNameOrder SET Used = 1 WHERE TransactionId = ?");
  },
  lazy => 1, 
);


sub nextTransactionId {
  debugMethodStart();
  my ($self) = @_;

  
  my $statementSelectNextTransaction = $self->statementSelectNextTransaction();
  $statementSelectNextTransaction->execute();
  
  my ($nextTransactionId) = $statementSelectNextTransaction->fetchrow_array();

  #If we have not passed the last value.  
  if (defined $nextTransactionId) {
    $self->statementUpdateSetTransactionAsUsed()->execute($nextTransactionId);
  }
  
  debugMethodEnd();
  return $nextTransactionId;
}

1;
