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

# debugging method
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

sub recur {
    my $class = shift;
    my %args = @_;

    # TODO: use Params::Validate 
    die "argument freq is missing"
        unless $args{freq};

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

    if ( exists $args{count} ) 
    {
        # count
        my $n = $args{count};
        $n *= $args{interval};
        my $unit = $args{freq};
        $unit =~ s/ly/s/;
        $unit = 'days' if $unit eq 'dais';  # :)
        # warn "count $args{count} $unit => $n ";
        $span = $span->complement(
                    DateTime::Span->from_datetimes( 
                        start => $args{dtstart}->clone->add( $unit => $n )
                ) );
        delete $args{count};
    }

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

    # try to make a recurrence using DateTime::Event::Recurrence
        # TODO!
        # freq = any
        # interval = any
        # byxxx = matching freq: hourly,byminute,bysecond

    my $base_set;
    my %by;
    if ( $args{freq} eq 'secondly' ) {
        unless ( grep { /by/ } keys %args ) {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =    $dtstart;
            $base_set = DateTime::Event::Recurrence->secondly( %by );
        }
    }
    elsif ( $args{freq} eq 'minutely' ) {
        unless ( grep { /by/ && !/bysecond/ } keys %args ) {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;  
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $base_set = DateTime::Event::Recurrence->minutely( %by );
        }
    }
    elsif ( $args{freq} eq 'hourly' ) {
        unless ( grep { /by/ && !/bysecond/ && !/byminute/ } keys %args ) {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $base_set = DateTime::Event::Recurrence->hourly( %by );
        }
    }
    elsif ( $args{freq} eq 'daily' ) {
        unless ( grep { /by/ &&
                        !/bysecond/ && !/byminute/ && !/byhour/
                      } keys %args ) 
        {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};
            $base_set = DateTime::Event::Recurrence->daily( %by );
        }
    }
    elsif ( $args{freq} eq 'monthly' ) {
        unless ( grep { /by/ &&
                        !/bymonthday/ && 
                        !/bysecond/ && !/byminute/ && !/byhour/
                      } keys %args )
        {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};
            $by{days} =    $args{bymonthday} if exists $args{bymonthday};
            $by{days} =    $dtstart->day unless exists $by{days};
            $base_set = DateTime::Event::Recurrence->monthly( %by );
        }
    }
    elsif ( $args{freq} eq 'yearly' ) {
        unless ( grep { /by/ &&
                        !/bymonth/ &&   # ... !/bymonthday/ &&
                        !/bysecond/ && !/byminute/ && !/byhour/
                      } keys %args )
        {
            $by{interval} = $args{interval} if exists $args{interval};
            $by{start} =   $dtstart;
            $by{seconds} = $args{bysecond} if exists $args{bysecond};
            $by{seconds} = $dtstart->second unless exists $by{seconds};
            $by{minutes} = $args{byminute} if exists $args{byminute};
            $by{minutes} = $dtstart->minute unless exists $by{minutes};
            $by{hours} =   $args{byhour} if exists $args{byhour};
            $by{hours} =   $dtstart->hour unless exists $by{hours};
            $by{days} =    $args{bymonthday} if exists $args{bymonthday};
            $by{days} =    $dtstart->day unless exists $by{days};
            $by{months} =  $args{bymonth} if exists $args{bymonth};
            $by{months} =  $dtstart->month unless exists $by{months};
            $base_set = DateTime::Event::Recurrence->yearly( %by );
        }
    }
    if ( $base_set ) 
    {
        return $base_set->intersection( $span ) if $span;
        return $base_set;
    }

    # not a simple recurrence.
    # make the recurrence, step by step

    %by = ();
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
                         ( $args{freq} eq 'daily' || $args{freq} eq 'yearly' ?
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
    # TODO: byweekno without byday
    if ( exists $args{byday} ||
         exists $args{byweekno} ) 
    {
        my %by2 = %by;   # reuse hour/min/sec components
        # TODO: indexed "-1fr" argument not supported yet
        my %weekdays = ( mo => 1, tu => 2, we => 3, th => 4, 
                         fr => 5, sa => 6, su => 7 );

        $by2{days} = exists $args{byday} ?
                         [ map { $weekdays{$_} } @{$args{byday}} ] :
                         ( $args{freq} eq 'daily' ?
                             [ 1 .. 7 ] :
                             $dtstart->day_of_week );

        if ( exists $args{byweekno} ) 
        {
            $by2{weeks} = $args{byweekno};
            $by_week_day = DateTime::Event::Recurrence->yearly( %by2 );
            delete $args{byweekno};
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

        $by{interval} = delete $args{interval} if $args{interval};

        $by_hour = &{"DateTime::Event::Recurrence::$args{freq}"} ( undef, %by );
    }
    # warn 'BASE-SET '. $base_set->intersection($span)->{set};

    # join the rules together

    $base_set = $by_year_day;
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

    # interval

    my $interval;
    if ( $args{interval} > 1 )   # || exists $args{count} ) 
    {
        # $args{interval} = 1 unless $args{interval};
        # $args{count} = INFINITY unless $args{count};

        no strict 'refs';
        my $interval_base_set = &{"DateTime::Event::Recurrence::$args{freq}"}();
        my $interval_spanset = DateTime::SpanSet->from_sets(
                 start_set => $interval_base_set,
                 end_set =>   $interval_base_set );
        $interval_spanset = $interval_spanset->intersection( $span );
        # note: 'select' is a Set::Infinite method,
        #       we have to rebless it to DateTime::SpanSet
        my $interval_set_inf = $interval_spanset->{set}
                  ->select( 
                      freq => $args{interval}, 
                      # count => $args{count} 
                    );
        # warn 'INTERVAL,COUNT '.$interval_set_inf;
        $interval = bless { set => $interval_set_inf }, 'DateTime::SpanSet';

        delete $args{interval};
        # delete $args{count};
    }

    if ( $interval ) {
        $base_set = $base_set->intersection( $interval );
    }
    elsif ( $span ) {
        $base_set = $base_set->intersection( $span );
    }

    # TODO:
    # wkst
    # bysetpos

    # check for nonprocessed arguments
    delete $args{freq};
    delete $args{interval};
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

=item recur

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

