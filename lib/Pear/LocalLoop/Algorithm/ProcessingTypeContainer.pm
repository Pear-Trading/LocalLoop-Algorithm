package Pear::LocalLoop::Algorithm::ProcessingTypeContainer;

use Moo;

has staticRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has transactionOrder => (
  is => 'ro',
  default => sub { return undef; },
#  lazy => 1,
);

has dynamicRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has heuristicArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);



1;
