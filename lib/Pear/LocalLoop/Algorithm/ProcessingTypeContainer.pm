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

has dynamicRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has loopDynamicRestrictionsArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

has heuristicArray => (
  is => 'ro',
  default => sub { return []; },
#  lazy => 1,
);

sub init {
  debugMethodStart();
  my ($self) = @_;
  
  foreach my $staticRestriction (@{$self->staticRestrictionsArray()}) {
    $staticRestriction->init();
  }
  
  $self->transactionOrder()->init();
  
  foreach my $dynamicRestriction (@{$self->dynamicRestrictionsArray()}) {
    $dynamicRestriction->init();
  }
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->init();
  }
  
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->init();
  }    
  
  debugMethodEnd();
}

sub applyStaticRestrictions {
  debugMethodStart();
  my ($self) = @_;
  
  foreach my $staticRestriction (@{$self->staticRestrictionsArray()}) {
    $staticRestriction->applyStaticRestriction();
  }
  
  debugMethodEnd();
}

sub initAfterStaticRestrictions {
  debugMethodStart();
  my ($self) = @_;

  $self->transactionOrder()->initAfterStaticRestrictions();
  
  foreach my $dynamicRestriction (@{$self->dynamicRestrictionsArray()}) {
    $dynamicRestriction->initAfterStaticRestrictions();
  }
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->initAfterStaticRestrictions();
  }
  
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->initAfterStaticRestrictions();
  }    
  
  debugMethodEnd();
}


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
  

sub applyChainDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self, $chainGenerationContextInstance) = @_;
  
  #debugMethodMiddle("Inputted data:" . Dumper ($chainGenerationContextInstance));
  
  if (! defined $chainGenerationContextInstance) {
    die "chainGenerationContextInstance cannot be undefined."
  }
  
  my $isFirst = 1;
  foreach my $dynamicRestriction (@{$self->dynamicRestrictionsArray()}) {
    $dynamicRestriction->applyChainDynamicRestriction($isFirst, $chainGenerationContextInstance);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0;
  }
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristic($isFirst, $chainGenerationContextInstance);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values
  if ($isFirst) {
    debugMethodMiddle("No dynamic restrictions or heuristics executed. All transactions reset.");
    $self->_statementDynamicRestrictionsAndHeuristicsReset()->execute();
  }
  
  debugMethodEnd();
}

has _statementHeuristicsCandinatesReset => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE CandinateTransactions SET Included = 1 WHERE Included = 0");
  },
  lazy => 1,
);

sub applyHeuristicsCandinates {
  debugMethodStart();
  my ($self, $loopGenerationContextInstance) = @_;

  my $isFirst = 1;
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristicCandinates($isFirst, $loopGenerationContextInstance);
    $self->_dumpCandinateTransactionsIncluded();
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values.
  if ($isFirst) {
    debugMethodMiddle("No heuristics executed. All candinate transactions reset.");
    $self->_statementHeuristicsCandinatesReset()->execute();
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

sub applyLoopDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self) = @_;

  my $isFirst = 1;
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->applyLoopDynamicRestriction($isFirst);
    $isFirst = 0;
  }    
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyLoopHeuristic($isFirst);
    $isFirst = 0;
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

has _statementDumpCandinateTransactionsIncluded => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT CandinateTransactionsId, Included FROM CandinateTransactions ORDER BY CandinateTransactionsId");
  },
  lazy => 1,
);

sub _dumpCandinateTransactionsIncluded {
  
  if (isDebug()) {
    my ($self) = @_;
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    
    my $statement = $self->_statementDumpCandinateTransactionsIncluded();
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
    
    debugMethodMiddle("CandinateTransactionsIncludedDump: ".$string);
  }
}



1;
