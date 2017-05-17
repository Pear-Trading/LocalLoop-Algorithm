package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IDynamicRestriction');

#When considering the next transaction the current transactions "to user" must be the same as the next "from user".
#So set include to 0 if it differs, otherwise it cannot form a chain.

#If it's the first restriction then set all of the from users to be included.

sub applyDynamicRestriction {
  my ($self, $transactionId, $isFirstRestriction) = @_;
  my $dbh = $self->dbh();
  
  
  my $fromUserId = @{$dbh->selectrow_arrayref("SELECT ToUserId FROM ProcessedTransactions WHERE TransactionId = ?", undef, ($transactionId))}[0];
  
  #Set all after the max transaction id to not be included.
  my $statement = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND FromUserId != ?");
  $statement->execute($fromUserId);
  
  if ($isFirstRestriction) {
    #Set all transactions before or on the max id to be be included
    my $statement = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND FromUserId = ?");
    $statement->execute($fromUserId);
  }
}

1;

