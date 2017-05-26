package Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction');

#Prevent the selection of any loops that have been selected previously.

sub applyLoopDynamicRestriction {
  debugMethodStart();

  my ($self, $isFirstRestriction) = @_;
  my $dbh = $self->dbh();
  
  if ( ! defined $isFirstRestriction ) {
    die "isFirstRestriction cannot be undefined";
  }
  
  #FIXME move prepare statements outside this method so it does not waste resources every time.
  my $statement = $dbh->prepare("UPDATE LoopInfo SET Included = 0 WHERE Included != 0 AND Active != 0");
  $statement->execute();
  
  if ($isFirstRestriction){
    my $statement = $dbh->prepare("UPDATE LoopInfo SET Included = 1 WHERE Included = 0 AND Active = 0");
    $statement->execute();
  }
  
  debugMethodEnd();
}

1;

