#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use Cwd qw(abs_path);
use Getopt::Long qw(GetOptions);

# ==============================================================================
# bump.pl
#
# 1. Bumps the addon version by 1 in SlackHacks.toc
# 2. Checks if a matching changelog/changelog-v<NEW_VERSION>.md file exists
# 3. If it doesn't, generates one based on git commits since the last tag
#    matching the previous version (using GitHub Copilot CLI if available,
#    or built-in commit parsing as fallback).
# ==============================================================================

my $script_dir = $FindBin::Bin;
my $repo_root  = abs_path(File::Spec->catdir($script_dir, ".."));
chdir($repo_root) or die "Cannot change directory to $repo_root: $!\n";

# Helper to load .env file if present
sub load_dotenv {
    my ($file) = @_;
    return unless -f $file;
    open my $fh, "<:encoding(UTF-8)", $file or return;
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

load_dotenv(File::Spec->catfile($repo_root, ".env"));

# Ensure standard Windows tool paths (PowerShell / System32) are in PATH on Windows
if ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') {
    for my $extra_path ('/c/Windows/System32', '/c/Windows/System32/WindowsPowerShell/v1.0',
                        'C:\\Windows\\System32', 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0') {
        if (-d $extra_path && $ENV{PATH} !~ /\Q$extra_path\E/i) {
            $ENV{PATH} .= ($^O eq 'MSWin32' ? ';' : ':') . $extra_path;
        }
    }
}

# ------------------------------------------------------------------------------
# CLI Options
# ------------------------------------------------------------------------------
my $dry_run    = 0;
my $blank      = 0;
my $no_copilot = 0;
my $force      = 0;
my $no_open    = 0;
my $help       = 0;

GetOptions(
    'dry-run|n'    => \$dry_run,
    'blank|b'      => \$blank,
    'no-copilot'   => \$no_copilot,
    'force|f'      => \$force,
    'no-open'      => \$no_open,
    'help|h'       => \$help,
) or die "Usage: $0 [--dry-run] [--blank] [--no-copilot] [--force] [--no-open]\n";

if ($help) {
    print <<"HELP";
Usage: perl bump.pl [OPTIONS]

Options:
  -b, --blank       Create a blank release changelog with just the version header
  -n, --dry-run     Show what would be done without modifying files
      --no-copilot  Skip Copilot CLI and generate changelog directly from git log
  -f, --force       Overwrite existing changelog file if it already exists
      --no-open     Do not open the changelog file in VS Code after generating
  -h, --help        Show this help message

HELP
    exit 0;
}

# ------------------------------------------------------------------------------
# Step 1: Read and Parse TOC
# ------------------------------------------------------------------------------
my $addon_name    = $ENV{ADDON_NAME}    || "SlackHacks";
my $toc_file      = $ENV{TOC_FILE}      || "$addon_name.toc";
my $changelog_dir = $ENV{CHANGELOG_DIR} || "changelog";
my $tag_prefix    = $ENV{TAG_PREFIX}    // "v";
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

open my $rfh, "<:encoding(UTF-8)", $toc_file or die "Cannot read $toc_file: $!\n";
my @lines = <$rfh>;
close $rfh;

my $found_version_line = 0;
my $old_version_raw;
my $old_version_num;
my $new_version_num;
my $version_line_index;

for my $i (0 .. $#lines) {
    if ($lines[$i] =~ /^(\s*##\s*Version:\s*)([^\r\n]+)([\r\n]*)$/i) {
        my ($prefix, $ver, $ending) = ($1, $2, $3);
        $old_version_raw = $ver;
        $old_version_raw =~ s/^\s+|\s+$//g;

        if ($old_version_raw =~ /(\d+)/) {
            $old_version_num = int($1);
            $new_version_num = $old_version_num + 1;
            $lines[$i] = "${prefix}${new_version_num}${ending}";
            $found_version_line = 1;
            $version_line_index = $i;
            last;
        } else {
            die "Error: Version value '$old_version_raw' does not contain a recognizable number.\n";
        }
    }
}

die "Error: Could not find '## Version:' line in $toc_file\n" unless $found_version_line;

print "Current Version: $old_version_num (raw: $old_version_raw)\n";
print "Target Version:  $new_version_num\n";

# ------------------------------------------------------------------------------
# Step 2: Write Updated SlackHacks.toc
# ------------------------------------------------------------------------------
if ($dry_run) {
    print "[Dry Run] Would update $toc_file: Version -> $new_version_num\n";
} else {
    open my $wfh, ">:encoding(UTF-8)", $toc_file or die "Cannot write to $toc_file: $!\n";
    print $wfh @lines;
    close $wfh;
    print "Updated $toc_file to version $new_version_num.\n";
}

# ------------------------------------------------------------------------------
# Step 3: Check Changelog Directory and File
# ------------------------------------------------------------------------------
if (!-d $changelog_dir && !$dry_run) {
    mkdir $changelog_dir or die "Cannot create directory '$changelog_dir': $!\n";
}

my $changelog_filename = "changelog-$tag_prefix${new_version_num}.md";
my $changelog_path = File::Spec->catfile($changelog_dir, $changelog_filename);

if (-f $changelog_path && !$force) {
    print "Changelog '$changelog_path' already exists. Skipping changelog generation.\n";
    open_in_vscode($changelog_path) unless $dry_run || $no_open;
    exit 0;
}

if (-f $changelog_path && $force) {
    print "Changelog '$changelog_path' already exists, but --force was specified. Overwriting.\n";
}

# ------------------------------------------------------------------------------
# Step 4: Gather Git Commits Since Previous Version Tag
# ------------------------------------------------------------------------------
my $prev_tag = "$tag_prefix$old_version_num";
my $tag_check = `git tag -l "$prev_tag" 2>/dev/null`;
$tag_check =~ s/^\s+|\s+$//g if defined $tag_check;

if (!defined $tag_check || $tag_check eq "") {
    # Try finding the latest tag overall if v<old> wasn't exact
    my $latest_tag = `git describe --tags --abbrev=0 2>/dev/null`;
    if ($? == 0 && defined $latest_tag && $latest_tag =~ /\S/) {
        $latest_tag =~ s/^\s+|\s+$//g;
        print "Tag '$prev_tag' not found. Using most recent tag '$latest_tag' instead.\n";
        $prev_tag = $latest_tag;
    } else {
        warn "Warning: No git tags found. Gathering recent commits from HEAD.\n";
        $prev_tag = "";
    }
}

my $git_range = ($prev_tag ne "") ? "$prev_tag..HEAD" : "-n 20";
print "Collecting git commits using range: $git_range\n";

my @commits_raw = `git log $git_range --no-merges --pretty=format:"%s" 2>/dev/null`;
chomp @commits_raw;

# Filter out empty lines or trivial self-referential changelog bumps
my @commits = ();
for my $c (@commits_raw) {
    $c =~ s/^\s+|\s+$//g;
    next if $c eq "";
    # Skip commits like "changelog-v4" if already committed
    next if $c =~ /^changelog-v\d+/i;
    push @commits, $c;
}

my $commit_count = scalar(@commits);
print "Found $commit_count commit(s) since tag '$prev_tag'.\n";

# ------------------------------------------------------------------------------
# Helpers: Browser Launch & Proton Pass Login
# ------------------------------------------------------------------------------
sub open_url_in_browser {
    my ($url) = @_;
    if ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') {
        if (-x '/usr/bin/start') {
            system('/usr/bin/start', $url);
        } elsif (-x '/c/Windows/explorer.exe') {
            system('/c/Windows/explorer.exe', $url);
        } else {
            system('start', $url);
        }
    } elsif ($^O eq 'darwin') {
        system('open', $url);
    } else {
        system('xdg-open', $url);
    }
}

sub run_pass_cli_login {
    my ($bin) = @_;
    print "\nStarting Proton Pass login...\n";

    open my $pipe, "-|", $bin, "login" or do {
        warn "Failed to execute '$bin login': $!\n";
        return 0;
    };

    my $browser_opened = 0;
    while (my $line = <$pipe>) {
        print $line;
        if (!$browser_opened && $line =~ m{(https://account\.proton\.me\S+)}) {
            my $url = $1;
            print "\n[Opening your browser automatically to complete authentication...]\n";
            open_url_in_browser($url);
            $browser_opened = 1;
        }
    }
    close $pipe;
    return ($? == 0);
}

sub clean_stale_proton_pass_session {
    my $appdata = $ENV{APPDATA} || '';
    if ($appdata ne '') {
        my $stale_file = File::Spec->catfile($appdata, "proton-pass-cli", ".session", "session.json");
        if (-f $stale_file) {
            unlink $stale_file;
        }
    }
}

# ------------------------------------------------------------------------------
# Helper: Fetch Proton Pass secret for GITHUB_TOKEN if needed
# ------------------------------------------------------------------------------
sub get_github_token {
    return $ENV{GITHUB_TOKEN} if ($ENV{GITHUB_TOKEN} && $ENV{GITHUB_TOKEN} =~ /\S/);

    my $pass_cli = $ENV{PROTON_PASS_CLI_BIN}       || "pass-cli";
    my $item     = $ENV{PROTON_PASS_ITEM_GITHUB}   || $ENV{PROTON_PASS_ITEM} || "GitHub: SlackHacksDeploy API Token";
    my $vault    = $ENV{PROTON_PASS_VAULT}         || "Personal";
    my $attr     = $ENV{PROTON_PASS_ATTRIBUTE}     || "Secret";

    my @cmd = ($pass_cli, "item", "view", "--item-title", $item, "--field", $attr);
    push @cmd, "--vault-name", $vault if ($vault ne "");

    my $run_query = sub {
        my $cmd_str = join(" ", map { /\s/ ? qq{"$_"} : $_ } @cmd);
        my $output = `$cmd_str 2>&1`;
        my $status = $? >> 8;
        return ($status, $output);
    };

    my ($status, $output) = $run_query->();

    # Check for stale corrupted session in Windows file lock state
    if ($status != 0 && $output =~ /Session is some but is not logged in|Error deleting base dir/i) {
        clean_stale_proton_pass_session();
        ($status, $output) = $run_query->();
    }

    # If unauthenticated, locked, or no session, trigger pass-cli login (browser window)
    if ($status != 0 && $output =~ /no session|requires an authenticated client|lock|not logged in/i) {
        run_pass_cli_login($pass_cli);
        ($status, $output) = $run_query->();
    }

    if ($status == 0 && defined $output) {
        $output =~ s/^\s+|\s+$//g;
        if ($output =~ /^\Q$attr\E:\s*(.+)$/i) {
            $output = $1;
            $output =~ s/^\s+|\s+$//g;
        }
        return $output if $output ne "";
    }
    return undef;
}

# ------------------------------------------------------------------------------
# Helper: Detect and/or Install GitHub Copilot CLI
# ------------------------------------------------------------------------------
sub find_copilot_cmd {
    # 1. Check PATH
    for my $c ('copilot', 'copilot.cmd', 'copilot.exe', 'copilot.bat') {
        my $which = `which $c 2>/dev/null`;
        if ($? == 0 && defined $which && $which =~ /\S/) {
            chomp $which;
            return $which;
        }
    }

    # 2. Check standard Windows AppData paths
    my $appdata = $ENV{APPDATA} || '';
    if ($appdata ne '') {
        for my $candidate (
            "$appdata/Code/User/globalStorage/github.copilot-chat/copilotCli/copilot.bat",
            "$appdata/Code/User/globalStorage/github.copilot-chat/copilotCli/copilot",
            "$appdata/npm/copilot.cmd",
            "$appdata/npm/copilot"
        ) {
            if (-f $candidate) {
                return $candidate;
            }
        }
    }

    # 3. Check Unix/Linux standard paths
    for my $loc ('/usr/local/bin/copilot', '/usr/bin/copilot') {
        if (-x $loc) {
            return $loc;
        }
    }
    if (defined $ENV{HOME}) {
        for my $user_loc ("$ENV{HOME}/.npm-global/bin/copilot", "$ENV{HOME}/.local/bin/copilot") {
            if (-x $user_loc) {
                return $user_loc;
            }
        }
    }

    return undef;
}

sub install_copilot_cli {
    print "GitHub Copilot CLI was not found. Attempting to install it via package manager...\n";

    # Strategy 1: npm (cross-platform)
    my $npm_cmd;
    for my $n ('npm', 'npm.cmd') {
        my $check = `which $n 2>/dev/null`;
        if ($? == 0 && defined $check && $check =~ /\S/) {
            chomp $check;
            $npm_cmd = $check;
            last;
        }
    }

    if ($npm_cmd) {
        print "Installing \@github/copilot globally using $npm_cmd...\n";
        my $status = system($npm_cmd, "install", "-g", '@github/copilot');
        if ($status == 0) {
            print "Successfully installed \@github/copilot!\n";
            return 1;
        } else {
            warn "Warning: npm install failed with exit code " . ($status >> 8) . ".\n";
        }
    }

    # Strategy 2: winget (Windows)
    if ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') {
        my $winget_cmd;
        for my $w ('winget', 'winget.exe') {
            my $check = `which $w 2>/dev/null`;
            if ($? == 0 && defined $check && $check =~ /\S/) {
                $winget_cmd = $w;
                last;
            }
        }
        if ($winget_cmd) {
            print "Attempting to install GitHub.Copilot via winget...\n";
            my $status = system($winget_cmd, "install", "--id", "GitHub.Copilot", "--accept-source-agreements", "--accept-package-agreements");
            if ($status == 0) {
                print "Successfully installed GitHub.Copilot via winget!\n";
                return 1;
            } else {
                warn "Warning: winget install failed with exit code " . ($status >> 8) . ".\n";
            }
        }
    }

    # Strategy 3: GitHub CLI extension (if gh is present)
    my $gh_cmd = `which gh 2>/dev/null`;
    if ($? == 0 && defined $gh_cmd && $gh_cmd =~ /\S/) {
        chomp $gh_cmd;
        print "Attempting to install gh-copilot extension via gh...\n";
        my $status = system($gh_cmd, "extension", "install", "github/gh-copilot");
        if ($status == 0) {
            print "Successfully installed gh-copilot extension!\n";
            return 1;
        }
    }

    return 0;
}

sub ensure_copilot_ready {
    my $cmd = find_copilot_cmd();
    my $is_working = 0;

    if ($cmd) {
        my $ver_out = `$cmd --version 2>&1`;
        if ($? == 0 && defined $ver_out && $ver_out =~ /copilot/i && $ver_out !~ /cannot find github copilot/i) {
            $is_working = 1;
        }
    }

    if (!$is_working) {
        if (install_copilot_cli()) {
            $cmd = find_copilot_cmd();
            if ($cmd) {
                my $ver_out = `$cmd --version 2>&1`;
                if ($? == 0 && defined $ver_out && $ver_out =~ /copilot/i && $ver_out !~ /cannot find github copilot/i) {
                    $is_working = 1;
                }
            }
        }
    }

    return $is_working ? $cmd : undef;
}

# ------------------------------------------------------------------------------
# Step 5: Generate Changelog Content
# ------------------------------------------------------------------------------
my $changelog_content;

sub generate_changelog_with_copilot {
    my ($ver, @cmt_list) = @_;

    my $copilot_cmd = ensure_copilot_ready();

    if (!$copilot_cmd) {
        warn "Note: GitHub Copilot CLI could not be located or installed.\n";
        return undef;
    }

    # Ensure GITHUB_TOKEN is available if not already authenticated
    if (!defined $ENV{GITHUB_TOKEN} || $ENV{GITHUB_TOKEN} eq "") {
        my $token = get_github_token();
        if ($token && $token =~ /\S/) {
            $ENV{GITHUB_TOKEN} = $token;
        }
    }

    my $commits_str = join("\n", map { "- $_" } @cmt_list);
    my $prompt = <<"PROMPT";
Generate a release changelog in Markdown for SlackHacks version $ver.

Follow this exact style:
The document must start with:
# SlackHacks v$ver

Group the changes by UI area or module (for example: "## Listview Bag", "## Minimap", "## Error Log", "## General", etc.) based on the commit subjects.
Under each section heading, list the changes as bullet points starting with "- ".
Keep bullets concise and user-facing.
Do not wrap your entire response in markdown code block fences (no ```). Output plain markdown directly.

Commits:
$commits_str
PROMPT

    print "Invoking GitHub Copilot CLI to draft changelog...\n";
    my @cmd = ($copilot_cmd, "-s", "-p", $prompt);
    open my $pipe, "-|", @cmd or do {
        warn "Failed to execute copilot CLI: $!\n";
        return undef;
    };
    my $output = do { local $/; <$pipe> };
    close $pipe;

    if (!defined $output || $output !~ /\S/) {
        warn "Copilot CLI produced no output.\n";
        return undef;
    }

    # Clean up any wrapping code fences if returned
    $output =~ s/^```(?:markdown)?\r?\n//i;
    $output =~ s/\r?\n```\s*$//;
    $output =~ s/^\s+|\s+$//g;

    # Verify that the output starts with the proper header
    if ($output !~ /^#\s+SlackHacks\s+v$ver/i) {
        $output = "# SlackHacks v$ver\n\n" . $output;
    }

    return $output;
}

sub generate_changelog_fallback {
    my ($ver, @cmt_list) = @_;

    if (@cmt_list == 0) {
        return "# SlackHacks v$ver\n\n## Changes\n- Maintenance update and bug fixes\n";
    }

    my %sections;
    my @order;

    for my $cmt (@cmt_list) {
        if ($cmt =~ /^([^:]+):\s*(.+)$/) {
            my $section = $1;
            my $desc    = $2;
            $section =~ s/^\s+|\s+$//g;
            $desc    =~ s/^\s+|\s+$//g;

            # Capitalize first letter of description
            $desc = ucfirst($desc);

            if (!exists $sections{$section}) {
                push @order, $section;
                $sections{$section} = [];
            }
            push @{ $sections{$section} }, $desc;
        } else {
            my $section = "Changes";
            if (!exists $sections{$section}) {
                push @order, $section;
                $sections{$section} = [];
            }
            push @{ $sections{$section} }, ucfirst($cmt);
        }
    }

    my $out = "# SlackHacks v$ver\n\n";
    for my $sec (@order) {
        $out .= "## $sec\n";
        for my $item (@{ $sections{$sec} }) {
            $out .= "- $item\n";
        }
        $out .= "\n";
    }
    $out =~ s/\s+$//;
    return $out . "\n";
}

if ($blank) {
    print "Generating blank release changelog with version header...\n";
    $changelog_content = "# SlackHacks v$new_version_num\n\n";
} elsif (!$no_copilot && $commit_count > 0) {
    $changelog_content = eval { generate_changelog_with_copilot($new_version_num, @commits) };
    if ($@ || !defined $changelog_content) {
        warn "Copilot generation skipped or failed. Falling back to git log parser.\n";
        $changelog_content = generate_changelog_fallback($new_version_num, @commits);
    }
} else {
    $changelog_content = generate_changelog_fallback($new_version_num, @commits);
}

# ------------------------------------------------------------------------------
# Step 6: Write Changelog File
# ------------------------------------------------------------------------------
if ($dry_run) {
    print "\n[Dry Run] Preview of '$changelog_path':\n";
    print "----------------------------------------\n";
    print $changelog_content;
    print "----------------------------------------\n";
} else {
    open my $wfh, ">:encoding(UTF-8)", $changelog_path or die "Cannot write to $changelog_path: $!\n";
    print $wfh $changelog_content;
    close $wfh;
    print "\nGenerated changelog: $changelog_path\n";
    print "----------------------------------------\n";
    print $changelog_content;
    print "----------------------------------------\n";
    open_in_vscode($changelog_path) unless $no_open;
}

print "\nVersion bump complete! SlackHacks is now v$new_version_num.\n";

# ------------------------------------------------------------------------------
# Helper: Open file in VS Code
# ------------------------------------------------------------------------------
sub open_in_vscode {
    my ($file) = @_;

    my $code_cmd;
    for my $c ('code', 'code.cmd', 'code.exe') {
        my $which = `which $c 2>/dev/null`;
        if ($? == 0 && defined $which && $which =~ /\S/) {
            chomp $which;
            $code_cmd = $which;
            last;
        }
    }

    if (!$code_cmd) {
        my $localappdata = $ENV{LOCALAPPDATA} || '';
        my $programfiles = $ENV{ProgramFiles} || '';
        for my $candidate (
            "$localappdata/Programs/Microsoft VS Code/bin/code.cmd",
            "$localappdata/Programs/Microsoft VS Code/bin/code",
            "$programfiles/Microsoft VS Code/bin/code.cmd",
            "$programfiles/Microsoft VS Code/bin/code"
        ) {
            if (-f $candidate) {
                $code_cmd = $candidate;
                last;
            }
        }
    }

    if ($code_cmd) {
        print "Opening '$file' in VS Code...\n";
        system($code_cmd, $file);
    } else {
        warn "Note: 'code' CLI was not found. Please review '$file' manually.\n";
    }
}
