use strict;

use ExtUtils::MakeMaker;

    WriteMakefile( NAME         => 'DateTime::Event::ICal',
                   VERSION_FROM => 'lib/DateTime/Event/ICal.pm',
                   AUTHOR       => 'Flavio S. Glock <fglock@pucrs.br>',
                   ABSTRACT     => 'DateTime rfc2445 recurrences',

                   PREREQ_PM    => { 'DateTime' => 0,
                                     'DateTime::Event::Recurrence' => 0.03,
                                   },
                 );

