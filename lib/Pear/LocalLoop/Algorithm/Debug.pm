package Pear::LocalLoop::Algorithm::Debug;

use v5.10;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&setDebugMode &clearDebugMode &isDebug &debugMethodStart &debugMethodEnd &debugMethodMiddle &debugError);

sub setDebugMode {
  $ENV{'DEBUG'} = "true";
}

sub clearDebugMode {
  $ENV{'DEBUG'} = undef;
}

sub isDebug {
  my $mode = $ENV{'DEBUG'};
  if (defined $mode && $mode eq "true") {
    return 1;
  }
  else {
    return 0;
  }
}

sub _removeStartOfPackageName {
  my ($package) = @_;
  
  #Use tilde to indicate the default root. It reduces the amount of text on screen, so makes it quicker to 
  #find out what's going on.
  $package =~ s/^Pear::LocalLoop::Algorithm::/~::/;
  
  return $package;
}

sub _line {
  my ($package, $method, $line) = @_;
  
  return "Pack:'" . $package . "'\tMeth:'" . $method . "'\tLine:" . $line; 
}

sub debugMethodStart {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    $package = _removeStartOfPackageName($package);
    say "Path-Method-Start: " . _line($package, $method, $line);
  }

}

sub debugMethodEnd {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    $package = _removeStartOfPackageName($package);
    say "Path-Method-End:   " . _line($package, $method, $line);
  }
}

sub debugMethodMiddle {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    $package = _removeStartOfPackageName($package);
    say "Path-Method:       " . _line($package, $method, $line);
  }
}

sub debugError {
  my ($package, $method, $line) = @_;
  
  $package = _removeStartOfPackageName($package);
  
  say "Path-Error: " . _line($package, $method, $line);
}

1;
