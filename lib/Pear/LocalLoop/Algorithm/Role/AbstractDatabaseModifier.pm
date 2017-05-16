package Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier;

use Moo;
use Pear::LocalLoop::Algorithm::Main;

has dbh => (
  is => 'ro',
  default => sub { return Pear::LocalLoop::Algorithm::Main->dbi(); },
  lazy => 1,
);

#Empty method for subclasses to override if they have any initialisation work
#todo before the algorithm is run.
sub init {

}

1;

