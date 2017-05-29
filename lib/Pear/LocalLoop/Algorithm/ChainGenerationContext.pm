package Pear::LocalLoop::Algorithm::ChainGenerationContext;

use Moo;
use Pear::LocalLoop::Algorithm::Debug;
use Pear::LocalLoop::Algorithm::LoopGenerationContext qw(checkIsNumberAndNotUndef);

extends("Pear::LocalLoop::Algorithm::LoopGenerationContext");

has currentChainId => (
  required => 1,
  is => 'ro',
  isa => sub { Pear::LocalLoop::Algorithm::LoopGenerationContext::checkIsNumberAndNotUndef($_[0]); },
);

has currentTransactionId => (
  required => 1,
  is => 'ro',
  isa => sub { Pear::LocalLoop::Algorithm::LoopGenerationContext::checkIsNumberAndNotUndef($_[0]); },
);

#userIdWhichCreatesALoop from super class.

1;
