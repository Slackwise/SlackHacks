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
    read_toc_version has_changelog_section update_changelog open_in_vscode);

# ==============================================================================
# bump.pl
#
# 1. Bumps the addon version by 1 in SlackHacks.toc
# 2. If CHANGELOG.md has no "## v<NEW_VERSION>" section, asks whether to
#    generate it (default yes) and whether to use GitHub Copilot CLI (yes/no).
#    Without Copilot, entries are built from commit subjects since the
#    previous version tag. Use changelog.pl to extend the changelog later.
# ==============================================================================

my $script_dir = $FindBin::Bin;
my $repo_root  = abs_path(File::Spec->catdir($script_dir, ".."));
chdir($repo_root) or die "Cannot change directory to $repo_root: $!\n";
load_config($repo_root, $script_dir);

my ($dry_run, $blank, $force, $no_open, $help) = (0, 0, 0, 0, 0);
my ($changelog, $copilot);

GetOptions(
    'dry-run|n'  => \$dry_run,
    'blank|b'    => \$blank,
    'changelog!' => \$changelog,
    'copilot!'   => \$copilot,
    'force|f'    => \$force,
    'no-open'    => \$no_open,
    'help|h'     => \$help,
) or die "Usage: $0 [--dry-run] [--blank] [--[no-]changelog] [--[no-]copilot] [--force] [--no-open]\n";

if ($help) {
    print <<"HELP";
Usage: perl bump.pl [OPTIONS]

Options:
  -b, --blank         Add an empty "## v<VERSION>" changelog section to fill in manually
  -n, --dry-run       Show what would be done without modifying files
      --changelog     Generate the changelog section without asking
      --no-changelog  Skip changelog generation without asking
      --copilot       Use Copilot CLI for the changelog without asking
      --no-copilot    Build the changelog from git log without asking
  -f, --force         Replace the version's changelog section if it already exists
      --no-open       Do not open the changelog file in VS Code after generating
  -h, --help          Show this help message

Without --[no-]changelog or --[no-]copilot, you are prompted for each choice.
HELP
    exit 0;
}

my $addon_name     = require_config("ADDON_NAME");
my $toc_file       = require_config("TOC_FILE");
my $changelog_file = require_config("CHANGELOG_FILE");
my $tag_prefix     = require_config("TAG_PREFIX");
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

my $old_version = read_toc_version($toc_file);
my $new_version = $old_version + 1;
my $section = "'## $tag_prefix$new_version' in '$changelog_file'";
print "Current Version: $old_version\n";
print "Target Version:  $new_version\n";

# Ask every question before modifying files so an aborted prompt leaves the TOC untouched.
my $exists = has_changelog_section($changelog_file, "$tag_prefix$new_version");
my ($generate, $use_copilot) = (0, 0);
if ($exists && !$force) {
    print "Changelog section $section already exists. Skipping changelog generation.\n";
} elsif ($blank) {
    $generate = 1;
} else {
    $generate = $changelog // ask_yes_no("Generate changelog section $section?", 1);
    $use_copilot = $copilot // ask_yes_no("Use Copilot to generate the changelog?", undef)
        if $generate;
}

bump_toc_version($toc_file, $dry_run);

if ($generate) {
    print "Changelog section $section already exists, but --force was specified. Replacing it.\n"
        if $exists;
    update_changelog(
        addon       => $addon_name,
        version     => $new_version,
        file        => $changelog_file,
        prefix      => $tag_prefix,
        use_copilot => $use_copilot,
        blank       => $blank,
        overwrite   => $force,
        dry_run     => $dry_run,
        no_open     => $no_open,
    );
} elsif ($exists) {
    open_in_vscode($changelog_file) unless $dry_run || $no_open;
} else {
    print "Skipped changelog generation. Run 'perl scripts/changelog.pl' to create it later.\n";
}

print "\nVersion bump complete! $addon_name is now v$new_version.\n";
