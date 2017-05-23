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
  debugMethodStart(__PACKAGE__, "init", __LINE__);
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
  
  debugMethodEnd(__PACKAGE__, "init", __LINE__);
}

sub applyStaticRestrictions {
  debugMethodStart(__PACKAGE__, "applyStaticRestrictions", __LINE__);
  my ($self) = @_;
  
  foreach my $staticRestriction (@{$self->staticRestrictionsArray()}) {
    $staticRestriction->applyStaticRestriction();
  }
  
  debugMethodEnd(__PACKAGE__, "applyStaticRestrictions", __LINE__);
}

sub initAfterStaticRestrictions {
  debugMethodStart(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
  my ($self) = @_;

  $self->transactionOrder()->initAfterStaticRestrictions();
  
  foreach my $dynamicRestriction (@{$self->dynamicRestrictionsArray()}) {
    $dynamicRestriction->initAfterStaticRestrictions();
  }
  
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->initAfterStaticRestrictions();
  }
  
  debugMethodEnd(__PACKAGE__, "initAfterStaticRestrictions", __LINE__);
}


sub nextTransactionId {
  debugMethodStart(__PACKAGE__, "nextTransactionId", __LINE__);
  my ($self) = @_;
  
  my $nextId = $self->transactionOrder()->nextTransactionId();
  
  debugMethodEnd(__PACKAGE__, "nextTransactionId", __LINE__);
  return $nextId;
}
  

sub applyDynamicRestrictionsAndHeuristics {
  debugMethodStart(__PACKAGE__, "applyDynamicRestrictionsAndHeuristics", __LINE__);
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
  debugMethodEnd(__PACKAGE__, "applyDynamicRestrictionsAndHeuristics", __LINE__);
}

sub applyHeuristicsCandinates {
  debugMethodStart(__PACKAGE__, "applyHeuristicsCandinates", __LINE__);
  my ($self) = @_;

  my $isFirst = 1;
  foreach my $heuristic (@{$self->heuristicArray()}) {
    $heuristic->applyHeuristicCandinates($isFirst);
    $self->_dumpCandinateTransactionsIncluded();
    $isFirst = 0;
  }    
  
  debugMethodEnd(__PACKAGE__, "applyHeuristicsCandinates", __LINE__);
}

sub _dumpTransactionsIncluded {
  #debugMethodStart(__PACKAGE__, "_dumpTransactionsIncluded", __LINE__);
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
  
  #debugMethodEnd(__PACKAGE__, "_dumpTransactionsIncluded", __LINE__);
}

sub _dumpCandinateTransactionsIncluded {
  #debugMethodStart(__PACKAGE__, "_dumpCandinateTransactionsIncluded", __LINE__);
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
  
  #debugMethodEnd(__PACKAGE__, "_dumpCandinateTransactionsIncluded", __LINE__);
}



1;
