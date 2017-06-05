package Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction');

#Prevent the selection of any loops that have been selected previously.

has _tableNameAllActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->uniqueTableName(ref($self), "TransactionsActive");
  },
  lazy => 1, 
);

has _statementDropTableAllActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameTransActive = $self->_tableNameAllActiveTransactions();
    return $self->dbh()->prepare("DROP TABLE IF EXISTS $tableNameTransActive");
  },
  lazy => 1, 
);

has _statementCreateTableAllActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameTransActive = $self->_tableNameAllActiveTransactions();
    return $self->dbh()->prepare("CREATE TABLE $tableNameTransActive (ActiveTransactionId INTEGER PRIMARY KEY)");
  },
  lazy => 1, 
);


has _tableNameLoopsWithAnyActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->uniqueTableName(ref($self), "LoopsWithTransactionsActive");
  },
  lazy => 1, 
);

has _statementDropTableLoopsWithAnyActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("DROP TABLE IF EXISTS $tableNameLoopsWithActiveTrans");
  },
  lazy => 1, 
);

has _statementCreateTableLoopsWithAnyActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("CREATE TABLE $tableNameLoopsWithActiveTrans (ActiveLoopId INTEGER PRIMARY KEY)");
  },
  lazy => 1, 
);


sub init {
  debugMethodStart();
  my ($self) = @_;
  
  $self->_statementDropTableAllActiveTransactions()->execute();
  $self->_statementCreateTableAllActiveTransactions()->execute();
  
  $self->_statementDropTableLoopsWithAnyActiveTransactions()->execute();
  $self->_statementCreateTableLoopsWithAnyActiveTransactions()->execute();
  
  debugMethodEnd(); 
}


has _statementClearTableAllActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameTransActive = $self->_tableNameAllActiveTransactions();
    return $self->dbh()->prepare("DELETE FROM $tableNameTransActive");
  },
  lazy => 1, 
);

has _statementClearTableLoopsWithAnyActiveTransactions => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("DELETE FROM $tableNameLoopsWithActiveTrans");
  },
  lazy => 1, 
);


has _statementInsertAllActiveTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    my $tableNameTransActive = $self->_tableNameAllActiveTransactions();
    return $self->dbh()->prepare("INSERT INTO $tableNameTransActive (ActiveTransactionId) SELECT DISTINCT TransactionId_FK FROM Loops_ViewActive");
  },
  lazy => 1,
);

has _statementInsertLoopsWithAnyActiveTransactions => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    my $tableNameTransActive = $self->_tableNameAllActiveTransactions();
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("INSERT INTO $tableNameLoopsWithActiveTrans (ActiveLoopId) SELECT DISTINCT Loops.LoopId_FK FROM Loops WHERE Loops.TransactionId_FK IN (SELECT ActiveTransactionId FROM $tableNameTransActive)");
  },
  lazy => 1,
);


has _statementDisallowLoopsWhichHaveTransactionInActiveLoops => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 0 WHERE Included != 0 AND LoopInfo.LoopId IN (SELECT ActiveLoopId FROM $tableNameLoopsWithActiveTrans)");
  },
  lazy => 1,
);

has _statementDisallowLoopsWhichHaveTransactionInActiveLoopsFirstRestriction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    my $tableNameLoopsWithActiveTrans = $self->_tableNameLoopsWithAnyActiveTransactions();
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 1 WHERE Included = 0 AND LoopInfo.LoopId NOT IN (SELECT ActiveLoopId FROM $tableNameLoopsWithActiveTrans)");
  },
  lazy => 1,
);



sub applyLoopDynamicRestriction {
  debugMethodStart();
  my ($self, $isFirstRestriction) = @_;
  
  if ( ! defined $isFirstRestriction ) {
    die "isFirstRestriction cannot be undefined";
  }
  
  #Select Tranaction ids from all active loops.
  # SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo  WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0
  # SELECT DISTINCT Loops.LoopId_FK FROM Loops WHERE Loops.TransactionId_FK IN (SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo  WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0)
  
  $self->_statementClearTableAllActiveTransactions()->execute();
  $self->_statementClearTableLoopsWithAnyActiveTransactions()->execute();
  
  $self->_statementInsertAllActiveTransactions()->execute();
  $self->_statementInsertLoopsWithAnyActiveTransactions()->execute();
  
  $self->_statementDisallowLoopsWhichHaveTransactionInActiveLoops()->execute();
  
  if ($isFirstRestriction){
    $self->_statementDisallowLoopsWhichHaveTransactionInActiveLoopsFirstRestriction()->execute();
  }
  
  debugMethodEnd();
}

1;

