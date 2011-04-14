package Kismet::DB;

use strict;

use DBI;
use Carp qw/croak/;
use Time::HiRes;

my $_g_dbh;

sub __connect {
    my $dbh;

    $dbh = DBI->connect('DBI:Pg:host=localhost;port=5432;database=postgres',
                        "kismet", "kismet",
                        {
                            RaiseError => 1,
                            PrintError => 0,
                            FetchHashKeyName => "NAME_uc",
                        } );
    $dbh;
}

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = bless {}, $class;
    $_g_dbh = __connect unless($_g_dbh);
    $self->{_dbh} = $_g_dbh;
    $self;
}

sub disconnect {
    my $self = shift;
    eval { $_g_dbh->disconnect(); };
    $_g_dbh = undef;
    $self->{_dbh} = undef;
    return;
}

sub prepare_test {
    my $self = shift;
    my $sql = shift;
    eval {
        $self->prepare($sql);
    };
    return $@;
}
sub prepare {
    my $self = shift;
    my $sql = shift;

    my $dbh = $self->{_dbh};
    my ($package,$file,$line) = caller;
    if($package eq __PACKAGE__) {
        ($package,$file,$line) = caller(2);
    }
    my $i = 2;

#Handle named bindings:
    my $pos = 1;
    my $bind_pos = {};
    $sql =~ s/(?<!:):([a-zA-Z_0-9]+)/push(@{$bind_pos->{$1}}, $pos++); '?';/eg;

  prepare_retry:
    eval {
        $self->{_sth} = $dbh->prepare($sql);
    };
    if($@) {
        if((($@ =~ /lost connection/) || ($@ =~ /gone away/)) and $i > 0) {
            $i--;
            $_g_dbh->disconnect;
            undef($_g_dbh);
            $_g_dbh = __connect;
            $self->{_dbh} = $_g_dbh;
            goto prepare_retry;
        } else {
            die;
        }
    }
    $self->{_sth}->{private_binds} = $bind_pos;
    $self->{_sth}->{private_package} = $package;
    $self->{_sth}->{private_file} = $file;
    $self->{_sth}->{private_line} = $line;
    $self->{_sth}->{private_sql} = $sql;
    $self->{_sth};
}

sub execute {
    my $self = shift;

    my $rv;
    # Reset out timers
    $self->_reset_timers;

    unless($self->{_sth}) {
        return undef;
    }
    $self->{_sth_execute_start_time} = Time::HiRes::time();
    my $i = 2;
  execute_retry:
    eval {
        $rv = $self->{_sth}->execute(@_);
    };
    if($@) {
        if((($@ =~ /\b(?:terminating|lost|no) connection/i) ||  ($@ =~ /gone away/i)) and $i > 0) {
            $i--;
            $_g_dbh->disconnect;
            undef($_g_dbh);
            $_g_dbh = __connect;
            $self->{_dbh} = $_g_dbh;
            $self->prepare($self->{_sth}->{private_sql});
            goto execute_retry;
        } else {
            croak $@;
        }
    }
    $self->{_sth_execute_finish_time} = Time::HiRes::time();
    $self->{_sth_execute_elapsed_time} =
        $self->{_sth_execute_finish_time} - $self->{_sth_execute_start_time};
    return $self->{_sth};
}

sub finish {
    my $self = shift;

    if($self->{_sth}) {
        eval {
            $self->{_sth}->finish;
        };
        if($@) {
        }
    }
}

sub bind_param {
    my $self = shift;
    my $index = shift;
    my $param = shift;
    my $options = shift;

    if($self->{_sth}) {
        die "No such bind: '$index'\n"
          unless exists($self->{_sth}->{private_binds}->{$index});
	for my $pos (@{$self->{_sth}->{private_binds}->{$index}}) {
            $self->{_sth}->bind_param($pos, ref($param)?$$param:$param, $options);
        }
    } else {
        die "bind_param cannot be called without a prepared statement.\n";
    }
}

sub fetch {
    my $self = shift;

    my $rv;
    eval {
        $self->{_sth}->bind_columns(undef, @_) unless (!@_);
    };
    if($@) {
        die;
    }
    $self->{_sth_fetch_row_start_time} = Time::HiRes::time();
    eval {
        $rv = $self->{_sth}->fetch;
    };
    if($@) {
        die;
    }
    $self->{_sth_fetch_row_finish_time} = Time::HiRes::time();
    $self->{_sth_fetch_row_elapsed_time} =
        $self->{_sth_fetch_row_finish_time}-$self->{_sth_fetch_row_start_time};
    $self->{_sth_fetch_count}++;
    $self->{_sth_fetch_elapsed_time} += $self->{_sth_fetch_row_elapsed_time};
    $rv;
}

sub fetchrow {
    my $self = shift;

    my @rv;

    $self->{_sth_fetch_row_start_time} = Time::HiRes::time();
    eval {
        @rv = $self->{_sth}->fetchrow();
    };
    if($@) {
        return undef;
    }
    $self->{_sth_fetch_row_finish_time} = Time::HiRes::time();
    $self->{_sth_fetch_row_elapsed_time} =
        $self->{_sth_fetch_row_finish_time}-$self->{_sth_fetch_row_start_time};
    $self->{_sth_fetch_count}++;
    $self->{_sth_fetch_elapsed_time} += $self->{_sth_fetch_row_elapsed_time};
    @rv;
}

sub fetchrow_hashref {
    my $self = shift;

    my $rv;

    $self->{_sth_fetch_row_start_time} = Time::HiRes::time();
    eval {
        $rv = $self->{_sth}->fetchrow_hashref();
    };
    if($@) {
        return undef;
    }
    $self->{_sth_fetch_row_finish_time} = Time::HiRes::time();
    $self->{_sth_fetch_row_elapsed_time} =
        $self->{_sth_fetch_row_finish_time}-$self->{_sth_fetch_row_start_time};
    $self->{_sth_fetch_count}++;
    $self->{_sth_fetch_elapsed_time} += $self->{_sth_fetch_row_elapsed_time};
    $rv;
}

sub get_now {
    my $self = shift;
    my $now;
    $self->prepare(q{select NOW()});
    $self->execute;
    $self->fetch(\$now);
    $self->finish;
    $now;
}

sub _reset_timers {
    my $self = shift;
        $self->{_sth_execute_start_time} =
        $self->{_sth_execute_elapsed_time} =
        $self->{_sth_execute_finish_time} = 
        $self->{_sth_fetch_row_start_time} = 
        $self->{_sth_fetch_row_finish_time} =
        $self->{_sth_fetch_row_elapsed_time} = 
        $self->{_sth_fetch_count} =
        $self->{_sth_fetch_elapsed_time} = 0;
}

sub AutoCommit {
    my $self = shift;
    $self->{_dbh}->{AutoCommit} = shift;
}

sub rollback {
    my $self = shift;
    $self->{_dbh}->rollback;
}

sub commit {
    my $self = shift;
    $self->{_dbh}->commit;
}

sub do {
    my $self = shift;
    $self->{_dbh}->do(shift);
}
1;
