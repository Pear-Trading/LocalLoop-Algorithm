#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Try::Tiny;
use v5.10;

use lib "lib";
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::Debug;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction;
use Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet;
use Pear::LocalLoop::Algorithm::Heuristic::None;
use Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst;
use Pear::LocalLoop::Algorithm::TransactionOrder::LargestTransactionValueFirst;

my $debug = 0;

foreach my $arg (@ARGV) {
  if ($arg eq "debug") {
    $debug = 1;
  }
}

if ($debug) {
  Pear::LocalLoop::Algorithm::Debug->setDebugMode();
}

my $main = Pear::LocalLoop::Algorithm::Main->new();

my $rst = Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop->new();
my $staticRestrictions = [$rst];

my $matchId = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();
my $afterCurrent = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction->new();
my $extendedOnto = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();
my $dynamicRestrictions = [$matchId, $extendedOnto, $afterCurrent];

my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $heuristics = [$none];

my $hash = {
  staticRestrictionsArray => $staticRestrictions,
  dynamicRestrictionsArray => $dynamicRestrictions,
  heuristicArray => $heuristics,
  transactionOrder => Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst->new(),
};

my $proc = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new($hash);

#say Dumper($proc);

say $main->process($proc);




