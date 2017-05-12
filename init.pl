#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Try::Tiny;
use v5.10;

use lib "lib";
use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::Exception;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;
use Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop;

my $main = Pear::LocalLoop::Algorithm::Main->new();

my $rst = Pear::LocalLoop::Algorithm::StaticRestriction::RemoveTransactionsThatCannotFormALoop->new();

my $staticRestrictions = [$rst];
my $dynamicRestrictions = [];
my $heuristics = [];

my $proc = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new(staticRestrictionsArray => $staticRestrictions);

#say Dumper($proc);

say $main->process($proc);



