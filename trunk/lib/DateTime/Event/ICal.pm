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
            # TODO: -1fr should work too
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
            $by{days} =    $args{bymonthday} if exists $args{bymonthday};
            $by{days} =    $dtstart->day unless exists $by{days};
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
    # ( freq , interval, dtstart
    #    week_count(s) , week_day(s) )
    my %args = @_;
    my $base_set;

    my $days;
    die "week count can't be zero" if $args{week_count} == 0;
    if ( $args{week_count} > 0 ) {
        $days = 1 + 7 * ( $args{week_count} - 1 );
    }
    else {
        $days = -1 + 7 * ( $args{week_count} + 1 );
    }

    # TODO: use DTSTART

    # TODO: use a singleton for $base_set ?
    if ( $args{freq} eq 'monthly' ) {
        $base_set = DateTime::Event::Recurrence->monthly(
            interval => $args{interval},
            days => $days );
    }
    elsif ( $args{freq} eq 'yearly' ) {
        $base_set = DateTime::Event::Recurrence->yearly(
            interval => $args{interval},
            days => $days );
    }
    else {
        die "invalid freq ($args{freq})";
    }

    # return a callback-recurrence

    # next-sub
    sub {
        # ( current_value, 'month'/'year', n, weekday 0-6 )
        my $self = $_[0]->clone;
        my $start = $_[0]->truncate( to => $_[1] );
    }

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

    delete $args{freq};
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

    # check for nonprocessed arguments
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

The set can thus be used for creating exclusion rules (rfc2445 C<exrule>),
which don't include C<dtstart>.

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

