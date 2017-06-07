package Pear::LocalLoop::Algorithm::ProcessingTypeContainer;

use Moo;
use Pear::LocalLoop::Algorithm::Debug;
use DBI;

extends("Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier");


has staticRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has transactionOrder => (
  is => 'ro',
  default => sub { return undef; },
#  lazy => 1,
);

has chainDynamicRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has loopDynamicRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has chainHeuristicArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has loopHeuristicArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);


#Initialise all of the modules, this happens before static restrictions.
sub init {
  debugMethodStart();
  my ($self) = @_;
  
  foreach my $staticRestriction (@{$self->staticRestrictionsArray()}) {
    $staticRestriction->init();
  }
  
  $self->transactionOrder()->init();
  
  foreach my $chainDynamicRestriction (@{$self->chainDynamicRestrictionsArray()}) {
    $chainDynamicRestriction->init();
  }
  
  foreach my $chainHeuristic (@{$self->chainHeuristicArray()}) {
    $chainHeuristic->init();
  }
  
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->init();
  }
  
  foreach my $loopHeuristic (@{$self->loopHeuristicArray()}) {
    $loopHeuristic->init();
  }    
  
  debugMethodEnd();
}


#Apply the static restrictions.
sub applyStaticRestrictions {
  debugMethodStart();
  my ($self) = @_;
  
  foreach my $staticRestriction (@{$self->staticRestrictionsArray()}) {
    $staticRestriction->applyStaticRestriction();
  }
  
  debugMethodEnd();
}


#Call the "initAfterStaticRestrictions" on all instances.
sub initAfterStaticRestrictions {
  debugMethodStart();
  my ($self) = @_;

  $self->transactionOrder()->initAfterStaticRestrictions();
  
  foreach my $chainDynamicRestriction (@{$self->chainDynamicRestrictionsArray()}) {
    $chainDynamicRestriction->initAfterStaticRestrictions();
  }
  
  foreach my $chainHeuristic (@{$self->chainHeuristicArray()}) {
    $chainHeuristic->initAfterStaticRestrictions();
  }
  
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->initAfterStaticRestrictions();
  }
  
  foreach my $loopHeuristic (@{$self->loopHeuristicArray()}) {
    $loopHeuristic->initAfterStaticRestrictions();
  }    
  
  debugMethodEnd();
}


#Get the next transaction id.
sub nextTransactionId {
  debugMethodStart();
  my ($self) = @_;
  
  my $nextId = $self->transactionOrder()->nextTransactionId();
  
  debugMethodEnd();
  return $nextId;
}



has _statementDynamicRestrictionsAndHeuristicsReset => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);
  
#Apply the chain dynamic restrictions and heuristics,
sub applyChainDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self, $chainGenerationContextInstance) = @_;
  
  #debugMethodMiddle("Inputted data:" . Dumper ($chainGenerationContextInstance));
  
  if (! defined $chainGenerationContextInstance) {
    die "chainGenerationContextInstance cannot be undefined."
  }
  
  my $isFirst = 1;
  foreach my $chainDynamicRestriction (@{$self->chainDynamicRestrictionsArray()}) {
    $chainDynamicRestriction->applyChainDynamicRestriction($isFirst, $chainGenerationContextInstance);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0;
  }
  
  foreach my $chainHeuristic (@{$self->chainHeuristicArray()}) {
    $chainHeuristic->applyChainHeuristic($isFirst, $chainGenerationContextInstance);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0; #Assume the above may be blank.
  }    
  
  #Nothing applied? Reset all of the included values
  if ($isFirst) {
    debugMethodMiddle("No dynamic restrictions or heuristics executed. All transactions reset.");
    $self->_statementDynamicRestrictionsAndHeuristicsReset()->execute();
  }
  
  debugMethodEnd();
}



has _statementHeuristicsCandidatesReset => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandidateTransactions SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);

#Apply the candidate transaction  heuristics.
sub applyChainHeuristicsCandidates {
  debugMethodStart();
  my ($self, $loopGenerationContextInstance) = @_;

  my $isFirst = 1;
  foreach my $chainHeuristic (@{$self->chainHeuristicArray()}) {
    $chainHeuristic->applyCandidateTransactionHeuristic($isFirst, $loopGenerationContextInstance);
    $self->_dumpCandidateTransactionsIncluded();
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values.
  if ($isFirst) {
    debugMethodMiddle("No heuristics executed. All candidate transactions reset.");
    $self->_statementHeuristicsCandidatesReset()->execute();
  }
  
  debugMethodEnd();
}


has _statementLoopDynamicRestrictionsAndHeuristicsReset => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE LoopStats SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);

#Apply the loop dynamic restrictions and heuristics
sub applyLoopDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self) = @_;

  my $isFirst = 1;
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->applyLoopDynamicRestriction($isFirst);
    $isFirst = 0; 
  }    
  
  foreach my $loopHeuristic (@{$self->loopHeuristicArray()}) {
    $loopHeuristic->applyLoopHeuristic($isFirst);
    $isFirst = 0; #Assume the above may be blank.
  }    
  
  #Nothing applied? Reset all of the included values.
  if ($isFirst) {
    debugMethodMiddle("No dynamic restrictions or heuristics executed. All loops reset.");
    $self->_statementLoopDynamicRestrictionsAndHeuristicsReset->execute();
  }
  
  debugMethodEnd();
}



has _statementDumpTransactionsIncluded => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT TransactionId, Included FROM ProcessedTransactions ORDER BY TransactionId");
  },
  lazy => 1,
);


#Dump all included transactions to the console during debugging.
sub _dumpTransactionsIncluded {

  if (isDebug()) {
    my ($self) = @_;
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    
    my $statement = $self->_statementDumpTransactionsIncluded();
    $statement->execute();
    
    my $string = "";
    my $isFirst = 1;
    while (my ($transactionId, $included) = $statement->fetchrow_array()) {
      if ($included) {
        my $comma = ($isFirst ? "" : ", ");
        $string = $string . $comma . "$transactionId=T";
        $isFirst = 0;
      }
    }
    
    debugMethodMiddle("TransactionsIncludedDump: ".$string);
  }
}



has _statementDumpCandidateTransactionsIncluded => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandidateTransactionsId, Included FROM CandidateTransactions ORDER BY CandidateTransactionsId");
  },
  lazy => 1,
);

#Dump all active candidate transactions to the console during debugging.
sub _dumpCandidateTransactionsIncluded {
  
  if (isDebug()) {
    my ($self) = @_;
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    
    my $statement = $self->_statementDumpCandidateTransactionsIncluded();
    $statement->execute();
    
    my $string = "";
    my $isFirst = 1;
    while (my ($transactionId, $included) = $statement->fetchrow_array) {
      if ($included) {
        my $comma = ($isFirst ? "" : ", ");
        $string = $string . $comma . "$transactionId=T";
        $isFirst = 0;
      }
    }
    
    debugMethodMiddle("CandidateTransactionsIncludedDump: ".$string);
  }
}



1;
