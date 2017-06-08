package Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops;

use Moo;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;
use Data::Dumper;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::IChainHeuristic');

#This heuristic tries to select the transactions and candidate transactions that will form loops, otherwise
#it does nothing.

has _selectChainHasFinishUserId => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT TransactionId FROM ProcessedTransactions_ViewIncluded WHERE ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _selectChainHasFinishUserIdFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT TransactionId FROM ProcessedTransactions WHERE ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _selectChainPrioritiseFindingLoops => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND ToUserId != ?");
  },
  lazy => 1,
);

has _selectChainPrioritiseFindingLoopsFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND ToUserId = ?");
  },
  lazy => 1,
);

has _selectChainReset => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0");
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
  
  my $finishingUserId = $chainGenerationContextInstance->userIdWhichCreatesALoop();
  
  #Check to see whether it can actually finish or not
  my $statementHasFinishUseId = ($isFirst ? $self->_selectChainHasFinishUserIdFirst() : $self->_selectChainHasFinishUserId());
  $statementHasFinishUseId->execute($finishingUserId);
  
  my ($hasFinishingTransaction) = $statementHasFinishUseId->fetchrow_array();
 
  
  #There is at least one next transaction id.
  if (defined $hasFinishingTransaction)
  {
    #Exclude all transactions to users that don't match the user id.
    $self->_selectChainPrioritiseFindingLoops()->execute($finishingUserId);
    
    if ($isFirst) {
      #Include all transactions to users that match the user id.
      $self->_selectChainPrioritiseFindingLoopsFirst()->execute($finishingUserId);
    }
  }
  #No end transaction, but this is the first pass so reset everything.
  elsif ($isFirst) {
    $self->_selectChainReset()->execute();
  }
  
  #If none is found this heuristic has no effect.
  
  debugMethodEnd();
};

has _statementCandidatesHasTransactionsIncluded => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId FROM CandidateTransactions_ViewIncluded, ProcessedTransactions WHERE TransactionTo_FK = TransactionId AND ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _statementCandidatesHasTransactionsFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId FROM CandidateTransactions, ProcessedTransactions WHERE TransactionTo_FK = TransactionId AND ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _statementCandidatesPrioritiseFindingLoops => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 0 WHERE Included != 0 AND TransactionTo_FK NOT IN (SELECT TransactionId FROM ProcessedTransactions WHERE ToUserId = ?)");
  },
  lazy => 1,
);

has _statementCandidatesPrioritiseFindingLoopsFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 1 WHERE Included = 0 AND TransactionTo_FK IN (SELECT TransactionId FROM ProcessedTransactions WHERE ToUserId = ?)");
  },
  lazy => 1,
);

has _selectCandidatesReset => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);

sub applyCandidateTransactionHeuristic {
  debugMethodStart();
  
  my ($self, $isFirst, $loopGenerationContextInstance) = @_;
  
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undef";
  }
  if ( ! defined $loopGenerationContextInstance ) {
    die "loopGenerationContextInstance cannot be undef";
  }
  
  my $loopUserId = $loopGenerationContextInstance->userIdWhichCreatesALoop();

  my $statementHasTransactions = ($isFirst ? $self->_statementCandidatesHasTransactionsFirst() : $self->_statementCandidatesHasTransactionsIncluded());
  $statementHasTransactions->execute($loopUserId);
  my ($hasCandidateTransactions) = $statementHasTransactions->fetchrow_array();
 

  #If this is undef all are not included anyway.  
  #There is at least one next transaction id. We only need the candidate transaction id as that identifies one row.
  if (defined $hasCandidateTransactions) {
    #Exclude all included transactions that don't have the specified user id.
    $self->_statementCandidatesPrioritiseFindingLoops()->execute($loopUserId);
    
    if ($isFirst) {
      #Include all excluded transactions that have the specified user id.
      $self->_statementCandidatesPrioritiseFindingLoopsFirst()->execute($loopUserId);
    }
  }
  #No end transaction, but this is the first pass so reset everything.
  elsif ($isFirst) {
    $self->_selectCandidatesReset()->execute();
  }
  
  debugMethodEnd();
};

1;
