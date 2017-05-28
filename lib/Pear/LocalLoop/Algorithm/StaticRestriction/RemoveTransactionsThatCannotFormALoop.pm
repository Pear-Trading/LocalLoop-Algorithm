package Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;

use Moo;
use v5.10;
use Data::Dumper;
use Pear::LocalLoop::Algorithm::Debug;
extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IStaticRestriction');

has _tableName => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->uniqueTableName(ref($self), "0");
  },
  lazy => 1, 
);

has _statementDropTable => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameZero = $self->_tableName();
    return $self->dbh()->prepare("DROP TABLE IF EXISTS $tableNameZero");
  },
  lazy => 1, 
);

has _statementCreateTable => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameZero = $self->_tableName();
    return $self->dbh()->prepare("CREATE TABLE $tableNameZero (ZeroIds INTEGER PRIMARY KEY)");
  },
  lazy => 1, 
);

has _statementInsertUserIdsOnlyInToUserIdAttribute => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameZero = $self->_tableName();
    return $self->dbh()->prepare("INSERT OR IGNORE INTO $tableNameZero (ZeroIds) SELECT ProcessedTransactions.ToUserId FROM ProcessedTransactions EXCEPT SELECT ProcessedTransactions.FromUserId FROM ProcessedTransactions");
  },
  lazy => 1, 
);

has _statementInsertUserIdsOnlyInFromUserIdAttribute => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameZero = $self->_tableName();
    return $self->dbh()->prepare("INSERT OR IGNORE INTO $tableNameZero (ZeroIds) SELECT ProcessedTransactions.FromUserId FROM ProcessedTransactions EXCEPT SELECT ProcessedTransactions.ToUserId FROM ProcessedTransactions");
  },
  lazy => 1, 
);

has _statementDeleteTransactionsThatCantFormLoops => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    my $tableNameZero = $self->_tableName();
    return $self->dbh()->prepare("DELETE FROM ProcessedTransactions WHERE FromUserId IN (SELECT ZeroIds FROM $tableNameZero) OR ToUserId IN (SELECT ZeroIds FROM $tableNameZero)");
  },
  lazy => 1, 
);

sub applyStaticRestriction{
  debugMethodStart();
  my ($self) = @_;
  
  $self->_statementDropTable()->execute();
  $self->_statementCreateTable()->execute();

  my $loop = 1;
  while ($loop != 0) {
    $loop = 0;
    
    $self->_statementInsertUserIdsOnlyInToUserIdAttribute()->execute();
    $self->_statementInsertUserIdsOnlyInFromUserIdAttribute()->execute();
    
    my $del1 = $self->_statementDeleteTransactionsThatCantFormLoops()->execute(); 
    
    #If there was more than 1 deleted keep on deleting.
    if (0 < $del1) {
      $loop = 1;
    }
    #print "looped";
  }

  debugMethodEnd();
}

1;
