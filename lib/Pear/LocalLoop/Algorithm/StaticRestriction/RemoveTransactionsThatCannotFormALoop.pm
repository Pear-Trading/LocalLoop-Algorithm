package Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;

use Moo;
use v5.10;
use Data::Dumper;
extends 'Pear::LocalLoop::Algorithm::AbstractDatabaseModifier';
with ('Pear::LocalLoop::Algorithm::IStaticRestriction');


sub applyStaticRestriction{
  my $self = shift;
  my $dbh = $self->dbh;

  my $tableName = "Tmp_StaticRestrictionRemoveTransactions";
  my $tableNameZero = $tableName ."_0";
  
  print "$tableNameZero\n";
  
  $dbh->do("DROP TABLE IF EXISTS $tableNameZero");
  $dbh->do("CREATE TABLE $tableNameZero (ZeroIds INTEGER PRIMARY KEY)");

  my $loop = 1;
  while ($loop != 0) {
    $loop = 0;
 
    #$dbh->do("DELETE FROM $tableNameZero");
    
    $dbh->do("INSERT OR IGNORE INTO $tableNameZero (ZeroIds) SELECT ProcessedTransactions.ToUserId FROM ProcessedTransactions EXCEPT SELECT ProcessedTransactions.FromUserId FROM ProcessedTransactions");
    $dbh->do("INSERT OR IGNORE INTO $tableNameZero (ZeroIds) SELECT ProcessedTransactions.FromUserId FROM ProcessedTransactions EXCEPT SELECT ProcessedTransactions.ToUserId FROM ProcessedTransactions");  
    
    my $del1 = $dbh->do("DELETE FROM ProcessedTransactions WHERE FromUserId IN (SELECT ZeroIds FROM $tableNameZero)"); 
    my $del2 = $dbh->do("DELETE FROM ProcessedTransactions WHERE ToUserId IN (SELECT ZeroIds FROM $tableNameZero)"); 
    
    #If there was more than 1 deleted keep on deleting.
    if (0 < ($del1 + $del2)) {
      $loop = 1;
    }
    #print "looped";
  }


  return;
}

1;