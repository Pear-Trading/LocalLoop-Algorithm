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
    return _dbi();
  }
  else {
    return _dbi_test();
  }
}

sub process {
  my ($self, $settings) = @_;
  
  #TODO add more checks for settings.
  if (! defined $settings) {
    die "Settings are undefined";
  }
  
  say (Dumper($settings));
  
  my $dbh = $self->dbh or die "Database does not exist";  
  

  $self->_initialSetup($settings);  

  $self->_applyStaticRestrictions($settings);

}

#This is executed once per analysis.
sub _initialSetup {
  my ($self, $settings) = @_;
  my $dbh = $self->dbh;
  
  $dbh->do("DELETE FROM ProcessedTransactions");
  $dbh->do("INSERT INTO ProcessedTransactions (TransactionId , FromUserId, ToUserId, Value) SELECT * FROM OriginalTransactions"); 
  
  foreach my $staticRestriction (@{$settings->staticRestrictionsArray}) {
    $staticRestriction->init();
  }
  
  foreach my $dynamicRestriction (@{$settings->dynamicRestrictionsArray}) {
    $dynamicRestriction->init();
  }
  
  foreach my $heuristic (@{$settings->heuristicArray}) {
    $heuristic->init();
  }
  
}

sub _applyStaticRestrictions {
  #This assumes settings is present and is valid.
  my ($self, $settings) = @_;
  
  my $staticRestrictions = $settings->staticRestrictionsArray;
  
  say Dumper($staticRestrictions);
  
  foreach my $staticRestriction (@{$staticRestrictions}) {
    $staticRestriction->applyStaticRestriction();
  }


}

sub _applyDynamicRestrictions {

}

sub _applyHeuristics {

}

sub _selectBestLoops {

}










1;
