package Pear::LocalLoop::Algorithm::Role::IHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

sub applyHeuristic {
  die "applyHeuristic has not been implemented.";
};

sub applyHeuristicCandinates {
  die "applyHeuristicCandinates has not been implemented.";
};

1;
