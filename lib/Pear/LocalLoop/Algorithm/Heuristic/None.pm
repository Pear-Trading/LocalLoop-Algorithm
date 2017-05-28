package Pear::LocalLoop::Algorithm::Heuristic::None;

use Moo;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IHeuristic');

has selectChainMinimumTransactionId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId) FROM ProcessedTransactions_ViewIncluded WHERE ? < TransactionId");
  },
  lazy => 1,
);

has selectChainMinimumTransactionIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId) FROM ProcessedTransactions WHERE ? < TransactionId");
  },
  lazy => 1,
);

has selectChainNone => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId != ?");
  },
  lazy => 1,
);

has selectChainNoneFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND TransactionId = ?");
  },
  lazy => 1,
);

has selectChainNoSelectedTransaction => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0");
  },
  lazy => 1,
);


sub applyHeuristic {
  debugMethodStart();
  
  my ($self, $transactionId, $chainId, $isFirst) = @_;
  
  #Chain id is not used so it does not matter if it's undefined.
  if ( ! defined $transactionId) {
    die "transactionId cannot be undefined.";
  }
  elsif ( ! defined $isFirst) {
    die "isFirstRestriction cannot be undefined.";
  }
  
  my $statementMinTransaction = ($isFirst ? $self->selectChainMinimumTransactionIdFirst() : $self->selectChainMinimumTransactionId());
  $statementMinTransaction->execute($transactionId);
  
  my ($nextTransactionId) = $statementMinTransaction->fetchrow_array();
 
  #say "next: $nextTransactionId";
  
  #There is at least one next transaction id.
  if (defined $nextTransactionId)
  {
    $self->selectChainNone()->execute($nextTransactionId);
    
    if ($isFirst) {
      $self->selectChainNoneFirst()->execute($nextTransactionId);
    }
  }
  #No next value so set all valued to not be included.
  else {
    $self->selectChainNoSelectedTransaction()->execute();
  }
  
  debugMethodEnd();
};

has statementCandinatesMinimumTransactionId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandinateTransactionsId, MIN(TransactionTo_FK) FROM CandinateTransactions_ViewIncluded");
  },
  lazy => 1,
);

has statementCandinatesMinimumTransactionIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandinateTransactionsId, MIN(TransactionTo_FK) FROM CandinateTransactions");
  },
  lazy => 1,
);

has statementCandinatesNone => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 0 WHERE Included != 0 AND CandinateTransactionsId != ?");
  },
  lazy => 1,
);

has statementCandinatesNoneFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 1 WHERE Included = 0 AND CandinateTransactionsId = ?");
  },
  lazy => 1,
);

sub applyHeuristicCandinates {
  debugMethodStart();
  
  my ($self, $isFirst) = @_;
  my $dbh = $self->dbh();

  my $statementMinTransaction = ($isFirst ? $self->statementCandinatesMinimumTransactionIdFirst() : $self->statementCandinatesMinimumTransactionId());
  $statementMinTransaction->execute();
  my ($candinateTransactionsId, $nextTransactionId) = $statementMinTransaction->fetchrow_array();

  #If this is undef all are not included anyway.  
  #There is at least one next transaction id. We only need the candinate transaction id as that identifies one row.
  if (defined $candinateTransactionsId)
  {
    $self->statementCandinatesNone()->execute($candinateTransactionsId);
    
    if ($isFirst) {
      $self->statementCandinatesNoneFirst()->execute($candinateTransactionsId);
    }
  }
  
  debugMethodEnd();
};


has statementLoopsMinimumTransactionId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT LoopId FROM LoopInfo_ViewIncluded ORDER BY FirstTransactionId_FK ASC, LastTransactionId_FK ASC");
  },
  lazy => 1,
);

has statementLoopsMinimumTransactionIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT LoopId FROM LoopInfo ORDER BY FirstTransactionId_FK ASC, LastTransactionId_FK ASC");
  },
  lazy => 1,
);

has statementLoopsNone => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 0 WHERE Included != 0 AND LoopId != ?");
  },
  lazy => 1,
);

has statementLoopsNoneFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopInfo SET Included = 1 WHERE Included = 0 AND LoopId = ?");
  },
  lazy => 1,
);

sub applyHeuristicLoops {
  debugMethodStart();
  
  my ($self, $isFirst) = @_;
  my $dbh = $self->dbh();

  my $statementEarliestLoop = ($isFirst ? $self->statementLoopsMinimumTransactionIdFirst() : $self->statementLoopsMinimumTransactionId());
  $statementEarliestLoop->execute();
  my ($earliestLoop) = $statementEarliestLoop->fetchrow_array();
  
  if (defined $earliestLoop) {
    $self->statementLoopsNone()->execute($earliestLoop);
  
    if ($isFirst) {
      $self->statementLoopsNoneFirst()->execute($earliestLoop);
    }
  }

  debugMethodEnd();
};

1;
