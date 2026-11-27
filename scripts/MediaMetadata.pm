package MediaMetadata;
use strict;
use warnings;
use Exporter 'import';
use File::Copy qw(copy);
use File::Find qw(find);
use File::Path qw(make_path);
use File::Spec;
use File::Basename qw(dirname);

our @EXPORT_OK = qw(library_version read_toc_field read_toc_version update_toc_version package_library);

sub git_output {
    my (@args) = @_;
    open my $fh, '-|', 'git', @args or die "Cannot run git: $!\n";
    my $output = do { local $/; <$fh> } // '';
    close $fh or die "git @args failed.\n";
    $output =~ s/\s+$//;
    return $output;
}

# Resolve @project-version@ like the upstream BigWigs packager.
sub library_version {
    my ($library) = @_;
    my $toc = File::Spec->catfile($library, 'LibRPMedia.toc');
    my $version = read_toc_version($toc);
    return $version unless $version eq '@project-version@';
    my $tags = git_output('-C', $library, 'tag', '--points-at', 'HEAD',
        '--sort=-committerdate', '--sort=-v:refname', '--sort=-taggerdate');
    return (split /\n/, $tags)[0] if length $tags;
    my $fallback = git_output('-C', $library, 'describe', '--tags', '--always', '--abbrev=7');
    my $reachable = git_output('-C', $library, 'tag', '--merged', 'HEAD');
    return $fallback unless grep { !/alpha/i } split /\n/, $reachable;
    return git_output('-C', $library, 'describe', '--tags', '--abbrev=7',
        '--exclude=*[Aa][Ll][Pp][Hh][Aa]*');
}

sub read_toc_field {
    my ($path, $field) = @_;
    open my $fh, '<', $path or die "Cannot read '$path': $!\n";
    my @values = map { /^\s*##\s*\Q$field\E:\s*(.*?)\s*$/i ? $1 : () } <$fh>;
    close $fh or die "Cannot close '$path': $!\n";
    die "Expected exactly one non-empty $field in '$path'.\n" unless @values == 1 && length $values[0];
    return $values[0];
}

sub read_toc_version {
    return read_toc_field($_[0], 'Version');
}

sub update_toc_version {
    my ($path, $version) = @_;
    read_toc_version($path);
    open my $fh, '<:raw', $path or die "Cannot read '$path': $!\n";
    my $text = do { local $/; <$fh> };
    close $fh or die "Cannot close '$path': $!\n";
    $text =~ s/^(##\s*Version:\s*)[^\r\n]*/${1}$version/m
        or die "Cannot update version in '$path'.\n";
    open $fh, '>:raw', $path or die "Cannot write '$path': $!\n";
    print {$fh} $text or die "Cannot write '$path': $!\n";
    close $fh or die "Cannot close '$path': $!\n";
}

# Read the simple scalar sequence used by LibRPMedia's pkgmeta, rejecting unsupported YAML.
sub ignore_patterns {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read '$path': $!\n";
    my (@patterns, $in_ignore, $found);
    while (my $line = <$fh>) {
        $line =~ s/\r?\n$//;
        if ($line =~ /^ignore:\s*(?:#.*)?$/) { $in_ignore = $found = 1; next }
        next unless $in_ignore;
        next if $line =~ /^\s*(?:#.*)?$/;
        last if $line !~ /^\s/;
        $line =~ /^\s+-\s+(.+?)\s*$/ or die "Unsupported ignore entry in '$path': $line\n";
        my $value = $1;
        if ($value =~ /^'((?:[^']|'')*)'\s*(?:#.*)?$/) {
            $value = $1;
            $value =~ s/''/'/g;
        } elsif ($value =~ /^"([^"\\]*)"\s*(?:#.*)?$/) {
            $value = $1;
        } elsif ($value =~ /^([^\s#\[\]{}&!|>]+)(?:\s+#.*)?$/) {
            $value = $1;
        } else {
            die "Unsupported ignore pattern in '$path': $value\n";
        }
        die "Unsafe ignore pattern '$value'.\n" if $value =~ m{(?:^/|(?:^|/)\.\.(?:/|$)|\\)};
        push @patterns, $value;
    }
    close $fh or die "Cannot close '$path': $!\n";
    die "Missing ignore sequence in '$path'.\n" unless $found;
    return @patterns;
}

sub ignored {
    my ($path, @patterns) = @_;
    return 1 if $path =~ m{(?:^|/)\.[^/]+(?:/|$)};
    for my $pattern (@patterns) {
        my $regex = quotemeta($pattern);
        $regex =~ s/\\\*/[^\\\/]*/g;
        $regex =~ s/\\\?/[^\\\/]/g;
        return 1 if $path =~ /^$regex(?:\/|$)/;
    }
    return 0;
}

sub package_library {
    my ($library, $destination) = @_;
    my @patterns = ignore_patterns(File::Spec->catfile($library, '.pkgmeta'));
    find({ no_chdir => 1, wanted => sub {
        my $source = $File::Find::name;
        my $relative = File::Spec->abs2rel($source, $library);
        return if $relative eq '.';
        $relative =~ s{\\}{/}g;
        if (ignored($relative, @patterns)) {
            $File::Find::prune = 1 if -d $source;
            return;
        }
        return if -d $source;
        die "Unsupported non-file '$source'.\n" unless -f $source;
        my $target = File::Spec->catfile($destination, split m{/}, $relative);
        make_path(dirname($target));
        copy($source, $target) or die "Cannot copy '$source' to '$target': $!\n";
    }}, $library);
}

1;
