package Pear::LocalLoop::Algorithm::Role::ITransactionOrder;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

#Returns the next transaction id to be analysed.
#If it returns undef when its finished.
sub nextTransactionId {
  die "nextTransactionId has not been implemented.";
}


1;
