package Pear::LocalLoop::Algorithm::Role::ITransactionOrder;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
  
  debugMethodEnd(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
}

#Returns the next transaction id to be analysed.
#If it returns undef when its finished.
sub nextTransactionId {
  die "nextTransactionId has not been implemented.";
}


1;
