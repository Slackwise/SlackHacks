package ChangelogUtil;
use strict;
use warnings;
use utf8;
use Exporter 'import';
use File::Spec;
use ReleaseUtil qw(read_changelog_file changelog_section find_changelog_section);

# ==============================================================================
# ChangelogUtil.pm
#
# Shared helpers for bump.pl and changelog.pl: configuration loading, TOC
# version handling, git commit collection, Copilot/fallback changelog drafting,
# and maintaining "## v<VERSION>" sections in the combined CHANGELOG.md.
# ==============================================================================

our @EXPORT_OK = qw(
    load_config require_config ask_yes_no
    read_toc_version bump_toc_version latest_tagged_version
    has_changelog_section update_changelog open_in_vscode
);

# Loads KEY=VALUE pairs from a dotenv file without overriding existing variables.
# @param $file Path to the dotenv file; missing files are ignored.
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

# Loads the repository .env and scripts/defaults.env, and extends PATH on Windows.
# @param $repo_root Repository root directory.
# @param $script_dir Directory containing defaults.env.
sub load_config {
    my ($repo_root, $script_dir) = @_;
    my $defaults_file = File::Spec->catfile($script_dir, "defaults.env");
    die "Error: Required configuration file scripts/defaults.env is missing.\n" unless -f $defaults_file;
    load_dotenv(File::Spec->catfile($repo_root, ".env"));
    load_dotenv($defaults_file);

    # Copilot/Proton Pass helpers shell out to Windows tools that Git Bash may not have on PATH.
    if ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') {
        for my $extra_path ('/c/Windows/System32', '/c/Windows/System32/WindowsPowerShell/v1.0',
                            'C:\\Windows\\System32', 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0') {
            if (-d $extra_path && $ENV{PATH} !~ /\Q$extra_path\E/i) {
                $ENV{PATH} .= ($^O eq 'MSWin32' ? ';' : ':') . $extra_path;
            }
        }
    }
}

# Returns a required configuration value or dies when it is missing.
# @param $name Environment variable name.
# @return The configured value.
sub require_config {
    my ($name) = @_;
    die "Error: Required setting $name is missing. Check scripts/defaults.env.\n"
        unless defined $ENV{$name} && length $ENV{$name};
    return $ENV{$name};
}

# Asks a yes/no question on STDIN, re-prompting on invalid input.
# @param $question Prompt text without the [y/n] hint.
# @param $default 1 for yes, 0 for no, or undef to require an explicit answer.
# @return 1 for yes, 0 for no. Dies on end of input.
sub ask_yes_no {
    my ($question, $default) = @_;
    my $hint = !defined $default ? '[y/n]' : $default ? '[Y/n]' : '[y/N]';
    local $| = 1;
    while (1) {
        print "$question $hint: ";
        my $answer = <STDIN>;
        die "\nError: No response received; aborted.\n" unless defined $answer;
        $answer =~ s/^\s+|\s+$//g;
        return $default if $answer eq '' && defined $default;
        return 1 if $answer =~ /^(?:y|yes)$/i;
        return 0 if $answer =~ /^(?:n|no)$/i;
        print "Please answer 'yes' or 'no'.\n";
    }
}

# Runs git and returns its output lines.
# @param @args Git arguments.
# @return ($ok, @lines) where $ok is true when git exited successfully.
sub git_lines {
    my (@args) = @_;
    open my $pipe, '-|', 'git', @args or die "Error: Cannot execute git: $!\n";
    my @lines = <$pipe>;
    close $pipe;
    my $ok = $? == 0;
    s/\r?\n\z// for @lines;
    return ($ok, @lines);
}

# Reads the TOC and locates its version line.
# @param $toc_file Path to the addon TOC.
# @return (\@lines, $line_index, $version_number).
sub read_toc {
    my ($toc_file) = @_;
    open my $fh, "<:encoding(UTF-8)", $toc_file or die "Cannot read $toc_file: $!\n";
    my @lines = <$fh>;
    close $fh;
    for my $i (0 .. $#lines) {
        next unless $lines[$i] =~ /^\s*##\s*Version:\s*([^\r\n]+)/i;
        my $raw = $1;
        $raw =~ s/^\s+|\s+$//g;
        die "Error: Version value '$raw' does not contain a recognizable number.\n"
            unless $raw =~ /(\d+)/;
        return (\@lines, $i, int($1));
    }
    die "Error: Could not find '## Version:' line in $toc_file\n";
}

# Returns the numeric addon version from the TOC.
# @param $toc_file Path to the addon TOC.
# @return Version number.
sub read_toc_version {
    my ($toc_file) = @_;
    my (undef, undef, $version) = read_toc($toc_file);
    return $version;
}

# Increments the TOC version by one.
# @param $toc_file Path to the addon TOC.
# @param $dry_run When true, only reports the change.
# @return ($old_version, $new_version).
sub bump_toc_version {
    my ($toc_file, $dry_run) = @_;
    my ($lines, $index, $old) = read_toc($toc_file);
    my $new = $old + 1;
    $lines->[$index] =~ s/^(\s*##\s*Version:\s*)[^\r\n]+/${1}$new/i;
    if ($dry_run) {
        print "[Dry Run] Would update $toc_file: Version $old -> $new\n";
    } else {
        open my $wfh, ">:encoding(UTF-8)", $toc_file or die "Cannot write to $toc_file: $!\n";
        print $wfh @$lines;
        close $wfh;
        print "Updated $toc_file: Version $old -> $new.\n";
    }
    return ($old, $new);
}

# Finds the highest numeric release tag, optionally below a version.
# @param $tag_prefix Tag prefix such as "v".
# @param $below Optional exclusive upper bound.
# @return Highest tagged version number, or undef when none exists.
sub latest_tagged_version {
    my ($tag_prefix, $below) = @_;
    my ($ok, @tags) = git_lines('tag', '--list');
    die "Error: Could not list git tags.\n" unless $ok;
    my $latest;
    for my $tag (@tags) {
        next unless $tag =~ /^\Q$tag_prefix\E(\d+)$/;
        my $num = int($1);
        next if defined $below && $num >= $below;
        $latest = $num if !defined $latest || $num > $latest;
    }
    return $latest;
}

# Reports whether the combined changelog already has a section for a release.
# @param $file Combined changelog path.
# @param $tag Release tag such as "v17".
# @return True when a "## <tag>" section exists (even if empty).
sub has_changelog_section {
    my ($file, $tag) = @_;
    return defined changelog_section(read_changelog_file($file), $tag);
}

# Runs git with stderr suppressed.
# @param @args Git arguments.
# @return ($ok, $stdout).
sub git_quiet {
    my (@args) = @_;
    open my $err_save, '>&', \*STDERR or die "Error: Cannot save STDERR: $!\n";
    open STDERR, '>', File::Spec->devnull or die "Error: Cannot redirect STDERR: $!\n";
    my $pid = open my $pipe, '-|', 'git', @args;
    open STDERR, '>&', $err_save or die "Error: Cannot restore STDERR: $!\n";
    return (0, '') unless $pid;
    my $out = do { local $/; <$pipe> };
    close $pipe;
    return ($? == 0, $out // '');
}

# Returns a release's changelog section as committed in a revision.
# @param $rev Git revision.
# @param $file Changelog path relative to the repository root.
# @param $tag Release tag.
# @return Section body, or undef when the file or section is absent.
sub committed_section {
    my ($rev, $file, $tag) = @_;
    (my $git_path = $file) =~ s{\\}{/}g;
    my ($ok, $text) = git_quiet('show', "$rev:$git_path");
    return $ok ? changelog_section($text, $tag) : undef;
}

# Chooses the git revision after which commits belong in a version's changelog.
# Appends start after the last commit that changed this version's section,
# because earlier commits were already available when it was last written.
# Commits that only edit other versions' sections in the shared file are ignored.
# @param $version Version being documented.
# @param $tag_prefix Tag prefix such as "v".
# @param $file Combined changelog path.
# @param $append True when extending an existing section.
# @return Base revision, or "" when no base exists.
sub changelog_base {
    my ($version, $tag_prefix, $file, $append) = @_;
    my $prev = latest_tagged_version($tag_prefix, $version);
    my $base = defined $prev ? "$tag_prefix$prev" : '';
    return $base unless $append;
    my $tag = "$tag_prefix$version";
    my ($ok, @revs) = git_lines('log', '--format=%H', length $base ? ("$base..HEAD") : (), '--', $file);
    return $base unless $ok;
    for my $rev (@revs) {
        my $after  = committed_section($rev, $file, $tag);
        my $before = committed_section("$rev^", $file, $tag);
        next if (defined $after ? $after : "\0") eq (defined $before ? $before : "\0");
        return $rev;
    }
    return $base;
}

# Collects non-merge commit subjects after a base revision.
# @param $base Base revision, or "" for the 20 most recent commits.
# @return Commit subjects, oldest-relevant filtering applied.
sub collect_commits {
    my ($base) = @_;
    my @range = length $base ? ("$base..HEAD") : ('-n', '20');
    print "Collecting git commits using range: @range\n";
    my ($ok, @raw) = git_lines('log', @range, '--no-merges', '--pretty=format:%s');
    warn "Warning: git log failed; no commits collected.\n" unless $ok;
    my @commits;
    for my $c (@raw) {
        $c =~ s/^\s+|\s+$//g;
        next if $c eq '';
        # Changelog-only commits ("changelog-v12", "Changelog: ...", "CHANGELOG.md ...")
        # describe the changelog itself, not user-facing changes.
        next if $c =~ /^changelog\b/i;
        push @commits, $c;
    }
    return @commits;
}

# Reports whether a commit's description already appears in a changelog section.
# @param $existing Existing section text.
# @param $commit Commit subject.
# @return True when the description is already present.
sub already_listed {
    my ($existing, $commit) = @_;
    my $desc = $commit =~ /^[^:]+:\s*(.+)$/ ? $1 : $commit;
    $desc =~ s/^\s+|\s+$//g;
    return length $desc && index(lc $existing, lc $desc) >= 0;
}

# Splits section Markdown into "### " area groups, ignoring "#"/"##" headings.
# Lines before the first area heading are grouped under "Changes".
# @param $markdown Section Markdown.
# @return (\@area_order, \%area_lines).
sub parse_areas {
    my ($markdown) = @_;
    my (@order, %items);
    my $current = 'Changes';
    for my $line (split /\r?\n/, $markdown) {
        next if $line =~ /^#{1,2}\s/;
        if ($line =~ /^###\s+(.+?)\s*$/) {
            $current = $1;
            next;
        }
        next unless $line =~ /\S/;
        push @order, $current unless $items{$current};
        push @{ $items{$current} }, $line;
    }
    return (\@order, \%items);
}

# Merges new entries into a release section, appending bullets to matching
# "### " areas and adding new areas at the end.
# @param $body Array ref of existing section body lines.
# @param $addition New Markdown entries.
# @return Merged section body lines.
sub merge_into_section {
    my ($body, $addition) = @_;
    my @lines = @$body;
    pop @lines while @lines && $lines[-1] !~ /\S/;
    my ($order, $areas) = parse_areas($addition);
    for my $heading (@$order) {
        my @items = @{ $areas->{$heading} };
        my ($start) = grep { $lines[$_] =~ /^###\s+\Q$heading\E\s*$/i } 0 .. $#lines;
        if (defined $start) {
            my $end = $start + 1;
            $end++ while $end < @lines && $lines[$end] !~ /^#{1,3}\s/;
            $end-- while $end > $start + 1 && $lines[$end - 1] !~ /\S/;
            splice @lines, $end, 0, @items;
        } else {
            push @lines, '' if @lines;
            push @lines, "### $heading", @items;
        }
    }
    return @lines;
}

# Builds "### " area groups from "Area: description" commit subjects.
# @param @commits Commit subjects.
# @return Markdown area groups without release or file headings.
sub fallback_entries {
    my (@commits) = @_;
    return "### Changes\n- Maintenance update and bug fixes\n" unless @commits;
    my (@order, %areas);
    for my $cmt (@commits) {
        my ($area, $desc) = $cmt =~ /^([^:]+):\s*(.+)$/ ? ($1, $2) : ('Changes', $cmt);
        $area =~ s/^\s+|\s+$//g;
        $desc =~ s/^\s+|\s+$//g;
        push @order, $area unless $areas{$area};
        push @{ $areas{$area} }, ucfirst $desc;
    }
    my $out = '';
    for my $area (@order) {
        $out .= "### $area\n" . join('', map { "- $_\n" } @{ $areas{$area} }) . "\n";
    }
    $out =~ s/\s+$//;
    return "$out\n";
}

# Opens a URL in the default browser.
# @param $url URL to open.
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

# Runs Proton Pass CLI login, opening the authentication URL automatically.
# @param $bin Proton Pass CLI executable.
# @return True when login succeeded.
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
            print "\n[Opening your browser automatically to complete authentication...]\n";
            open_url_in_browser($1);
            $browser_opened = 1;
        }
    }
    close $pipe;
    return ($? == 0);
}

# Removes a stale Proton Pass session file that blocks queries on Windows.
sub clean_stale_proton_pass_session {
    my $appdata = $ENV{APPDATA} || '';
    return if $appdata eq '';
    my $stale_file = File::Spec->catfile($appdata, "proton-pass-cli", ".session", "session.json");
    unlink $stale_file if -f $stale_file;
}

# Returns GITHUB_TOKEN from the environment or Proton Pass.
# @return Token string, or undef when unavailable.
sub get_github_token {
    return $ENV{GITHUB_TOKEN} if ($ENV{GITHUB_TOKEN} && $ENV{GITHUB_TOKEN} =~ /\S/);

    my $pass_cli = require_config("PROTON_PASS_CLI_BIN");
    my $item     = require_config("PROTON_PASS_ITEM_GITHUB");
    my $vault    = require_config("PROTON_PASS_VAULT");
    my $attr     = require_config("PROTON_PASS_ATTRIBUTE");

    my @cmd = ($pass_cli, "item", "view", "--item-title", $item, "--field", $attr);
    push @cmd, "--vault-name", $vault if ($vault ne "");

    my $run_query = sub {
        my $cmd_str = join(" ", map { /\s/ ? qq{"$_"} : $_ } @cmd);
        my $output = `$cmd_str 2>&1`;
        return ($? >> 8, $output);
    };

    my ($status, $output) = $run_query->();
    if ($status != 0 && $output =~ /Session is some but is not logged in|Error deleting base dir/i) {
        clean_stale_proton_pass_session();
        ($status, $output) = $run_query->();
    }
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

# Returns the first command found on PATH.
# @param @names Candidate command names.
# @return Command path, or undef.
sub which_cmd {
    for my $c (@_) {
        my $which = `which $c 2>/dev/null`;
        if ($? == 0 && defined $which && $which =~ /\S/) {
            chomp $which;
            return $which;
        }
    }
    return undef;
}

# Locates the GitHub Copilot CLI on PATH or in known install locations.
# @return Command path, or undef.
sub find_copilot_cmd {
    my $cmd = which_cmd('copilot', 'copilot.cmd', 'copilot.exe', 'copilot.bat');
    return $cmd if $cmd;

    my $appdata = $ENV{APPDATA} || '';
    if ($appdata ne '') {
        for my $candidate (
            "$appdata/Code/User/globalStorage/github.copilot-chat/copilotCli/copilot.bat",
            "$appdata/Code/User/globalStorage/github.copilot-chat/copilotCli/copilot"
        ) {
            return $candidate if -f $candidate;
        }
    }
    for my $loc ('/usr/local/bin/copilot', '/usr/bin/copilot',
                 defined $ENV{HOME} ? "$ENV{HOME}/.local/bin/copilot" : ()) {
        return $loc if -x $loc;
    }
    return undef;
}

# Installs the Copilot CLI with a native package manager (no Node.js/npm).
# @return True when an installer reported success.
sub install_copilot_cli {
    print "GitHub Copilot CLI was not found. Attempting to install it via package manager...\n";
    if ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') {
        if (my $winget = which_cmd('winget', 'winget.exe')) {
            print "Attempting to install GitHub.Copilot via winget...\n";
            my $status = system($winget, "install", "--id", "GitHub.Copilot",
                "--accept-source-agreements", "--accept-package-agreements");
            return 1 if $status == 0;
            warn "Warning: winget install failed with exit code " . ($status >> 8) . ".\n";
        }
    }
    if (my $gh = which_cmd('gh')) {
        print "Attempting to install gh-copilot extension via gh...\n";
        return 1 if system($gh, "extension", "install", "github/gh-copilot") == 0;
    }
    return 0;
}

# Returns a working Copilot CLI command, installing it if needed.
# @return Command path, or undef when unavailable.
sub ensure_copilot_ready {
    my $works = sub {
        my ($cmd) = @_;
        return 0 unless $cmd;
        my $ver_out = `"$cmd" --version 2>&1`;
        return $? == 0 && defined $ver_out && $ver_out =~ /copilot/i
            && $ver_out !~ /cannot find github copilot/i;
    };
    my $cmd = find_copilot_cmd();
    return $cmd if $works->($cmd);
    return undef unless install_copilot_cli();
    $cmd = find_copilot_cmd();
    return $works->($cmd) ? $cmd : undef;
}

# Drafts changelog sections with the Copilot CLI.
# @param $addon Addon name.
# @param $version Version being documented.
# @param $commits Array reference of commit subjects.
# @param $existing Existing changelog text when appending, otherwise undef.
# @return Markdown sections without a title, or undef on failure.
sub copilot_entries {
    my ($addon, $version, $commits, $existing) = @_;
    my $copilot_cmd = ensure_copilot_ready();
    if (!$copilot_cmd) {
        warn "Note: GitHub Copilot CLI could not be located or installed.\n";
        return undef;
    }
    if (!defined $ENV{GITHUB_TOKEN} || $ENV{GITHUB_TOKEN} eq "") {
        my $token = get_github_token();
        $ENV{GITHUB_TOKEN} = $token if $token && $token =~ /\S/;
    }

    my $commits_str = join("\n", map { "- $_" } @$commits);
    my $prompt = <<"PROMPT";
Write release changelog entries in Markdown for $addon version $version.

Group the changes by UI area or module (for example: "### Listview Bag", "### Minimap", "### Error Log", "### General", etc.) based on the commit subjects.
Under each "### " area heading, list the changes as bullet points starting with "- ".
Keep bullets concise and user-facing.
Do not include "# " or "## " headings; the release heading is added separately.
Do not wrap your response in markdown code block fences (no ```). Output plain markdown directly.
PROMPT
    if (defined $existing) {
        $prompt .= <<"PROMPT";

This release's changelog section already contains the entries below. Only describe changes that are not
already covered, and reuse the existing area headings where they fit.

Existing entries:
$existing
PROMPT
    }
    $prompt .= "\nCommits:\n$commits_str\n";

    print "Invoking GitHub Copilot CLI to draft changelog...\n";
    open my $pipe, "-|", $copilot_cmd, "-s", "-p", $prompt or do {
        warn "Failed to execute copilot CLI: $!\n";
        return undef;
    };
    my $output = do { local $/; <$pipe> };
    close $pipe;
    if (!defined $output || $output !~ /\S/) {
        warn "Copilot CLI produced no output.\n";
        return undef;
    }
    $output =~ s/^```(?:markdown)?\r?\n//i;
    $output =~ s/\r?\n```\s*$//;
    # Drop any title/release headings Copilot adds anyway, then demote stray "## " areas
    # so they cannot be mistaken for release sections in the combined file.
    1 while $output =~ s/^\s*##?\s[^\r\n]*(?:\r?\n|\z)//;
    $output =~ s/^##\s/### /mg;
    $output =~ s/^\s+|\s+$//g;
    return "$output\n";
}

# Creates or extends a release's "## <tag>" section in the combined changelog and
# optionally opens the file in VS Code. New sections are inserted above older
# releases; an existing section is appended to unless overwrite is requested.
# @param %opt addon, version, file, prefix, use_copilot, blank, overwrite, dry_run, no_open.
# @return Changelog path.
sub update_changelog {
    my (%opt) = @_;
    my $path = $opt{file};
    my $tag = "$opt{prefix}$opt{version}";
    my $text = read_changelog_file($path);
    my @lines = defined $text ? split(/\r?\n/, $text) : ("# $opt{addon} Changelog", '');
    my ($start, $end) = find_changelog_section(\@lines, $tag);
    my $append = defined $start && !$opt{overwrite};
    my $existing = $append ? changelog_section($text, $tag) : undef;

    my @body;
    if ($opt{blank}) {
        print "Generating blank '## $tag' changelog section...\n";
    } else {
        my $base = changelog_base($opt{version}, $opt{prefix}, $path, $append);
        my @commits = collect_commits($base);
        @commits = grep { !already_listed($existing, $_) } @commits if $append;
        printf "Found %d %scommit(s) since %s.\n", scalar @commits, $append ? 'new ' : '',
            length $base ? "'$base'" : 'the start of the log';
        if ($append && !@commits) {
            print "No new commits to add to '## $tag' in '$path'.\n";
            open_in_vscode($path) unless $opt{dry_run} || $opt{no_open};
            return $path;
        }
        my $entries;
        if ($opt{use_copilot} && @commits) {
            $entries = eval { copilot_entries($opt{addon}, $opt{version}, \@commits, $existing) };
            warn "Copilot generation skipped or failed. Falling back to git log parser.\n"
                if $@ || !defined $entries;
        }
        $entries //= fallback_entries(@commits);
        @body = $append ? merge_into_section([split /\n/, $existing], $entries) : split(/\n/, $entries);
    }

    my @section = ("## $tag", '', @body, @body ? '' : ());
    if (defined $start) {
        splice @lines, $start, $end - $start, @section;
    } else {
        # Newest release first: insert above the first existing release section.
        my ($first) = grep { $lines[$_] =~ /^##\s/ } 0 .. $#lines;
        $first //= scalar @lines;
        splice @lines, $first, 0, ($first > 0 && $lines[$first - 1] =~ /\S/ ? '' : ()), @section;
    }
    pop @lines while @lines && $lines[-1] !~ /\S/;
    my $content = join("\n", @lines) . "\n";
    my $preview = join("\n", @section);
    $preview =~ s/\s+\z/\n/;

    my $verb = $append ? 'Updated' : 'Added';
    if ($opt{dry_run}) {
        print "\n[Dry Run] Preview of '## $tag' in '$path':\n";
    } else {
        open my $wfh, ">:encoding(UTF-8)", $path or die "Cannot write to $path: $!\n";
        print $wfh $content;
        close $wfh;
        print "\n$verb '## $tag' in changelog: $path\n";
    }
    print "----------------------------------------\n$preview----------------------------------------\n";
    open_in_vscode($path) unless $opt{dry_run} || $opt{no_open};
    return $path;
}

# Opens a file in VS Code when the code CLI is available.
# @param $file File path.
sub open_in_vscode {
    my ($file) = @_;
    my $code_cmd = which_cmd('code', 'code.cmd', 'code.exe');
    if (!$code_cmd) {
        my $localappdata = $ENV{LOCALAPPDATA} || '';
        my $programfiles = $ENV{ProgramFiles} || '';
        ($code_cmd) = grep { -f $_ } (
            "$localappdata/Programs/Microsoft VS Code/bin/code.cmd",
            "$localappdata/Programs/Microsoft VS Code/bin/code",
            "$programfiles/Microsoft VS Code/bin/code.cmd",
            "$programfiles/Microsoft VS Code/bin/code"
        );
    }
    if ($code_cmd) {
        print "Opening '$file' in VS Code...\n";
        system($code_cmd, $file);
    } else {
        warn "Note: 'code' CLI was not found. Please review '$file' manually.\n";
    }
}

1;
