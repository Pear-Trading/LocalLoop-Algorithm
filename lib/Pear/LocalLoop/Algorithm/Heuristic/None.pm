package Pear::LocalLoop::Algorithm::Heuristic::None;

use Moo;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::ILoopHeuristic');

#This heuristic selects one of the earliest transactions possible.

has _selectChainMinimumTransactionId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId) FROM ProcessedTransactions_ViewIncluded WHERE ? < TransactionId");
  },
  lazy => 1,
);

has _selectChainMinimumTransactionIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId) FROM ProcessedTransactions WHERE ? < TransactionId");
  },
  lazy => 1,
);

has _selectChainNone => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId != ?");
  },
  lazy => 1,
);

has _selectChainNoneFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND TransactionId = ?");
  },
  lazy => 1,
);

has _selectChainNoSelectedTransaction => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0");
  },
  lazy => 1,
);


sub applyChainHeuristic {
  debugMethodStart();
  
  my ($self, $isFirst, $chainGenerationContextInstance) = @_;
  
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undefined";
  }
  elsif ( ! defined $chainGenerationContextInstance ) {
    die "chainGenerationContextInstance cannot be undefined";
  }
  
  my $transactionId = $chainGenerationContextInstance->currentTransactionId();
  
  my $statementMinTransaction = ($isFirst ? $self->_selectChainMinimumTransactionIdFirst() : $self->_selectChainMinimumTransactionId());
  $statementMinTransaction->execute($transactionId);
  
  #Select the next transaction
  my ($nextTransactionId) = $statementMinTransaction->fetchrow_array();
 
  #say "next: $nextTransactionId";
  
  #There is at least one next transaction id.
  if (defined $nextTransactionId)
  {
    #Exclude all of the other included transactions except this one.
    $self->_selectChainNone()->execute($nextTransactionId);
    
    #Include the selected transaction if excluded.
    if ($isFirst) {
      $self->_selectChainNoneFirst()->execute($nextTransactionId);
    }
  }
  #No next value so set all valued to not be included.
  else {
    $self->_selectChainNoSelectedTransaction()->execute();
  }
  
  debugMethodEnd();
};

has statementCandidatesMinimumTransactionId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId, MIN(TransactionTo_FK) FROM CandidateTransactions_ViewIncluded");
  },
  lazy => 1,
);

has statementCandidatesMinimumTransactionIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId, MIN(TransactionTo_FK) FROM CandidateTransactions");
  },
  lazy => 1,
);

has statementCandidatesNone => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 0 WHERE Included != 0 AND CandidateTransactionsId != ?");
  },
  lazy => 1,
);

has statementCandidatesNoneFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 1 WHERE Included = 0 AND CandidateTransactionsId = ?");
  },
  lazy => 1,
);

sub applyCandidateTransactionHeuristic {
  debugMethodStart();
  
  my ($self, $isFirst) = @_;
  my $dbh = $self->dbh();

  my $statementMinTransaction = ($isFirst ? $self->statementCandidatesMinimumTransactionIdFirst() : $self->statementCandidatesMinimumTransactionId());
  $statementMinTransaction->execute();
  #Candidate transaction and and minimum "TransactionTo_FK" that goes with it.
  my ($candidateTransactionsId, $nextTransactionId) = $statementMinTransaction->fetchrow_array();

  #If this is undef all are not included anyway.  
  #There is at least one next transaction id. We only need the candidate transaction id as that identifies one row.
  if (defined $candidateTransactionsId)
  {
    #Exclude all candidate transactions except the specified one.
    $self->statementCandidatesNone()->execute($candidateTransactionsId);
    
    if ($isFirst) {
      #Include the specfied candidate transaction if it's excluded.
      $self->statementCandidatesNoneFirst()->execute($candidateTransactionsId);
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

sub applyLoopHeuristic {
  debugMethodStart();
  
  my ($self, $isFirst) = @_;
  my $dbh = $self->dbh();

  my $statementEarliestLoop = ($isFirst ? $self->statementLoopsMinimumTransactionIdFirst() : $self->statementLoopsMinimumTransactionId());
  $statementEarliestLoop->execute();
  
  #What's the earliest starting loop
  my ($earliestLoop) = $statementEarliestLoop->fetchrow_array();
  
  #If no loops exist we cannot change the state of them
  if (defined $earliestLoop) {
    #Exclude all loops except the one specified.
    $self->statementLoopsNone()->execute($earliestLoop);
  
    if ($isFirst) {
      #Include the specified loop if it's exluded.
      $self->statementLoopsNoneFirst()->execute($earliestLoop);
    }
  }

  debugMethodEnd();
};

1;
