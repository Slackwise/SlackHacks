#!/usr/bin/env perl
# Release and changelog script regression tests.
# Run with: perl scripts/release.t   (or: prove scripts/release.t)
# Requires Perl, Git, Bash, and curl. Uses temporary local repositories and a
# local HTTP server, never publishing credentials or live release APIs.
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(getcwd abs_path);
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode_utf8 decode_utf8);

my $scripts = abs_path($FindBin::Bin);
my $root    = abs_path("$scripts/..");
my $capture = tempdir('slackhacks-capture-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $json    = JSON::PP->new->utf8->canonical;
my %git_env = (
    GIT_AUTHOR_NAME => 'Release Test', GIT_AUTHOR_EMAIL => 'test@example.invalid',
    GIT_COMMITTER_NAME => 'Release Test', GIT_COMMITTER_EMAIL => 'test@example.invalid',
);
# Release notes for the fixture's "## v1" CHANGELOG.md section (a character string).
use constant V1_NOTES => "### Release \"one\"\n\nNotes with caf\x{e9} and \\\\paths.\n";

# Runs a command with captured output, isolated STDIN, and a temporary environment.
# @param %o cmd (array ref), cwd, env (hash ref), unset (array ref), stdin (string), ok (die on failure).
# @return Hash ref with status, stdout, and stderr.
sub run_cmd {
    my (%o) = @_;
    my %saved_env = %ENV;
    my $orig = getcwd();
    my ($out_file, $err_file, $in_file) = map { "$capture/$_" } qw(out err in);
    if (defined $o{stdin}) {
        open my $fh, '>:raw', $in_file or die "Cannot write stdin: $!";
        print {$fh} $o{stdin};
        close $fh;
    }
    $ENV{$_} = $o{env}{$_} for keys %{ $o{env} || {} };
    delete $ENV{$_} for @{ $o{unset} || [] };
    chdir $o{cwd} or die "Cannot chdir to $o{cwd}: $!";
    open my $in_save,  '<&', \*STDIN  or die;
    open my $out_save, '>&', \*STDOUT or die;
    open my $err_save, '>&', \*STDERR or die;
    # Closed/empty STDIN mirrors a non-interactive caller so prompts hit EOF instead of hanging.
    open STDIN, '<', defined $o{stdin} ? $in_file : File::Spec->devnull or die;
    open STDOUT, '>', $out_file or die;
    open STDERR, '>', $err_file or die;
    my $rc = system { $o{cmd}[0] } @{ $o{cmd} };
    open STDIN,  '<&', $in_save  or die;
    open STDOUT, '>&', $out_save or die;
    open STDERR, '>&', $err_save or die;
    chdir $orig;
    %ENV = %saved_env;
    my %result = (
        status => $rc == -1 ? -1 : ($rc & 127) ? 128 + ($rc & 127) : $rc >> 8,
        stdout => slurp($out_file),
        stderr => slurp($err_file),
    );
    die "Command failed (@{ $o{cmd} }): exit $result{status}\n$result{stderr}$result{stdout}"
        if $o{ok} && $result{status} != 0;
    return \%result;
}

# Reads a file as raw bytes.
# @param $path File path.
# @return File contents.
sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read $path: $!";
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data // '';
}

# Writes or appends raw bytes to a file.
# @param $path File path.
# @param $data Bytes to write.
# @param $append True to append.
sub spew {
    my ($path, $data, $append) = @_;
    open my $fh, $append ? '>>:raw' : '>:raw', $path or die "Cannot write $path: $!";
    print {$fh} $data;
    close $fh;
}

# Runs a command with the test git identity.
# @param $cmd Array ref command.
# @param $cwd Working directory.
# @param $ok When true (default), dies on failure.
# @return Result hash ref.
sub run {
    my ($cmd, $cwd, $ok) = @_;
    return run_cmd(cmd => $cmd, cwd => $cwd, ok => $ok // 1,
        env => { %git_env, GIT_CONFIG_NOSYSTEM => '1', GIT_TERMINAL_PROMPT => '0' });
}

# Runs git and returns trimmed stdout.
# @param $cwd Working directory.
# @param @args Git arguments.
# @return Trimmed stdout.
sub git {
    my ($cwd, @args) = @_;
    my $out = run(['git', @args], $cwd)->{stdout};
    $out =~ s/\s+\z//;
    return $out;
}

# Runs Perl code with ReleaseUtil loaded.
# @param $code Perl code.
# @param $cwd Working directory.
# @param $args Array ref of @ARGV values.
# @param $ok When true, dies on failure.
# @return Result hash ref.
sub perl_code {
    my ($code, $cwd, $args, $ok) = @_;
    return run([$^X, '-I', $scripts, '-MReleaseUtil', '-e', $code, @{ $args || [] }], $cwd, $ok);
}

# Runs a script from a fixture repository's scripts directory.
# @param $repo Fixture repository.
# @param $file Script name.
# @param $args Array ref of arguments.
# @param $ok When true (default), dies on failure.
# @return Result hash ref.
sub script {
    my ($repo, $file, $args, $ok) = @_;
    return run([$^X, "scripts/$file", @{ $args || [] }], $repo, $ok // 1);
}

# Returns the current branch name.
# @param $repo Repository path.
# @return Branch name.
sub branch { git($_[0], 'branch', '--show-current') }

# Defines a test whose exceptions are reported as failures rather than aborting the run.
# @param $name Test name.
# @param $code Test body.
sub test {
    my ($name, $code) = @_;
    subtest $name => sub {
        eval { $code->(); 1 } or fail("died: $@");
    };
}

# Creates a repository with a bare origin, a dev branch, a prod branch, and tag v1.
# @return Repository path.
sub fixture {
    my $dir = tempdir('slackhacks-release-XXXXXX', TMPDIR => 1, CLEANUP => 1);
    my ($remote, $repo) = ("$dir/origin.git", "$dir/repo");
    run(['git', 'init', '--bare', $remote], $dir);
    run(['git', 'init', '-b', 'dev', $repo], $dir);
    git($repo, 'remote', 'add', 'origin', $remote);
    spew("$repo/release.txt", 'release');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'release');
    git($repo, 'branch', 'prod');
    git($repo, 'tag', '-a', 'v1', '-m', 'release');
    return $repo;
}

# Copies release scripts into a fixture, optionally redirecting APIs to a local server.
# @param $repo Fixture repository.
# @param $base_url Local API base URL, or undef.
sub prepare_scripts {
    my ($repo, $base_url) = @_;
    git($repo, 'tag', '-d', 'v1');
    make_path("$repo/scripts");
    for my $file (qw(release.pl deploy.sh load-env.sh deploy-github.pl deploy-curseforge.pl
                     ReleaseUtil.pm defaults.env)) {
        my $content = slurp("$scripts/$file");
        if ($base_url) {
            $content =~ s{https://(?:api|uploads)\.github\.com}{$base_url}g;
            $content =~ s{https://wow\.curseforge\.com}{$base_url}g;
        }
        spew("$repo/scripts/$file", $content);
    }
    spew("$repo/.gitignore", "dist/\n");
    spew("$repo/SlackHacks.toc", "## Version: 1\n## Interface: 120000\n");
    spew("$repo/CHANGELOG.md", encode_utf8("# SlackHacks Changelog\n\n## v1\n\n" . V1_NOTES));
    spew("$repo/scripts/build.sh", "#!/usr/bin/env bash\nset -euo pipefail\nmkdir -p dist\n" .
        "printf archive > dist/SlackHacks.zip\necho build >> dist/build-count\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'release scripts');
    git($repo, 'branch', '-f', 'prod', 'HEAD');
    git($repo, 'push', 'origin', 'prod');
}

# ------------------------------------------------------------------------------
# Mock HTTP API: a separate Perl process so synchronous script runs can reach it.
# State lives in a JSON file that the server reloads on every request.
# ------------------------------------------------------------------------------
my $server_code = <<'SERVER';
use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode_utf8);

my $state_file = shift;
my $json = JSON::PP->new->utf8->canonical;
my $server = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0, Listen => 16,
    ReuseAddr => 1, Proto => 'tcp') or die "Cannot listen: $!";
$| = 1;
print $server->sockport, "\n";

sub load { open my $fh, '<:raw', $state_file or die; local $/; my $s = $json->decode(<$fh>); close $fh; $s }
sub save { open my $fh, '>:raw', "$state_file.tmp" or die; print {$fh} $json->encode($_[0]); close $fh;
           rename "$state_file.tmp", $state_file or die }

sub handle {
    my ($s, $method, $url, $headers, $bytes) = @_;
    if ($s->{mode} eq 'echo') {
        $s->{last} = { method => $method, content_type => $headers->{'content-type'},
                       json => $json->decode($bytes) };
        return (201, { id => 1 });
    }
    if ($url =~ m{/releases/tags/v1$}) {
        return $s->{release} ? (200, $s->{release}) : (404, { message => 'Not Found' });
    }
    if ($url =~ m{/releases$} && $method eq 'POST') {
        $s->{creates}++;
        $s->{release} = { %{ $json->decode($bytes) }, id => 10, html_url => 'test-release' };
        return (201, $s->{release});
    }
    if ($url =~ m{/releases/10$} && $method eq 'PATCH') {
        $s->{patches}++;
        $s->{release} = { %{ $s->{release} }, %{ $json->decode($bytes) } };
        return (200, $s->{release});
    }
    if ($url =~ m{/releases/10/assets\?} && $method eq 'GET') {
        return (200, $s->{assets});
    }
    if ($url =~ m{/releases/10/assets\?} && $method eq 'POST') {
        return (500, { error => 'upload failed' }) if $s->{uploadFail};
        $s->{uploads}++;
        my $asset = { id => 11, name => 'SlackHacks.zip', state => 'uploaded',
                      size => length $bytes, digest => 'sha256:' . sha256_hex($bytes) };
        push @{ $s->{assets} }, $asset;
        return (201, $asset);
    }
    if ($url =~ m{/releases/assets/11$} && $method eq 'DELETE') {
        return (403, { error => 'delete failed' }) if $s->{deleteFail};
        $s->{deletes}++;
        $s->{assets} = [];
        return (204, undef);
    }
    return (200, [{ id => 1, name => 'Retail' }]) if $url =~ m{/api/game/version-types$};
    return (200, [{ id => 12, name => '12.0.0', gameVersionTypeID => 1 }]) if $url =~ m{/api/game/versions$};
    if ($url =~ m{/upload-file$}) {
        $s->{cfUploads}++;
        my $needle = encode_utf8(qq{"changelog":"### Release \\"one\\"\\n\\nNotes with caf\x{e9}});
        push @{ $s->{errors} }, 'multipart metadata part missing' unless $bytes =~ /name="metadata"/;
        push @{ $s->{errors} }, 'multipart changelog not preserved' if index($bytes, $needle) < 0;
        return $s->{cfFail} ? (500, { error => 'uncertain' }) : (200, { id => 22 });
    }
    push @{ $s->{errors} }, "Unexpected request $method $url";
    return (500, { error => "Unexpected request $method $url" });
}

while (my $c = $server->accept) {
    binmode $c;
    my $line = <$c>;
    next unless defined $line;
    my ($method, $url) = $line =~ /^(\S+)\s+(\S+)/;
    my %headers;
    while (my $h = <$c>) {
        $h =~ s/\r?\n\z//;
        last if $h eq '';
        my ($k, $v) = split /:\s*/, $h, 2;
        $headers{lc $k} = $v;
    }
    # curl waits for 100 Continue before sending larger bodies.
    print {$c} "HTTP/1.1 100 Continue\r\n\r\n" if ($headers{expect} // '') =~ /100-continue/i;
    my $bytes = '';
    if (($headers{'transfer-encoding'} // '') =~ /chunked/i) {
        while (defined(my $size = <$c>)) {
            $size = hex $size;
            last unless $size;
            read($c, my $chunk, $size);
            $bytes .= $chunk;
            <$c>;
        }
        <$c>;
    } else {
        my $len = $headers{'content-length'} // 0;
        while (length $bytes < $len) {
            my $n = read($c, my $buf, $len - length $bytes);
            last unless $n;
            $bytes .= $buf;
        }
    }
    my $s = load();
    my ($status, $data) = eval { handle($s, $method, $url, \%headers, $bytes) };
    ($status, $data) = (500, { error => "$@" }) unless defined $status;
    save($s);
    my $payload = defined $data ? $json->encode($data) : '';
    print {$c} "HTTP/1.1 $status Mock\r\nContent-Type: application/json\r\n" .
        "Content-Length: " . length($payload) . "\r\nConnection: close\r\n\r\n$payload";
    close $c;
}
SERVER

my (@servers, @server_pipes);
# Kill servers before File::Temp cleanup; closing a live pipe would wait for the child forever.
END { kill 'KILL', $_ for @servers; }

# Starts the mock server with initial state.
# @param $state Initial state hash ref.
# @return (base_url, state_file).
sub start_server {
    my ($state) = @_;
    my $dir = tempdir('slackhacks-server-XXXXXX', TMPDIR => 1, CLEANUP => 1);
    spew("$dir/server.pl", $server_code);
    spew("$dir/state.json", $json->encode($state));
    my $pid = open my $out, '-|', $^X, "$dir/server.pl", "$dir/state.json"
        or die "Cannot start mock server: $!";
    push @servers, $pid;
    push @server_pipes, $out;
    my $port = <$out>;
    die "Mock server did not start\n" unless defined $port && $port =~ /^(\d+)/;
    return ("http://127.0.0.1:$1", "$dir/state.json");
}

# Reads mock server state.
sub state_of { $json->decode(slurp($_[0])) }

# Applies a change to mock server state while the server is idle.
# @param $file State file.
# @param $change Code ref receiving the state hash ref.
sub update_state {
    my ($file, $change) = @_;
    my $s = state_of($file);
    $change->($s);
    spew($file, $json->encode($s));
}

# ==============================================================================
# Tests
# ==============================================================================

test 'Perl and Bash entry points pass syntax checks' => sub {
    for my $file (qw(ReleaseUtil.pm ChangelogUtil.pm release.pl deploy-github.pl
                     deploy-curseforge.pl bump.pl changelog.pl)) {
        is(run([$^X, '-I', $scripts, '-c', "$scripts/$file"], $root, 0)->{status}, 0, $file);
    }
    for my $file (qw(deploy.sh build.sh)) {
        is(run(['bash', '-n', "$scripts/$file"], $root, 0)->{status}, 0, $file);
    }
};

test 'deployment requires a clean checkout and matching pushed prod tip and tag' => sub {
    my $repo = fixture();
    my $verify = sub { perl_code('ReleaseUtil::verify_release("v1", "prod")', $repo, [], 0) };
    isnt($verify->()->{status}, 0, 'unpushed release must fail');
    git($repo, 'push', 'origin', 'prod');
    isnt($verify->()->{status}, 0, 'unpushed tag must fail');
    git($repo, 'push', 'origin', 'v1');
    is($verify->()->{status}, 0, 'pushed release verifies');
    is($verify->()->{status}, 0, 'verification is repeatable');
    spew("$repo/dirty.txt", 'dirty');
    isnt($verify->()->{status}, 0, 'untracked files must fail');
    unlink "$repo/dirty.txt";
    spew("$repo/release.txt", 'changed', 1);
    isnt($verify->()->{status}, 0, 'tracked changes must fail');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'new work');
    isnt($verify->()->{status}, 0, 'different HEAD must fail');
    git($repo, 'branch', '-f', 'prod', 'HEAD');
    git($repo, 'push', 'origin', 'prod');
    git($repo, 'checkout', 'v1');
    isnt($verify->()->{status}, 0, 'old release must not roll back prod');
};

test 'lightweight pushed tags are supported; mismatched remote tags are rejected' => sub {
    my $repo = fixture();
    git($repo, 'tag', 'v2');
    git($repo, 'push', 'origin', 'prod', 'v2');
    is(perl_code('ReleaseUtil::verify_release("v2", "prod")', $repo, [], 0)->{status}, 0);
    spew("$repo/release.txt", 'next', 1);
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'next');
    git($repo, 'tag', '-f', 'v2');
    git($repo, 'branch', '-f', 'prod', 'HEAD');
    git($repo, 'push', 'origin', 'prod');
    isnt(perl_code('ReleaseUtil::verify_release("v2", "prod")', $repo, [], 0)->{status}, 0);
};

test 'changelog notes preserve quotes, newlines, backslashes and UTF-8 through curl' => sub {
    my $dir = tempdir('slackhacks-json-XXXXXX', TMPDIR => 1, CLEANUP => 1);
    my $changelog = "### Release\r\n\"Quotes\", \\\\paths\\\\, tabs\tand caf\x{e9} \x{2603}\n";
    spew("$dir/CHANGELOG.md", encode_utf8("# Changelog\r\n\r\n## v2\r\n\r\nnewer\r\n\r\n" .
        "## v1\r\n\r\n$changelog\r\n## v0\r\n\r\nolder\r\n"));
    my ($url, $state_file) = start_server({ mode => 'echo' });
    my $code = <<'CODE';
my ($file, $body) = ReleaseUtil::read_changelog("$ARGV[0]/CHANGELOG.md", "v1");
my $json = ReleaseUtil::json_file({body => $body, generate_release_notes => JSON::PP::false});
my ($status, $response) = ReleaseUtil::curl_response("-H", "Content-Type: application/json",
    "--data-binary", "\@$json", $ARGV[1]);
die "$status: $response" unless $status == 201;
CODE
    my $result = perl_code($code, $dir, [$dir, $url], 0);
    is($result->{status}, 0, 'request succeeded') or diag $result->{stderr};
    my $last = state_of($state_file)->{last};
    (my $expected = $changelog) =~ s/\r\n/\n/g;
    (my $received = $last->{json}{body} // '') =~ s/\r\n/\n/g;
    is($received, $expected, 'only the v1 section body round-trips');
    ok(JSON::PP::is_bool($last->{json}{generate_release_notes}) && !$last->{json}{generate_release_notes},
        'generate_release_notes is false');
    is($last->{content_type}, 'application/json');
    my $read = sub { perl_code('ReleaseUtil::read_changelog("$ARGV[0]/CHANGELOG.md", "v1")', $dir, [$dir], 0) };
    spew("$dir/CHANGELOG.md", "# Changelog\n\n## v1\n\n## v0\n\nolder\n");
    isnt($read->()->{status}, 0, 'empty section fails');
    spew("$dir/CHANGELOG.md", "# Changelog\n\n## v10\n\nnotes\n");
    isnt($read->()->{status}, 0, 'missing section fails (v10 is not v1)');
    spew("$dir/CHANGELOG.md", "# Changelog\n\n## v1 - 2025-01-01\n\nnotes\n");
    is($read->()->{status}, 0, 'section heading may carry a date');
    isnt(perl_code('ReleaseUtil::read_changelog("missing.md", "v1")', $dir, [], 0)->{status}, 0,
        'missing changelog fails');
};

test 'release errors and EOF return to dev even when started on another branch' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    git($repo, 'checkout', '-b', 'release-work');
    script($repo, 'release.pl', ['--no-push']);
    is(branch($repo), 'dev');

    git($repo, 'checkout', 'prod');
    my $early = script($repo, 'release.pl', [], 0);
    isnt($early->{status}, 0);
    like($early->{stderr}, qr/already 'prod'/);
    is(branch($repo), 'dev');

    git($repo, 'checkout', 'release-work');
    spew("$repo/SlackHacks.toc", "## Version: 2\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'missing changelog');
    my $eof = script($repo, 'release.pl', [], 0);
    isnt($eof->{status}, 0);
    like($eof->{stderr}, qr/No response received/);
    is(branch($repo), 'dev');

    git($repo, 'checkout', 'release-work');
    my $preview = script($repo, 'release.pl', ['--dry-run'], 0);
    isnt($preview->{status}, 0);
    is(branch($repo), 'release-work');
};

test 'a conflicted release merge is aborted before returning to dev' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    spew("$repo/release.txt", 'dev change');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'dev change');
    my $dev = git($repo, 'rev-parse', 'dev');
    git($repo, 'checkout', 'prod');
    spew("$repo/release.txt", 'prod change');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'prod change');
    git($repo, 'push', 'origin', 'prod');
    git($repo, 'checkout', 'dev');
    my $result = script($repo, 'release.pl', ['--no-push'], 0);
    isnt($result->{status}, 0);
    like($result->{stderr}, qr/Command failed/);
    is(branch($repo), 'dev');
    is(git($repo, 'rev-parse', 'dev'), $dev);
    is(git($repo, 'status', '--porcelain'), '');
    ok(!-e "$repo/.git/MERGE_HEAD", 'merge aborted');
};

test 'deployment failure returns to dev rather than the caller branch' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    git($repo, 'checkout', '-b', 'release-work');
    spew("$repo/scripts/deploy.sh", "#!/usr/bin/env bash\nexit 97\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'failing deployment');
    my $result = script($repo, 'release.pl', [], 0);
    isnt($result->{status}, 0);
    like($result->{stderr}, qr/exit code 97/);
    is(branch($repo), 'dev');
};

test 'blocked recovery reports failure without discarding working changes' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    git($repo, 'checkout', '-b', 'release-work');
    spew("$repo/release.txt", 'branch change');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'branch change');
    spew("$repo/release.txt", 'unsaved work');
    my $result = script($repo, 'release.pl', [], 0);
    isnt($result->{status}, 0);
    like($result->{stderr}, qr/uncommitted changes/);
    like($result->{stderr}, qr/Could not return to branch 'dev'/);
    is(branch($repo), 'release-work');
    is(slurp("$repo/release.txt"), 'unsaved work');
};

test 'cleanup failure makes an otherwise successful exit fail' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    git($repo, 'branch', '-m', 'dev', 'release-work');
    my $result = script($repo, 'release.pl', ['--help'], 0);
    isnt($result->{status}, 0);
    like($result->{stderr}, qr/Could not return to branch 'dev'/);
};

for my $signal (qw(SIGINT SIGTERM SIGHUP)) {
    test "input interrupted by $signal returns to dev" => sub {
        my $repo = fixture();
        prepare_scripts($repo);
        git($repo, 'checkout', '-b', 'release-work');
        spew("$repo/CHANGELOG.md", "# SlackHacks Changelog\n");
        # Deliver the signal from inside Perl when release.pl reads its prompt answer.
        spew("$repo/scripts/ReleaseTestInterrupt.pm",
            "package ReleaseTestInterrupt;\n" .
            "sub TIEHANDLE { bless {}, shift }\n" .
            "sub READLINE { kill \$ENV{RELEASE_TEST_SIGNAL}, \$\$; die \"Signal was not handled\\n\"; }\n" .
            "INIT { tie *STDIN, __PACKAGE__; }\n1;\n");
        git($repo, 'add', '.');
        git($repo, 'commit', '-m', 'missing changelog');
        my $result = run_cmd(cmd => [$^X, 'scripts/release.pl'], cwd => $repo,
            env => { PERL5LIB => "$repo/scripts", PERL5OPT => '-MReleaseTestInterrupt',
                     RELEASE_TEST_SIGNAL => $signal });
        like($result->{stdout}, qr/Run bump.pl now/);
        isnt($result->{status}, 0);
        like($result->{stderr}, qr/Release interrupted/);
        is(branch($repo), 'dev');
    };
}

test 'local-only releases resume without retagging, deploying, or hiding new changes' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    spew("$repo/scripts/deploy.sh", "#!/usr/bin/env bash\nexit 97\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'deployment must not run');
    git($repo, 'checkout', 'prod');
    spew("$repo/prod-only.txt", 'production history');
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'production-only commit');
    git($repo, 'checkout', 'dev');
    script($repo, 'release.pl', ['--no-push']);
    my $tag = git($repo, 'rev-parse', 'v1');
    is(scalar(split ' ', git($repo, 'rev-list', '--parents', '-n', '1', 'v1')), 3, 'release is a merge');
    script($repo, 'release.pl', ['--no-push']);
    is(git($repo, 'rev-parse', 'v1'), $tag);
    is(branch($repo), 'dev');
    is(git($repo, 'ls-remote', '--tags', 'origin', 'v1'), '');
    spew("$repo/release.txt", 'next', 1);
    my $dirty = script($repo, 'release.pl', ['--force'], 0);
    isnt($dirty->{status}, 0);
    like($dirty->{stderr}, qr/uncommitted changes/);
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'new work without bump');
    my $changed = script($repo, 'release.pl', ['--dry-run'], 0);
    isnt($changed->{status}, 0);
    like($changed->{stderr}, qr/unreleased changes/);
    is(git($repo, 'rev-parse', 'v1'), $tag);
};

test 'release deploys pushed prod, restores dev on failure, and retries the same tag' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    spew("$repo/scripts/deploy.sh", "#!/usr/bin/env bash\nset -eu\n" .
        "test \"\$(git branch --show-current)\" = prod\n" .
        "test \"\$(git rev-parse HEAD)\" = \"\$(git ls-remote origin refs/heads/prod | cut -f1)\"\n" .
        "git ls-remote --exit-code --tags origin refs/tags/v1\nexit 97\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'failing deployment');
    my $first = script($repo, 'release.pl', [], 0);
    isnt($first->{status}, 0);
    like($first->{stderr}, qr/exit code 97/);
    is(branch($repo), 'dev');
    my $tag = git($repo, 'rev-parse', 'v1');
    my $second = script($repo, 'release.pl', [], 0);
    isnt($second->{status}, 0);
    like($second->{stdout}, qr/Resuming existing release/);
    like($second->{stderr}, qr/exit code 97/);
    is(git($repo, 'rev-parse', 'v1'), $tag);
    is(branch($repo), 'dev');
};

test 're-release refuses older versions, dirty trees, and concurrent remote tag changes' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    spew("$repo/scripts/deploy.sh", "#!/usr/bin/env bash\nexit 0\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'test deployment');
    script($repo, 'release.pl', ['--rerelease']);
    my $old_tag  = git($repo, 'rev-parse', 'v1');
    my $old_prod = git($repo, 'rev-parse', 'prod');
    spew("$repo/release.txt", 'more features', 1);
    my $dirty = script($repo, 'release.pl', ['--rerelease'], 0);
    isnt($dirty->{status}, 0);
    like($dirty->{stderr}, qr/uncommitted changes/);
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'new features');
    git($repo, 'tag', 'v2');
    my $older = script($repo, 'release.pl', ['--rerelease', '--dry-run'], 0);
    isnt($older->{status}, 0);
    like($older->{stderr}, qr/latest tagged version 2/);
    git($repo, 'tag', '-d', 'v2');
    # A hook simulates a second publisher changing the tag after release.pl snapshots it.
    my $hook = "$repo/.git/hooks/pre-push";
    spew($hook, "#!/usr/bin/env bash\nset -eu\n" .
        "while read -r local_ref local_sha remote_ref remote_sha; do\n" .
        "  if [[ \"\$remote_ref\" = refs/heads/prod ]]; then git --git-dir=../origin.git update-ref refs/tags/v1 $old_prod; fi\n" .
        "done\n");
    chmod 0755, $hook;
    my $raced = script($repo, 'release.pl', ['--rerelease'], 0);
    isnt($raced->{status}, 0);
    like($raced->{stderr}, qr/stale info|atomic transaction failed/);
    like(git($repo, 'ls-remote', '--refs', 'origin', 'refs/heads/prod'), qr/^\Q$old_prod\E/);
    like(git($repo, 'ls-remote', '--refs', 'origin', 'refs/tags/v1'), qr/^\Q$old_prod\E/);
    is(branch($repo), 'dev');
    my $revised_tag = git($repo, 'rev-parse', 'v1');
    isnt($revised_tag, $old_tag);
    unlink $hook;
    script($repo, 'release.pl', ['--rerelease']);
    is(git($repo, 'rev-parse', 'v1'), $revised_tag);
    like(git($repo, 'ls-remote', '--refs', 'origin', 'refs/tags/v1'), qr/^\Q$revised_tag\E/);
};

test 'deployers reconcile GitHub releases and guard completed or uncertain CurseForge uploads' => sub {
    my ($url, $state_file) = start_server({ mode => 'deploy', release => undef, assets => [],
        creates => 0, patches => 0, uploads => 0, deletes => 0, cfUploads => 0,
        cfFail => 0, uploadFail => 0, deleteFail => 0, errors => [] });
    my @defaults = slurp("$scripts/defaults.env") =~ /^([A-Z_]+)=/mg;
    # Deployers run without the test git config isolation, mirroring a developer shell.
    my $deployer = sub {
        my ($repo, $file, $args) = @_;
        return run_cmd(cmd => [$^X, "scripts/$file", @{ $args || [] }], cwd => $repo, unset => \@defaults,
            env => { %git_env, GITHUB_TOKEN => 'test-token', CURSEFORGE_API_TOKEN => 'test-token' });
    };
    my $deploy = sub {
        my $result = $deployer->(@_);
        is($result->{status}, 0, "deploy $_[1] @{ $_[2] || [] }") or diag "$result->{stderr}$result->{stdout}";
        return $result;
    };
    my $state = sub { state_of($state_file) };

    my $repo = fixture();
    prepare_scripts($repo, $url);
    git($repo, 'tag', '-a', 'v1', '-m', 'release');
    for my $file (qw(deploy-github.pl deploy-curseforge.pl)) {
        isnt($deployer->($repo, $file, ['--dry-run'])->{status}, 0, "unpushed tag blocks $file");
    }
    ok(!-e "$repo/dist", 'no build before verification');
    git($repo, 'push', 'origin', 'v1');
    $deploy->($repo, $_, ['--dry-run']) for qw(deploy-github.pl deploy-curseforge.pl);
    ok(!-e "$repo/dist", 'dry runs must not build');
    is($state->()->{creates} + $state->()->{cfUploads}, 0);
    $deploy->($repo, 'deploy-github.pl');
    $deploy->($repo, 'deploy-github.pl');
    is($state->()->{creates}, 1);
    is($state->()->{uploads}, 1);
    my $release = $state->()->{release};
    ok(JSON::PP::is_bool($release->{generate_release_notes}) && !$release->{generate_release_notes});
    is($release->{body}, V1_NOTES, 'release notes are the v1 section body');
    update_state($state_file, sub { $_[0]{release}{body} = 'old notes' });
    $deploy->($repo, 'deploy-github.pl');
    is($state->()->{patches}, 1);
    is($state->()->{uploads}, 1);
    update_state($state_file, sub { $_[0]{assets}[0]{digest} = 'sha256:different' });
    my $conflict = $deployer->($repo, 'deploy-github.pl');
    isnt($conflict->{status}, 0);
    like($conflict->{stderr}, qr/Refusing to replace/);
    is($state->()->{uploads}, 1);

    $deploy->($repo, 'deploy-curseforge.pl');
    $deploy->($repo, 'deploy-curseforge.pl');
    is($state->()->{cfUploads}, 1);
    is(slurp("$repo/dist/build-count"), "build\n");
    update_state($state_file, sub { $_[0]{assets}[0]{digest} = 'sha256:' . sha256_hex('archive') });
    my $retry = $deploy->($repo, 'release.pl');
    like($retry->{stdout}, qr/Resuming existing release/);
    is(branch($repo), 'dev');
    is($state->()->{creates}, 1);
    is($state->()->{uploads}, 1);
    is($state->()->{cfUploads}, 1);

    my $old_tag = git($repo, 'rev-parse', 'v1');
    spew("$repo/release.txt", 'more features', 1);
    (my $build = slurp("$repo/scripts/build.sh")) =~ s/printf archive/printf revised/;
    spew("$repo/scripts/build.sh", $build);
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'more features for same version');
    my $preview = $deploy->($repo, 'release.pl', ['--rerelease', '--dry-run']);
    like($preview->{stdout}, qr{--force-with-lease=refs/tags/v1:});
    is(git($repo, 'rev-parse', 'v1'), $old_tag);
    is($state->()->{uploads}, 1, 'dry run must not replace published files');
    $deploy->($repo, 'release.pl', ['--rerelease', '--no-push']);
    my $revised_tag = git($repo, 'rev-parse', 'v1');
    isnt($revised_tag, $old_tag);
    like(git($repo, 'ls-remote', '--refs', 'origin', 'refs/tags/v1'), qr/^\Q$old_tag\E/);
    $deploy->($repo, 'release.pl', ['--rerelease']);
    is(git($repo, 'rev-parse', 'v1'), $revised_tag, 'resume must not recreate tag object');
    is($state->()->{deletes}, 1);
    is($state->()->{uploads}, 2);
    is($state->()->{cfUploads}, 2);
    $deploy->($repo, 'release.pl', ['--rerelease']);
    $deploy->($repo, 'release.pl');
    is($state->()->{deletes}, 1);
    is($state->()->{uploads}, 2);
    is($state->()->{cfUploads}, 2, 'same revision must not be uploaded twice');
    is(branch($repo), 'dev');

    git($repo, 'checkout', 'prod');
    update_state($state_file, sub { $_[0]{assets}[0]{digest} = 'sha256:old'; $_[0]{deleteFail} = 1 });
    my $delete_failure = $deployer->($repo, 'deploy-github.pl', ['--rerelease']);
    isnt($delete_failure->{status}, 0);
    like($delete_failure->{stderr}, qr/Cannot remove existing asset/);
    is($state->()->{uploads}, 2);
    update_state($state_file, sub { $_[0]{deleteFail} = 0; $_[0]{uploadFail} = 1 });
    isnt($deployer->($repo, 'deploy-github.pl', ['--rerelease'])->{status}, 0);
    is(scalar @{ $state->()->{assets} }, 0);
    update_state($state_file, sub { $_[0]{uploadFail} = 0 });
    $deploy->($repo, 'deploy-github.pl', ['--rerelease']);
    $deploy->($repo, 'deploy-github.pl', ['--rerelease']);
    is($state->()->{uploads}, 3, 'retry after deletion must recover missing asset once');

    my $other = fixture();
    prepare_scripts($other, $url);
    git($other, 'tag', '-a', 'v1', '-m', 'release');
    git($other, 'push', 'origin', 'v1');
    update_state($state_file, sub { $_[0]{cfFail} = 1 });
    isnt($deployer->($other, 'deploy-curseforge.pl')->{status}, 0);
    my $pending = $deployer->($other, 'deploy-curseforge.pl');
    isnt($pending->{status}, 0);
    like($pending->{stderr}, qr/pending or uncertain/);
    my $forced = $deployer->($other, 'deploy-curseforge.pl', ['--rerelease']);
    isnt($forced->{status}, 0);
    like($forced->{stderr}, qr/pending or uncertain/);
    is($state->()->{cfUploads}, 3, 'uncertain upload must not be repeated');
    is_deeply($state->()->{errors}, [], 'mock server saw only expected requests');
};

# ------------------------------------------------------------------------------
# bump.pl / changelog.pl
# ------------------------------------------------------------------------------

# Creates a repository with the changelog scripts, TOC version 1, and tag v1.
# @return Repository path.
sub changelog_fixture {
    my $repo = fixture();
    make_path("$repo/scripts");
    spew("$repo/scripts/$_", slurp("$scripts/$_"))
        for qw(bump.pl changelog.pl ChangelogUtil.pm ReleaseUtil.pm defaults.env);
    spew("$repo/SlackHacks.toc", "## Interface: 120000\n## Version: 1\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'scripts');
    git($repo, 'tag', '-f', '-a', 'v1', '-m', 'release');
    return $repo;
}

# Commits a change with the given subject.
# @param $repo Repository path.
# @param $subject Commit subject.
sub commit_change {
    my ($repo, $subject) = @_;
    spew("$repo/release.txt", "$subject\n", 1);
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', $subject);
}

# Runs a changelog script with optional STDIN answers.
# @param $repo Repository path.
# @param $file Script name.
# @param $args Array ref of arguments.
# @param $stdin STDIN text, or undef for EOF.
# @return Result hash ref.
sub changelog_script {
    my ($repo, $file, $args, $stdin) = @_;
    return run_cmd(cmd => [$^X, "scripts/$file", '--no-open', @{ $args || [] }], cwd => $repo,
        stdin => $stdin, env => \%git_env);
}

test 'bump.pl asks to generate a changelog (default yes) and whether to use Copilot' => sub {
    my $repo = changelog_fixture();
    commit_change($repo, 'Minimap: fix zoom');
    my $result = changelog_script($repo, 'bump.pl', [], "\nn\n");
    is($result->{status}, 0) or diag $result->{stderr};
    like($result->{stdout}, qr/Generate changelog .*\[Y\/n\]/);
    like($result->{stdout}, qr/Use Copilot to generate the changelog\? \[y\/n\]/);
    like(slurp("$repo/SlackHacks.toc"), qr/## Version: 2/);
    my $v2 = "## v2\n\n### Minimap\n- Fix zoom\n";
    is(slurp("$repo/CHANGELOG.md"), "# SlackHacks Changelog\n\n$v2");

    my $declined = changelog_script($repo, 'bump.pl', [], "n\n");
    is($declined->{status}, 0) or diag $declined->{stderr};
    like(slurp("$repo/SlackHacks.toc"), qr/## Version: 3/);
    unlike(slurp("$repo/CHANGELOG.md"), qr/## v3/, 'declined section is not created');

    my $invalid = changelog_script($repo, 'bump.pl', [], "\nmaybe\n");
    isnt($invalid->{status}, 0, 'Copilot question requires an explicit answer');
    like(slurp("$repo/SlackHacks.toc"), qr/## Version: 3/, 'aborted prompt leaves TOC untouched');

    my $existing = "# SlackHacks Changelog\n\n## v4\n\ncustom\n\n$v2";
    spew("$repo/CHANGELOG.md", $existing);
    my $skipped = changelog_script($repo, 'bump.pl', [], undef);
    is($skipped->{status}, 0, 'existing section needs no prompt') or diag $skipped->{stderr};
    is(slurp("$repo/CHANGELOG.md"), $existing);

    my $blank = changelog_script($repo, 'bump.pl', ['--blank'], undef);
    is($blank->{status}, 0) or diag $blank->{stderr};
    is(slurp("$repo/CHANGELOG.md"), "# SlackHacks Changelog\n\n## v5\n\n## v4\n\ncustom\n\n$v2",
        'new sections are inserted above older releases');
};

test 'changelog.pl offers a bump (default yes), then appends only new commits' => sub {
    my $repo = changelog_fixture();
    commit_change($repo, 'Minimap: fix zoom');
    isnt(changelog_script($repo, 'changelog.pl', ['--no-copilot'], undef)->{status}, 0,
        'unanswered bump prompt aborts');
    my $created = changelog_script($repo, 'changelog.pl', ['--no-copilot'], "\n");
    is($created->{status}, 0) or diag $created->{stderr};
    like($created->{stdout}, qr/Bump the version to 2\? \[Y\/n\]/);
    like(slurp("$repo/SlackHacks.toc"), qr/## Version: 2/);
    is(slurp("$repo/CHANGELOG.md"), "# SlackHacks Changelog\n\n## v2\n\n### Minimap\n- Fix zoom\n");

    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'Bump to v2');
    commit_change($repo, 'Minimap: add border');
    commit_change($repo, 'Bags: sort items');
    my $appended = changelog_script($repo, 'changelog.pl', [], "n\n");
    is($appended->{status}, 0) or diag $appended->{stderr};
    unlike($appended->{stdout}, qr/Bump the version/, 'unreleased version is not bumped');
    like($appended->{stdout}, qr/Appending to existing '## v2' section/);
    is(slurp("$repo/CHANGELOG.md"), "# SlackHacks Changelog\n\n## v2\n\n" .
        "### Minimap\n- Fix zoom\n- Add border\n\n### Bags\n- Sort items\n");

    my $again = changelog_script($repo, 'changelog.pl', ['--no-copilot'], undef);
    is($again->{status}, 0) or diag $again->{stderr};
    like($again->{stdout}, qr/No new commits/);

    # A later commit that only edits another release's section must not hide earlier
    # commits from the next append.
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'Changelog for v2');
    commit_change($repo, 'Bags: fix count');
    spew("$repo/CHANGELOG.md", slurp("$repo/CHANGELOG.md") . "\n## v1\n\n- Old notes\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'Docs: add v1 notes');
    my $later = changelog_script($repo, 'changelog.pl', ['--no-copilot'], undef);
    is($later->{status}, 0) or diag $later->{stderr};
    like(slurp("$repo/CHANGELOG.md"), qr/### Bags\n- Sort items\n- Fix count\n/,
        'commits before an unrelated section edit are still appended');
    like(slurp("$repo/CHANGELOG.md"), qr/\n## v1\n\n- Old notes\n\z/, 'other sections are untouched');

    git($repo, 'tag', 'v2');
    my $kept = changelog_script($repo, 'changelog.pl', ['--no-copilot', '--dry-run'], "no\n");
    is($kept->{status}, 0) or diag $kept->{stderr};
    like($kept->{stdout}, qr/Keeping version 2/);
    like(slurp("$repo/SlackHacks.toc"), qr/## Version: 2/);
};

test 'release.pl requires a non-empty section for the TOC version' => sub {
    my $repo = fixture();
    prepare_scripts($repo);
    spew("$repo/SlackHacks.toc", "## Version: 2\n## Interface: 120000\n");
    spew("$repo/CHANGELOG.md", "# SlackHacks Changelog\n\n## v2\n\n## v1\n\nold\n");
    git($repo, 'add', '.');
    git($repo, 'commit', '-m', 'empty v2 section');
    my $result = script($repo, 'release.pl', [], 0);
    isnt($result->{status}, 0);
    like($result->{stdout} . $result->{stderr}, qr/non-empty '## v2' section is required/);
};

test 'build.sh does not package CHANGELOG.md' => sub {
    my $repo = tempdir('slackhacks-build-XXXXXX', TMPDIR => 1, CLEANUP => 1);
    run(['git', 'init', '-q', $repo], $repo);
    make_path("$repo/scripts");
    spew("$repo/scripts/$_", slurp("$scripts/$_")) for qw(build.sh load-env.sh defaults.env);
    spew("$repo/SlackHacks.toc", "## Version: 1\n## Interface: 120000\n");
    spew("$repo/Core.lua", "-- core\n");
    spew("$repo/CHANGELOG.md", "# SlackHacks Changelog\n\n## v1\n\nnotes\n");
    my $result = run(['bash', 'scripts/build.sh'], $repo, 0);
    is($result->{status}, 0, 'build succeeds') or diag $result->{stdout} . $result->{stderr};
    ok(-f "$repo/dist/SlackHacks/Core.lua", 'addon files are staged');
    ok(!-e "$repo/dist/SlackHacks/CHANGELOG.md", 'CHANGELOG.md is not staged');
};

done_testing();
