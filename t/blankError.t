use Test::More;
use Test::Exception;
use Test::Fatal;

use Pear::LocalLoop::Algorithm::Main;
use Pear::LocalLoop::Algorithm::ProcessingTypeContainer;

Pear::LocalLoop::Algorithm::Main->setTestingMode();

my $main = Pear::LocalLoop::Algorithm::Main->new();

like(exception { $main->process(); }, qr/Settings are undefined/, 'Settings are undefined exception');

#my $proc = Pear::LocalLoop::Algorithm::ProcessingTypeContainer->new();

#Unsure whether to include this as it's non-deterministic 
#like(exception { $main->process($proc); }, qr/Database does not exist/, 'Database does not exist');

done_testing();
