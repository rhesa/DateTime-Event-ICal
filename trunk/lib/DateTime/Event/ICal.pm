package DateTime::Event::ICal;

use strict;
require Exporter;
use Carp;
use DateTime;
use DateTime::Set;
use DateTime::Span;
use DateTime::SpanSet;
use DateTime::Event::Recurrence;
use Params::Validate qw(:all);
use vars qw( $VERSION @ISA );
@ISA     = qw( Exporter );
$VERSION = '0.00_02';

use constant INFINITY     =>       100 ** 100 ** 100 ;
use constant NEG_INFINITY => -1 * (100 ** 100 ** 100);

my %weekdays = ( mo => 1, tu => 2, we => 3, th => 4,
                 fr => 5, sa => 6, su => 7 );

my %freqs = ( 
    secondly => { name => 'second', names => 'seconds' },
    minutely => { name => 'minute', names => 'minutes' },
    hourly =>   { name => 'hour',   names => 'hours' },
    daily =>    { name => 'day',    names => 'days' },
    monthly =>  { name => 'month',  names => 'months' },
    weekly =>   { name => 'week',   names => 'weeks' },
    yearly =>   { name => 'year',   names => 'years' },
);

# internal debugging method - formats the argument list for error messages
sub _param_str {
    my %param = @_;
    my @str;
    for ( qw( freq interval count ), 
          keys %param ) 
    {
        next unless exists $param{$_};
        if ( ref( $param{$_} ) eq 'ARRAY' ) {
            push @str, "$_=". join( ',', @{$param{$_}} )
        }
        elsif ( UNIVERSAL::can( $param{$_}, 'datetime' ) ) {
            push @str, "$_=". $param{$_}->datetime 
        }
        elsif ( defined $param{$_} ) {
            push @str, "$_=". $param{$_} 
        }
        else {
            push @str, "$_=undef" 
        }
        delete $param{$_};
    }
    return join(';', @str);
}

# recurrence constructors

sub _secondly_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
    delete $$argsref{$_}
        for qw( interval );
    return DateTime::Event::Recurrence->secondly( %by );
}

sub _minutely_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
    delete $$argsref{$_}
        for qw( interval bysecond );
    return DateTime::Event::Recurrence->minutely( %by );
}

sub _hourly_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
    delete $$argsref{$_}
        for qw( interval byminute bysecond );
    return DateTime::Event::Recurrence->hourly( %by );
}

sub _daily_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};
    delete $$argsref{$_}
        for qw( interval bysecond byminute byhour );
    # TODO: (maybe) - same thing if byweekno exists
    $$argsref{bymonthday} = [ 1 .. 31 ] 
        if exists $args{bymonth} && ! exists $args{bymonthday};
    return DateTime::Event::Recurrence->daily( %by );
}

sub _weekly_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};
            # TODO: -1fr should work too?
            $by{days} = exists $args{byday} ?
                        [ map { $weekdays{$_} } @{$args{byday}} ] :
                        $dtstart->day_of_week ;
    # warn "weekly:"._param_str(%by);

    delete $$argsref{$_}
        for qw( interval bysecond byminute byhour byday );
    return DateTime::Event::Recurrence->weekly( %by );
}

sub _monthly_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};

            if ( exists $args{bymonthday} )
            {
                $by{days} =    $args{bymonthday};
            }
            elsif ( exists $args{byday} )
            {   # "1FR"
                $by{byday} =    $args{byday};
                delete $$argsref{$_} 
                    for qw( interval bysecond byminute byhour byday );
                return _recur_1fr( %by, freq => 'monthly' );
            }
            else
            {
                $by{days} =    $dtstart->day unless exists $by{days};
            }
    delete $$argsref{$_}
        for qw( interval bysecond byminute byhour bymonthday );
    return DateTime::Event::Recurrence->monthly( %by );
}

sub _yearly_recurrence {
    my ($dtstart, $argsref) = @_;
    my %by;
    my %args = %$argsref;
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};

            if ( exists $args{bymonth} )
            {
                $by{months} =  $args{bymonth};
                delete $$argsref{bymonth};

                $by{days} =    $args{bymonthday} if exists $args{bymonthday};
                $by{days} =    [ 1 .. 31 ] 
                    if ! exists $by{days} && 
                       exists $args{byday};
                $by{days} =    $dtstart->day unless exists $by{days};
                delete $$argsref{bymonthday};
            }
            elsif ( exists $args{byweekno} ) 
            {
                $by{weeks} =  $args{byweekno};
                delete $$argsref{byweekno};

                $by{days} =    $args{byweekday} if exists $args{byweekday};
                $by{days} =    $dtstart->day_of_week unless exists $by{days};
                delete $$argsref{byweekday};
            }
            elsif ( exists $args{byyearday} )
            {
                $by{days} =    $args{byyearday};
                delete $$argsref{byyearday};
            }
            elsif ( exists $args{byday} )
            {   # "1FR"
                $by{byday} =    $args{byday};
                delete $$argsref{$_} 
                    for qw( interval bysecond byminute byhour byday );
                return _recur_1fr( %by, freq => 'yearly' );
            }
            else {
                $by{months} =  $dtstart->month;

                $by{days} =    $args{bymonthday} if exists $args{bymonthday};
                $by{days} =    $dtstart->day unless exists $by{days};
                delete $$argsref{bymonthday};
            }
    delete $$argsref{$_} 
        for qw( interval bysecond byminute byhour );
    return DateTime::Event::Recurrence->yearly( %by );
}

# recurrence constructor for '1FR' specification

sub _recur_1fr {
    # ( freq , interval, dtstart, byday[ week_count . week_day ] )
    my %args = @_;
    my $positive_base_set;
    my @positive_days;
    my $base_duration;

    # parse byday
    for ( @{$args{byday}} ) 
    {
        my ( $count, $day_name ) = $_ =~ /(.*)(\w\w)/;
        die "week count ($count) can't be zero" unless $count;
        my $week_day = $weekdays{ $day_name };
        die "invalid week day ($day_name)" unless $week_day;
        push @positive_days, [ $count, $week_day ];

    }
    delete $args{byday};

    if ( $args{freq} eq 'monthly' ) {
        $base_duration = 'months';
        delete $args{freq};
        # warn "creating base set with "._param_str( %args );
        $positive_base_set = DateTime::Event::Recurrence->monthly( %args )
    }
    elsif ( $args{freq} eq 'yearly' ) {
        $base_duration = 'years';
        delete $args{freq};
        $positive_base_set = DateTime::Event::Recurrence->yearly( %args )
    }
    else {
        die "invalid freq ($args{freq})";
    }

    # return a callback-recurrence

    return DateTime::Set->from_recurrence (
        next =>
        sub {
            my $self = $_[0]->clone;
            my $base = $positive_base_set->current( $_[0] ) ;
            my $start;

            while(1) {

                my @result;
                for ( @positive_days ) 
                {
                    my ( $count, $week_day ) = @$_;

                    # warn "date ".$self->datetime." base ".$base->datetime." weeks $count weekday $week_day";
                    $start = $base->clone;
                    $start->add( $base_duration => 1, days => 7 ) if $count < 0;
                    $start->add( weeks => $count - 1);
                    # print STDERR "    start ".$start->datetime." weekday ".$start->day_of_week."\n";
                    my $dow = $start->day_of_week;
                    my $delta_days = $dow <= $week_day ? 
                                     $week_day - $dow :
                                     7 + $week_day - $dow;
                    $start->add( days => $delta_days );
                    # print STDERR "    start ".$start->datetime." weekday ".$start->day_of_week."\n";
                    push @result, $start if $start > $self;
                }
                if ( @result ) {
                    # print "    $base_duration results: ". join(",", map { $_->datetime } @result ), "\n";
                    my $r = $result[0];
                    for ( @result[ 1 .. $#result ] ) {
                        $r = $_ if $r > $_;
                    }
                    # print "    result: ". $r->datetime. "\n";
                    return $r;
                }
                $base = $positive_base_set->next( $base ) ;
            }
        }
    );
}

# bysetpos constructor

sub _recur_bysetpos {
    # ( freq , interval, bysetpos, recurrence )
    my %args = @_;
    # my $names = $freqs{ $args{freq} }{names};
    # my $name =  $freqs{ $args{freq} }{name};
    no strict "refs";
    my $base_set = &{"DateTime::Event::Recurrence::$args{freq}"}();
    # die "invalid freq parameter ($args{freq})" 
    #    unless exists $DateTime::Event::Recurrence::truncate_interval{ $names };
    #my $truncate_interval_sub = 
    #    $DateTime::Event::Recurrence::truncate_interval{ $names };
    #my $next_unit_sub =
    #    $DateTime::Event::Recurrence::next_unit{ $names };
    #my $previous_unit_sub =
    #    $DateTime::Event::Recurrence::previous_unit{ $names };
    # print STDERR "bysetpos:  [@{$args{bysetpos}}]\n";
    for ( @{$args{bysetpos}} ) { $_-- if $_ > 0 }
    return DateTime::Set->from_recurrence (
        next =>
        sub {
            my $self = $_[0]->clone;
            # warn "bysetopos: next of ".$_[0]->datetime;
            # print STDERR "    previous: ".$base_set->current( $_[0] )->datetime."\n";
            my $start = $base_set->current( $_[0] );
          while(1) {
            my $end   = $base_set->next( $start->clone );
            # print STDERR "    base: ".$start->datetime." ".$end->datetime."\n";
            my $span = DateTime::Span->from_datetimes( 
                          start => $start,
                          before => $end );
            # print STDERR "    done span\n";
            my $subset = $args{recurrence}->intersection( $span );
            my @list = $subset->as_list;
            # print STDERR "    got list ".join(",", map{$_->datetime}@list)."\n";
            # select
            @list = sort @list[ @{$args{bysetpos}} ];
            # print STDERR "    selected [@{$args{bysetpos}}]".join(",", map{$_->datetime}@list)."\n";
            for ( @list ) {
                return $_ if $_ > $self;
            }
            $start = $end;
          }  # /while
        }
    );
}

# main recurrence constructor

sub recur {
    my $class = shift;
    my %args = @_;

    if ( exists $args{count} )
    {
        # count
        my $n = $args{count};
        delete $args{count};
        my $count_inf = $class->recur( %args )->{set}
                  ->select( count => $n );
        return bless { set => $count_inf }, 'DateTime::Set';
    }

    # warn "recur:"._param_str(%args);

    # dtstart / dtend / until
    my $span = 
        exists $args{dtstart} ?
            DateTime::Span->from_datetimes( start => $args{dtstart} ) :
            DateTime::Set->empty_set->complement;
    $span = $span->complement( 
                DateTime::Span->from_datetimes( after => delete $args{dtend} )
            ) if exists $args{dtend};
    $span = $span->complement(
                DateTime::Span->from_datetimes( after => delete $args{until} )
            ) if exists $args{until};
    # warn 'SPAN '. $span->{set};

    $args{interval} = 1 unless $args{interval};

    # setup the "default time"
    my $dtstart = exists $args{dtstart} ?
            delete $args{dtstart} : 
            DateTime->new( year => 2000, month => 1, day => 1 );
    # warn 'DTSTART '. $dtstart->datetime;

    # rewrite: daily-bymonth to yearly-bymonth-bymonthday[1..31]
    if ( $args{freq} eq 'daily' ) {
        if ( exists $args{bymonth} &&
             $args{interval} == 1 ) 
        {
            $args{freq} = 'yearly';
            $args{bymonthday} = [ 1 .. 31 ] unless exists $args{bymonthday};
            # warn "rewrite recur:"._param_str(%args);
        }
    }

    # TODO: use a hash of CODE
    my $base_set;
    my %by;
    if ( $args{freq} eq 'secondly' ) {
        $base_set = _secondly_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'minutely' ) {
        $base_set = _minutely_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'hourly' ) {
        $base_set = _hourly_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'daily' ) {
        $base_set = _daily_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'monthly' ) {
        $base_set = _monthly_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'weekly' ) {
        $base_set = _weekly_recurrence($dtstart, \%args);
    }
    elsif ( $args{freq} eq 'yearly' ) {
        $base_set = _yearly_recurrence($dtstart, \%args);
    }
    else {
        die "invalid freq ($args{freq})";
    }

    delete $args{wkst};    # TODO: wkst

    # warn "\ncomplex recur:"._param_str(%args);

    %by = ();
    my $has_day = 0;

    my $by_year_day;
    if ( exists $args{byyearday} ) 
    {
        $by_year_day = _yearly_recurrence($dtstart, \%args);
    }

    my $by_month_day;
    if ( exists $args{bymonthday} ||
         exists $args{bymonth} ) 
    {
        $by_month_day = _yearly_recurrence($dtstart, \%args);
    }

    my $by_week_day;
    # TODO: byweekno without byday
    if ( exists $args{byday} ||
         exists $args{byweekno} ) 
    {
        $by_week_day = _weekly_recurrence($dtstart, \%args);
    }

    # join the rules together

    $base_set = $base_set && $by_year_day ?
                $base_set->intersection( $by_year_day ) :
                ( $base_set ? $base_set : $by_year_day );
    $base_set = $base_set && $by_month_day ?
                $base_set->intersection( $by_month_day ) :
                ( $base_set ? $base_set : $by_month_day );
    $base_set = $base_set && $by_week_day ?
                $base_set->intersection( $by_week_day ) :
                ( $base_set ? $base_set : $by_week_day );
    $base_set = $base_set->intersection( $span )
                if $span;

    # TODO:
    # wkst
    # bysetpos

    if ( exists $args{bysetpos} ) {
        $base_set = _recur_bysetpos (
            freq => $args{freq},
            interval => $args{interval},
            bysetpos => $args{bysetpos},
            recurrence => $base_set );
        delete $args{bysetpos};
    }

    # check for nonprocessed arguments
    delete $args{freq};
    my @args = %args;
    die "these arguments are not implemented: "._param_str(%args) if @args;

    return $base_set;
}


=head1 NAME

DateTime::Event::ICal - Perl DateTime extension for computing rfc2445 recurrences.

=head1 SYNOPSIS

 use DateTime;
 use DateTime::Event::ICal;
 
 my $dt = DateTime->new( year   => 2000,
                         month  => 6,
                         day    => 20,
                       );

 my $set = DateTime::Event::ICal->recur( %args );

 my $dt_next = $set->next( $dt );

 my $dt_previous = $set->previous( $dt );

 my $bool = $set->contains( $dt );

 my @days = $set->as_list( start => $dt1, end => $dt2 );

 my $iter = $set->iterator;

 while ( my $dt = $iter->next ) {
     print ' ', $dt->datetime;
 }

=head1 DESCRIPTION

This module provides convenience methods that let you easily create
C<DateTime::Set> objects for rfc2445 style recurrences.

=head1 USAGE

=over 4

=item recur

This method returns a C<DateTime::Set> object representing the
given recurrence.

  my $set = DateTime::Event::ICal->recur( %args );

=over 4

=item * dtstart

A DateTime object. Start date.

C<dtstart> is not included in the recurrence, unless it satisfy the rule.

The set can thus be used for creating exclusion rules (rfc2445 C<exrule>),
which don't include C<dtstart>.

=item * dtend

A DateTime object. End date.

=item * freq

One of:

   'yearly', 'monthly', 'weekly', 'daily', 
   'hourly', 'minutely', 'secondly'

=item * until

A DateTime object. End date. 

=item * count

A positive number. 
Total number of recurrences, after the rule is evaluated.

=item * interval

A positive number, starting in 1. Default is 1.

Example: 

  freq=yearly;interval=2

events on this recurrence occur each other year.

=item * wkst

Week start day. Default is monday ('mo').

=item * bysetpos => [ list ]

Positive or negative numbers, without zero.

Example: 

  freq=yearly;bysetpos=2 

inside a yearly recurrence, select 2nd occurence within each year.

=item * bysecond => [ list ], byminute => [ list ], byhour => [ list ]

Positive or negative numbers, including zero.

=item * byday => [ list ]

Day of week: one or more of:

 'mo', 'tu', 'we', 'th', 'fr', 'sa', 'su'

The day of week may have a prefix:

 '1tu',  # the first tuesday of month or year
 '-2we'  # the second to last wednesday of month or year

=item * bymonthday => [ list ], byyearday => [ list ]

Positive or negative numbers, without zero.
Days start in 1.

Day -1 is last day of month or year.

=item * byweekno => [ list ]

Week number. 
Positive or negative numbers, without zero.
First week of year is week 1. 

Default week start day is monday.

Week -1 is the last week of year.

=item * bymonth => [ list ]

Months, numbered 1 until 12.
Positive or negative numbers, without zero.

Month -1 is december.

=back

=back

=head1 VERSION NOTES

byday=1fr gives wrong results if byhour, byminute, or bysecond 
have 2 or more options.

wkst is not implemented.

no tests were made defining recurrences without dtstart.

the effect of 'count' on a recurrence without dtstart is not defined.
the effect of count == 0 is not defined.

no tests were made using datetimes with timezones.

mixing positive and negative arguments in the same list
might give wrong results is the numbers are big enough
to cause the datetimes to interleave.

some arguments are not checked for overflow, 
such as byyearday.

'until' is not parsed. It should be parsed by DateTime::Format::ICal.

=head1 AUTHOR

Flavio Soibelmann Glock
fglock@pucrs.br

=head1 CREDITS

The API was developed with help from the people
in the datetime@perl.org list. 

=head1 COPYRIGHT

Copyright (c) 2003 Flavio Soibelmann Glock.  
All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=head1 SEE ALSO

datetime@perl.org mailing list

DateTime Web page at http://datetime.perl.org/

DateTime

DateTime::Event::Recurrence - simple rule-based recurrences

DateTime::Format::ICal - can parse rfc2445 recurrences

DateTime::Set - recurrences defined by callback subroutines

DateTime::Event::Cron - recurrences defined by 'cron' rules

DateTime::SpanSet 

=cut
1;

