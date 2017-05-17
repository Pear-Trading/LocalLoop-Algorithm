package Pear::LocalLoop::Algorithm::Role::IHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
  
  debugMethodEnd(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
}

sub applyHeuristic {
  die "applyHeuristic has not been implemented.";
};

1;
