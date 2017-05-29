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
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops;
use Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops;
use Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops;


my $debug = 0;

foreach my $arg (@ARGV) {
  if ($arg eq "debug") {
    $debug = 1;
  }
}

if ($debug) {
  Pear::LocalLoop::Algorithm::Debug->setDebugMode();
}

my $main = Pear::LocalLoop::Algorithm::Main->instance();

#FIXME It should not have this in the final version, but for now use this for state management.
my $dbh = $main->dbi();
$dbh->prepare("DELETE FROM Loops")->execute();  
$dbh->prepare("DELETE FROM LoopInfo")->execute();

my $rst = Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop->new();
my $staticRestrictions = [$rst];

my $matchId = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsWhichFromUserMatchesOurToUser->new();
my $afterCurrent = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyAfterCurrentTransaction->new();
my $extendedOnto = Pear::LocalLoop::Algorithm::DynamicRestriction::AllowOnlyTransactionsNotExtendedOntoYet->new();
my $dynamicRestrictions = [$matchId, $extendedOnto, $afterCurrent];

my $none = Pear::LocalLoop::Algorithm::Heuristic::None->new();
my $findFirstFinish = Pear::LocalLoop::Algorithm::Heuristic::PrioritiseFindingLoops->new();
my $heuristics = [$findFirstFinish, $none];

my $disallowSelectedLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowSelectionOfAlreadySelectedLoops->new();
my $disallowTransactionsInLoops = Pear::LocalLoop::Algorithm::LoopDynamicRestriction::DisallowLoopsWhichHaveTransactionsInActiveLoops->new();
my $loopDynamicRestrictions = [$disallowSelectedLoops, $disallowTransactionsInLoops];

my $hash = {
  staticRestrictionsArray => $staticRestrictions,
  dynamicRestrictionsArray => $dynamicRestrictions,
  heuristicArray => $heuristics,
  loopDynamicRestrictionsArray => $loopDynamicRestrictions,
  transactionOrder => Pear::LocalLoop::Algorithm::TransactionOrder::EarliestFirst->new(),
};

my $proc = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new($hash);

#say Dumper($proc);

say $main->process($proc);




