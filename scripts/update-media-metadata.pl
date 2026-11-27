use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use File::Spec;
use MediaMetadata qw(library_version);

die "Usage: perl update-media-metadata.pl\n" if @ARGV;
my $root = File::Spec->catdir($FindBin::Bin, '..');
my $library = File::Spec->catdir($root, 'Libs', 'LibRPMedia');
if (!-e File::Spec->catfile($library, '.git')) {
    system('git', '-C', $root, 'submodule', 'update', '--init', '--', 'Libs/LibRPMedia') == 0
        or die "Cannot initialize LibRPMedia submodule.\n";
}
open my $status, '-|', 'git', '-C', $library, 'status', '--porcelain'
    or die "Cannot inspect LibRPMedia submodule: $!\n";
my $changes = do { local $/; <$status> } // '';
close $status or die "Cannot inspect LibRPMedia submodule.\n";
die "LibRPMedia has uncommitted changes; preserve them before updating.\n" if $changes =~ /\S/;
system('git', '-C', $library, 'fetch', '--tags', 'origin') == 0
    or die "Cannot fetch LibRPMedia updates.\n";
system('git', '-C', $library, 'merge', '--ff-only', 'origin/HEAD') == 0
    or die "Cannot fast-forward LibRPMedia to origin/HEAD; resolve its Git state and retry.\n";
my $version = library_version($library);
print "LibRPMedia version: $version\n";
