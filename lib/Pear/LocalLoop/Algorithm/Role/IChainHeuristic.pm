package Pear::LocalLoop::Algorithm::Role::IChainHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

sub applyChainHeuristic {
  die "applyChainHeuristic has not been implemented.";
};

sub applyCandidateTransactionHeuristic {
  die "applyCandidateTransactionHeuristic has not been implemented.";
};

1;
