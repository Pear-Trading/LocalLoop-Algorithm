package Pear::LocalLoop::Algorithm::ChainDynamicRestriction::AllowOnlyAfterCurrentTransaction;

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

#Exclude transactions before on the current one.
has _statementAllowOnlyAfterCurrentTransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId <= ?");
  },
  lazy => 1,
);

#Include transactions after this transaction if they have been excluded
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
  
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  elsif ( ! defined $chainGenerationContextInstance ) {
    die "chainGenerationContextInstance cannot be undefined";
  }
  
  my $transactionId = $chainGenerationContextInstance->currentTransactionId();
  
  #Exclude included transactions before or on this transaction.
  $self->_statementAllowOnlyAfterCurrentTransaction()->execute($transactionId);
  
  if ($isFirst){
    #Include transactions after this transaction if they are excluded.
    $self->_statementAllowOnlyAfterCurrentTransactionFirst()->execute($transactionId);
  }
  
  debugMethodEnd();
}

1;

