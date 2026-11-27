use strict;
use warnings;
use Test::More;
use FindBin;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

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

my $temp = tempdir('slackhacks-icon-names-XXXXXX', TMPDIR => 1, CLEANUP => 1);
make_path("$temp/scripts", "$temp/dist/LibRPMedia");
copy("$FindBin::Bin/update-icon-names.pl", "$temp/scripts/update-icon-names.pl") or die $!;
my %fixtures = (
    Standard => [ '100,200,67108865', '"shared_icon","retail_tbc","atlas"' ],
    Forever => [ '100,300', '"shared_icon","forever icon"' ],
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
is(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0,
    'extractor works without a network update');
my $result = read_file("$temp/IconNames.lua");
like($result, qr/^100\|3\|shared_icon$/m, 'shared icons combine client flags');
like($result, qr/^200\|9\|retail_tbc$/m, 'nonadjacent client flags combine');
like($result, qr/^300\|2\|forever icon$/m, 'names with spaces are preserved');
unlike($result, qr/atlas/, 'atlas entries are excluded');
is(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0, 'regeneration succeeds');
is(read_file("$temp/IconNames.lua"), $result, 'regeneration is deterministic');
write_file("$temp/dist/LibRPMedia/LibRPMediaData_Mists.lua",
    "size = 2,\ndb_icons_id = {400};\ndb_icons_name = {\"mists_icon\"};\n");
isnt(system($^X, "$temp/scripts/update-icon-names.pl", '--no-update'), 0,
    'mismatched upstream counts fail');
is(read_file("$temp/IconNames.lua"), $result, 'failed extraction preserves the previous output');

my $build = "$temp/build";
my $mock = "$temp/mock-bin";
make_path("$build/scripts", $mock);
copy("$FindBin::Bin/$_", "$build/scripts/$_") or die $!
    for qw(build.sh load-env.sh output-style.sh defaults.env);
write_file("$mock/git", <<'MOCK_GIT');
#!/bin/sh
if [ "$1 $2" = "submodule status" ]; then
    printf '+1234567 dist/LibRPMedia\n'
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
open my $generated, '<', "$root/IconNames.lua" or die $!;
while (<$generated>) {
    next unless /^(\d+)\|(\d+)\|([^\r\n]+)\r?$/;
    my ($id, $flags, $name) = ($1, $2, $3);
    my $expected = delete $expected{"$id|$name"};
    if (!defined $expected) { $unexpected++ }
    elsif ($flags != $expected) { $wrong_flags++ }
}
close $generated;
$missing = keys %expected;
is("$missing/$unexpected/$wrong_flags", '0/0/0',
    'generated file exactly matches all upstream file icons and client flags');

done_testing();
