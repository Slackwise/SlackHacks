package ReleaseUtil;
use strict;
use warnings;
use Exporter 'import';
use File::Spec;
use File::Temp qw(tempfile);
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);

our @EXPORT_OK = qw(git_output verify_release read_changelog json_file curl_response file_digest ensure_build);

sub git_output {
    my (@args) = @_;
    open my $pipe, '-|', 'git', @args or die "Error: Cannot execute git: $!\n";
    my $output = do { local $/; <$pipe> };
    close $pipe or die "Error: git @args failed (exit " . ($? >> 8) . ").\n";
    $output //= '';
    $output =~ s/\s+$//;
    return $output;
}

sub verify_release {
    my ($tag, $target) = @_;
    die "Error: Deployment target must be prod.\n" unless $target eq 'prod';
    die "Error: Commit or stash all changes before deploying.\n"
        if git_output('status', '--porcelain') =~ /\S/;
    my $head = git_output('rev-parse', 'HEAD');
    my $commit = git_output('rev-parse', '--verify', "refs/tags/$tag^{commit}");
    die "Error: HEAD is not release tag '$tag'. Check out the release before deploying.\n"
        unless $head eq $commit;
    git_output('fetch', '--no-tags', 'origin', "refs/heads/$target");
    my $prod = git_output('rev-parse', 'FETCH_HEAD');
    # Require the exact production tip: deploying an older ancestor can roll back a release.
    die "Error: Release '$tag' is not the pushed origin/$target tip.\n" unless $commit eq $prod;
    my $remote = git_output('ls-remote', '--tags', 'origin', "refs/tags/$tag", "refs/tags/$tag^{}");
    my %refs = map { my ($sha, $ref) = split /\s+/, $_; ($ref, $sha) } split /\n/, $remote;
    my $remote_commit = $refs{"refs/tags/$tag^{}"} // $refs{"refs/tags/$tag"} // '';
    die "Error: Release tag '$tag' has not been pushed to origin at $commit.\n"
        unless $remote_commit eq $commit;
    print "Verified pushed release $tag at origin/$target ($commit).\n";
    return $commit;
}

sub read_changelog {
    my ($file, $dir, $tag) = @_;
    $file = File::Spec->catfile($dir, "changelog-$tag.md") unless length $file;
    open my $fh, '<:encoding(UTF-8)', $file
        or die "Error: Cannot read required changelog '$file': $!\n";
    my $body = do { local $/; <$fh> };
    close $fh or die "Error: Cannot close changelog '$file': $!\n";
    die "Error: Changelog '$file' is empty.\n" unless defined $body && $body =~ /\S/;
    return ($file, $body);
}

sub json_file {
    my ($data) = @_;
    my ($fh, $path) = tempfile('slackhacks-json-XXXXXX', TMPDIR => 1, UNLINK => 1);
    binmode $fh;
    print {$fh} JSON::PP->new->utf8->canonical->encode($data)
        or die "Error: Cannot write JSON request: $!\n";
    close $fh or die "Error: Cannot close JSON request: $!\n";
    return $path;
}

sub curl_response {
    my (@args) = @_;
    open my $pipe, '-|', 'curl', '-s', '-S', '-w', "\nHTTP_STATUS:%{http_code}", @args
        or die "Error: Cannot execute curl: $!\n";
    my $body = do { local $/; <$pipe> };
    close $pipe or die "Error: curl failed (exit " . ($? >> 8) .
        "). Remote state may have changed; retry to reconcile it.\n";
    die "Error: Missing HTTP status in curl response.\n"
        unless defined $body && $body =~ s/\nHTTP_STATUS:(\d{3})\s*$//;
    return (int($1), $body);
}

sub file_digest {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Error: Cannot read '$path': $!\n";
    my $digest = Digest::SHA->new(256)->addfile($fh)->hexdigest;
    close $fh or die "Error: Cannot close '$path': $!\n";
    return $digest;
}

sub ensure_build {
    my ($script_dir, $zip_path, $commit) = @_;
    my $state_dir = File::Spec->catdir(git_output('rev-parse', '--git-common-dir'), 'slackhacks-deploy');
    make_path($state_dir);
    my $key = sha256_hex(join "\0", $commit, $zip_path, map { $ENV{$_} // '' }
        qw(ADDON_NAME FOLDER_NAME TOC_FILE DIST_DIR ZIP_NAME));
    my $stamp = File::Spec->catfile($state_dir, "build-$key.sha256");
    if (-f $zip_path && -f $stamp) {
        open my $fh, '<', $stamp or die "Error: Cannot read build stamp: $!\n";
        my $digest = <$fh>;
        close $fh;
        if (defined $digest && $digest eq file_digest($zip_path)) {
            print "Reusing verified release archive: $zip_path\n";
            return;
        }
    }
    system('bash', File::Spec->catfile($script_dir, 'build.sh')) == 0
        or die "Error: build.sh failed.\n";
    die "Error: Build output '$zip_path' not found.\n" unless -f $zip_path;
    open my $fh, '>', $stamp or die "Error: Cannot save build stamp: $!\n";
    print {$fh} file_digest($zip_path) or die "Error: Cannot write build stamp: $!\n";
    close $fh or die "Error: Cannot close build stamp: $!\n";
}

1;
