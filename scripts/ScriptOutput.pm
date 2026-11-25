package ScriptOutput;
use strict;
use warnings;
use Exporter 'import';
use Term::ANSIColor qw(colored);

our @EXPORT_OK = qw(status_info status_success status_warning status_error install_error_styling start_progress);

sub is_terminal { return -t $_[0] }

sub color_enabled {
    my ($handle) = @_;
    return !exists $ENV{NO_COLOR} && is_terminal($handle) && ($ENV{TERM} // '') ne 'dumb';
}

# Color only interactive output, preserving redirected output and machine-readable streams.
sub styled {
    my ($handle, $color, $text) = @_;
    return $text unless color_enabled($handle);
    return colored($text, $color);
}

sub status {
    my ($handle, $level, $color, $text) = @_;
    my $leading_newlines = $text =~ s/\A(\n+)// ? $1 : '';
    my $prefix = color_enabled($handle) ? "[$level] " : '';
    print {$handle} $leading_newlines, styled($handle, $color, "$prefix$text\n");
}
sub status_info    { status(\*STDOUT, 'INFO',  'cyan',   $_[0]) }
sub status_success { status(\*STDOUT, 'OK',    'green',  $_[0]) }
sub status_warning { status(\*STDERR, 'WARN',  'yellow', $_[0]) }
sub status_error   { status(\*STDERR, 'ERROR', 'red',    $_[0]) }

sub styled_diagnostic {
    my ($color, $text) = @_;
    my $trailing_newlines = $text =~ s/(\n+)\z// ? $1 : '';
    return styled(\*STDERR, $color, $text) . $trailing_newlines;
}

# Perl's exceptions still propagate normally, including exceptions caught inside eval.
sub install_error_styling {
    return unless color_enabled(\*STDERR);
    $SIG{__WARN__} = sub { warn styled_diagnostic('yellow', $_[0]) };
    $SIG{__DIE__} = sub { die styled_diagnostic('red', $_[0]) unless $^S };
}

# Progress is optional, interactive only, and reports completed work rather than elapsed time.
sub start_progress {
    my ($label, $count) = @_;
    return unless is_terminal(\*STDERR) && ($ENV{TERM} // '') ne 'dumb';
    unless (eval { require Term::ProgressBar; 1 }) {
        status_warning("Term::ProgressBar is unavailable; bootstrap progress is disabled: $@");
        return;
    }
    return Term::ProgressBar->new({ name => $label, count => $count, remove => 1 });
}

1;
