package Pear::LocalLoop::Algorithm::Role::IChainDynamicRestriction;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

#1st param $self.
#2rd param whether this is the first chain dynamic restriction called, hence any previous state 
#in the "Included" column of the "ProcessedTransactions" table should be ignored.
#3rd param ChainGenerationContext instance.
sub applyChainDynamicRestriction {
  die "applyChainDynamicRestriction has not been implemented.";
};

1;
