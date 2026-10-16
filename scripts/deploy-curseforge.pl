#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib $FindBin::Bin;
use ReleaseUtil qw(git_output verify_release read_changelog json_file curl_response file_digest ensure_build);
use Fcntl qw(O_WRONLY O_CREAT O_EXCL);
use File::Path qw(make_path);
use Cwd qw(abs_path);
use File::Spec;
use JSON::PP;
use Getopt::Long qw(GetOptions);

# ==============================================================================
# deploy-curseforge.pl
# 
# Deploys the built SlackHacks addon package to CurseForge using the Upload API.
#
# Prerequisites:
# 1. Proton Pass CLI (pass-cli) installed and authenticated.
# 2. CurseForge API token stored in Proton Pass.
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
# Configurable Variables & Settings (Environment variables take precedence)
# ------------------------------------------------------------------------------
sub require_config {
    my ($name) = @_;
    die "Error: Required setting $name is missing. Check scripts/defaults.env.\n"
        unless defined $ENV{$name} && length $ENV{$name};
    return $ENV{$name};
}

my $addon_name                 = require_config("ADDON_NAME");
my $toc_file                   = require_config("TOC_FILE");
my $dist_dir                   = require_config("DIST_DIR");
my $zip_name                   = require_config("ZIP_NAME");
my $tag_prefix                 = require_config("TAG_PREFIX");
my $changelog_dir              = require_config("CHANGELOG_DIR");
my $curseforge_display_name_prefix = require_config("CURSEFORGE_DISPLAY_NAME_PREFIX");

my $curseforge_project_id      = require_config("CURSEFORGE_PROJECT_ID");
my $release_type               = require_config("RELEASE_TYPE");
my $changelog_type             = require_config("CHANGELOG_TYPE");
my $changelog_file             = defined $ENV{CHANGELOG_FILE} ? $ENV{CHANGELOG_FILE}
    : die "Error: Required setting CHANGELOG_FILE is missing. Check scripts/defaults.env.\n";

# Proton Pass CLI settings
my $proton_pass_item      = require_config("PROTON_PASS_ITEM_CURSEFORGE");
my $proton_pass_vault     = require_config("PROTON_PASS_VAULT");
my $proton_pass_attribute = require_config("PROTON_PASS_ATTRIBUTE");
my $proton_pass_cli_bin   = require_config("PROTON_PASS_CLI_BIN");

# Command line options
my $dry_run       = 0;
my $list_versions;
my $help          = 0;

GetOptions(
    'dry-run|n'           => \$dry_run,
    'list-versions|l|v:s' => \$list_versions,
    'help|h'              => \$help,
) or die "Usage: $0 [--dry-run] [--list-versions [filter]] [--help]\n";

if ($help) {
    print <<"HELP";
Usage: perl deploy-curseforge.pl [OPTIONS]

Options:
  -n, --dry-run                 Simulate deployment and preview metadata without uploading
  -l, --list-versions [filter]  Fetch available game version names and IDs from CurseForge API
                                (optional filter by keyword, e.g. -l retail or -l classic)
  -h, --help                    Show this help message

HELP
    exit 0;
}

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
# Helper: Fetch secret from Proton Pass CLI
# ------------------------------------------------------------------------------
sub fetch_secret_from_proton_pass {
    my ($item, $vault, $attr) = @_;

    if ($ENV{CURSEFORGE_API_TOKEN} && $ENV{CURSEFORGE_API_TOKEN} =~ /\S/) {
        return $ENV{CURSEFORGE_API_TOKEN};
    }

    my @cmd = ($proton_pass_cli_bin, "item", "view", "--item-title", $item, "--field", $attr);
    push @cmd, "--vault-name", $vault if $vault ne "";

    my $run_query = sub {
        my $cmd_str = join(" ", map { /\s/ ? qq{"$_"} : $_ } @cmd);
        my $output = `$cmd_str 2>&1`;
        my $status = $? >> 8;
        return ($status, $output);
    };

    my ($status, $output) = $run_query->();

    # Check for stale corrupted session in Windows file lock state
    if ($status != 0 && $output =~ /Session is some but is not logged in|Error deleting base dir/i) {
        print "Detected stale Proton Pass session file. Cleaning up...\n";
        clean_stale_proton_pass_session();
        ($status, $output) = $run_query->();
    }

    # If unauthenticated, locked, or no session, trigger browser login
    if ($status != 0 && $output =~ /no session|requires an authenticated client|lock|not logged in/i) {
        print "Proton Pass session is unauthenticated or expired.\n";
        run_pass_cli_login($proton_pass_cli_bin);
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

    warn "Error: Could not retrieve secret for item '$item' from Proton Pass.\n";
    warn "Output: $output\n" if defined $output && $output =~ /\S/;
    return undef;
}

# ------------------------------------------------------------------------------
# Handle --list-versions
# ------------------------------------------------------------------------------
if (defined $list_versions) {
    my $filter = $list_versions;
    print "Fetching CurseForge game versions...\n";
    my $token = fetch_secret_from_proton_pass($proton_pass_item, $proton_pass_vault, $proton_pass_attribute);
    die "Error: Could not retrieve CurseForge API token.\n" unless defined $token;

    # Fetch version types
    my %type_names = ();
    my $types_resp = `curl -s -H "X-Api-Token: $token" https://wow.curseforge.com/api/game/version-types`;
    my $types_data = eval { JSON::PP->new->utf8->decode($types_resp) };
    if ($types_data && ref($types_data) eq 'ARRAY') {
        for my $t (@$types_data) {
            $type_names{$t->{id}} = $t->{name} if defined $t->{id} && defined $t->{name};
        }
    }

    # Fetch versions
    my $ver_resp = `curl -s -H "X-Api-Token: $token" https://wow.curseforge.com/api/game/versions`;
    my $versions = eval { JSON::PP->new->utf8->decode($ver_resp) };
    if (!$versions || ref($versions) ne 'ARRAY') {
        die "Error fetching versions from CurseForge: $ver_resp\n";
    }

    printf "%-10s | %-20s | %s\n", "ID", "Version Name", "Flavor / Type";
    print "-" x 60 . "\n";
    for my $v (@$versions) {
        my $type_name = $type_names{$v->{gameVersionTypeID} || 0} || ("Type " . ($v->{gameVersionTypeID} || ''));
        if ($filter ne "") {
            next unless ($v->{name} =~ /\Q$filter\E/i || ($v->{slug} || '') =~ /\Q$filter\E/i || $type_name =~ /\Q$filter\E/i);
        }
        printf "%-10s | %-20s | %s\n", $v->{id}, $v->{name}, $type_name;
    }
    exit 0;
}

sub resolve_game_versions_from_toc {
    my ($token, @interfaces) = @_;
    return [] unless defined $token && length($token) && $token ne "DRY_RUN_TOKEN";

    # Fetch version types
    my %type_names = ();
    my ($types_status, $types_resp) = curl_response('-H', "X-Api-Token: $token",
        'https://wow.curseforge.com/api/game/version-types');
    die "Error: Cannot fetch CurseForge version types (HTTP $types_status).\nResponse: $types_resp\n"
        unless $types_status == 200;
    my $types_data = JSON::PP->new->utf8->decode($types_resp);
    die "Error: Invalid CurseForge version types response.\n" unless ref($types_data) eq 'ARRAY';
    for my $t (@$types_data) {
        $type_names{$t->{id}} = $t->{name} if defined $t->{id} && defined $t->{name};
    }

    # Fetch versions
    my ($versions_status, $ver_resp) = curl_response('-H', "X-Api-Token: $token",
        'https://wow.curseforge.com/api/game/versions');
    die "Error: Cannot fetch CurseForge game versions (HTTP $versions_status).\nResponse: $ver_resp\n"
        unless $versions_status == 200;
    my $versions = JSON::PP->new->utf8->decode($ver_resp);
    die "Error: Invalid CurseForge game versions response.\n" unless ref($versions) eq 'ARRAY';

    my $semver_cmp = sub {
        my ($a_str, $b_str) = @_;
        my @a_p = map { int($_) } ($a_str =~ /(\d+)/g);
        my @b_p = map { int($_) } ($b_str =~ /(\d+)/g);
        for my $i (0 .. 4) {
            my $ai = $a_p[$i] // 0;
            my $bi = $b_p[$i] // 0;
            return $ai <=> $bi if $ai != $bi;
        }
        return 0;
    };

    my @retail_list  = ();
    my @forever_list = ();

    for my $v (@$versions) {
        my $type_name = $type_names{$v->{gameVersionTypeID} || 0} || '';
        my $v_name = $v->{name} || '';

        # Match Retail (Type "World of Warcraft", "Retail", or version 10.x, 11.x, 12.x)
        if ($type_name =~ /retail|^world of warcraft$/i || $v_name =~ /^(?:10|11|12)\./) {
            push @retail_list, $v;
        }
        # Match Forever / Classic Era (Type "Classic Era", "Era", "Forever", or version 1.14.x, 1.15.x, 1.16.x)
        elsif ($type_name =~ /forever|classic\s*era|era/i || $v_name =~ /^1\.(?:14|15|16)\./) {
            push @forever_list, $v;
        }
    }

    my @sorted_retail  = sort { $semver_cmp->($a->{name}, $b->{name}) } @retail_list;
    my @sorted_forever = sort { $semver_cmp->($a->{name}, $b->{name}) } @forever_list;

    my @resolved_ids = ();

    for my $iface (@interfaces) {
        my $iface_num = int($iface);
        my $major = int($iface_num / 10000);
        my $minor = int(($iface_num % 10000) / 100);
        my $patch = $iface_num % 100;
        my $semver = "$major.$minor.$patch";

        if ($major >= 10) {
            # Retail branch target from TOC (e.g. 120105 -> 12.1.5, or 110007 -> 11.0.7)
            my ($exact) = grep { $_->{name} eq $semver } @retail_list;
            if ($exact) {
                print "TOC Interface $iface_num ($semver) -> Matched exact Retail version: $exact->{name} (ID: $exact->{id})\n";
                push @resolved_ids, $exact->{id};
            } elsif (@sorted_retail) {
                my @same_major = grep { $_->{name} =~ /^$major\./ } @sorted_retail;
                my $best = @same_major ? $same_major[-1] : $sorted_retail[-1];
                print "TOC Interface $iface_num ($semver) -> Matched latest Retail version: $best->{name} (ID: $best->{id})\n";
                push @resolved_ids, $best->{id};
            }
        } else {
            # Forever / Classic Era branch target from TOC (e.g. 16001 -> 1.60.1, or 11505 -> 1.15.5)
            my ($exact) = grep { $_->{name} eq $semver } @forever_list;
            if ($exact) {
                print "TOC Interface $iface_num ($semver) -> Matched exact Forever/Classic version: $exact->{name} (ID: $exact->{id})\n";
                push @resolved_ids, $exact->{id};
            } elsif (@sorted_forever) {
                my $best = $sorted_forever[-1];
                print "TOC Interface $iface_num ($semver) -> Matched latest Forever/Classic version: $best->{name} (ID: $best->{id})\n";
                push @resolved_ids, $best->{id};
            }
        }
    }

    return \@resolved_ids;
}

# ------------------------------------------------------------------------------
# Step 1: Extract Version from SlackHacks.toc & Check Build Artifact
# ------------------------------------------------------------------------------
die "Error: $toc_file not found in $repo_root\n" unless -f $toc_file;

open my $fh, "<:encoding(UTF-8)", $toc_file or die "Cannot open $toc_file: $!\n";
my $version;
my @toc_interfaces = ();
while (my $line = <$fh>) {
    if ($line =~ /^\s*##\s*Version:\s*(.+)$/i) {
        $version = $1;
        $version =~ s/^\s+|\s+$//g;
        $version =~ s/^v//i; # strip leading v if present
    }
    if ($line =~ /^\s*##\s*Interface:\s*(.+)$/i) {
        my $iface_val = $1;
        $iface_val =~ s/^\s+|\s+$//g;
        for my $raw (split /,/, $iface_val) {
            $raw =~ s/^\s+|\s+$//g;
            push @toc_interfaces, $raw if $raw =~ /^\d+$/;
        }
    }
}
close $fh;

die "Error: Could not extract version from $toc_file\n" unless defined $version && length($version);

my $zip_path = File::Spec->catfile($dist_dir, $zip_name);
my $tag_name = "$tag_prefix$version";
my $commit = verify_release($tag_name, require_config("TARGET_COMMITISH"));

my ($state_file, $state_key);
unless ($dry_run) {
    my $state_dir = File::Spec->catdir(git_output('rev-parse', '--git-common-dir'), 'slackhacks-deploy');
    make_path($state_dir);
    $state_key = Digest::SHA::sha256_hex("$curseforge_project_id:$tag_name");
    $state_file = File::Spec->catfile($state_dir, "$state_key.json");
    if (-f $state_file) {
        my $receipt_file = -f "$state_file.complete" ? "$state_file.complete" : $state_file;
        open my $state_fh, '<:raw', $receipt_file or die "Error: Cannot read $receipt_file: $!\n";
        my $state = eval { JSON::PP->new->utf8->decode(do { local $/; <$state_fh> }) };
        die "Error: Invalid upload receipt '$receipt_file'; inspect CurseForge before retrying. $@\n"
            unless ref($state) eq 'HASH' && defined $state->{commit} && defined $state->{status};
        close $state_fh or die "Error: Cannot close '$receipt_file': $!\n";
        die "Error: CurseForge receipt does not match this release.\n" unless $state->{commit} eq $commit;
        if ($state->{status} eq 'complete' && $state->{file_id}) {
            print "CurseForge release $tag_name already uploaded (file $state->{file_id}).\n";
            exit 0;
        }
        die "Error: A previous CurseForge upload is pending or uncertain. Check the project's files " .
            "before removing '$state_file' to retry; an upload may already exist.\n";
    }
}

ensure_build($script_dir, $zip_path, $commit) unless $dry_run;

die "Error: Build output '$zip_path' not found.\n" unless $dry_run || -f $zip_path;

# ------------------------------------------------------------------------------
# Step 2: Validate CurseForge Project ID
# ------------------------------------------------------------------------------
if ($curseforge_project_id eq "REPLACE_WITH_CURSEFORGE_PROJECT_ID") {
    die "Error: CURSEFORGE_PROJECT_ID is a placeholder. Check scripts/defaults.env.\n";
}

# ------------------------------------------------------------------------------
# Step 3: Retrieve API Token
# ------------------------------------------------------------------------------
my $api_token;
if ($dry_run) {
    print "[Dry Run] Skipping Proton Pass token retrieval.\n";
    $api_token = "DRY_RUN_TOKEN";
} else {
    print "Fetching CurseForge API Token from Proton Pass...\n";
    $api_token = fetch_secret_from_proton_pass($proton_pass_item, $proton_pass_vault, $proton_pass_attribute);
    die "Error: Failed to retrieve CurseForge API token. Set CURSEFORGE_API_TOKEN or check PROTON_PASS_ITEM_CURSEFORGE in scripts/defaults.env and your Proton Pass item.\n"
        unless defined $api_token;
    print "Successfully retrieved CurseForge API Token.\n";
}

# ------------------------------------------------------------------------------
# Step 4: Resolve Game Versions Dynamically from SlackHacks.toc & CurseForge API
# ------------------------------------------------------------------------------
my @game_version_ids = ();

if ($dry_run) {
    print "Parsed Game Version Targets from SlackHacks.toc:\n";
    for my $raw (@toc_interfaces) {
        my $num = int($raw);
        my $major = int($num / 10000);
        my $semver = sprintf("%d.%d.%d", $major, int(($num % 10000)/100), $num % 100);
        my $flavor = ($major >= 10) ? "Retail" : "Forever / Classic Era";
        print "  - Interface $raw ($semver) -> Targeting $flavor\n";
    }
    print "[Dry Run] In live deployment, CurseForge API will be queried to look up the latest version IDs.\n";
} else {
    print "Resolving game version IDs dynamically from SlackHacks.toc via CurseForge API...\n";
    my $resolved = resolve_game_versions_from_toc($api_token, @toc_interfaces);
    if ($resolved && @$resolved) {
        @game_version_ids = @$resolved;
    }
}

# ------------------------------------------------------------------------------
# Step 5: Prepare Changelog
# ------------------------------------------------------------------------------
my $changelog_text;
($changelog_file, $changelog_text) = read_changelog($changelog_file, $changelog_dir, $tag_name);

# ------------------------------------------------------------------------------
# Step 6: Construct Metadata JSON & Upload
# ------------------------------------------------------------------------------
my $display_name = "$curseforge_display_name_prefix$version";
my $metadata = {
    changelog     => $changelog_text,
    changelogType => $changelog_type,
    displayName   => $display_name,
    releaseType   => $release_type,
    gameVersions  => \@game_version_ids,
};

my $json_encoder = JSON::PP->new->utf8->canonical;

my $upload_url = "https://wow.curseforge.com/api/projects/$curseforge_project_id/upload-file";

print "=== CurseForge Deployment Summary ===\n";
print "Project ID:       $curseforge_project_id\n";
print "Display Name:     $display_name\n";
print "Release Type:     $release_type\n";
print "Changelog File:   " . ($changelog_file ne "" ? $changelog_file : "(none)") . "\n";
print "Archive:          $zip_path\n";
print "Upload URL:       $upload_url\n";
print "TOC Interfaces:   " . join(", ", @toc_interfaces) . "\n";
print "Game Version IDs: " . $json_encoder->encode(\@game_version_ids) . "\n";
print "=====================================\n";

if ($dry_run) {
    print "[Dry Run] Deployment simulation complete. No files were uploaded.\n";
    if ($changelog_text =~ /\S/) {
        print "\n[Dry Run] Changelog Preview:\n";
        print "----------------------------------------\n";
        print $changelog_text;
        print "----------------------------------------\n";
    }
    exit 0;
}

print "Uploading to CurseForge...\n";
die "Error: No compatible CurseForge game versions resolved; refusing upload.\n" unless @game_version_ids;
my $metadata_file = json_file($metadata);
my $receipt = {
    status => 'pending', commit => $commit, tag => $tag_name,
    project => $curseforge_project_id, digest => file_digest($zip_path),
};
# Claim the upload before sending it. Keep uncertain attempts for manual reconciliation:
# the legacy upload API has no idempotency key or authoritative file-list endpoint.
sysopen my $state_fh, $state_file, O_WRONLY | O_CREAT | O_EXCL
    or die "Error: Cannot claim CurseForge upload '$state_file': $!\n";
binmode $state_fh;
print {$state_fh} $json_encoder->encode($receipt) or die "Error: Cannot write upload receipt: $!\n";
close $state_fh or die "Error: Cannot save upload receipt: $!\n";
my @curl_cmd = (
    "-H", "X-Api-Token: $api_token",
    "-F", "metadata=<$metadata_file",
    "-F", "file=\@$zip_path",
    $upload_url
);

my ($http_status, $response) = curl_response(@curl_cmd);

if ($http_status >= 200 && $http_status < 300) {
    my $result = $json_encoder->decode($response);
    die "Error: CurseForge did not confirm a file ID; inspect '$state_file' before retrying.\n"
        unless ref($result) eq 'HASH' && $result->{id};
    $receipt->{status} = 'complete';
    $receipt->{file_id} = $result->{id};
    my $completed_file = "$state_file.result";
    open my $completed_fh, '>:raw', $completed_file or die "Error: Cannot save upload result: $!\n";
    print {$completed_fh} $json_encoder->encode($receipt) or die "Error: Cannot write upload result: $!\n";
    close $completed_fh or die "Error: Cannot close upload result: $!\n";
    # A separate completion file avoids losing the pending claim on interrupted writes.
    rename $completed_file, "$state_file.complete" or die "Error: Cannot finalize upload receipt: $!\n";
    print "Deployment to CurseForge succeeded (HTTP $http_status)!\n";
    print "Response: $response\n";
} else {
    die "Error: CurseForge deployment failed with HTTP status $http_status.\nResponse: $response\n";
}
