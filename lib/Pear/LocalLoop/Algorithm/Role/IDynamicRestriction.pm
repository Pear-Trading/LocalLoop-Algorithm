package Pear::LocalLoop::Algorithm::Role::IDynamicRestriction;

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
#2rd param whether this is the first dynamic restriction called, hence 
#any previous state in the "Included" column of the "ProcessedTransactions" table.
#3rd param ChainGenerationContext instance.
sub applyChainDynamicRestriction {
  die "applyChainDynamicRestriction has not been implemented.";
};

1;
