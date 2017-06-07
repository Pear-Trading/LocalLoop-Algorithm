package Pear::LocalLoop::Algorithm::Debug;

use v5.10;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&removeStartOfPackageName &debugBraceStart &debugBraceEnd &setDebugMode &clearDebugMode &isDebug &debugMethodStart &debugMethodEnd &debugMethodMiddle &debugError);

#Static variable to determine the indentation of the debug statements.
my $stackLevel = 0;


sub setDebugMode {
  $ENV{'DEBUG'} = "true";
}

sub clearDebugMode {
  $ENV{'DEBUG'} = undef;
}

#Is debugging mode enabled.
sub isDebug {
  my $mode = $ENV{'DEBUG'};
  return (defined $mode && $mode eq "true");
}

#Removes the start of a package name so prevent wasting space.
sub removeStartOfPackageName {
  my ($package) = @_;
  
  #Use tilde to indicate the default root. It reduces the amount of text on screen, so makes it quicker to 
  #find out what's going on.
  $package =~ s/^Pear::LocalLoop::Algorithm::/~::/;
  
  return $package;
}

#Remove the package name from a method name. i.e. "Pear::LocalLoop::Algorithm::Main::SomeMethod" to "SomeMethod".
sub _removePackageNameMethod {
  my ($functionName) = @_;
  
  my @arr = split('::', $functionName);
  $functionName = @arr[-1];
  
  return $functionName;
}

#Print out the package name, method and line with the callees details 
sub _printPackageMethodLine {
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Pack:'" . $package . "' Meth:'" . $method . "' Line:" . $line; 
}

#Print out the line and comment with the callees details.
sub _printLineComment {
  my ($comment) = @_;
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Line:" . $line . " Comment:" . $comment; 
}

#Print out the package name, method, and comment with the callees details.
sub _printPackageMethodLineComment {
  my ($comment) = @_;
  my ($package, $ignore, $line, $ignore) = caller(1);
  my ($ignore, $ignore, $ignore, $method) = caller(2);
  $package = removeStartOfPackageName($package);
  $method = _removePackageNameMethod($method);
  
  my $stackLevelSpaces = "| "x$stackLevel;
  
  return $stackLevelSpaces .  "Pack:'" . $package . "' Meth:'" . $method . "' Line:" . $line . " Comment:" . $comment; 
}


#Print out the start of method debug statement.
sub debugMethodStart {

  if (isDebug()) {
    say "Path-Method-Start: { " . _printPackageMethodLine();
  }
  
  $stackLevel++;
}

#Print out the end of method debug statement.
sub debugMethodEnd {

  $stackLevel--;
  
  if (isDebug()) {
    say "Path-Method-End:   } " . _printPackageMethodLine();
  }
}

#Print out the start of a code block debug statement.
sub debugBraceStart {
  my ($comment) = @_;
  
  if (isDebug()) {
    say "Path-Brace-Start:  { " . _printPackageMethodLineComment($comment);
  }
  
  $stackLevel++;
}

#Print out the end of a code block debug statement.
sub debugBraceEnd {
  my ($comment) = @_;
  $stackLevel--;
  
  if (isDebug()) {
    say "Path-Brace-End:    } " . _printPackageMethodLineComment($comment);
  }
}

#Print out a general comment with the indentation,
sub debugMethodMiddle {
  my ($comment) = @_;
  
  if (isDebug()) {
    say "Path-Method:         " . _printLineComment($comment);
  }
}

#Print out an error regardless if debug mode is enabled,
sub debugError {
  my ($comment) = @_;
  
  say "Path-Error: " . _printPackageMethodLine($comment);
}

1;
