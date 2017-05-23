package Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::IDynamicRestriction');

#If it is the first restriction then set included in all of the transactions 
#before itself and itself to 0, any after itself set to 1.
#If it's not the first restriction then set included in all of the transactions 
#before itself and itself to 0.

sub applyDynamicRestriction {
  debugMethodStart();

  my ($self, $transactionId, $chainId, $isFirstRestriction) = @_;
  my $dbh = $self->dbh();
  
  #We don't care if chainId is undefined as we don't use it.
  if ( ! defined $transactionId ) {
    die "transactionId cannot be undefined";
  }
  elsif ( ! defined $isFirstRestriction ) {
    die "isFirstRestriction cannot be undefined";
  }
  
  #FIXME move prepare statements outside this method so it does not waste resources every time.
  my $statement = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 0 WHERE Included != 0 AND TransactionId <= ?");
  $statement->execute($transactionId);
  
  if ($isFirstRestriction){
    my $statement = $dbh->prepare("UPDATE ProcessedTransactions SET Included = 1 WHERE Included = 0 AND ? < TransactionId");
    $statement->execute($transactionId);
  }
  
  debugMethodEnd();
}

1;

