package Pear::LocalLoop::Algorithm::Role::ILoopHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

with("Pear::LocalLoop::Algorithm::Role::IChainHeuristic");

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}


#1st param $self.
#2nd param whether this is the first loop dynamic restriction/loop heuristic called, 
#hence any previous state in the "Included" column of the "LoopInfo" table should be ignored.
sub applyLoopHeuristic {
  die "applyLoopHeuristic has not been implemented.";
};

1;
