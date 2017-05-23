package Pear::LocalLoop::Algorithm::Heuristic::None;

use Moo;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IHeuristic');


sub applyHeuristic {
  debugMethodStart(__PACKAGE__, "applyHeuristic", __LINE__);
  
  my ($self, $transactionId, $chainId, $isFirst) = @_;
  my $dbh = $self->dbh();
  
  #Chain id is not used so it does not matter if it's undefined.
  if ( ! defined $transactionId) {
    die "transactionId cannot be undefined.";
  }
  elsif ( ! defined $isFirstRestriction) {
    die "isFirstRestriction cannot be undefined.";
  }

  my $nextTransactionId = undef;
  
  if ($isFirst) {
    $nextTransactionId = @{$dbh->selectrow_arrayref("SELECT MIN(TransactionId) FROM ProcessedTransactions WHERE ? < TransactionId", undef, ($transactionId))}[0];
  }
  else {
    $nextTransactionId = @{$dbh->selectrow_arrayref("SELECT MIN(TransactionId) FROM ProcessedTransactions_ViewIncluded WHERE ? < TransactionId", undef, ($transactionId))}[0];    
  }
  
  #say "next: $nextTransactionId";
  
  #There is at least one next transaction id.
  if (defined $nextTransactionId)
  {
    $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId != ?")->execute($nextTransactionId);
    
    if ($isFirst) {
      $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND TransactionId = ?")->execute($nextTransactionId);
    }
  }
  #No next value so set all valued to not be included.
  else {
    $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0")->execute();
  }
  
  debugMethodEnd(__PACKAGE__, "applyHeuristic", __LINE__);
};

1;
