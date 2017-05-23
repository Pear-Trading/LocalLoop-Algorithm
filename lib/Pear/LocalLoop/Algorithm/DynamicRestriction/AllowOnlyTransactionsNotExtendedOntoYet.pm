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

sub applyDynamicRestriction {
  debugMethodStart(__PACKAGE__, "applyDynamicRestriction", __LINE__);

  #We assume transactionId and chainId are both valid.
  my ($self, $transactionId, $chainId, $isFirstRestriction) = @_;
  my $dbh = $self->dbh();
  
  if ( ! defined $transactionId) {
    die "transactionId cannot be undefined.";
  }
  elsif ( ! defined $chainId) {
    die "chainId cannot be undefined.";
  }
  elsif ( ! defined $isFirstRestriction) {
    die "isFirstRestriction cannot be undefined.";
  }
  
  #say "# tx:$transactionId ch:$chainId 1st:$isFirstRestriction";

  #Select next transaction in the chain, if undefined that means the inputted transaction id is the last in the chain.  
  #FIXME BUG IN SQLite DBI? Does the the aggregate functions require group by. In the "None" heuristic they don't...
  #my $statementNextTransactionInChain = $dbh->prepare("SELECT MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ");
  #my $statementNextTransactionInChain = $dbh->prepare("SELECT ChainStatsId_FK, MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ");
  #my $minTransactionId = @{$dbh->selectrow_arrayref("SELECT ChainStatsId_FK, MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK ", undef, ($chainId, $transactionId))}[0];
  
  my $statementNextTransactionInChain = $dbh->prepare("SELECT MIN(TransactionId_FK) FROM CurrentChains WHERE ChainId = ? AND ? < TransactionId_FK GROUP BY ChainId");
  
  $statementNextTransactionInChain->execute($chainId, $transactionId);
  my ($minTransactionId) = $statementNextTransactionInChain->fetchrow_array();
  
  #Is is at the start or in the middle of a chain.
  if (defined $minTransactionId) {
    my $statementUpdate = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND (TransactionId = ? OR TransactionId IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? ))");
    $statementUpdate->execute($minTransactionId, $chainId, $transactionId);
  
    if ($isFirstRestriction){
      my $statementUpdateFirst = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND (TransactionId != ? AND TransactionId NOT IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? ))");
      $statementUpdateFirst->execute($minTransactionId, $chainId, $transactionId);
    }
  }
  #Is at the end of a chain.
  else {
    my $statementUpdate = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? )");
    $statementUpdate->execute($chainId, $transactionId);
  
    if ($isFirstRestriction){
      my $statementUpdateFirst = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND TransactionId NOT IN (SELECT ToTransactionId_FK FROM BranchedTransactions WHERE ChainId_FK = ? AND FromTransactionId_FK = ? )");
      $statementUpdateFirst->execute($chainId, $transactionId);
    }
  }

  
  debugMethodEnd(__PACKAGE__, "applyDynamicRestriction", __LINE__);
}

1;

