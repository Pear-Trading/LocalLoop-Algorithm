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

sub debugMethodStart {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    say "Path-Method-Start: Pack:" . $package . " Meth:" . $method . " Line:" . $line; 
  }

}

sub debugMethodEnd {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    say "Path-Method-End: Pack:" . $package . " Meth:" . $method . " Line:" . $line; 
  }
}

sub debugMethodMiddle {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    say "Path-Method: Pack:" . $package . " Meth:" . $method . " Line:" . $line; 
  }
}

sub debugError {
  my ($package, $method, $line) = @_;
  
  say "Path-Error: Pack:" . $package . " Meth:" . $method . " Line:" . $line; 
}

1;
