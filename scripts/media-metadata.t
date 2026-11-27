use strict;
use warnings;
use Test::More;
use FindBin;
use lib $FindBin::Bin;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use MediaMetadata qw(library_version read_toc_version update_toc_version package_library);

my $temp = tempdir('slackhacks-media-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $source = "$temp/library";
my $dest = "$temp/staged";
make_path("$source/Exporter", "$source/Libs/Other/docs", "$source/Libs/Other");

sub write_file {
    my ($path, $contents) = @_;
    open my $fh, '>:raw', $path or die "Cannot write '$path': $!";
    print {$fh} $contents or die "Cannot write '$path': $!";
    close $fh or die "Cannot close '$path': $!";
}

write_file("$source/.pkgmeta", "package-as: Fixture\nignore:\n  - Exporter\n  - Libs/*/docs\n  - '*.rockspec'\n  - Libs/*/README.*\n");
write_file("$source/LibRPMedia.toc", "## Version: fixture\r\n");
write_file("$source/keep.lua", "return true\n");
write_file("$source/example.rockspec", "ignored\n");
write_file("$source/Exporter/data.lua", "ignored\n");
write_file("$source/Libs/Other/docs/a.lua", "ignored\n");
write_file("$source/Libs/Other/README.md", "ignored\n");
write_file("$source/Libs/Other/keep.lua", "keep\n");
is(library_version($source), 'fixture', 'concrete upstream version is preserved');
package_library($source, $dest);
ok(-f "$dest/keep.lua" && -f "$dest/Libs/Other/keep.lua", 'ordinary files are staged');
ok(!-e "$dest/Exporter" && !-e "$dest/example.rockspec" && !-e "$dest/Libs/Other/docs"
    && !-e "$dest/Libs/Other/README.md" && !-e "$dest/.pkgmeta", 'YAML patterns and hidden files are excluded');
update_toc_version("$source/LibRPMedia.toc", 'v1.2.3');
is(read_toc_version("$source/LibRPMedia.toc"), 'v1.2.3', 'TOC version updates');
open my $fh, '<:raw', "$source/LibRPMedia.toc" or die $!;
my $toc = do { local $/; <$fh> };
close $fh;
like($toc, qr/\r\n$/, 'TOC line endings are preserved');
write_file("$source/.pkgmeta", "ignore:\n  - [bad, yaml]\n");
my $ok = eval { package_library($source, "$temp/invalid"); 1 };
ok(!$ok && $@ =~ /Unsupported ignore pattern/, 'unsupported YAML fails explicitly');

local $ENV{GIT_AUTHOR_NAME} = 'Media Test';
local $ENV{GIT_AUTHOR_EMAIL} = 'test@example.invalid';
local $ENV{GIT_COMMITTER_NAME} = 'Media Test';
local $ENV{GIT_COMMITTER_EMAIL} = 'test@example.invalid';
system('git', 'init', '-q', $source) == 0 or die "Cannot initialize test repository";
write_file("$source/LibRPMedia.toc", "## Version: \@project-version\@\n");
system('git', '-C', $source, 'add', 'LibRPMedia.toc') == 0 or die "Cannot stage fixture";
system('git', '-C', $source, 'commit', '-qm', 'initial') == 0 or die "Cannot commit fixture";
system('git', '-C', $source, 'tag', 'v1.2.3') == 0 or die "Cannot tag fixture";
is(library_version($source), 'v1.2.3', 'placeholder resolves to the current tag');
write_file("$source/LibRPMedia.toc", "## Version: \@project-version\@\n# next commit\n");
system('git', '-C', $source, 'add', 'LibRPMedia.toc') == 0 or die "Cannot stage fixture";
system('git', '-C', $source, 'commit', '-qm', 'next') == 0 or die "Cannot commit fixture";
like(library_version($source), qr/^v1\.2\.3-1-g[0-9a-f]{7}$/,
    'untagged checkout uses the upstream packager describe version');

my ($remote, $upstream, $super) = map { "$temp/$_" } qw(remote.git upstream super);
system('git', 'init', '--bare', '--initial-branch=main', '-q', $remote) == 0 or die "Cannot initialize origin";
system('git', 'clone', '-q', $remote, $upstream) == 0 or die "Cannot clone origin";
write_file("$upstream/LibRPMedia.toc", "## Interface: 120105, 16001\n## Version: \@project-version\@\n");
write_file("$upstream/.pkgmeta", "ignore:\n  - ignored.lua\n");
write_file("$upstream/ignored.lua", "ignored\n");
system('git', '-C', $upstream, 'add', '.') == 0 or die "Cannot stage upstream";
system('git', '-C', $upstream, 'commit', '-qm', 'initial') == 0 or die "Cannot commit upstream";
system('git', '-C', $upstream, 'tag', 'v2.0') == 0 or die "Cannot tag upstream";
system('git', '-C', $upstream, 'push', '-q', '--tags', 'origin', 'HEAD') == 0 or die "Cannot push upstream";
system('git', 'init', '-q', $super) == 0 or die "Cannot initialize superproject";
system('git', '-C', $super, '-c', 'protocol.file.allow=always', 'submodule', 'add', '-q',
    $remote, 'Libs/LibRPMedia') == 0 or die "Cannot add test submodule";
make_path("$super/scripts");
copy("$FindBin::Bin/$_", "$super/scripts/$_") or die $!
    for qw(MediaMetadata.pm update-media-metadata.pl package-media-metadata.pl);
is(system($^X, "$super/scripts/update-media-metadata.pl"), 0, 'updater succeeds when already up to date');
my $built = "$super/dist/SlackHacks_MediaMetadata";
my $companion = "$built/SlackHacks_MediaMetadata.toc";
is(system($^X, "$super/scripts/package-media-metadata.pl"), 0, 'build generates a companion without a source TOC');
is(read_toc_version($companion), 'v2.0', 'generated TOC uses the current library version');
open my $generated, '<', $companion or die $!;
my $generated_toc = do { local $/; <$generated> };
close $generated;
like($generated_toc, qr/^## Interface: 120105, 16001$/m, 'generated TOC uses upstream interfaces');
like($generated_toc, qr/^## LoadOnDemand: 1\n## Dependencies: SlackHacks\n\nLibs\\LibRPMedia\\lib\.xml$/m,
    'generated TOC loads the library on demand with its dependency');
write_file("$upstream/LibRPMedia.toc", "## Interface: 120105, 16001\n## Version: \@project-version\@\n# update\n");
system('git', '-C', $upstream, 'add', 'LibRPMedia.toc') == 0 or die "Cannot stage upstream";
system('git', '-C', $upstream, 'commit', '-qm', 'update') == 0 or die "Cannot commit upstream";
system('git', '-C', $upstream, 'push', '-q', 'origin', 'HEAD') == 0 or die "Cannot push upstream";
is(system($^X, "$super/scripts/update-media-metadata.pl"), 0, 'updater fast-forwards the submodule');
is(read_toc_version($companion), 'v2.0', 'updater does not modify the existing build');
is(system($^X, "$super/scripts/package-media-metadata.pl"), 0, 'default build refreshes the companion');
like(read_toc_version($companion), qr/^v2\.0-1-g[0-9a-f]{7}$/,
    'rebuild derives the new version without a synchronization step');
ok(-f "$built/Libs/LibRPMedia/LibRPMedia.toc" && !-e "$built/Libs/LibRPMedia/ignored.lua",
    'built library excludes pkgmeta ignore entries');
write_file("$built/keep-root", "junction target marker\n");
write_file("$built/Libs/LibRPMedia/ignored.lua", "stale\n");
is(system($^X, "$super/scripts/package-media-metadata.pl"), 0, 'companion can be rebuilt');
ok(-f "$built/keep-root" && !-e "$built/Libs/LibRPMedia/ignored.lua",
    'rebuild preserves the companion directory while removing stale library files');
open my $clean, '-|', 'git', '-C', $super, 'clean', '-nfdx',
    '-e', 'dist/SlackHacks_MediaMetadata/', '--', 'dist' or die "Cannot run git clean: $!";
my $clean_output = do { local $/; <$clean> } // '';
close $clean or die "git clean dry run failed";
unlike($clean_output, qr{SlackHacks_MediaMetadata|Would remove dist/?\s*$}m,
    'updater clean exclusion preserves the companion and its parent');

my $updater_fixture = "$temp/updater";
my $mock_bin = "$temp/mock-bin";
make_path("$updater_fixture/scripts", $mock_bin);
copy("$FindBin::Bin/update-addon.sh", "$updater_fixture/scripts/update-addon.sh") or die $!;
write_file("$mock_bin/git", <<'MOCK_GIT');
#!/bin/sh
printf '%s\n' "$*" >> "$UPDATER_LOG"
exit 0
MOCK_GIT
chmod 0755, "$mock_bin/git" or die $!;
write_file("$updater_fixture/scripts/package-media-metadata.pl", <<'MOCK_BUILD');
use strict;
use warnings;
open my $log, '>>', $ENV{UPDATER_LOG} or die $!;
print {$log} "BUILD\n";
close $log or die $!;
exit($ENV{UPDATER_BUILD_FAIL} ? 1 : 0);
MOCK_BUILD
{
    local $ENV{PATH} = "$mock_bin:$ENV{PATH}";
    local $ENV{UPDATER_LOG} = "$temp/updater.log";
    my @command = ('bash', '-c', 'exec bash "$1" --repo-path "$2" --rerun </dev/null',
        'updater-test', "$updater_fixture/scripts/update-addon.sh", $updater_fixture);
    is(system(@command), 0, 'shell updater builds after a successful pull');
    open my $log, '<', $ENV{UPDATER_LOG} or die $!;
    my $actions = do { local $/; <$log> };
    close $log;
    like($actions, qr/pull --force --ff-only\n.*submodule update --init --recursive --force\nBUILD\n\z/s,
        'shell updater builds after pulling and updating submodules');
    local $ENV{UPDATER_BUILD_FAIL} = 1;
    isnt(system(@command), 0, 'shell updater reports a companion build failure');
}

copy("$FindBin::Bin/$_", "$super/scripts/$_") or die $!
    for qw(build.sh load-env.sh output-style.sh defaults.env);
my $updated = library_version("$super/Libs/LibRPMedia");
isnt(system('bash', "$super/scripts/build.sh"), 0, 'build refuses an unstaged submodule revision');
is(library_version("$super/Libs/LibRPMedia"), $updated, 'build preserves the updated submodule checkout');
write_file("$super/Libs/LibRPMedia/LibRPMedia.toc", "## Version: \@project-version\@\n# local changes\n");
isnt(system($^X, "$super/scripts/update-media-metadata.pl"), 0, 'updater refuses dirty library changes');
isnt(system($^X, "$super/scripts/package-media-metadata.pl"), 0, 'build rejects missing upstream TOC metadata');
like(read_toc_version($companion), qr/^v2\.0-1-g[0-9a-f]{7}$/, 'failed build leaves existing companion intact');

done_testing();
