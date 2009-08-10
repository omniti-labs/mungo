package Mungo::Quiet;
use strict;
use warnings;

use Apache2::Const qw ( OK NOT_FOUND SERVER_ERROR );

=head1 NAME

Mungo::Quiet - Mungo with safer/quieter error handling

=head1 SYNOPSIS

In your httpd.conf:

  <FilesMatch "\.asp$">
    PerlSetVar      StatINC     1
    SetHandler      perl-script

    # Instead of Mungo
    PerlHandler     Mungo::Quiet
  </FilesMatch>

=head1 DESCRIPTION

Behaves exactly as Mungo (in fact, it's just Mungo with a replacement
mod_perl handler), except when it comes to error handling.

Mungo has the following behavior when an exception (a die()) occurs
in an Include call:

=over

=item Render the page up to this point

=item Guesses (often wrongly) which file had the problem, and dump its source code to the page

=item Return a HTTP status 200

=item Doesn't log anything to STDERR (the Apache error log)

=back

That's not helpful, and the stack trace is a bad idea on production.  So,
Mungo::Quiet has this behavior:

=over

=item Don't render anything if possible (you may have already print()ed, though)

=item Silence to the browser, regarding the error

=item Return HTTP status 500

=item Barf the error and a stacktrace to the Apache Error Log

=back

You can use the 500 status along with Apache's ErrorDocument directive to create
custom error landing pages.

=head1 OPTION

By default, Mungo::Quiet only dumps a stacktrace to STDERR, not the actual code 
(unlike Mungo).  If you really want the code barfed to the log as well, set this
at the top of your page:

  $Mungo::Quiet::DUMP_CODE_TO_STDERR = 1;


=head1 AUTHOR

  Clinton Wolfe, with Dave Hubbard and Brian Dunavant

=cut

our $DEBUG = 0;

# Set this to true if desired
our $DUMP_CODE_TO_STDERR = 0;

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


    local $SIG{__DIE__} = \&Mungo::wrapErrorsInObjects;
    # !@#$%!@#$% Theo, why did you make this so hard to get to????
    my $thing = tied %{$self->Response()};
    $thing->{data}->{OnError} = \&quieterMungoErrors;

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
    } else {
        if ($DEBUG) { print STDERR __PACKAGE__ . ':' . __LINE__ . "- Aive after outer include with no exception\n"; }
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
        print STDERR "\tp:" . $frame->[$package] . "\tf:" . $frame->[$filename] . "\tl:" .$frame->[$line] . "\ts:" . $frame->[$subroutine] . "\n";
    }

    # This is rarely accurate or useful.... and very noisy.
    if ($DUMP_CODE_TO_STDERR) {
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
    }

    # Jump to exit
    eval { goto  MUNGO_HANDLER_FINISH; }; # Jump back to Mungo::handler()

}


1;
