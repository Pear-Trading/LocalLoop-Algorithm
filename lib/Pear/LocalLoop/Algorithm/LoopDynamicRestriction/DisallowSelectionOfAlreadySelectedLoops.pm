package Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction');

#Prevent the selection of any loops that have been selected previously.

has _statementDisallowSelectionOfAlreadySelectedLoops => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 0 WHERE Included != 0 AND Active != 0");
  },
  lazy => 1,
);

has _statementDisallowSelectionOfAlreadySelectedLoopsFirstRestriction => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 1 WHERE Included = 0 AND Active = 0");
  },
  lazy => 1,
);

sub applyLoopDynamicRestriction {
  debugMethodStart();
  my ($self, $isFirstRestriction) = @_;
  
  if ( ! defined $isFirstRestriction ) {
    die "isFirstRestriction cannot be undefined";
  }
  
  $self->_statementDisallowSelectionOfAlreadySelectedLoops->execute();
  
  if ($isFirstRestriction){
    $self->_statementDisallowSelectionOfAlreadySelectedLoopsFirstRestriction->execute();
  }
  
  debugMethodEnd();
}

1;

