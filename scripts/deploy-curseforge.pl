#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use FindBin;
use Cwd qw(abs_path);
use File::Spec;
use JSON::PP;

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

# ------------------------------------------------------------------------------
# Configurable Variables & Settings (Environment variables take precedence)
# ------------------------------------------------------------------------------
my $curseforge_project_id = $ENV{CURSEFORGE_PROJECT_ID} || "1740483";
my $release_type          = $ENV{RELEASE_TYPE}          || "release";   # release, beta, alpha
my $changelog_type        = $ENV{CHANGELOG_TYPE}        || "markdown";  # markdown, text, html
my $changelog_file        = $ENV{CHANGELOG_FILE}        || "";
my $game_version_ids_raw  = $ENV{CURSEFORGE_GAME_VERSION_IDS} || "";

# Proton Pass CLI settings
my $proton_pass_item      = $ENV{PROTON_PASS_ITEM}      || "CurseForge: SlackHacksDeploy API Token";
my $proton_pass_vault     = $ENV{PROTON_PASS_VAULT}     || "Personal";
my $proton_pass_attribute = $ENV{PROTON_PASS_ATTRIBUTE} || "Secret";
my $proton_pass_cli_bin   = $ENV{PROTON_PASS_CLI_BIN}   || "pass-cli";

# Dry run flag: --dry-run
my $dry_run = 0;
for my $arg (@ARGV) {
    if ($arg eq '--dry-run' || $arg eq '-n') {
        $dry_run = 1;
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
    if ($vault ne "") {
        push @cmd, "--vault-name", $vault;
    }

    open my $pipe, "-|", @cmd or do {
        warn "Error: Failed to execute '$proton_pass_cli_bin': $!\n";
        warn "Please ensure the Proton Pass CLI is installed in PATH, or set CURSEFORGE_API_TOKEN.\n";
        return undef;
    };
    my $secret = do { local $/; <$pipe> };
    close $pipe;

    if (defined $secret) {
        $secret =~ s/^\s+|\s+$//g;
        # If pass-cli prints a label such as "Secret: <token>", extract the token
        if ($secret =~ /^\Q$attr\E:\s*(.+)$/i) {
            $secret = $1;
            $secret =~ s/^\s+|\s+$//g;
        }
    }

    if (!defined $secret || $secret eq "") {
        warn "Error: Could not retrieve secret for item '$item' from Proton Pass.\n";
        warn "Please ensure you are logged in ('pass-cli login') and the item/field exists.\n";
        return undef;
    }

    return $secret;
}

# ------------------------------------------------------------------------------
# Step 1: Extract Version from SlackHacks.toc & Check Build Artifact
# ------------------------------------------------------------------------------
my $toc_file = "SlackHacks.toc";
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

my $zip_name = "SlackHacks-v$version.zip";
my $zip_path = File::Spec->catfile("dist", $zip_name);

if (!-f $zip_path) {
    print "Zip archive '$zip_path' not found. Running build.sh first...\n";
    my $build_script = File::Spec->catfile($script_dir, "build.sh");
    my $build_status = system("bash", $build_script);
    if ($build_status != 0) {
        die "Error: build.sh failed with exit code " . ($build_status >> 8) . "\n";
    }
}

die "Error: Build output '$zip_path' not found after build.\n" unless -f $zip_path;
print "Found release archive: $zip_path\n";

# ------------------------------------------------------------------------------
# Step 2: Validate CurseForge Project ID
# ------------------------------------------------------------------------------
if ($curseforge_project_id eq "REPLACE_WITH_CURSEFORGE_PROJECT_ID" || $curseforge_project_id eq "") {
    die "Error: CURSEFORGE_PROJECT_ID is not configured.\n" .
        "Please set CURSEFORGE_PROJECT_ID environment variable or edit the script configuration.\n";
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
    die "Failed to retrieve CurseForge API Token.\n" unless defined $api_token;
    print "Successfully retrieved CurseForge API Token.\n";
}

# ------------------------------------------------------------------------------
# Step 4: Parse Game Version IDs
# ------------------------------------------------------------------------------
my @game_version_ids = ();
if ($game_version_ids_raw =~ /\S/) {
    for my $id (split /,/, $game_version_ids_raw) {
        $id =~ s/^\s+|\s+$//g;
        if ($id =~ /^\d+$/) {
            push @game_version_ids, int($id);
        }
    }
}

# ------------------------------------------------------------------------------
# Step 5: Prepare Changelog
# ------------------------------------------------------------------------------
my $changelog_text = "";
if ($changelog_file eq "") {
    my $default_changelog = File::Spec->catfile("changelog", "changelog-v$version.md");
    if (-f $default_changelog) {
        $changelog_file = $default_changelog;
    }
}

if ($changelog_file ne "" && -f $changelog_file) {
    open my $cfh, "<:encoding(UTF-8)", $changelog_file or warn "Cannot open changelog file '$changelog_file': $!\n";
    if ($cfh) {
        $changelog_text = do { local $/; <$cfh> };
        close $cfh;
    }
} elsif (-d ".git") {
    my $last_tag = `git describe --tags --abbrev=0 2>/dev/null`;
    if ($? == 0 && defined $last_tag && $last_tag =~ /\S/) {
        $last_tag =~ s/^\s+|\s+$//g;
        $changelog_text = `git log "${last_tag}..HEAD" --oneline --no-merges 2>/dev/null`;
    } else {
        $changelog_text = `git log -n 10 --oneline --no-merges 2>/dev/null`;
    }
}

if (!defined $changelog_text || $changelog_text !~ /\S/) {
    $changelog_text = "Release SlackHacks v$version";
}

# ------------------------------------------------------------------------------
# Step 6: Construct Metadata JSON & Upload
# ------------------------------------------------------------------------------
my $display_name = "SlackHacks-v$version";
my $metadata = {
    changelog     => $changelog_text,
    changelogType => $changelog_type,
    displayName   => $display_name,
    parentFileID  => JSON::PP::null,
    gameVersions  => \@game_version_ids,
    releaseType   => $release_type,
};

my $json_encoder = JSON::PP->new->utf8->canonical;
my $metadata_json = $json_encoder->encode($metadata);

my $upload_url = "https://wow.curseforge.com/api/projects/$curseforge_project_id/upload-file";

print "=== CurseForge Deployment Summary ===\n";
print "Project ID:    $curseforge_project_id\n";
print "Display Name:  $display_name\n";
print "Release Type:  $release_type\n";
print "Archive:       $zip_path\n";
print "Upload URL:    $upload_url\n";
print "Game Versions: " . $json_encoder->encode(\@game_version_ids) . "\n";
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
my @curl_cmd = (
    "curl", "-s", "-S",
    "-w", "\nHTTP_STATUS:%{http_code}",
    "-H", "X-Api-Token: $api_token",
    "-F", "metadata=$metadata_json",
    "-F", "file=\@$zip_path",
    $upload_url
);

open my $curl_pipe, "-|", @curl_cmd or die "Failed to execute curl: $!\n";
my $response = do { local $/; <$curl_pipe> };
close $curl_pipe;

my $http_status = 0;
if ($response =~ /HTTP_STATUS:(\d+)/) {
    $http_status = int($1);
    $response =~ s/\n?HTTP_STATUS:\d+//;
}

if ($http_status >= 200 && $http_status < 300) {
    print "Deployment to CurseForge succeeded (HTTP $http_status)!\n";
    print "Response: $response\n";
} else {
    die "Error: CurseForge deployment failed with HTTP status $http_status.\nResponse: $response\n";
}
