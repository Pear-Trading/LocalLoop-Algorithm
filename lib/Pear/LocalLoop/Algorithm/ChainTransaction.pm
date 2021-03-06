package Pear::LocalLoop::Algorithm::ChainTransaction;

use Moo;
use Scalar::Util qw(looks_like_number);
use v5.10;
use Data::Dumper;
use Pear::LocalLoop::Algorithm::ExtendedTransaction;
use Pear::LocalLoop::Algorithm::Debug;


has transactionId => (
  is => 'ro',
  required => 1,
  isa => sub {
    if ( ! looks_like_number($_[0]) ) {
      die "transactionId does not look like a number";
    }
    elsif ( ! defined $_[0] ) {
      die "transactionId is undefined";
    }
  },
);

has chainId => (
  is => 'ro',
  required => 1,
  isa => sub {
    if ( ! looks_like_number($_[0]) ) {
      die "transactionId does not look like a number";
    }
    elsif ( ! defined $_[0] ) {
      die "transactionId is undefined";
    }
  },
);

has fromTo => (
  is => 'ro',
  required => 1,
  isa => sub {
    if ( ! ($_[0] eq "from" || $_[0] eq "to") ) {
      die "fromTo is neither 'from' or 'to'.";
    }
  },
);


#Compares if two chain transactions are the same.
sub equals {
  my ($self, $compare1, $compare2) = @_;
  
  if ( ! defined $compare1 && ! defined $compare2 ) {
    return 1;
  }
  elsif ( defined $compare1 != defined $compare2 ) {
    return 0;
  }
  elsif (ref($compare1) ne ref($compare2)) {
    return 0;
  }
  elsif (ref($compare1) ne __PACKAGE__) {
    return 0;
  }
  elsif ($compare1->transactionId() != $compare2->transactionId()) {
    return 0;
  }
  elsif ($compare1->chainId() != $compare2->chainId()) {
    return 0;
  }
  elsif ($compare1->fromTo() ne $compare2->fromTo()) {
    return 0;
  }
  else {
    return 1;
  }
}



1;
