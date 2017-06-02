package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::IChainDynamicRestriction');

#If it is the first restriction then set included in all of the transactions 
#before itself and itself to 0, any after itself set to 1.
#If it's not the first restriction then set included in all of the transactions 
#before itself and itself to 0.


has _statementAllowOnlyAfterCurrentTransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId <= ?");
  },
  lazy => 1,
);

has _statementAllowOnlyAfterCurrentTransactionFirst => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND ? < TransactionId");
  },
  lazy => 1,
);


sub applyChainDynamicRestriction {
  debugMethodStart();

  my ($self, $isFirst, $chainGenerationContextInstance) = @_;
  my $dbh = $self->dbh();
  
  #We don't care if chainId is undefined as we don't use it.
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  elsif ( ! defined $chainGenerationContextInstance ) {
    die "chainGenerationContextInstance cannot be undefined";
  }
  
  my $transactionId = $chainGenerationContextInstance->currentTransactionId();
  
  $self->_statementAllowOnlyAfterCurrentTransaction()->execute($transactionId);
  
  if ($isFirst){
    $self->_statementAllowOnlyAfterCurrentTransactionFirst()->execute($transactionId);
  }
  
  debugMethodEnd();
}

1;

