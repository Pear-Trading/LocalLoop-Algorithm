package Pear::LocalLoop::Algorithm::AbstractDatabaseModifier;

use Moo;
use Pear::LocalLoop::Algorithm::Main;

has dbh => (
  is => 'ro',
  default => sub { return Pear::LocalLoop::Algorithm::Main->dbi(); },
  lazy => 1,
);

1;

