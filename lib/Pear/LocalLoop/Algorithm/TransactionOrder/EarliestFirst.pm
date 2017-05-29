package Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst;

use Moo;
use v5.10;
use Data::Dumper;
use DBI;
use Pear::LocalLoop::Algorithm::Debug;

extends("Pear::LocalLoop::Algorithm::TransactionOrder::AbstractTransactionOrder");

sub getOrderSqlString {
  return "SELECT ProcessedTransactions.TransactionId FROM ProcessedTransactions ORDER BY ProcessedTransactions.TransactionId ASC";
}

1;
