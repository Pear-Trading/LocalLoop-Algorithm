package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IDynamicRestriction');

#If it is the first restriction then set included in all of the transactions 
#before itself and itself to 0, any after itself set to 1.
#If it's not the first restriction then set included in all of the transactions 
#before itself and itself to 0.


has statementAllowOnlyAfterCurrentTransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId <= ?");
  },
  lazy => 1,
);

has statementAllowOnlyAfterCurrentTransactionFirst => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND ? < TransactionId");
  },
  lazy => 1,
);


sub applyDynamicRestriction {
  debugMethodStart();

  my ($self, $transactionId, $chainId, $isFirst) = @_;
  my $dbh = $self->dbh();
  
  #We don't care if chainId is undefined as we don't use it.
  if ( ! defined $transactionId ) {
    die "transactionId cannot be undefined";
  }
  elsif ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  
  $self->statementAllowOnlyAfterCurrentTransaction()->execute($transactionId);
  
  if ($isFirst){
    $self->statementAllowOnlyAfterCurrentTransactionFirst()->execute($transactionId);
  }
  
  debugMethodEnd();
}

1;

