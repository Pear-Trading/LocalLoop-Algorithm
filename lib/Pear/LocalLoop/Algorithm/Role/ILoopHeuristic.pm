package Pear::LocalLoop::Algorithm::Role::ILoopHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

with("Pear::LocalLoop::Algorithm::Role::IChainHeuristic");

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

sub applyLoopHeuristic {
  die "applyLoopHeuristic has not been implemented.";
};

1;
