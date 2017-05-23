package Pear::LocalLoop::Algorithm::ChainTransaction;

use Moo;
use Scalar::Util qw(looks_like_number);

extends('Pear::LocalLoop::Algorithm::Role::AbstractDatabaseModifier');


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



1;
