package Pear::LocalLoop::Algorithm::Debug;

use v5.10;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&removeStartOfPackageName &debugBraceStart &debugBraceEnd &setDebugMode &clearDebugMode &isDebug &debugMethodStart &debugMethodEnd &debugMethodMiddle &debugError);

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

sub _removePackageNameMethod {
  my ($functionName) = @_;
  
  my @arr = split('::', $functionName);
  $functionName = @arr[-1];
  
  return $functionName;
}

sub _printPackageMethodLine {
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Pack:'" . $package . "' Meth:'" . $method . "' Line:" . $line; 
}

sub _printLineComment {
  my ($comment) = @_;
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Line:" . $line . " Comment:" . $comment; 
}

sub _printPackageMethodLineComment {
  my ($comment) = @_;
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Pack:'" . $package . "' Meth:'" . $method . "' Line:" . $line . " Comment:" . $comment; 
}


sub debugMethodStart {

  if (isDebug()) {
    say "Path-Method-Start: { " . _printPackageMethodLine();
  }
  
  $stackLevel++;
}

sub debugMethodEnd {

  $stackLevel--;
  
  if (isDebug()) {
    say "Path-Method-End:   } " . _printPackageMethodLine();
  }
}

sub debugBraceStart {
  my ($comment) = @_;
  
  if (isDebug()) {
    say "Path-Brace-Start:  { " . _printPackageMethodLineComment($comment);
  }
  
  $stackLevel++;
}

sub debugBraceEnd {
  my ($comment) = @_;
  $stackLevel--;
  
  if (isDebug()) {
    say "Path-Brace-End:    } " . _printPackageMethodLineComment($comment);
  }
}

sub debugMethodMiddle {
  my ($comment) = @_;
  
  if (isDebug()) {
    say "Path-Method:         " . _printLineComment($comment);
  }
}

sub debugError {
  my ($comment) = @_;
  
  say "Path-Error: " . _printPackageMethodLine($comment);
}

1;
