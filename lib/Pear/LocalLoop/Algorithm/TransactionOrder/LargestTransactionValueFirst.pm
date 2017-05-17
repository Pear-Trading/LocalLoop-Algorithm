package Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ITransactionOrder');

#TODO this should be rwp
has dbQuery => (
  is => 'rw',
);

sub initAfterStaticRestrictions {
  debugMethodStart(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
  
  my $self = shift;
  
  my $query = $self->dbh->prepare("SELECT TransactionId FROM ProcessedTransactions ORDER BY Value DESC, TransactionId ASC");
  $query->execute();
  
  $self->dbQuery($query);
  
  debugMethodEnd(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
}


sub nextTransactionId {
  debugMethodStart(__PACKAGE__, "nextTransactionId", __LINE__);
  
  my $self = shift;
  
  #Has an integer or undef.
  my ($transactionId) = $self->dbQuery->fetchrow_array();
  #say $transactionId . ' ' . $value;
  
  debugMethodEnd(__PACKAGE__, "nextTransactionId", __LINE__);
  return $transactionId;
}

1;
