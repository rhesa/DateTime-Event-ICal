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
$VERSION = '0.00_01';

use constant INFINITY     =>       100 ** 100 ** 100 ;
use constant NEG_INFINITY => -1 * (100 ** 100 ** 100);

sub recur {
    my $class = shift;
    my %args = @_;

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

    # setup the "default time"
    my $dtstart = exists $args{dtstart} ?
            delete $args{dtstart} : 
            DateTime->new( year => 2000, month => 1, day => 1 );
    # warn 'DTSTART '. $dtstart->datetime;

    my %by;
    # bysecond / byminute / byhour

    # TODO: test with leap seconds
    $by{seconds} = exists $args{bysecond} ?
                       delete $args{bysecond} : 
                       ( $args{freq} eq 'secondly' ? 
                           [ 0 .. 59, -1 ] : 
                           $dtstart->second );

    $by{minutes} = exists $args{byminute} ?
                      delete $args{byminute} : 
                      ( $args{freq} eq 'minutely' ||
                        $args{freq} eq 'secondly' ? 
                          [ 0 .. 59 ] :
                          $dtstart->minute );

    # TODO: replace for negative values, in order to avoid DST changes
    $by{hours} = exists $args{byhour} ?
                    delete $args{byhour} : 
                    ( $args{freq} eq 'hourly' || 
                      $args{freq} eq 'minutely' ||
                      $args{freq} eq 'secondly' ?
                        [ 0 .. 23 ] :
                        $dtstart->hour );


    my $has_day = 0;

    my $by_year_day;
    if ( exists $args{byyearday} ) 
    {
        my %by2 = %by;   # reuse hour/min/sec components
        $by2{days} = $args{byyearday};
        $by_year_day = DateTime::Event::Recurrence->yearly( %by2 );
        $has_day = 1;
        delete $args{byyearday};
    }

    my $by_month_day;

    if ( $args{freq} eq 'monthly' &&
         ! exists $args{bymonth} ) 
    {
        $args{bymonth} = [ 1 .. 12 ];
    }

    if ( exists $args{bymonthday} ||
         exists $args{bymonth} ) 
    {
        my %by2 = %by;   # reuse hour/min/sec components
        $by2{days} = exists $args{bymonthday} ?
                         $args{bymonthday} :
                         ( $args{freq} eq 'daily' ?
                             [ 1 .. 31 ] :
                             $dtstart->day );
        if ( exists $args{bymonth} ) 
        {
            $by2{months} = $args{bymonth};
            $by_month_day = DateTime::Event::Recurrence->yearly( %by2 );
            delete $args{bymonth};
        }
        else 
        {
            $by_month_day = DateTime::Event::Recurrence->monthly( %by2 );
        }
        $has_day = 1;
        delete $args{bymonthday};
    }

    my $by_week_day;
    # TODO: byweek without byday
    if ( exists $args{byday} ) 
    {
        my %by2 = %by;   # reuse hour/min/sec components
        # TODO: indexed "-1fr" argument not supported yet
        my %weekdays = ( mo => 1, tu => 2, we => 3, th => 4, 
                         fr => 5, sa => 6, su => 7 );
        $by2{days} = map { $weekdays{$_} } @{$args{byday}};
        if ( exists $args{byweek} ) 
        {
            $by2{weeks} = $args{byweek};
            $by_week_day = DateTime::Event::Recurrence->yearly( %by2 );
            delete $args{byweek};
        }
        else 
        {
            $by_week_day = DateTime::Event::Recurrence->weekly( %by2 );
        }
        $has_day = 1;
        delete $args{byday};
    }

    # freq == hourly, minutely, secondly 
    my $by_hour;
    unless ( $has_day ) 
    {
        no strict 'refs';
        $by_hour = &{"DateTime::Event::Recurrence::$args{freq}"} ( undef, %by );
    }
    # warn 'BASE-SET '. $base_set->intersection($span)->{set};

    # join the rules together

    my $base_set = $by_year_day;
    $base_set = $base_set && $by_month_day ?
                $base_set->intersection( $by_month_day ) :
                ( $base_set ? $base_set : $by_month_day );
    $base_set = $base_set && $by_week_day ?
                $base_set->intersection( $by_week_day ) :
                ( $base_set ? $base_set : $by_week_day );
    $base_set = $base_set && $by_hour ?
                $base_set->intersection( $by_hour ) :
                ( $base_set ? $base_set : $by_hour );
    return DateTime::Set->empty_set unless $base_set;

    # interval / count

    my $interval;
    if ( exists $args{interval} || exists $args{count} ) 
    {
        $args{interval} = 1 unless $args{interval};
        $args{count} = INFINITY unless $args{count};

        no strict 'refs';
        my $interval_base_set = &{"DateTime::Event::Recurrence::$args{freq}"};
        my $interval_spanset = DateTime::SpanSet->from_sets(
                 start_set => $interval_base_set,
                 end_set =>   $interval_base_set );
        $interval_spanset = $interval_spanset->intersection( $span );
        # note: 'select' is a Set::Infinite method,
        #       we have to rebless it to DateTime::SpanSet
        my $interval_set_inf = $interval_spanset->{set}
                  ->select( 
                      freq => $args{interval}, 
                      count => $args{count} );
        # warn 'INTERVAL,COUNT '.$interval_set_inf;
        $interval = bless { set => $interval_set_inf }, 'DateTime::SpanSet';

        delete $args{interval};
        delete $args{count};
    }

    $base_set = $base_set->intersection( $interval ) if $interval;

    # TODO:
    # wkst
    # bysetpos

    # check for nonprocessed arguments
    delete $args{freq};
    my @args = %args;
    warn "remaining args are not implemented: @args" if @args;

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

=item * recur

This method returns a C<DateTime::Set> object representing the
given recurrence.

  my $set = DateTime::Event::ICal->recur( %args );

=over 4

=item * dtstart

C<dtstart> is not included in the recurrence, unless it satisfy the rule.

=item * dtend

=item * freq

=item * until

=item * count

=item * interval

=item * wkst

=item * bysetpos

=item * bysecond byminute byhour

=item * byday 

=item * bymonthday byyearday

=item * byweekno

=item * bymonth

=back

=back

=head1 AUTHOR

Flavio Soibelmann Glock
fglock@pucrs.br

=head1 CREDITS

The API is under development, with help from the people
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

DateTime::Event::Recurrence

DateTime::Set 

DateTime::SpanSet 

=cut
1;

