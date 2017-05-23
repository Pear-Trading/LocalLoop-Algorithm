package Pear::LocalLoop::Algorithm::ExtendedTransaction;

use Moo;

extends('Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier');

#This will always be not null, unless there are no more candinate transactions left.
has extendedTransaction => (
  is => 'ro',
  default => sub { return undef; }
);

#This will only be null on an initial transaction and when there are no candinate transactions left.
has fromTransaction => (
  is => 'ro',
  default => sub { return undef; }
);


has loopStartEndUserId => (
  is => 'ro',
  required => 1,
);

has firstTransaction => (
  is => 'ro', 
  required => 0,
  default => sub { return 0; }
);

has noCandinateTransactionsLeft => (
  is => 'ro', 
  required => 0,
  default => sub { return 0; }
);

sub hasLoopFormed {
  my ($self) = @_;
  my $dbh = $self->dbh();
  
  my $extendedTrans = $self->extendedTransaction;
  if (! defined $extendedTrans) {
    return 0;
  }
  
  my $statementFromUserId = $dbh->prepare("SELECT ToUserId FROM ProcessedTransactions WHERE TransactionId = ?");
  $statementFromUserId->execute($extendedTrans->transactionId);
  
  my ($toUserId) = $statementFromUserId->fetchrow_array();
  
  #Loop has been formed?
  return ($self->loopStartEndUserId() == $toUserId);
}

sub hasFinished {
  my ($self) = @_;
  
  return ($self->noCandinateTransactionsLeft() || $self->hasLoopFormed());
}

sub isStillFormingLoops {
  my ($self) = @_;  
  
  return (! $self->noCandinateTransactionsLeft() && $self->hasLoopFormed());
}


1;

