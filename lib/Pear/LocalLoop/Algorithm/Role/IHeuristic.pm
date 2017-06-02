package Pear::LocalLoop::Algorithm::Role::IHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

sub applyHeuristic {
  die "applyHeuristic has not been implemented.";
};

sub applyCandinateTransactionHeuristic {
  die "applyCandinateTransactionHeuristic has not been implemented.";
};

sub applyLoopHeuristic {
  die "applyLoopHeuristic has not been implemented.";
};

1;
