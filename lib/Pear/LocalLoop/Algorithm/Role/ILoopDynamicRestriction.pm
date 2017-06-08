package Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

#1st param $self.
#2nd param whether this is the first loop dynamic restriction/loop heuristic called, 
#hence any previous state in the "Included" column of the "LoopInfo" table should be ignored.
sub applyLoopDynamicRestriction {
  die "applyLoopDynamicRestriction has not been implemented.";
};

1;
