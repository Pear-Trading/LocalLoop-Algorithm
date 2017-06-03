package Pear::LocalLoop::Algorithm::ExtendedTransaction;

use Moo;
use v5.10;
use Data::Dumper;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::Debug;

extends('Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier');

#This will always be not null, unless there are no more candidate transactions left.
has extendedTransaction => (
  is => 'ro',
  default => sub { return undef; }
);

#This will only be null on an initial transaction and when there are no candidate transactions left.
has fromTransaction => (
  is => 'ro',
  default => sub { return undef; }
);

has firstTransaction => (
  is => 'ro', 
  required => 0,
  default => sub { return 0; }
);

has noCandidateTransactionsLeft => (
  is => 'ro', 
  required => 0,
  default => sub { return 0; }
);


has statementToUserIdOfTransaction => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT ToUserId FROM ProcessedTransactions WHERE TransactionId = ?");
  },
  lazy => 1,
);

sub hasLoopFormed {
  my ($self, $loopGenerationContext) = @_;
  
  my $dbh = $self->dbh();
  
  my $extendedTrans = $self->extendedTransaction;
  if (! defined $extendedTrans) {
    return 0;
  }
  
  my $statementToUserIdOfTransaction = $self->statementToUserIdOfTransaction();
  $statementToUserIdOfTransaction->execute($extendedTrans->transactionId);
  my ($toUserId) = $statementToUserIdOfTransaction->fetchrow_array();

  #Loop has been formed?
  return ($toUserId == $loopGenerationContext->userIdWhichCreatesALoop());
}

sub hasFinished {
  my ($self, $loopGenerationContext) = @_;
  
  return ($self->noCandidateTransactionsLeft() || $self->hasLoopFormed($loopGenerationContext));
}

sub isStillFormingLoops {
  my ($self, $loopGenerationContext) = @_;  
  
  return (! $self->noCandidateTransactionsLeft() && $self->hasLoopFormed($loopGenerationContext));
}

#TODO we assume $compare is the correct class.
sub equals {
  my ($self, $compare1, $compare2) = @_;
 
  if ( ! defined $compare1 && ! defined $compare2 ) {
    return 1;
  }
  elsif ( defined $compare1 != defined $compare2 ) {
    return 0;
  }
  #Done from a static context to prevent deferencing a null ref.
  elsif ( ! Pear::LocalLoop::Algorithm::ChainTransaction->equals($compare1->extendedTransaction(), $compare2->extendedTransaction()) ) {
    return 0;
  }
  elsif ( ! Pear::LocalLoop::Algorithm::ChainTransaction->equals($compare1->fromTransaction(), $compare2->fromTransaction()) ) {
    return 0;
  }
  elsif ($compare1->firstTransaction() != $compare2->firstTransaction()) {
    return 0;
  }
  elsif ($compare1->noCandidateTransactionsLeft() != $compare2->noCandidateTransactionsLeft()) {
    return 0;
  }
  else {
    return 1;
  }
}


1;


