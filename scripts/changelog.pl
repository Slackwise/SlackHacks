#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib $FindBin::Bin;
use File::Spec;
use Cwd qw(abs_path);
use Getopt::Long qw(GetOptions);
use ChangelogUtil qw(load_config require_config ask_yes_no bump_toc_version
    read_toc_version latest_tagged_version changelog_path update_changelog);

# ==============================================================================
# changelog.pl
#
# Creates or extends changelog/changelog-v<VERSION>.md for the TOC version,
# independently of bump.pl. An existing changelog is appended to with commits
# made since it was last committed (skipping commits it already mentions),
# merged into matching "## " sections. If the TOC version has already been
# tagged, offers to bump it first (default yes).
# ==============================================================================

my $script_dir = $FindBin::Bin;
my $repo_root  = abs_path(File::Spec->catdir($script_dir, ".."));
chdir($repo_root) or die "Cannot change directory to $repo_root: $!\n";
load_config($repo_root, $script_dir);

my ($dry_run, $no_open, $help) = (0, 0, 0);
my ($bump, $copilot);

GetOptions(
    'dry-run|n' => \$dry_run,
    'bump!'     => \$bump,
    'copilot!'  => \$copilot,
    'no-open'   => \$no_open,
    'help|h'    => \$help,
) or die "Usage: $0 [--dry-run] [--[no-]bump] [--[no-]copilot] [--no-open]\n";

if ($help) {
    print <<"HELP";
Usage: perl changelog.pl [OPTIONS]

Creates the changelog for the current TOC version, or appends new commits to it
if it already exists.

Options:
  -n, --dry-run     Preview without modifying files
      --bump        Bump an already-released version without asking
      --no-bump     Keep an already-released version without asking
      --copilot     Use Copilot CLI without asking
      --no-copilot  Build entries from git log without asking
      --no-open     Do not open the changelog file in VS Code
  -h, --help        Show this help message
HELP
    exit 0;
}

my $addon_name    = require_config("ADDON_NAME");
my $toc_file      = require_config("TOC_FILE");
my $changelog_dir = require_config("CHANGELOG_DIR");
my $tag_prefix    = require_config("TAG_PREFIX");
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

my $version = read_toc_version($toc_file);
my $latest  = latest_tagged_version($tag_prefix);
print "TOC Version: $version\n";

my $do_bump = 0;
if (defined $latest && $version <= $latest) {
    print "Version $version has not been bumped past the latest tagged release $tag_prefix$latest.\n";
    $do_bump = $bump // ask_yes_no("Bump the version to " . ($version + 1) . "?", 1);
    print "Keeping version $version.\n" unless $do_bump;
}

my $path = changelog_path($changelog_dir, $tag_prefix, $do_bump ? $version + 1 : $version);
print -f $path ? "Appending to existing changelog '$path'.\n" : "Creating changelog '$path'.\n";
my $use_copilot = $copilot // ask_yes_no("Use Copilot to generate the changelog?", undef);

(undef, $version) = bump_toc_version($toc_file, $dry_run) if $do_bump;

update_changelog(
    addon       => $addon_name,
    version     => $version,
    dir         => $changelog_dir,
    prefix      => $tag_prefix,
    use_copilot => $use_copilot,
    dry_run     => $dry_run,
    no_open     => $no_open,
);
