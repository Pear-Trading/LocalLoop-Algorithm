package Pear::LocalLoop::Algorithm::Role::IDynamicRestriction;

use Moo::Role;

#Similar to "IStaticRestriction" but the restriction is dependent on the transaction
#context it's working with.
#1st param $self.
#2nd param whether this is the first dynamic restriction called, hence must overwrite 
#any previous state in the "Included" column of the "ProcessedTransactions" table.
sub applyDynamicRestriction
{
  die "applyDynamicRestriction has not been implemented.";
};

1;
