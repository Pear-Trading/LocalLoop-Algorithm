package Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier;

use Moo;
use Pear::LocalLoop::Algorithm::Main;
use v5.10;
use Pear::LocalLoop::Algorithm::Debug;

has dbh => (
  is => 'ro',
  default => sub { return Pear::LocalLoop::Algorithm::Main->dbi(); },
  lazy => 1,
);

#Empty method for subclasses to override if they have any initialisation work
#todo before the algorithm is run.
sub init {
  debugMethodStart(__PACKAGE__, "init", __LINE__);
  
  debugMethodEnd(__PACKAGE__, "init", __LINE__);
}

#This is not perfect as the package name could include an underscore, but it will do for now.
sub uniqueTableName {
  debugMethodStart(__PACKAGE__, "uniqueTableName", __LINE__);
  
  my ($self, $packageName, $moduleTableName) = @_;
  #say "pack:" . $packageName;
  #say "mod:" . $moduleTableName;
  my $str = "\"ZTmp_" . removeStartOfPackageName($packageName) . "_" . $moduleTableName . "\"";

  debugMethodEnd(__PACKAGE__, "uniqueTableName", __LINE__);  
  return $str;
}

1;

