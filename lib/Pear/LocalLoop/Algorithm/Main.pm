package Pear::LocalLoop::Algorithm::Main;

use Moo;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;
use v5.10;

#FIXME move into a config file and dynamically read it in.
my $dbConfig = {
  dsn => "dbi:SQLite:dbname=transactions.db",
  user => undef,
  pass => undef,
};

my $dbTestConfig = {
  dsn => "dbi:SQLite:dbname=transactions-test.db",
  user => undef,
  pass => undef,
};


#  return DBI->connect($dbConfig->{dsn},$dbConfig->{user},$dbConfig->{pass}) or die "Could not connect";
sub _dbi {
  my $self = shift;
  return DBI->connect($dbConfig->{dsn},$dbConfig->{user},$dbConfig->{pass});
};

sub _dbi_test {
  my $self = shift;
  return DBI->connect($dbTestConfig->{dsn},$dbTestConfig->{user},$dbTestConfig->{pass});
};


has dbh => (
  is => 'ro',
  default => sub { return dbi(); },
  lazy => 1,
);

sub setTestingMode {
  $ENV{'MODE'} = "testing";
}

sub clearTestingMode {
  $ENV{'MODE'} = undef;
}

sub dbi {
  my $mode = $ENV{'MODE'};
  if (defined $mode && $mode eq "testing") {
    return _dbi_test();
  }
  else {
    return _dbi();
  }
}

sub process {
  #say 'Path-Enter process:' . __FILE__ . ', line: ' . __LINE__;
  
  my ($self, $settings) = @_;
  
  #TODO add more checks for settings.
  if (! defined $settings) {
    die "Settings are undefined";
  }
  
  say (Dumper($settings));
  
  my $dbh = $self->dbh or die "Database does not exist";  
  

  $self->_initialSetup($settings);  

  $self->_applyStaticRestrictions($settings);
  
  $self->_initialSetupPostApplyStaticRestrictions($settings);
  
  my $transactionOrder = $settings->transactionOrder;

  
  for (my $nextTransactionId = $transactionOrder->nextTransactionId; 
    defined $nextTransactionId; 
    $nextTransactionId = $transactionOrder->nextTransactionId)
  {
    say "$nextTransactionId";
    
    #Apply dynamic restrictions
    #TODO PARAMS
    foreach my $dynamicRestriction (@{$settings->dynamicRestrictionsArray}) {
      $dynamicRestriction->applyDynamicRestriction();
    }    

  }
  
  #say 'Path-Exit process:' . __FILE__ . ', line: ' . __LINE__;
}

#This is executed once per analysis.
sub _initialSetup {
  #say 'Path-Enter _initialSetup:' . __FILE__ . ', line: ' . __LINE__;
  
  my ($self, $settings) = @_;
  my $dbh = $self->dbh;
  
  $dbh->do("DELETE FROM ProcessedTransactions");
  $dbh->do("INSERT INTO ProcessedTransactions (TransactionId, FromUserId, ToUserId, Value) SELECT * FROM OriginalTransactions"); 
  
  foreach my $staticRestriction (@{$settings->staticRestrictionsArray}) {
    $staticRestriction->init();
  }
  
  $settings->transactionOrder->init();
  
  foreach my $dynamicRestriction (@{$settings->dynamicRestrictionsArray}) {
    $dynamicRestriction->init();
  }
  
  foreach my $heuristic (@{$settings->heuristicArray}) {
    $heuristic->init();
  }
  
  #say 'Path-Exit _initialSetup:' . __FILE__ . ', line: ' . __LINE__;
}

sub _applyStaticRestrictions {
  #say 'Path-Enter _applyStaticRestrictions:' . __FILE__ . ', line: ' . __LINE__;
  
  #This assumes settings is present and is valid.
  my ($self, $settings) = @_;
  
  my $staticRestrictions = $settings->staticRestrictionsArray;
  
  say Dumper($staticRestrictions);
  
  foreach my $staticRestriction (@{$staticRestrictions}) {
    $staticRestriction->applyStaticRestriction();
  }

  #say 'Path-Exit _applyStaticRestrictions:' . __FILE__ . ', line: ' . __LINE__;
}

sub _initialSetupPostApplyStaticRestrictions {
  my ($self, $settings) = @_;
  
  $settings->transactionOrder->initAfterStaticRestrictions();
  
  foreach my $dynamicRestriction (@{$settings->dynamicRestrictionsArray}) {
    $dynamicRestriction->initAfterStaticRestrictions();
  }
  
  foreach my $heuristic (@{$settings->heuristicArray}) {
    $heuristic->initAfterStaticRestrictions();
  }
}

sub _applyDynamicRestrictions {

}

sub _applyHeuristics {

}

sub _selectBestLoops {

}










1;
