package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IDynamicRestriction');

#Maintain a list of all transactions which this chain and transaction pair have extended onto, prevent it from
#connecting to them again in future. This includes the next transaction in this chain and all branches from 
#this transaction.

#This allows to connect back to yourself. TODO

has _statementSelectNextTransactionInChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("SELECT MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK GROUP BY ChainId");
  },
  lazy => 1,
);

has _statementUpdateStartOrMiddleOfChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND (TransactionId = ? OR TransactionId IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? ))");
  },
  lazy => 1,
);

has _statementUpdateStartOrMiddleOfChainFirst => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND (TransactionId != ? AND TransactionId NOT IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? ))");
  },
  lazy => 1,
);

has _statementUpdateEndOfChain => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? )");
  },
  lazy => 1,
);

has _statementUpdateEndOfChainFirst => (
  is => 'ro', 
  default => sub {
    my ($self) = @_;
    return $self->dbh()->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND TransactionId NOT IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? )");
  },
  lazy => 1,
);


sub applyDynamicRestriction {
  debugMethodStart();

  #We assume transactionId and chainId are both valid.
  my ($self, $isFirst, $chainGenerationContextInstance) = @_;
  my $dbh = $self->dbh();
  
  if ( ! defined $isFirst) {
    die "isFirst cannot be undefined.";
  }
  elsif ( ! defined $chainGenerationContextInstance) {
    die "chainGenerationContextInstance cannot be undefined.";
  }
  
  my $transactionId = $chainGenerationContextInstance->currentTransactionId();
  my $chainId = $chainGenerationContextInstance->currentChainId();
  
  #say "# tx:$transactionId ch:$chainId 1st:$isFirst";

  #Select next transaction in the chain, if undefined that means the inputted transaction id is the last in the chain.  
  #FIXME BUG IN SQLite DBI? Does the the aggregate functions require group by. In the "None" heuristic they don't...
  #my $statementNextTransactionInChain = $dbh->prepare("SELECT MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ");
  #my $statementNextTransactionInChain = $dbh->prepare("SELECT ChainStatsId_FK, MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ");
  #my $minTransactionId = @{$dbh->selectrow_arrayref("SELECT ChainStatsId_FK, MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ", undef, ($chainId, $transactionId))}[0];
  
  my $statementNextTransactionInChain = $self->_statementSelectNextTransactionInChain();
  $statementNextTransactionInChain->execute($chainId, $transactionId);
  my ($minTransactionId) = $statementNextTransactionInChain->fetchrow_array();
  
  #Is is at the start or in the middle of a chain.
  if (defined $minTransactionId) {
    $self->_statementUpdateStartOrMiddleOfChain()->execute($minTransactionId, $chainId, $transactionId);
  
    if ($isFirst){
      $self->_statementUpdateStartOrMiddleOfChainFirst()->execute($minTransactionId, $chainId, $transactionId);
    }
  }
  #Is at the end of a chain.
  else {
    $self->_statementUpdateEndOfChain()->execute($chainId, $transactionId);
  
    if ($isFirst){
      $self->_statementUpdateEndOfChainFirst()->execute($chainId, $transactionId);
    }
  }

  
  debugMethodEnd();
}

1;

