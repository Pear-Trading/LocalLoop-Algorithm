package Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ITransactionOrder');

#TODO this should be rwp
has dbQuery => (
  is => 'rw',
);

sub initAfterStaticRestrictions {
  #say 'Path-Enter init: file:' . __FILE__ . ', line: ' . __LINE__;
  my $self = shift;
  
  my $query = $self->dbh->prepare("SELECT TransactionId FROM ProcessedTransactions ORDER BY TransactionId ASC");
  $query->execute();
  
  $self->dbQuery($query);
  
  #say 'Path-Exit init: file:' . __FILE__ . ', line: ' . __LINE__;
}


sub nextTransactionId {
  #say 'Path-Enter nextTransactionId: file:' . __FILE__ . ', line: ' . __LINE__;
  my $self = shift;
  
  #Has an integer or undef.
  my ($transactionId) = $self->dbQuery->fetchrow_array();
  #say $transactionId;
  
  #say 'Path-Exit nextTransactionId: file:' . __FILE__ . ', line: ' . __LINE__;
  return $transactionId;
}

1;
