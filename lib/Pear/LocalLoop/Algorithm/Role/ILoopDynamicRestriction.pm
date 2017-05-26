package Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

#Similar to "IStaticRestriction" but the restriction is dependent on the transaction
#context it's working with.
#1st param $self.
#2nd param whether this is the first dynamic restriction called, hence 
#any previous state in the "Included" column of the "LoopInfo" table.
sub applyLoopDynamicRestriction {
  die "applyLoopDynamicRestriction has not been implemented.";
};

1;
