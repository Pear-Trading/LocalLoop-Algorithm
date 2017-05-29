package Pear::LocalLoop::Algorithm::LoopGenerationContext;

use Moo;
use Pear::LocalLoop::Algorithm::Debug;
use Scalar::Util qw(looks_like_number);
use v5.10;
use Data::Dumper;


has userIdWhichCreatesALoop => (
  required => 1,
  is => 'ro',
  isa => sub { checkIsNumberAndNotUndef($_[0]); },
);

sub checkIsNumberAndNotUndef {
  my ($num) = @_;
  
  if ( ! defined $num ) {
      die "it's undefined";
  }
  elsif ( ! looks_like_number($num) ) {
    die "it does not look like a number";
  }
}

1;
