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
  
  debugMethodEnd();
}

sub _dumpTransactionsIncluded {
  #debugMethodStart();
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
  
  debugMethodMiddle(__LINE__, "TransactionsIncludedDump: ".$string);
  
  #debugMethodEnd();
}

sub _dumpCandinateTransactionsIncluded {
  #debugMethodStart();
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
  
  debugMethodMiddle(__LINE__, "CandinateTransactionsIncludedDump: ".$string);
  
  #debugMethodEnd();
}



1;
