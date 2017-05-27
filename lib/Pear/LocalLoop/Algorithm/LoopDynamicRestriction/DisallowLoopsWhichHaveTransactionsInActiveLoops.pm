package Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends 'Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::Role::ILoopDynamicRestriction');

#Prevent the selection of any loops that have been selected previously.

sub applyLoopDynamicRestriction {
  debugMethodStart();

  my ($self, $isFirstRestriction) = @_;
  my $dbh = $self->dbh();
  
  if ( ! defined $isFirstRestriction ) {
    die "isFirstRestriction cannot be undefined";
  }
  
  #Select Tranaction ids from all active loops.
  # SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo  WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0
  # SELECT DISTINCT Loops.LoopId_FK FROM Loops WHERE Loops.TransactionId_FK IN (SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo  WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0)
  
  my $statement = $dbh->prepare("UPDATE LoopInfo SET Included = 0 WHERE Included != 0 AND LoopInfo.LoopId IN (SELECT DISTINCT Loops.LoopId_FK FROM Loops WHERE Loops.TransactionId_FK IN (SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0))");
  $statement->execute();
  
  if ($isFirstRestriction){
    my $statement = $dbh->prepare("UPDATE LoopInfo SET Included = 1 WHERE Included = 0 AND LoopInfo.LoopId NOT IN (SELECT DISTINCT Loops.LoopId_FK FROM Loops WHERE Loops.TransactionId_FK IN (SELECT DISTINCT Loops.TransactionId_FK FROM Loops, LoopInfo WHERE Loops.LoopId_FK = LoopInfo.LoopId AND LoopInfo.Active != 0))");
    $statement->execute();
  }
  
  debugMethodEnd();
}

1;
