package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::IChainDynamicRestriction');

#When considering the next transaction the current transactions "to user" must be the same as the next "from user".
#So set include to 0 if it differs, otherwise it cannot form a chain.

#If it's the first restriction then set all of the from users to be included.


has _statementSelectToUserOfATransaction => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT ToUserId FROM ProcessedTransactions WHERE TransactionId = ?");
  },
  lazy => 1,
);

has statementAllowOnlyTransactionsWhichFromUserMatchesOurToUser => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND FromUserId != ?");
  },
  lazy => 1,
);

has statementAllowOnlyTransactionsWhichFromUserMatchesOurToUserFirst => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND FromUserId = ?");
  },
  lazy => 1,
);

sub applyChainDynamicRestriction {
  debugMethodStart();
  my ($self, $isFirst, $chainGenerationContextInstance) = @_;
  
  #It does not matter if $chainid is null as it's unused.
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  elsif ( ! defined $chainGenerationContextInstance ) {
    die "chainGenerationContextInstance cannot be undefined";
  }
  
  my $transactionId = $chainGenerationContextInstance->currentTransactionId();
  
  my $statementSelectToUserOfATransaction = $self->_statementSelectToUserOfATransaction();
  $statementSelectToUserOfATransaction->execute($transactionId);
  
  my ($fromUserId) = $statementSelectToUserOfATransaction->fetchrow_array();
  
  #Set all after the max transaction id to not be included.
  $self->statementAllowOnlyTransactionsWhichFromUserMatchesOurToUser()->execute($fromUserId);
  
  if ($isFirst) {
    #Set all transactions before or on the max id to be be included
    $self->statementAllowOnlyTransactionsWhichFromUserMatchesOurToUserFirst()->execute($fromUserId);
  }
  
  debugMethodEnd();
}

1;

