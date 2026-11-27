use strict;
use warnings;
use Test::More;
use FindBin;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use lib $FindBin::Bin;
use ReleaseUtil qw(git_output);

sub write_file {
    my ($path, $contents) = @_;
    open my $fh, '>:raw', $path or die "Cannot write '$path': $!";
    print {$fh} $contents or die "Cannot write '$path': $!";
    close $fh or die "Cannot close '$path': $!";
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read '$path': $!";
    my $contents = do { local $/; <$fh> };
    close $fh or die "Cannot close '$path': $!";
    return $contents;
}

sub decode_records {
    my ($generated) = @_;
    my ($data) = $generated =~ /IconNames = \{ compressed = true, data = \[==\[\n(.*?)\]==\] \}/s;
    die "Cannot find compressed icon data" unless defined $data;
    my ($id, $name) = (0, '');
    my @records;
    for my $line (split /\n/, $data) {
        my ($delta, $flags, $prefix, $suffix) = $line =~ /^(\d+)\|(\d+)\|(\d+)\|([^\r\n]*)$/
            or die "Invalid compressed icon record: $line";
        die "Invalid name prefix length" if $prefix > length($name);
        $suffix =~ s/~$//;
        $id += $delta;
        $name = substr($name, 0, $prefix) . $suffix;
        push @records, "$id|$flags|$name";
    }
    return @records;
}

my $temp = tempdir('slackhacks-icon-names-XXXXXX', TMPDIR => 1, CLEANUP => 1);
make_path("$temp/scripts", "$temp/dist/LibRPMedia");
copy("$FindBin::Bin/$_", "$temp/scripts/$_") or die $!
    for qw(update-icon-names.pl ReleaseUtil.pm);
my %fixtures = (
    Standard => [ '100,100,200,201,67108865', '"shared_ico","shared_icon","retail_tbc","retail_tbc","atlas"' ],
    Forever => [ '100,300', '"shared_icon","forever icon "' ],
    Mists => [ '400', '"mists_icon"' ],
    TBC => [ '200', '"retail_tbc"' ],
    Vanilla => [ '500', '"vanilla_icon"' ],
);
for my $flavor (keys %fixtures) {
    my ($ids, $names) = @{ $fixtures{$flavor} };
    my $count = scalar split /,/, $ids;
    write_file("$temp/dist/LibRPMedia/LibRPMediaData_$flavor.lua",
        "size = $count,\ndb_icons_id = {$ids};\ndb_icons_name = {$names};\n");
}
write_file("$temp/LibRPMedia-version.txt", "unchanged\n");
my $offline_mock = "$temp/offline-mock";
make_path($offline_mock);
for my $command (qw(curl git)) {
    write_file("$offline_mock/$command", "#!/bin/sh\nprintf called >> \"\$ICON_OFFLINE_LOG\"\nexit 1\n");
    chmod 0755, "$offline_mock/$command" or die $!;
}
{
    local $ENV{PATH} = "$offline_mock:$ENV{PATH}";
    local $ENV{ICON_OFFLINE_LOG} = "$temp/offline.log";
    is(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0,
        'extractor works without a network update');
    ok(!-e $ENV{ICON_OFFLINE_LOG}, 'offline extraction does not invoke Git or curl');
}
is(read_file("$temp/LibRPMedia-version.txt"), "unchanged\n", 'offline extraction does not change the recorded revision');
my $result = read_file("$temp/IconNames.lua");
my @records = decode_records($result);
is_deeply(\@records, [
    '100|1|shared_ico', '100|3|shared_icon', '200|9|retail_tbc',
    '201|1|retail_tbc', '300|2|forever icon ', '400|4|mists_icon', '500|16|vanilla_icon',
], 'compressed records preserve IDs, flags, shared prefixes, repeated names and trailing spaces');
is(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0, 'regeneration succeeds');
is(read_file("$temp/IconNames.lua"), $result, 'regeneration is deterministic');
write_file("$temp/dist/LibRPMedia/LibRPMediaData_Mists.lua",
    "size = 2,\ndb_icons_id = {400};\ndb_icons_name = {\"mists_icon\"};\n");
isnt(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0,
    'mismatched upstream counts fail');
is(read_file("$temp/IconNames.lua"), $result, 'failed extraction preserves the previous output');

my $server = "$temp/upstream";
my $update_root = "$temp/update";
my $update_mock = "$temp/update-mock";
make_path($server, "$update_root/scripts", $update_mock);
copy("$FindBin::Bin/$_", "$update_root/scripts/$_") or die $!
    for qw(update-icon-names.pl ReleaseUtil.pm);
for my $flavor (keys %fixtures) {
    my ($ids, $names) = @{ $fixtures{$flavor} };
    my $count = scalar split /,/, $ids;
    write_file("$server/LibRPMediaData_$flavor.lua",
        "size = $count,\ndb_icons_id = {$ids};\ndb_icons_name = {$names};\n");
}
system('git', 'init', '-q', '-b', 'main', $server) == 0 or die 'Cannot initialize fixture repository';
system('git', '-C', $server, 'add', '.') == 0 or die 'Cannot stage fixture data';
system('git', '-C', $server, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
    'commit', '-q', '-m', 'Initial fixture') == 0 or die 'Cannot commit fixture data';
sub git_head {
    my ($repo) = @_;
    open my $fh, '-|', 'git', '-C', $repo, 'rev-parse', 'HEAD' or die "Cannot execute git: $!";
    my $head = <$fh>;
    close $fh or die 'Cannot read fixture revision';
    chomp $head;
    return $head;
}
write_file("$update_mock/curl", <<'MOCK_CURL');
#!/bin/sh
if [ -n "$ICON_API_LOG" ]; then printf called >> "$ICON_API_LOG"; fi
printf '%s\nHTTP_STATUS:%s' "$ICON_API_BODY" "$ICON_API_STATUS"
MOCK_CURL
chmod 0755, "$update_mock/curl" or die $!;
{
    local $ENV{PATH} = "$update_mock:$ENV{PATH}";
    local $ENV{GIT_CONFIG_COUNT} = 1;
    local $ENV{GIT_CONFIG_KEY_0} = "url.file://$server.insteadOf";
    local $ENV{GIT_CONFIG_VALUE_0} = 'https://github.com/wow-rp-addons/LibRPMedia';
    local $ENV{ICON_API_STATUS} = 200;
    local $ENV{ICON_API_BODY} = '{"object":{"sha":"' . git_head($server) . '"}}';
    my $updater = "$update_root/scripts/update-icon-names.pl";
    my $checkout = "$update_root/dist/LibRPMedia";
    is(system($^X, $updater), 0, 'explicit update clones and extracts the API revision');
    ok(-d "$checkout/.git", 'new checkout is an ordinary clone');
    is(read_file("$update_root/LibRPMedia-version.txt"), git_head($checkout) . "\n",
        'recorded revision matches the checkout used for extraction');
    is_deeply([decode_records(read_file("$update_root/IconNames.lua"))], \@records,
        'cloned fixture produces the expected icon data');

    write_file("$server/LibRPMediaData_Mists.lua",
        "size = 1,\ndb_icons_id = {401};\ndb_icons_name = {\"new_icon\"};\n");
    system('git', '-C', $server, 'add', '.') == 0 or die 'Cannot stage updated fixture';
    system('git', '-C', $server, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
        'commit', '-q', '-m', 'Update fixture') == 0 or die 'Cannot commit updated fixture';
    $ENV{ICON_API_BODY} = '{"object":{"sha":"' . git_head($server) . '"}}';
    is(system($^X, $updater), 0, 'explicit update fast-forwards an existing clean checkout');
    is(read_file("$update_root/LibRPMedia-version.txt"), git_head($server) . "\n",
        'updated revision is recorded');
    my $updated = read_file("$update_root/IconNames.lua");
    ok(grep($_ eq '401|4|new_icon', decode_records($updated)), 'updated data is extracted');
    my $version = read_file("$update_root/LibRPMedia-version.txt");

    my $git_mock = "$temp/git-only-mock";
    make_path($git_mock);
    copy("$offline_mock/git", "$git_mock/git") or die $!;
    chmod 0755, "$git_mock/git" or die $!;
    write_file("$update_root/IconNames.lua", "$updated-- preserved\n");
    write_file("$update_root/LibRPMedia-version.txt", git_head($server) . "\r\n");
    {
        local $ENV{PATH} = "$git_mock:$ENV{PATH}";
        local $ENV{ICON_OFFLINE_LOG} = "$temp/unchanged-git.log";
        local $ENV{ICON_API_LOG} = "$temp/unchanged-api.log";
        is(system($^X, $updater), 0, 'matching revision skips the update');
        ok(-e $ENV{ICON_API_LOG}, 'matching revision is checked against the API');
        ok(!-e $ENV{ICON_OFFLINE_LOG}, 'matching revision invokes no Git commands');
    }
    is(read_file("$update_root/IconNames.lua"), "$updated-- preserved\n",
        'matching revision does not regenerate icon data');
    is(read_file("$update_root/LibRPMedia-version.txt"), git_head($server) . "\r\n",
        'matching revision leaves the version file unchanged');
    write_file("$update_root/IconNames.lua", $updated);
    write_file("$update_root/LibRPMedia-version.txt", $version);

    write_file("$server/LibRPMediaData_Mists.lua",
        "size = 2,\ndb_icons_id = {401};\ndb_icons_name = {\"new_icon\"};\n");
    system('git', '-C', $server, 'add', '.') == 0 or die 'Cannot stage invalid fixture';
    system('git', '-C', $server, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
        'commit', '-q', '-m', 'Invalid fixture') == 0 or die 'Cannot commit invalid fixture';
    $ENV{ICON_API_BODY} = '{"object":{"sha":"' . git_head($server) . '"}}';
    write_file("$checkout/user-file.txt", "preserve me\n");
    isnt(system($^X, $updater), 0, 'update refuses a dirty checkout');
    is(read_file("$checkout/user-file.txt"), "preserve me\n", 'dirty checkout contents are preserved');
    unlink "$checkout/user-file.txt" or die $!;
    $ENV{ICON_API_STATUS} = 503;
    isnt(system($^X, $updater), 0, 'update reports an API failure');
    $ENV{ICON_API_STATUS} = 200;
    $ENV{ICON_API_BODY} = '{"object":{"sha":"invalid"}}';
    isnt(system($^X, $updater), 0, 'update rejects an invalid API revision');
    $ENV{ICON_API_BODY} = '{"object":{"sha":"' . ('0' x 40) . '"}}';
    isnt(system($^X, $updater), 0, 'update rejects a revision absent from the fetched branch');
    is(read_file("$update_root/IconNames.lua"), $updated, 'failed updates preserve the generated output');
    is(read_file("$update_root/LibRPMedia-version.txt"), $version, 'failed updates preserve the recorded revision');

    $ENV{ICON_API_BODY} = '{"object":{"sha":"' . git_head($server) . '"}}';
    isnt(system($^X, $updater), 0, 'invalid upstream data fails extraction after checkout update');
    is(read_file("$update_root/IconNames.lua"), $updated, 'failed extraction preserves generated output');
    is(read_file("$update_root/LibRPMedia-version.txt"), $version, 'failed extraction preserves the recorded revision');
}

my $build = "$temp/build";
my $mock = "$temp/mock-bin";
make_path("$build/scripts", $mock);
copy("$FindBin::Bin/$_", "$build/scripts/$_") or die $!
    for qw(build.sh load-env.sh output-style.sh defaults.env);
write_file("$mock/git", <<'MOCK_GIT');
#!/bin/sh
if [ "$1 $2" = "submodule status" ]; then
    printf '+1234567 Libs/Ace3\n'
else
    printf 'unexpected git invocation\n' >> "$ICON_TEST_LOG"
fi
MOCK_GIT
chmod 0755, "$mock/git" or die $!;
{
    local $ENV{PATH} = "$mock:$ENV{PATH}";
    local $ENV{ICON_TEST_LOG} = "$temp/git.log";
    isnt(system('bash', "$build/scripts/build.sh"), 0,
        'build refuses an unstaged submodule revision');
    ok(!-e $ENV{ICON_TEST_LOG}, 'build does not update a changed submodule');
}

my $root = "$FindBin::Bin/..";
SKIP: {
my $local_library = "$root/dist/LibRPMedia";
my $can_compare = -e "$local_library/.git" && -f "$local_library/LibRPMediaData_Standard.lua"
    && -f "$root/LibRPMedia-version.txt";
if ($can_compare) {
    my $version = read_file("$root/LibRPMedia-version.txt");
    $version =~ s/\s+\z//;
    $can_compare = $version eq git_head($local_library)
        && git_output('-C', $local_library, 'status', '--porcelain', '--untracked-files=all') eq '';
}
skip 'matching clean upstream checkout is not available for comparison', 1
    unless $can_compare;
my %expected;
for my $flavor ([ Standard => 1 ], [ Forever => 2 ], [ Mists => 4 ], [ TBC => 8 ], [ Vanilla => 16 ]) {
    my ($name, $flag) = @$flavor;
    my $contents = read_file("$root/dist/LibRPMedia/LibRPMediaData_$name.lua");
    my ($ids) = $contents =~ /^db_icons_id = \{(.*)\};/m;
    my ($names) = $contents =~ /^db_icons_name = \{(.*)\};/m;
    die "Cannot find icon arrays for $name" unless defined $ids && defined $names;
    my @ids = split /,/, $ids;
    my @names = $names =~ /"([^"]*)"/g;
    die "Mismatched icon arrays for $name" unless @ids == @names;
    for my $i (0 .. $#ids) {
        next if $ids[$i] >= 0x04000000;
        $expected{"$ids[$i]|$names[$i]"} |= $flag;
    }
}
my ($missing, $unexpected, $wrong_flags) = (0, 0, 0);
for (decode_records(read_file("$root/IconNames.lua"))) {
    /^(\d+)\|(\d+)\|([^\r\n]+)$/ or die "Invalid decoded record: $_";
    my ($id, $flags, $name) = ($1, $2, $3);
    my $expected = delete $expected{"$id|$name"};
    if (!defined $expected) { $unexpected++ }
    elsif ($flags != $expected) { $wrong_flags++ }
}
$missing = keys %expected;
is("$missing/$unexpected/$wrong_flags", '0/0/0',
    'generated file exactly matches all upstream file icons and client flags');
}

done_testing();
