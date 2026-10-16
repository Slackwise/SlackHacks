#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Find qw(find);
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use HTTP::Tiny;

my $root = File::Spec->catdir($RealBin, File::Spec->updir());
my $bin_dir = File::Spec->catdir($root, '.bin');

my $architecture = $ENV{PROCESSOR_ARCHITEW6432} || $ENV{PROCESSOR_ARCHITECTURE} || '';
if ($^O ne 'MSWin32' || $architecture !~ /^(?:AMD64|x86_64)$/i) {
    die "This bootstrap currently supports Windows x64 only.\n";
}

make_path($bin_dir);

my $http = HTTP::Tiny->new(
    agent        => 'SlackHacks bootstrap/1.0',
    max_redirect => 5,
    timeout      => 120,
);

my $scratch_dir = tempdir('slackhacks-bootstrap-XXXXXX', DIR => $bin_dir, CLEANUP => 1);

install_luac();
install_stylua();
install_lua_language_server();

print "Lua development tools are ready in .bin.\n";

sub install_luac {
    my $destination = File::Spec->catfile($bin_dir, 'luac.exe');
    return print "Keeping existing luac.exe.\n" if -x $destination;

    my $archive = File::Spec->catfile($scratch_dir, 'lua-5.1.5_Win64_bin.zip');
    download(
        'https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip/download',
        $archive,
    );

    my $extracted = File::Spec->catdir($scratch_dir, 'lua');
    extract_archive($archive, $extracted);
    my $compiler = find_executable($extracted, qr/^luac.*\.exe$/i);
    die "LuaBinaries archive did not contain luac.exe.\n" unless $compiler;
    copy($compiler, $destination)
        or die "Could not install luac.exe: $!\n";

    print "Installed Lua 5.1 bytecode compiler.\n";
}

sub install_stylua {
    my $destination = File::Spec->catfile($bin_dir, 'stylua.exe');
    return print "Keeping existing stylua.exe.\n" if -x $destination;

    my $archive = File::Spec->catfile($scratch_dir, 'stylua-windows-x86_64.zip');
    download(
        'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.1.0/stylua-windows-x86_64.zip',
        $archive,
    );

    my $extracted = File::Spec->catdir($scratch_dir, 'stylua');
    extract_archive($archive, $extracted);
    my $formatter = find_executable($extracted, qr/^stylua\.exe$/i);
    die "StyLua archive did not contain stylua.exe.\n" unless $formatter;
    copy($formatter, $destination)
        or die "Could not install stylua.exe: $!\n";

    print "Installed StyLua formatter and formatting checker.\n";
}

sub install_lua_language_server {
    my $destination = File::Spec->catdir($bin_dir, 'lua-language-server');
    my $executable = File::Spec->catfile($destination, 'bin', 'lua-language-server.exe');
    return print "Keeping existing Lua Language Server.\n" if -x $executable;

    my $archive = File::Spec->catfile($scratch_dir, 'lua-language-server-win32-x64.zip');
    download(
        'https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip',
        $archive,
    );

    my $extracted = File::Spec->catdir($scratch_dir, 'lua-language-server');
    extract_archive($archive, $extracted);
    my $server = find_executable($extracted, qr/^lua-language-server\.exe$/i);
    die "Lua Language Server archive did not contain its executable.\n" unless $server;

    if (-d $destination) {
        require File::Path;
        File::Path::remove_tree($destination);
    }
    rename($extracted, $destination)
        or die "Could not install Lua Language Server: $!\n";

    print "Installed Lua Language Server.\n";
}

sub download {
    my ($url, $destination) = @_;
    print "Downloading $url\n";

    my $response = $http->get($url, {
        data_callback => sub {
            my ($chunk) = @_;
            open my $output, '>>:raw', $destination
                or die "Could not write $destination: $!\n";
            print {$output} $chunk
                or die "Could not write $destination: $!\n";
            close $output
                or die "Could not close $destination: $!\n";
        },
    });

    unless ($response->{success}) {
        unlink $destination if -e $destination;
        die "Download failed ($response->{status} $response->{reason}): $url\n";
    }
}

sub extract_archive {
    my ($archive, $destination) = @_;
    make_path($destination);

    my $status = system('tar', '-xf', $archive, '-C', $destination);
    die "Could not extract $archive with tar (exit status $status).\n" if $status != 0;
}

sub find_executable {
    my ($directory, $name_pattern) = @_;
    my $found;

    find(
        {
            wanted => sub {
                return unless -f $_ && basename($_) =~ $name_pattern;
                $found = $File::Find::name;
                $File::Find::prune = 1;
            },
            no_chdir => 1,
        },
        $directory,
    );

    return $found;
}
