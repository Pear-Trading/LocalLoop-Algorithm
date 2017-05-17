package Pear::LocalLoop::Algorithm::Role::IDynamicRestriction;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
  
  debugMethodEnd(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
}

#Similar to "IStaticRestriction" but the restriction is dependent on the transaction
#context it's working with.
#1st param $self.
#2nd param current transaction id.
#3rd param whether this is the first dynamic restriction called, hence 
#any previous state in the "Included" column of the "ProcessedTransactions" table.
sub applyDynamicRestriction {
  die "applyDynamicRestriction has not been implemented.";
};

1;
