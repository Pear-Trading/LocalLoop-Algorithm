package Pear::LocalLoop::Algorithm::Role::IStaticRestriction;

use Moo::Role;

#This removes transactions from the "ProcessedTransactions" table before processing begins.
#They are removed as the context which these restrictions are applied in is static (no-context)
#hence in all calculations they will be discounted, so they may as well be removed.
sub applyStaticRestriction {
  die "applyStaticRestriction has not been implemented.";
};

1;
