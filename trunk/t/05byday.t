use strict;

use Test::More tests => 6;

use DateTime;
use DateTime::Event::ICal;

# yearly
{
    my $dt1 = new DateTime( year => 2000 );
    my ( $set, @dt, $r );

    # test contributed by John Bishop
    $set = DateTime::Event::ICal->recur( 
       freq => 'yearly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( years => 3 ),
       bymonth => 7,
       byday => '3mo' );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-07-17T00:00:00 2001-07-16T00:00:00 2002-07-15T00:00:00',
        "yearly, bymonth, byday" );


    $set = DateTime::Event::ICal->recur(
       freq => 'yearly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( years => 3 ),
       bymonth => 7,
       byday => '3mo',
       byhour => 10 );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-07-17T10:00:00 2001-07-16T10:00:00 2002-07-15T10:00:00',
        "yearly, bymonth, byday, byhour" );


    $set = DateTime::Event::ICal->recur(
       freq => 'yearly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( years => 1 ),
       bymonth => 7,
       byday => ['3mo', 'fr' ],
       byhour => 10 );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-07-07T10:00:00 2000-07-14T10:00:00 2000-07-17T10:00:00 2000-07-21T10:00:00 2000-07-28T10:00:00',
        "yearly, bymonth, byday index+nonindex, byhour" );
}

# monthly
{
    my $dt1 = new DateTime( year => 2000 );
    my ( $set, @dt, $r );

    $set = DateTime::Event::ICal->recur(
       freq => 'monthly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( months => 4 ),
       byday => '3mo' );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-01-17T00:00:00 2000-02-21T00:00:00 2000-03-20T00:00:00 2000-04-17T00:00:00',
        "monthly, byday" );


    $set = DateTime::Event::ICal->recur(
       freq => 'monthly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( months => 4 ),
       byday => '3mo',
       byhour => 10 );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-01-17T10:00:00 2000-02-21T10:00:00 2000-03-20T10:00:00 2000-04-17T10:00:00',
        "monthly, byday, byhour" );

    $set = DateTime::Event::ICal->recur(
       freq => 'monthly',
       dtstart => $dt1,
       dtend => $dt1->clone->add( months => 2 ),
       byday => ['3mo', 'fr' ],
       byhour => 10 );

    @dt = $set->as_list;
    $r = join(' ', map { $_->datetime } @dt);
    is( $r,
        '2000-01-07T10:00:00 2000-01-14T10:00:00 2000-01-17T10:00:00 '.
        '2000-01-21T10:00:00 2000-01-28T10:00:00 2000-02-04T10:00:00 '.
        '2000-02-11T10:00:00 2000-02-18T10:00:00 2000-02-21T10:00:00 '.
        '2000-02-25T10:00:00',
        "monthly, byday index+nonindex, byhour" );
}

