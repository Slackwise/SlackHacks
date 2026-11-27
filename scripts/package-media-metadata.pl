use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Cwd qw(abs_path);
use MediaMetadata qw(library_version read_toc_field update_toc_version package_library);

die "Usage: perl package-media-metadata.pl [DESTINATION]\n" if @ARGV > 1;
my $root = File::Spec->catdir($FindBin::Bin, '..');
my $destination = $ARGV[0] // File::Spec->catdir($root, 'dist', 'SlackHacks_MediaMetadata');
my $library = File::Spec->catdir($root, 'Libs', 'LibRPMedia');
my $upstream_toc = File::Spec->catfile($library, 'LibRPMedia.toc');
my $version = library_version($library);
my $interface = read_toc_field($upstream_toc, 'Interface');
make_path($destination);
my $target = File::Spec->catdir($destination, 'Libs', 'LibRPMedia');
die "Refusing to replace the LibRPMedia source directory.\n"
    if -e $target && abs_path($target) eq abs_path($library);
die "Refusing to replace a linked or non-directory media library: '$target'.\n"
    if -l $target || (-e $target && !-d $target);

# Build alongside the existing copy so failures do not remove the junction target.
my $stage = tempdir('.media-metadata-XXXXXX', DIR => $destination, CLEANUP => 1);
my $staged_library = File::Spec->catdir($stage, 'LibRPMedia');
my $staged_toc = File::Spec->catfile($stage, 'SlackHacks_MediaMetadata.toc');
open my $toc, '>', $staged_toc or die "Cannot stage companion TOC: $!\n";
print {$toc} "## Interface: $interface\n",
    "## Title: SlackHacks: Media Metadata\n",
    "## Notes: Currently only used for enabling icon search by name.\n",
    "## Version: $version\n",
    "## LoadOnDemand: 1\n",
    "## Dependencies: SlackHacks\n\n",
    "Libs\\LibRPMedia\\lib.xml\n" or die "Cannot write companion TOC: $!\n";
close $toc or die "Cannot close companion TOC: $!\n";
package_library($library, $staged_library);
my $packaged_toc = File::Spec->catfile($staged_library, 'LibRPMedia.toc');
update_toc_version($packaged_toc, $version) if -f $packaged_toc;
make_path(File::Spec->catdir($destination, 'Libs'));
my $previous = File::Spec->catdir($stage, 'previous');
my $had_previous = -d $target;
rename($target, $previous) or die "Cannot stage previous media library: $!\n" if $had_previous;
if (!rename($staged_library, $target)) {
    my $error = $!;
    if ($had_previous && !rename($previous, $target)) {
        die "Cannot install media library ($error), and restoring the previous library failed: $!\n";
    }
    die "Cannot install media library: $error\n";
}
copy($staged_toc, File::Spec->catfile($destination, 'SlackHacks_MediaMetadata.toc'))
    or die "Cannot install companion TOC: $!\n";
print "Built media metadata companion in '$destination'.\n";
