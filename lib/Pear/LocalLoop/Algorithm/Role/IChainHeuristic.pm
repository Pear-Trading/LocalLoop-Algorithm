package Pear::LocalLoop::Algorithm::Role::IChainHeuristic;

use Moo::Role;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

sub initAfterStaticRestrictions {
  debugMethodStart();
  
  debugMethodEnd();
}

#1st param $self.
#2rd param whether this is the first chain heuristic/chain dynamic restriction called, 
#hence any previous state in the "Included" column of the "ProcessedTransactions" table should be ignored.
#3rd param ChainGenerationContext instance.
sub applyChainHeuristic {
  die "applyChainHeuristic has not been implemented.";
};

#1st param $self.
#2rd param whether this is the first candidate transaction heuristic called, 
#hence any previous state in the "Included" column of the "CandidateTransactions" table should be ignored.
#3rd param LoopGenerationContext instance.
sub applyCandidateTransactionHeuristic {
  die "applyCandidateTransactionHeuristic has not been implemented.";
};

1;
