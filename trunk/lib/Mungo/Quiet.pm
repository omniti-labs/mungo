package Mungo::Quiet;
use strict;
use warnings;

use Apache2::Const qw ( OK NOT_FOUND SERVER_ERROR );

our $DEBUG = 2;

sub handler($$) {
    my ($invocant, $r) = @_;
    my $mungo_class;
    if (ref $invocant eq 'Apache2::RequestRec') {
        # Called as subroutine
        $r = $invocant;
        $mungo_class = 'Mungo';
    } else {
        # Called as class method
        $mungo_class = 'Mungo';   # Override this
        # $r is already right
    }

    if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- Have filename " . $r->filename . "\n"; }

    # Short circuit if we can't find the file.
    return NOT_FOUND if(! -r $r->filename);

    my $self = $mungo_class->new($r);

    # Initialize Mungo environment
    $self->Response()->start();


    #local $SIG{__DIE__} = \&quieterMungoErrors;
    $self->{data}->{OnError} = \&quieterMungoErrors;

    # All exits from the Include - including Redirect, End, and die()ing
    # will end up with a 'goto MUNGO_HANDLER_FINISH'

    eval {
        $main::Request = $self->Request();
        $main::Response = $self->Response();
        $main::Server = $self->Server();
        if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- Entering Include \n"; }
        $self->Response()->Include($r->filename);
        if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- Survived Include \n"; }
    };


    # CODE HERE WILL NEVER GET EXECUTED
    if ($@) {
        if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- Eval threw exception: \n$@\n"; }
    }



    # gotos come here from:
    #   $Response->End()
  MUNGO_HANDLER_FINISH:
    $self->Response()->finish();
    $self->cleanse();
    undef $main::Request;
    undef $main::Response;
    undef $main::Server;
    return $self->{data}->{ApacheResponseCode} || OK;
}


sub quieterMungoErrors {
    my $response = shift; # A Mungo::Response object
    my $error = shift; # A Mungo::Error object, or a plain string
    my $subject = shift; # Either a coderef or a filename

    if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- In qME\n"; }

    my $have_obj = ref $error;
    my $errstr = $have_obj ? $error->{error} : $error;


    # Most importantly, set the apache error response
    $response->{Mungo}->{data}->{ApacheResponseCode} = SERVER_ERROR;

    print STDERR "Mungo error in file $subject:\n";
    print STDERR "\t $errstr \n";

    unless ($have_obj) {
        return;
    }

    # caller columns:
    #  0         1          2      3            4         5           6          7            8       9
    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = (0..9);
    my @callstack = @{$error->{callstack}};

    # Print basic trace
    print STDERR "Mungo stack trace:\n";
    foreach my $frame (@callstack) {
        print STDERR "\t" . $frame->[$package] . "\t" . $frame->[$filename] . "\t" .$frame->[$line] . "\t" . $frame->[$subroutine] . "\n";

    }

    # Try to obtain source code from mungo coderefs
    my $pkg = $callstack[0][$package];
    my $preamble = eval "\$${pkg}::Mungo_preamble;";
    my $postamble = eval "\$${pkg}::Mungo_postamble;";
    my $contents = eval "\$${pkg}::Mungo_contents;";

    # If that failed, try to read the file?
    unless ($contents) {
        my $file = $callstack[0][$filename];
        if (open(FILE, "<$file")) {
            local $/ = undef;
            $contents = <FILE>;
            close(FILE);
        }
    }

    # If that didn't work, try the eval text.
    unless ($contents) {
        $contents = $callstack[0][$evaltext];
    }

    if ($contents) {
        print STDERR Mungo::Utils::pretty_print_code($preamble, $contents, $postamble, $callstack[0][$line]);
    } else {
        print STDERR Dumper($@) . "\n";
    }

    # Jump to exit
    eval { goto  MUNGO_HANDLER_FINISH; }; # Jump back to Mungo::handler()

}


1;
