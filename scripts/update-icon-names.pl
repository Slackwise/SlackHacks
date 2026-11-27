#!/usr/bin/env perl
# Explicit updates check GitHub main and extract only when its revision changes.
# --no-update extracts local data without checking or changing the recorded revision.
use strict;
use warnings;
use FindBin;
use File::Copy qw(move);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptions);
use JSON::PP;
use lib $FindBin::Bin;
use ReleaseUtil qw(curl_response git_output);

my $update = 1;
GetOptions('update!' => \$update) or die "Usage: perl scripts/update-icon-names.pl [--no-update]\n";
die "Usage: perl scripts/update-icon-names.pl [--no-update]\n" if @ARGV;

my $root = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..'));
my $library = File::Spec->catdir($root, 'dist', 'LibRPMedia');
my $output = File::Spec->catfile($root, 'IconNames.lua');
my $version_file = File::Spec->catfile($root, 'LibRPMedia-version.txt');
my $repository = 'https://github.com/wow-rp-addons/LibRPMedia';
my $api = 'https://api.github.com/repos/wow-rp-addons/LibRPMedia/git/ref/heads/main';

sub run_git {
    system('git', @_) == 0 or die "git @_ failed.\n";
}

my $revision;
if ($update) {
    my ($status, $body) = curl_response('--location', '--max-time', '60',
        '-H', 'Accept: application/vnd.github+json',
        '-H', 'User-Agent: SlackHacks-icon-updater',
        '-H', 'X-GitHub-Api-Version: 2022-11-28', $api);
    die "GitHub API request for LibRPMedia main failed (HTTP $status): $body\n" unless $status == 200;
    my $response = JSON::PP->new->utf8->decode($body);
    $revision = ref($response) eq 'HASH' && ref($response->{object}) eq 'HASH' ? $response->{object}{sha} : undef;
    die "GitHub API returned an invalid LibRPMedia main commit.\n"
        unless defined $revision && !ref($revision) && $revision =~ /^[0-9a-f]{40}$/;

    if (-e $version_file) {
        open my $version_in, '<:raw', $version_file or die "Cannot read '$version_file': $!\n";
        my $stored_revision = do { local $/; <$version_in> } // '';
        close $version_in or die "Cannot close '$version_file': $!\n";
        $stored_revision =~ s/\s+\z//;
        if ($stored_revision eq $revision) {
            print "LibRPMedia icon names are already up to date at $revision.\n";
            exit 0;
        }
    }

    if (!-e $library) {
        make_path(File::Spec->catdir($root, 'dist'));
        run_git('clone', '--branch', 'main', '--single-branch', '--', $repository, $library);
    } elsif (!-e File::Spec->catfile($library, '.git')) {
        die "'$library' already exists and is not a Git checkout; preserve or move it before updating.\n";
    }

    my $origin = git_output('-C', $library, 'config', '--get', 'remote.origin.url');
    die "LibRPMedia origin '$origin' is not the expected GitHub repository.\n"
        unless $origin =~ m{^(?:https://github\.com/|git\@github\.com:|ssh://git\@github\.com/)wow-rp-addons/LibRPMedia(?:\.git)?/?$}i;
    my $changes = git_output('-C', $library, 'status', '--porcelain', '--untracked-files=all');
    die "LibRPMedia has uncommitted changes; preserve them before updating.\n" if $changes =~ /\S/;
    my $branch = git_output('-C', $library, 'branch', '--show-current');
    die "LibRPMedia is on branch '$branch', not main; switch to main before updating.\n"
        if $branch ne '' && $branch ne 'main';
    run_git('-C', $library, 'fetch', '--no-tags', 'origin', 'main');
    # Pin extraction to the API snapshot even if main advances during the fetch.
    run_git('-C', $library, 'merge-base', '--is-ancestor', $revision, 'FETCH_HEAD');
    run_git('-C', $library, 'merge-base', '--is-ancestor', 'HEAD', $revision);
    run_git('-C', $library, 'merge', '--ff-only', '--no-overwrite-ignore', $revision);
    my $head = git_output('-C', $library, 'rev-parse', 'HEAD');
    die "LibRPMedia checkout did not reach API revision $revision (HEAD is $head).\n" if $head ne $revision;
}

my @datasets = (
    [ Standard => 1 ], [ Forever => 2 ], [ Mists => 4 ],
    [ TBC => 8 ], [ Vanilla => 16 ],
);
my %icons;
for my $dataset (@datasets) {
    my ($flavor, $mask) = @$dataset;
    my $path = File::Spec->catfile($library, "LibRPMediaData_$flavor.lua");
    open my $fh, '<:raw', $path or die "Cannot read '$path': $!\n";
    my ($ids, $names, $declared);
    while (my $line = <$fh>) {
        $declared = $1 if $line =~ /^\s*size\s*=\s*(\d+),/ && !defined $declared;
        $ids = $1 if $line =~ /^db_icons_id\s*=\s*\{(.*)\};\s*$/;
        $names = $1 if $line =~ /^db_icons_name\s*=\s*\{(.*)\};\s*$/;
    }
    close $fh or die "Cannot close '$path': $!\n";
    die "Missing icon data in '$path'.\n" unless defined $ids && defined $names && defined $declared;
    die "Unsupported icon IDs in '$path'.\n" unless $ids =~ /^\d+(?:,\d+)*,?$/;
    my @ids = split /,/, $ids;
    my @names;
    pos($names) = 0;
    while ($names =~ /\G"([^"\\\r\n]*)",?/gc) {
        push @names, $1;
    }
    die "Unsupported icon names in '$path'.\n" unless pos($names) == length($names);
    die "Icon count mismatch in '$path'.\n" unless @ids == @names && @ids == $declared;
    for my $i (0 .. $#ids) {
        next if $ids[$i] >= 0x04000000; # Atlas IDs cannot be displayed as file textures.
        my $name = $names[$i];
        die "Unsupported icon name '$name' in '$path'.\n"
            if !length($name) || $name =~ /[|~\r\n]/ || $name =~ /\]==\]/ || $name ne lc $name;
        $icons{$ids[$i]}{$name} |= $mask;
    }
}
die "No file icons were extracted.\n" unless %icons;

my ($out, $temporary) = tempfile('.icon-names-XXXXXX', DIR => $root, UNLINK => 1);
binmode $out;
print {$out} "-- Generated by scripts/update-icon-names.pl from LibRPMedia (Unlicense).\n",
    "-- Delta IDs, client flags, name prefix lengths, and suffixes; do not edit by hand.\n",
    "setfenv(1, _G.SlackHacks)\n\nIconNames = { compressed = true, data = [==[\n"
    or die "Cannot write '$temporary': $!\n";
my $count = 0;
my ($previous_id, $previous_name) = (0, '');
for my $id (sort { $a <=> $b } keys %icons) {
    for my $name (sort keys %{ $icons{$id} }) {
        my $prefix = 0;
        my $limit = length($name) < length($previous_name) ? length($name) : length($previous_name);
        $prefix++ while $prefix < $limit
            && substr($name, $prefix, 1) eq substr($previous_name, $prefix, 1);
        my $delta = $id - $previous_id;
        my $suffix = substr($name, $prefix);
        $suffix .= '~' if $suffix =~ / $/; # Preserve trailing spaces without trailing whitespace in generated Lua.
        print {$out} "$delta|$icons{$id}{$name}|$prefix|$suffix\n"
            or die "Cannot write '$temporary': $!\n";
        ($previous_id, $previous_name) = ($id, $name);
        $count++;
    }
}
print {$out} "]==] }\n" or die "Cannot write '$temporary': $!\n";
close $out or die "Cannot close '$temporary': $!\n";
my $version_temporary;
if (defined $revision) {
    my $version_out;
    ($version_out, $version_temporary) = tempfile('.librpmedia-version-XXXXXX', DIR => $root, UNLINK => 1);
    binmode $version_out;
    print {$version_out} "$revision\n" or die "Cannot write '$version_temporary': $!\n";
    close $version_out or die "Cannot close '$version_temporary': $!\n";
}
move($temporary, $output) or die "Cannot install '$output': $!\n";
if (defined $revision) {
    move($version_temporary, $version_file)
        or die "IconNames.lua was updated, but '$version_file' could not be installed: $!\n";
    print "Recorded LibRPMedia main revision $revision in '$version_file'.\n";
}
print "Extracted $count icon names into '$output'.\n";
