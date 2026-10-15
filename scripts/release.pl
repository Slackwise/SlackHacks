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
# Merges the current working branch (e.g. 'dev') into 'prod', tags the release,
# and deploys it.
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
my $push          = (!defined $ENV{RELEASE_PUSH} || $ENV{RELEASE_PUSH} !~ /^(0|false|no)$/i) ? 1 : 0;
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
    'push!'       => \$push,
    'force|f'     => \$force,
    'source=s'    => \$source_branch,
    'target=s'    => \$target_branch,
    'help|h'      => \$help,
) or die "Usage: $0 [--dry-run] [--no-push] [--force] [--source <branch>] [--target <branch>]\n";

if ($help) {
    print <<"HELP";
Usage: perl release.pl [OPTIONS]

Merges the working branch into the configured target branch and applies a version tag.

Options:
  -n, --dry-run        Show commands that would be executed without running them
      --push           Push branches and new tag to origin after merge (default: true)
      --no-push        Skip pushing to origin
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
    die "Error: Current branch is already '$target_branch'. Please run this from your development branch (e.g. 'dev').\n";
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
my $changelog_dir = require_config("CHANGELOG_DIR");
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

sub read_toc_version {
    my ($toc_file) = @_;
    open my $fh, "<:encoding(UTF-8)", $toc_file or die "Cannot open $toc_file: $!\n";
    my $version;
    while (my $line = <$fh>) {
        if ($line =~ /^\s*##\s*Version:\s*(.+)$/i) {
            $version = $1;
            $version =~ s/^\s+|\s+$//g;
            $version =~ s/^v//i;
            last;
        }
    }
    close $fh;
    die "Error: Could not extract version from $toc_file\n"
        unless defined $version && length($version);
    return $version;
}

sub latest_tagged_version {
    my ($tag_prefix) = @_;
    my @tags = `git tag --list 2>/dev/null`;
    die "Error: Could not list git tags.\n" if $? != 0;
    my $latest;
    for my $tag (@tags) {
        chomp $tag;
        if ($tag =~ /^\Q$tag_prefix\E(\d+)$/ && (!defined $latest || $1 > $latest)) {
            $latest = int($1);
        }
    }
    return $latest;
}

sub release_requirements_met {
    my ($version, $latest, $tag_prefix, $changelog_dir) = @_;
    my @problems;
    if ($version !~ /^\d+$/) {
        push @problems, "TOC version '$version' is not a numeric release version.";
    } elsif (defined $latest && $version <= $latest) {
        push @problems, "TOC version $version has not been bumped past the latest tagged version $latest.";
    }

    my $changelog_file = File::Spec->catfile(
        $changelog_dir, "changelog-$tag_prefix$version.md"
    );
    if (!-f $changelog_file || !-s $changelog_file) {
        push @problems, "A non-empty changelog is required at '$changelog_file'.";
    }
    return @problems;
}

my $version = read_toc_version($toc_file);
my $latest_tagged_version = latest_tagged_version($tag_prefix);
my @requirement_problems = release_requirements_met(
    $version, $latest_tagged_version, $tag_prefix, $changelog_dir
);

if (@requirement_problems) {
    die "Error: Cannot release in the current state:\n  - " .
        join("\n  - ", @requirement_problems) . "\n"
        if $dry_run;

    print "Release prerequisites are not met:\n";
    print "  - $_\n" for @requirement_problems;
    print "Run bump.pl now? [y/N]: ";
    my $answer = <STDIN>;
    die "Error: No response received; release aborted.\n" unless defined $answer;
    $answer =~ s/^\s+|\s+$//g;
    die "Release aborted. Update the version and changelog, then retry.\n"
        unless $answer =~ /^(?:y|yes)$/i;

    print "Choose bump mode [copilot/blank]: ";
    my $bump_mode = <STDIN>;
    die "Error: No bump mode received; release aborted.\n" unless defined $bump_mode;
    $bump_mode =~ s/^\s+|\s+$//g;
    die "Error: Bump mode must be 'copilot' or 'blank'.\n"
        unless $bump_mode =~ /^(?:copilot|blank)$/i;

    my $bump_script = File::Spec->catfile($script_dir, "bump.pl");
    my @bump_cmd = ($^X, $bump_script);
    push @bump_cmd, "--blank" if lc($bump_mode) eq "blank";
    print "Running bump.pl in $bump_mode mode...\n";
    my $bump_status = system(@bump_cmd);
    die "Error: bump.pl failed with exit code " . ($bump_status >> 8) . "\n"
        if $bump_status != 0;

    die "Bump completed. Review and commit the updated TOC and changelog, then rerun release.pl.\n";
}

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

# If the merge will fast-forward or do nothing, reject a commit that already
# carries a release tag instead of creating another version tag on it.
my $source_commit = `git rev-parse --verify "$source_branch^{commit}" 2>/dev/null`;
die "Error: Could not resolve source branch '$source_branch'.\n" if $? != 0;
$source_commit =~ s/^\s+|\s+$//g;
my $target_commit = `git rev-parse --verify "$target_branch^{commit}" 2>/dev/null`;
die "Error: Could not resolve target branch '$target_branch'.\n" if $? != 0;
$target_commit =~ s/^\s+|\s+$//g;
my $merge_base = `git merge-base "$target_commit" "$source_commit" 2>/dev/null`;
die "Error: Could not determine the merge base of '$source_branch' and '$target_branch'.\n"
    if $? != 0;
$merge_base =~ s/^\s+|\s+$//g;
my $prospective_commit =
    ($merge_base eq $target_commit) ? $source_commit
    : ($merge_base eq $source_commit) ? $target_commit
    : undef;
if (defined $prospective_commit) {
    my @tags_on_commit = `git tag --points-at "$prospective_commit" 2>/dev/null`;
    die "Error: Could not inspect tags on the prospective release commit.\n" if $? != 0;
    chomp @tags_on_commit;
    if (@tags_on_commit) {
        die "Error: Invalid release state: prospective commit $prospective_commit is already tagged (" .
            join(", ", @tags_on_commit) . "). No additional release tag will be created.\n";
    }
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
my $release_error;
eval {
    print "\nSwitching to branch '$target_branch'...\n";
    run_cmd("git", "checkout", $target_branch);

    print "Merging '$source_branch' into '$target_branch'...\n";
    run_cmd(
        "git", "merge", $source_branch,
        "-m", "Release v$version",
        "-m", "Merge branch '$source_branch' into $target_branch"
    );

    print "Creating tag '$tag_name'...\n";
    my @tag_cmd = ("git", "tag", "-a", $tag_name, "-m", "Release $tag_name");
    push @tag_cmd, "-f" if $force;
    run_cmd(@tag_cmd);

    if ($push) {
        print "Pushing '$source_branch', '$target_branch', and tag '$tag_name' to origin...\n";
        run_cmd("git", "push", "origin", $source_branch);
        run_cmd("git", "push", "origin", $target_branch, $tag_name);
    }
    1;
} or $release_error = $@ || "Error: Release operation failed.\n";

# Always return to the branch from which release.pl was invoked before deploying.
if ($dry_run) {
    print "Would return to original branch '$current_branch'.\n";
} else {
    print "Returning to original branch '$current_branch'...\n";
    my $checkout_status = system("git", "checkout", $current_branch);
    if ($checkout_status != 0) {
        my $checkout_error =
            "Error: Could not return to original branch '$current_branch' (exit code " .
            ($checkout_status >> 8) . ").\n";
        die defined $release_error ? "$release_error$checkout_error" : $checkout_error;
    }
}

die $release_error if defined $release_error;

print "\nRelease complete! Successfully merged '$source_branch' into '$target_branch' and tagged '$tag_name'.\n";
if ($push) {
    print "Pushed '$source_branch', '$target_branch', and '$tag_name' to origin successfully.\n";
} else {
    print "Tip: Run 'git push origin $source_branch && git push origin $target_branch $tag_name' when you're ready to publish upstream.\n";
}

if ($dry_run) {
    print "[Dry Run] Skipping deployment.\n";
    exit 0;
}

my $deploy_script = File::Spec->catfile($script_dir, "deploy.sh");
die "Error: Deployment script '$deploy_script' not found.\n" unless -f $deploy_script;
print "\nRunning deployment script...\n";
my $deploy_status = system("bash", $deploy_script);
die "Error: deploy.sh failed with exit code " . ($deploy_status >> 8) . "\n"
    if $deploy_status != 0;
