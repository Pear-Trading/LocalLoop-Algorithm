package Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops;

use Moo;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;
use Data::Dumper;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");
with ('Pear::LocalLoop::Algorithm::Role::IChainHeuristic');

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
  
  my $statementHasFinishUseId = ($isFirst ? $self->_selectChainHasFinishUserIdFirst() : $self->_selectChainHasFinishUserId());
  $statementHasFinishUseId->execute($finishingUserId);
  
  my ($hasFinishingTransaction) = $statementHasFinishUseId->fetchrow_array();
 
  
  #There is at least one next transaction id.
  if (defined $hasFinishingTransaction)
  {
    $self->_selectChainPrioritiseFindingLoops()->execute($finishingUserId);
    
    if ($isFirst) {
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

has _statementCandinatesHasTransactionsIncluded => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandinateTransactionsId FROM CandinateTransactions_ViewIncluded, ProcessedTransactions WHERE TransactionTo_FK = TransactionId AND ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _statementCandinatesHasTransactionsFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandinateTransactionsId FROM CandinateTransactions, ProcessedTransactions WHERE TransactionTo_FK = TransactionId AND ToUserId = ? LIMIT 1");
  },
  lazy => 1,
);

has _statementCandinatesPrioritiseFindingLoops => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 0 WHERE Included != 0 AND TransactionTo_FK NOT IN (SELECT TransactionId FROM ProcessedTransactions WHERE ToUserId = ?)");
  },
  lazy => 1,
);

has _statementCandinatesPrioritiseFindingLoopsFirst => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 1 WHERE Included = 0 AND TransactionTo_FK IN (SELECT TransactionId FROM ProcessedTransactions WHERE ToUserId = ?)");
  },
  lazy => 1,
);

has _selectCandinatesReset => (
  is => 'ro',
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);

sub applyCandinateTransactionHeuristic {
  debugMethodStart();
  
  my ($self, $isFirst, $loopGenerationContextInstance) = @_;
  
  if ( ! defined $isFirst ) {
    die "isFirst cannot be undef";
  }
  if ( ! defined $loopGenerationContextInstance ) {
    die "loopGenerationContextInstance cannot be undef";
  }
  
  my $loopUserId = $loopGenerationContextInstance->userIdWhichCreatesALoop();

  my $statementHasTransactions = ($isFirst ? $self->_statementCandinatesHasTransactionsFirst() : $self->_statementCandinatesHasTransactionsIncluded());
  $statementHasTransactions->execute($loopUserId);
  my ($hasCandinateTransactions) = $statementHasTransactions->fetchrow_array();
 

  #If this is undef all are not included anyway.  
  #There is at least one next transaction id. We only need the candinate transaction id as that identifies one row.
  if (defined $hasCandinateTransactions) {
    $self->_statementCandinatesPrioritiseFindingLoops()->execute($loopUserId);
    
    if ($isFirst) {
      $self->_statementCandinatesPrioritiseFindingLoopsFirst()->execute($loopUserId);
    }
  }
  #No end transaction, but this is the first pass so reset everything.
  elsif ($isFirst) {
    $self->_selectCandinatesReset()->execute();
  }
  
  debugMethodEnd();
};



sub applyLoopHeuristic {
  debugMethodStart();
  
  #This does not impact loops.

  debugMethodEnd();
};

1;
