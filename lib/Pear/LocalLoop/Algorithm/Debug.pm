package Pear::LocalLoop::Algorithm::Debug;

use v5.10;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&removeStartOfPackageName &setDebugMode &clearDebugMode &isDebug &debugMethodStart &debugMethodEnd &debugMethodMiddle &debugError);

my $stackLevel = 0;

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

sub removeStartOfPackageName {
  my ($package) = @_;
  
  #Use tilde to indicate the default root. It reduces the amount of text on screen, so makes it quicker to 
  #find out what's going on.
  $package =~ s/^Pear::LocalLoop::Algorithm::/~::/;
  
  return $package;
}

sub _line {
  my ($package, $method, $line) = @_;
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Pack:'" . $package . "'\tMeth:'" . $method . "'\tLine:" . $line; 
}

sub _line2 {
  my ($line, $comment) = @_;
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Line:" . $line . " Comment:" . $comment; 
}

sub debugMethodStart {
  my ($package, $method, $line) = @_;
  
  if (isDebug()) {
    $package = removeStartOfPackageName($package);
    say "Path-Method-Start: " . _line($package, $method, $line);
  }
  
  $stackLevel++;
}

sub debugMethodEnd {
  my ($package, $method, $line) = @_;
  $stackLevel--;
  
  if (isDebug()) {
    $package = removeStartOfPackageName($package);
    say "Path-Method-End:   " . _line($package, $method, $line);
  }
}

sub debugMethodMiddle {
  my ($line, $comment) = @_;
  
  if (isDebug()) {
    say "Path-Method:       " . _line2($line, $comment);
  }
}

sub debugError {
  my ($package, $method, $line) = @_;
  
  $package = removeStartOfPackageName($package);
  
  say "Path-Error: " . _line($package, $method, $line);
}

1;
