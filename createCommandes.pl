#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# Author: Denis BEURIVE
# This script is used to generate a list of commands that should be replayed.
#
# Examples:
#
# $ perl createCommandes.pl --dateFrom=+2009:10:01:09:00:00 --dateTo=-2009:10:01:14:00:00 --period=1 --unit=hour
# perl myCommand.pl --dateFrom=+2009:10:01:09:00:00 --dateTo=-2009:10:01:10:00:00
# perl myCommand.pl --dateFrom=+2009:10:01:10:00:00 --dateTo=-2009:10:01:11:00:00
# perl myCommand.pl --dateFrom=+2009:10:01:11:00:00 --dateTo=-2009:10:01:12:00:00
# perl myCommand.pl --dateFrom=+2009:10:01:12:00:00 --dateTo=-2009:10:01:13:00:00
# perl myCommand.pl --dateFrom=+2009:10:01:13:00:00 --dateTo=-2009:10:01:14:00:00
#
# $ perl createCommandes.pl --dateFrom=+year:month:day:hour --dateTo=-year:month:day:hour+3hours --period=15 --unit=minute
# perl myCommand.pl --dateFrom=+2022:07:07:22:00:00 --dateTo=-2022:07:07:22:15:00
# perl myCommand.pl --dateFrom=+2022:07:07:22:15:00 --dateTo=-2022:07:07:22:30:00
# perl myCommand.pl --dateFrom=+2022:07:07:22:30:00 --dateTo=-2022:07:07:22:45:00
# perl myCommand.pl --dateFrom=+2022:07:07:22:45:00 --dateTo=-2022:07:07:23:00:00
# perl myCommand.pl --dateFrom=+2022:07:07:23:00:00 --dateTo=-2022:07:07:23:15:00
# perl myCommand.pl --dateFrom=+2022:07:07:23:15:00 --dateTo=-2022:07:07:23:30:00
# perl myCommand.pl --dateFrom=+2022:07:07:23:30:00 --dateTo=-2022:07:07:23:45:00
# perl myCommand.pl --dateFrom=+2022:07:07:23:45:00 --dateTo=-2022:07:08:00:00:00
# perl myCommand.pl --dateFrom=+2022:07:08:00:00:00 --dateTo=-2022:07:08:00:15:00
# perl myCommand.pl --dateFrom=+2022:07:08:00:15:00 --dateTo=-2022:07:08:00:30:00
# perl myCommand.pl --dateFrom=+2022:07:08:00:30:00 --dateTo=-2022:07:08:00:45:00
# perl myCommand.pl --dateFrom=+2022:07:08:00:45:00 --dateTo=-2022:07:08:01:00:00

use lib '.';
use strict;
use Getopt::Long;
use DateTime;
use DateParse;

# ----------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------

my $cli_help                 = 0;     # Help command flag.
my $cli_dateFrom             = undef; # Starting date from the command line (string).
my $cli_dateTo               = undef; # Ending date from the command line (string).
my $cli_period               = undef; # Period, from the command line.
my $cli_unit                 = undef; # Period's unit.

my %cliFrom              = ();    # Internal representation of the starting date.
my %cliTo                = ();    # Internal representation of the ending date.
my $cliDateFrom          = undef; # Starting date for the current loop.
my $cliDateTo            = undef; # End date for the current loop.
my $decal                = undef; # Total cumulated duration;

# ----------------------------------------------------------------------
# Parse the command line
# ----------------------------------------------------------------------

unless (
         GetOptions (
                      'help'          => \$cli_help,
                      'dateFrom=s'    => \$cli_dateFrom,
                      'dateTo=s'      => \$cli_dateTo,
                      'period=s'      => \$cli_period,
                      'unit=s'        => \$cli_unit
                    )
       )
{
   print STDERR "ERROR: Invalid command line.\n";
   exit 1;
}

sub help()
{
  print STDOUT "perl createDates.pl [--help] --dateFrom=... --dateTo=... --period=... --unit=...\n\n";
  print STDOUT "\t--dateFrom: This date defines the beginning of the period upon which we calculate statistics.\n";
  print STDOUT "\t            Ex: +2010:10:01 or +2010:10:01:21:55:00\n\n";
  print STDOUT "\t--dateTo: This date defines the end of the period upon which we calculate statistics.\n";
  print STDOUT "\t          Ex: -2010:10:02\n\n";
  print STDOUT "\t--period: This value represents the duration between two dates.\n\n";
  print STDOUT "\t--unit: This value represents the period's unit.\n\n";

  print STDOUT "Example: perl createCommandes.pl --dateFrom=+2010:11:01 --dateTo=+2011:01:01 --period=1 --unit=day\n";
}

if ($cli_help) { help(); exit 0; }

unless (defined($cli_dateFrom)) { print STDERR "ERROR: Missing command line argument <dateFrom>!\n"; exit 1; }
unless (defined($cli_dateTo))   { print STDERR "ERROR: Missing command line argument <dateTo>!\n";   exit 1; }
unless (defined($cli_period))   { print STDERR "ERROR: Missing command line argument <period>!\n";   exit 1; }
unless (defined($cli_unit))     { print STDERR "ERROR: Missing command line argument <unit>!\n";     exit 1; }

# ------------------------------------------------------------------------------
# Check dates
# ------------------------------------------------------------------------------

%cliFrom = parseDateAndDuration($cli_dateFrom);
%cliTo   = parseDateAndDuration($cli_dateTo);

unless (exists($cliFrom{'datetime'}))	{
						my $mess = "Invalid date specification for start date ($cli_dateFrom)";
						print STDERR "$mess\n";
						exit 1;
					}
unless (exists($cliTo{'datetime'}))	{
						my $mess = "Invalid date specification for stop date ($cli_dateTo)";
						print STDERR "$mess\n";
						exit 1;
					}

# ----------------------------------------------------------------------
# Calculate date day per day
# ----------------------------------------------------------------------

$cliDateFrom = $cli_dateFrom;
$cliDateTo   = $cli_dateTo;
$decal       = 0;

while (1)
{
  my %from    = (); # Starting date.
  my %to      = (); # Ending date.
  my $decalTo = undef;
  my $tagFrom = undef;
  my $tagTo   = undef;

  $decalTo       = $decal + $cli_period;
  $cli_dateFrom  = "${cliDateFrom}+${decal}${cli_unit}";
  $cli_dateTo    = "${cliDateFrom}+${decalTo}${cli_unit}";
  %from          = parseDateAndDuration($cli_dateFrom);
  %to            = parseDateAndDuration($cli_dateTo);
  $decal         += $cli_period;

  if (DateTime->compare($to{'datetime'}, $cliTo{'datetime'}) > 0) { last; }

  ## -------------------------------
  ## Lines to adapt.
  ## -------------------------------

  $tagFrom = $from{'datetime'}->strftime('+%Y:%m:%d:%H:%M:%S');
  $tagTo   = $to{'datetime'}->strftime('-%Y:%m:%d:%H:%M:%S');

  print "perl myCommand.pl --dateFrom=$tagFrom --dateTo=$tagTo\n";
}

