package Pear::LocalLoop::Algorithm::ProcessingTypeContainer;

use Moo;
use Pear::LocalLoop::Algorithm::Debug;
use DBI;

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
  

sub applyDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self, $transactionId, $chainId) = @_;
  
  debugMethodMiddle(__LINE__, "InputParams: TransactionId:$transactionId ChainId:$chainId");
  
  if (! defined $transactionId) {
    die "transactionId cannot be undefined."
  }
  elsif (! defined $chainId) {
    die "chainId cannot be undefined."
  }
  
  my $isFirst = 1;
  foreach my $dynamicRestriction (@{$self->dynamicRestrictionsArray()}) {
    $dynamicRestriction->applyDynamicRestriction($transactionId, $chainId, $isFirst);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0;
  }
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristic($transactionId, $chainId, $isFirst);
    $self->_dumpTransactionsIncluded();
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values
  if ($isFirst) {
    debugMethodMiddle("No dynamic restrictions or heuristics executed. All transactions reset.");
    
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    my $statement = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0");
    $statement->execute();
  }
  
  debugMethodEnd();
}

sub applyHeuristicsCandinates {
  debugMethodStart();
  my ($self) = @_;

  my $isFirst = 1;
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristicCandinates($isFirst);
    $self->_dumpCandinateTransactionsIncluded();
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values.
  if ($isFirst) {
    debugMethodMiddle("No heuristics executed. All candinate transactions reset.");
    
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    my $statement = $dbh->prepare("UPDATE CandinateTransactions SET Included = 1 WHERE Included = 0");
    $statement->execute();
  }
  
  debugMethodEnd();
}

sub applyLoopDynamicRestrictionsAndHeuristics {
  debugMethodStart();
  my ($self) = @_;

  my $isFirst = 1;
  foreach my $loopDynamicRestriction (@{$self->loopDynamicRestrictionsArray()}) {
    $loopDynamicRestriction->applyLoopDynamicRestriction($isFirst);
    $isFirst = 0;
  }    
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristicLoops($isFirst);
    $isFirst = 0;
  }    
  
  #Nothing applied? Reset all of the included values.
  if ($isFirst) {
    debugMethodMiddle("No dynamic restrictions or heuristics executed. All loops reset.");
    
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    my $statement = $dbh->prepare("UPDATE LoopStats SET Included = 1 WHERE Included = 0");
    $statement->execute();
  }
  
  debugMethodEnd();
}

sub _dumpTransactionsIncluded {

  if (isDebug()) {
    my ($self) = @_;
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    
    my $statement = $dbh->prepare("SELECT TransactionId, Included FROM ProcessedTransactions ORDER BY TransactionId");
    $statement->execute();
    
    my $string = "";
    my $isFirst = 1;
    while (my ($transactionId, $included) = $statement->fetchrow_array) {
      my $comma = ($isFirst ? "" : ", ");
      $string = $string . $comma . "$transactionId=" . ($included ? "T" : "F");
      $isFirst = 0;
    }
    
    debugMethodMiddle("TransactionsIncludedDump: ".$string);
  }
}

sub _dumpCandinateTransactionsIncluded {
  
  if (isDebug()) {
    my ($self) = @_;
    my $dbh = Pear::LocalLoop::Algorithm::Main->dbi();
    
    my $statement = $dbh->prepare("SELECT CandinateTransactionsId, Included FROM CandinateTransactions ORDER BY CandinateTransactionsId");
    $statement->execute();
    
    my $string = "";
    my $isFirst = 1;
    while (my ($transactionId, $included) = $statement->fetchrow_array) {
      my $comma = ($isFirst ? "" : ", ");
      $string = $string . $comma . "$transactionId=" . ($included ? "T" : "F");
      $isFirst = 0;
    }
    
    debugMethodMiddle("CandinateTransactionsIncludedDump: ".$string);
  }
}



1;
