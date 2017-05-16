package Pear::LocalLoop::Algorithm::Role::ITransactionOrder;

use Moo::Role;

sub initAfterStaticRestrictions {
  die "initAfterStaticRestrictions has not been implemented.";
}

#Returns the next transaction id to be analysed.
#If it returns undef when its finished.
sub nextTransactionId {
  die "nextTransactionId has not been implemented.";
}


1;
