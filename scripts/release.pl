#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use Cwd qw(abs_path);
use File::Spec;
use Getopt::Long qw(GetOptions);

# ==============================================================================
# release.pl
#
# Merges the current working branch (e.g. 'main') into 'prod' and creates a git
# tag matching the addon version number (e.g. 'v5').
# ==============================================================================

my $script_dir = $FindBin::Bin;
my $repo_root  = abs_path(File::Spec->catdir($script_dir, ".."));
chdir($repo_root) or die "Cannot change directory to $repo_root: $!\n";

# Helper to load .env file if present
sub load_dotenv {
    my ($file) = @_;
    return unless -f $file;
    open my $fh, "<:encoding(UTF-8)", $file
        or die "Error: Cannot read configuration file $file: $!\n";
    while (my $line = <$fh>) {
        $line =~ s/^\s+|\s+$//g;
        next if $line eq "" || $line =~ /^#/;
        if ($line =~ /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/) {
            my ($key, $val) = ($1, $2);
            $val =~ s/^['"]|['"]$//g;
            $ENV{$key} = $val unless defined $ENV{$key};
        }
    }
    close $fh;
}

my $defaults_file = File::Spec->catfile($script_dir, "defaults.env");
die "Error: Required configuration file scripts/defaults.env is missing.\n" unless -f $defaults_file;
load_dotenv(File::Spec->catfile($repo_root, ".env"));
load_dotenv($defaults_file);

# ------------------------------------------------------------------------------
# Options
# ------------------------------------------------------------------------------
my $dry_run       = 0;
my $push          = 0;
my $force         = 0;
my $source_branch = "";
sub require_config {
    my ($name) = @_;
    die "Error: Required setting $name is missing. Check scripts/defaults.env.\n"
        unless defined $ENV{$name} && length $ENV{$name};
    return $ENV{$name};
}

my $target_branch = require_config("TARGET_COMMITISH");
my $help          = 0;

GetOptions(
    'dry-run|n'   => \$dry_run,
    'push|p'      => \$push,
    'force|f'     => \$force,
    'source=s'    => \$source_branch,
    'target=s'    => \$target_branch,
    'help|h'      => \$help,
) or die "Usage: $0 [--dry-run] [--push] [--force] [--source <branch>] [--target <branch>]\n";

if ($help) {
    print <<"HELP";
Usage: perl release.pl [OPTIONS]

Merges the working branch into the configured target branch and applies a version tag.

Options:
  -n, --dry-run        Show commands that would be executed without running them
  -p, --push           Push target branch and new tag to origin after merge
  -f, --force          Force tag creation if tag already exists
      --source <name>  Source branch to merge from (default: current branch)
      --target <name>  Target production branch (default: TARGET_COMMITISH in scripts/defaults.env)
  -h, --help           Show this help message

HELP
    exit 0;
}

# ------------------------------------------------------------------------------
# Step 1: Detect Current Git Branch & Status
# ------------------------------------------------------------------------------
my $current_branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`;
if ($? != 0 || !defined $current_branch || $current_branch !~ /\S/) {
    die "Error: Not inside a valid git repository.\n";
}
$current_branch =~ s/^\s+|\s+$//g;

if ($source_branch eq "") {
    $source_branch = $current_branch;
}

if ($source_branch eq $target_branch) {
    die "Error: Current branch is already '$target_branch'. Please run this from your development branch (e.g. 'main').\n";
}

# Check for uncommitted changes
my $status_out = `git status --porcelain 2>/dev/null`;
if (defined $status_out && $status_out =~ /\S/ && !$dry_run && !$force) {
    die "Error: You have uncommitted changes in your working tree.\n" .
        "Please commit or stash your changes before releasing, or use --force.\n" .
        $status_out . "\n";
}

# ------------------------------------------------------------------------------
# Step 2: Extract Addon Version from TOC
# ------------------------------------------------------------------------------
my $addon_name = require_config("ADDON_NAME");
my $toc_file   = require_config("TOC_FILE");
my $tag_prefix = require_config("TAG_PREFIX");
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

open my $fh, "<:encoding(UTF-8)", $toc_file or die "Cannot open $toc_file: $!\n";
my $version;
while (my $line = <$fh>) {
    if ($line =~ /^\s*##\s*Version:\s*(.+)$/i) {
        $version = $1;
        $version =~ s/^\s+|\s+$//g;
        $version =~ s/^v//i; # strip leading v if present
        last;
    }
}
close $fh;

die "Error: Could not extract version from $toc_file\n" unless defined $version && length($version);

my $tag_name = "$tag_prefix$version";

# ------------------------------------------------------------------------------
# Step 3: Check if Tag Already Exists
# ------------------------------------------------------------------------------
my $existing_tag = `git tag -l "$tag_name" 2>/dev/null`;
$existing_tag =~ s/^\s+|\s+$//g if defined $existing_tag;

if (defined $existing_tag && $existing_tag eq $tag_name && !$force) {
    die "Error: Tag '$tag_name' already exists.\n" .
        "If you want to overwrite it, use --force, or bump the version first with 'perl bump.pl'.\n";
}

print "=== Release Summary ===\n";
print "Version:       $version\n";
print "Tag Name:      $tag_name\n";
print "Source Branch: $source_branch\n";
print "Target Branch: $target_branch\n";
print "Push to Remote:" . ($push ? " Yes" : " No (local only)") . "\n";
print "=======================\n";

# Helper to execute shell commands
sub run_cmd {
    my (@cmd) = @_;
    my $cmd_str = join(" ", @cmd);
    print "> $cmd_str\n";

    return 0 if $dry_run;

    my $exit_code = system(@cmd);
    if ($exit_code != 0) {
        die "Error: Command failed with exit code " . ($exit_code >> 8) . ": $cmd_str\n";
    }
    return 0;
}

# ------------------------------------------------------------------------------
# Step 4: Checkout Target Branch ('prod')
# ------------------------------------------------------------------------------
print "\nSwitching to branch '$target_branch'...\n";
run_cmd("git", "checkout", $target_branch);

# ------------------------------------------------------------------------------
# Step 5: Merge Source Branch into Target Branch
# ------------------------------------------------------------------------------
my $merge_subject = "Release v$version";
my $merge_body    = "Merge branch '$source_branch' into $target_branch";
print "Merging '$source_branch' into '$target_branch'...\n";
run_cmd("git", "merge", $source_branch, "-m", $merge_subject, "-m", $merge_body);

# ------------------------------------------------------------------------------
# Step 6: Create Release Tag
# ------------------------------------------------------------------------------
print "Creating tag '$tag_name'...\n";
my @tag_cmd = ("git", "tag", "-a", $tag_name, "-m", "Release $tag_name");
push @tag_cmd, "-f" if $force;
run_cmd(@tag_cmd);

# ------------------------------------------------------------------------------
# Step 7: Push if Requested
# ------------------------------------------------------------------------------
if ($push) {
    print "Pushing '$source_branch', '$target_branch', and tag '$tag_name' to origin...\n";
    run_cmd("git", "push", "origin", $source_branch);
    run_cmd("git", "push", "origin", $target_branch, $tag_name);
}

# ------------------------------------------------------------------------------
# Step 8: Return to Original Source Branch
# ------------------------------------------------------------------------------
print "Returning to branch '$source_branch'...\n";
run_cmd("git", "checkout", $source_branch);

print "\nRelease complete! Successfully merged '$source_branch' into '$target_branch' and tagged '$tag_name'.\n";
if (!$push) {
    print "Tip: Run 'git push origin $target_branch $tag_name' when you're ready to publish upstream.\n";
}
