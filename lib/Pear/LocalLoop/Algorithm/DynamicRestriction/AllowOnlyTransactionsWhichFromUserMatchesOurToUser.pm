package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IDynamicRestriction');

#When considering the next transaction the current transactions "to user" must be the same as the next "from user".
#So set include to 0 if it differs, otherwise it cannot form a chain.

#If it's the first restriction then set all of the from users to be included.


has statementSelectToUserOfATransaction => (
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

sub applyDynamicRestriction {
  debugMethodStart();
  my ($self, $transactionId, $chainId, $isFirst) = @_;
  
  #It does not matter if $chainid is null as it's unused.
  if ( ! defined $transactionId ) {
    die "transactionId cannot be undefined";
  }
  elsif ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  
  my $statementSelectToUserOfATransaction = $self->statementSelectToUserOfATransaction();
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

