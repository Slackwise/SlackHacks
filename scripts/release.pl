#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib $FindBin::Bin;
use ReleaseUtil qw(git_output);
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

my $dry_run = 0;
my $cleanup_pending = 1;
my $release_merge_started = 0;
$| = 1; # Prompts must remain visible while waiting for input, including through task runners.

# END covers early validation failures, EOF, explicit exits, and exceptions as well as the release phase.
# Never force checkout or discard user changes; abort only a merge started by this invocation.
sub return_to_dev {
    if ($dry_run) {
        print "Would return to branch 'dev'.\n";
        return 1;
    }
    if ($release_merge_started) {
        my $merge_head = git_output('rev-parse', '--git-path', 'MERGE_HEAD');
        if (-f $merge_head && system("git", "merge", "--abort") != 0) {
            warn "Error: Could not abort the release merge before returning to 'dev'.\n";
            return 0;
        }
    }
    print "Returning to branch 'dev'...\n";
    if (system("git", "checkout", "dev") != 0) {
        warn "Error: Could not return to branch 'dev'. Resolve the Git state and run 'git checkout dev'.\n";
        return 0;
    }
    return 1;
}

END {
    if ($cleanup_pending) {
        my $status = $?;
        # A second interrupt must not interrupt the recovery checkout itself.
        local $SIG{INT} = 'IGNORE';
        local $SIG{TERM} = 'IGNORE';
        local $SIG{HUP} = 'IGNORE';
        my $restored = eval { return_to_dev() };
        warn "Error: Branch cleanup failed: $@" if $@;
        $? = $status || ($restored ? 0 : 1);
    }
}

for my $signal (qw(INT TERM HUP)) {
    $SIG{$signal} = sub { die "Error: Release interrupted by SIG$signal.\n" };
}

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
my $push          = (!defined $ENV{RELEASE_PUSH} || $ENV{RELEASE_PUSH} !~ /^(0|false|no)$/i) ? 1 : 0;
my $force         = 0;
my $rerelease     = 0;
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
    'rerelease'   => \$rerelease,
    'source=s'    => \$source_branch,
    'target=s'    => \$target_branch,
    'help|h'      => \$help,
) or die "Usage: $0 [--dry-run] [--no-push] [--rerelease] [--source <branch>] [--target <branch>]\n";

if ($help) {
    print <<"HELP";
Usage: perl release.pl [OPTIONS]

Merges the working branch into the configured target branch and applies a version tag.

Options:
  -n, --dry-run        Show commands that would be executed without running them
      --push           Push branches and new tag to origin after merge (default: true)
      --no-push        Skip pushing to origin
  -f, --force          Deprecated; release tags and dirty worktrees are never overwritten
      --rerelease      Merge new changes, move this version's tag, and replace published
                       GitHub assets. CurseForge gets a new file; remove the old one manually.
      --source <name>  Source branch to merge from (default: current branch)
      --target <name>  Target production branch (default: TARGET_COMMITISH in scripts/defaults.env)
  -h, --help           Show this help message

Returns to dev on completion, errors, EOF, or handled interrupts (except in dry-run mode).

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
my $status_out = git_output('status', '--porcelain');
if (defined $status_out && $status_out =~ /\S/) {
    die "Error: You have uncommitted changes in your working tree.\n" .
        "Please commit or stash your changes before releasing.\n" .
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
my $tag_name = "$tag_prefix$version";
die "Error: Release target must be prod.\n" unless $target_branch eq 'prod';
if ($rerelease) {
    # Exclude only this tag so a locally retagged --no-push release can be resumed.
    git_output('fetch', '--no-tags', 'origin',
        "refs/heads/$target_branch:refs/remotes/origin/$target_branch",
        'refs/tags/*:refs/tags/*', "^refs/tags/$tag_name");
} else {
    git_output('fetch', '--tags', 'origin', "refs/heads/$target_branch:refs/remotes/origin/$target_branch");
}
my $remote_tag_ref = git_output('ls-remote', '--refs', 'origin', "refs/tags/$tag_name");
my ($remote_tag_oid) = split /\s+/, $remote_tag_ref;
$remote_tag_oid //= '';
if ($rerelease && length $remote_tag_oid && !length git_output('tag', '--list', $tag_name)) {
    git_output('fetch', '--no-tags', 'origin', "refs/tags/$tag_name:refs/tags/$tag_name");
}
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
    print "Run bump.pl now? [y/N]: " or die "Error: Could not prompt for bump confirmation.\n";
    my $answer = <STDIN>;
    die "Error: No response received; release aborted.\n" unless defined $answer;
    $answer =~ s/^\s+|\s+$//g;
    die "Release aborted. Update the version and changelog, then retry.\n"
        unless $answer =~ /^(?:y|yes)$/i;

    print "Use Copilot to generate the changelog? [Y/n]: "
        or die "Error: Could not prompt for Copilot selection.\n";
    my $use_copilot = <STDIN>;
    die "Error: No Copilot selection received; release aborted.\n" unless defined $use_copilot;
    $use_copilot =~ s/^\s+|\s+$//g;
    die "Error: Copilot selection must be 'yes' or 'no'.\n"
        unless $use_copilot eq "" || $use_copilot =~ /^(?:y|yes|n|no)$/i;

    my $bump_script = File::Spec->catfile($script_dir, "bump.pl");
    my @bump_cmd = ($^X, $bump_script, "--changelog");
    push @bump_cmd, $use_copilot =~ /^(?:n|no)$/i ? "--no-copilot" : "--copilot";
    print "Running bump.pl " .
        ($use_copilot =~ /^(?:n|no)$/i ? "without" : "with") .
        " Copilot...\n";
    my $bump_status = system(@bump_cmd);
    die "Error: bump.pl failed with exit code " . ($bump_status >> 8) . "\n"
        if $bump_status != 0;

    die "Bump completed. Review and commit the updated TOC and changelog, then rerun release.pl.\n";
}

# ------------------------------------------------------------------------------
# Step 3: Check if Tag Already Exists
# ------------------------------------------------------------------------------
my $existing_tag = `git tag -l "$tag_name" 2>/dev/null`;
$existing_tag =~ s/^\s+|\s+$//g if defined $existing_tag;

my $tag_exists = defined $existing_tag && $existing_tag eq $tag_name;
my $resuming = $tag_exists && !$rerelease;
my $previous_commit = $tag_exists ? git_output('rev-parse', "refs/tags/$tag_name^{commit}") : undef;

# If the merge will fast-forward or do nothing, reject a commit that already
# carries a release tag instead of creating another version tag on it.
my $source_commit = `git rev-parse --verify "$source_branch^{commit}" 2>/dev/null`;
die "Error: Could not resolve source branch '$source_branch'.\n" if $? != 0;
$source_commit =~ s/^\s+|\s+$//g;
my $target_commit = `git rev-parse --verify "$target_branch^{commit}" 2>/dev/null`;
die "Error: Could not resolve target branch '$target_branch'.\n" if $? != 0;
$target_commit =~ s/^\s+|\s+$//g;
if ($resuming) {
    my $tag_commit = git_output('rev-parse', "refs/tags/$tag_name^{commit}");
    my $source_base = git_output('merge-base', $source_commit, $tag_commit);
    die "Error: '$tag_name' already exists, but '$source_branch' contains unreleased changes. Bump the version.\n"
        unless $source_base eq $source_commit;
    my $target_base = git_output('merge-base', $target_commit, $tag_commit);
    die "Error: '$target_branch' has diverged from existing release '$tag_name'.\n"
        unless $target_base eq $target_commit;
    my $remote_commit = git_output('rev-parse', "refs/remotes/origin/$target_branch");
    my $remote_base = git_output('merge-base', $remote_commit, $tag_commit);
    die "Error: origin/$target_branch has advanced beyond or diverged from '$tag_name'.\n"
        unless $remote_base eq $remote_commit;
    print "Resuming existing release '$tag_name'; no merge or new tag will be created.\n";
}
my $merge_base = `git merge-base "$target_commit" "$source_commit" 2>/dev/null`;
die "Error: Could not determine the merge base of '$source_branch' and '$target_branch'.\n"
    if $? != 0;
$merge_base =~ s/^\s+|\s+$//g;
my $prospective_commit =
    ($merge_base eq $target_commit) ? $source_commit
    : ($merge_base eq $source_commit) ? $target_commit
    : undef;
if (!$tag_exists && defined $prospective_commit) {
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
print "WARNING: Explicit re-release may move a published tag and replace GitHub assets.\n" if $rerelease;
print "CurseForge will receive a new file for a revised commit; manage old files manually.\n" if $rerelease;
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
    run_cmd("git", "merge", "--ff-only", "refs/remotes/origin/$target_branch");

    if ($resuming) {
        run_cmd("git", "merge", "--ff-only", "refs/tags/$tag_name");
    } else {
        print "Merging '$source_branch' into '$target_branch'...\n";
        die "Error: A merge is already in progress; resolve it before releasing.\n"
            if !$dry_run && -f git_output('rev-parse', '--git-path', 'MERGE_HEAD');
        $release_merge_started = !$dry_run;
        run_cmd(
            "git", "merge", $source_branch,
            "-m", "Release v$version",
            "-m", "Merge branch '$source_branch' into $target_branch"
        );
        $release_merge_started = 0;

        die "Error: Merged production TOC version differs from planned release $version.\n"
            if !$dry_run && read_toc_version($toc_file) ne $version;
        if ($tag_exists && !$dry_run) {
            my $head = git_output('rev-parse', 'HEAD');
            die "Error: Refusing to move '$tag_name' away from unrelated release history.\n"
                unless git_output('merge-base', $previous_commit, $head) eq $previous_commit;
        }
        if (!$tag_exists || $dry_run || git_output('rev-parse', 'HEAD') ne $previous_commit) {
            print ($tag_exists ? "Moving tag '$tag_name'...\n" : "Creating tag '$tag_name'...\n");
            my @tag_cmd = ("git", "tag", "-a", $tag_name, "-m", "Release $tag_name");
            push @tag_cmd, '-f' if $rerelease && $tag_exists;
            run_cmd(@tag_cmd);
        } else {
            print "Tag '$tag_name' already points to this release; leaving it unchanged.\n";
        }
    }

    if ($push) {
        print "Pushing '$source_branch', '$target_branch', and tag '$tag_name' to origin...\n";
        run_cmd("git", "push", "origin", $source_branch);
        my @lease = $rerelease ? ("--force-with-lease=refs/tags/$tag_name:$remote_tag_oid") : ();
        run_cmd("git", "push", "--atomic", @lease, "origin",
            "refs/heads/$target_branch:refs/heads/$target_branch",
            "refs/tags/$tag_name:refs/tags/$tag_name");
        unless ($dry_run) {
            print "\nDeploying the pushed production release...\n";
            run_cmd("bash", File::Spec->catfile($script_dir, "deploy.sh"),
                $rerelease ? ('--rerelease') : ());
        }
    } else {
        print "Local release only; deployment skipped until branch and tag are pushed.\n";
    }
    1;
} or $release_error = $@ || "Error: Release operation failed.\n";

die $release_error if defined $release_error;

die "Error: Release finished but branch cleanup failed.\n" unless return_to_dev();
$cleanup_pending = 0;

print "\nRelease complete! Successfully merged '$source_branch' into '$target_branch' and tagged '$tag_name'.\n";
if ($push) {
    print "Pushed '$source_branch', '$target_branch', and '$tag_name' to origin successfully.\n";
} elsif ($rerelease) {
    print "Tip: Rerun release.pl --rerelease --push to publish this revised release and deploy.\n";
} else {
    print "Tip: Run 'git push origin $source_branch && git push origin $target_branch $tag_name' when you're ready to publish upstream.\n";
}

if ($dry_run) {
    print "[Dry Run] Skipping deployment.\n";
    exit 0;
}
