package dateParse;
use strict;
use warnings FATAL => 'all';
use Exporter;
use DateTime;

our (@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(parseDateAndDuration printDate);

# [PRIVATE]
# Local time zone.
my $tz = DateTime::TimeZone::Local->TimeZone();

# [PUBLIC]
# This function parses a date along with a duration. The syntax used to define the date is:
# (+|-)${date}((+|-)${duration})?
# With: ${date}     : "NOW" or YYYY[MM[DD[HH[SS[MM]]]]]. See the decription of the function parseDate().
#       ${duration} : See description of the function parseDuration(). The duration part is optional.
# @param string String that represents the date, in "Date/Duration" notation.
# @return Upon successful completion, the function returns a hash. This hash contains 2 entries:
#         - inclusion: The value could be 0 or 1, depending if the date is included or not.
#         - datetime: The date, as an object of class DateTime that represents the date.
#         Otherwize, the function returns an empty hash.

sub parseDateAndDuration
{
  my ($string) = @_;
  my %result = ();

  if ($string =~ m/^(\+|\-)([^\-\+]+)((\+|\-)([^\-\+]+))?$/)
  {
    my $inclusion   = $1;
    my $date        = $2;
    my $gap         = $3;
    my $direction   = $4;
    my $duration    = $5;
    my $dateObj     = undef;
    my $durationObj = undef;

    if ($date =~ m/^NOW$/i)
    {
      $dateObj = DateTime->now();
      $dateObj->set_time_zone($tz);
    }
    else { $dateObj = parseDate($date); }

    unless(defined($dateObj)) { return undef; }
    $result{'inclusion'} = ($inclusion eq '+')? 1 : 0;

    if (defined($gap))
    {
      $durationObj = parseDuration($duration);
      unless(defined($durationObj)) { return undef; }

      if ($direction eq '+')
      {
        $result{'datetime'} = $dateObj->add($durationObj);
        return %result;
      }
      else
      {
        $result{'datetime'} = $dateObj->subtract($durationObj);
        return %result;
      }
    }

    $result{'datetime'} = $dateObj;
    return %result;
  }

  return ();
}

# [PUBLIC]
# This function returns a string that represents the date, interpreted from the "Date/Duration" notation.
# @param $expr String that represents the date in "Date/Duration" notation.
# @return Upon successfull completion, the function will return a pretty textual representation of the date.
#         Otherwize, the function returns the value undef.

sub printDate
{
  my ($expr) = @_;
  my %date = parseDateAndDuration($expr);

  unless(exists($date{'datetime'})) { return undef; }
  return $date{'datetime'}->strftime('%A %d %B %Y - %H:%M:%S') . ' ' . ($date{'inclusion'} ? '(included)' : '(excluded)');
}

# [PRIVATE]
# This function parses a string that represents a duration.
# The syntax use to define a duration is:
#    (\d+\s*years?:)?   \
#    (\d+\s*months?:)?  \
#    (\d+\s*weeks?:)?   \
#    (\d+\s*days?:)?    \
#    (\d+\s*hours?:)?   \
#    (\d+\s*minutes?:)? \
#    (\d+\s*seconds?)?
# @param $string string that represents the duration.
# @return Upon successful completion, the function returns an object of the class DateTime::Duration.
#         Otherwize, the function returns the value undef.

sub parseDuration
{
  my ($string) = @_;
  my $lastIdx  = 0;
  my @tab      = ();
  my %order    = ('years' => 1, 'months' => 2, 'weeks' => 3, 'days' => 4, 'hours' => 5, 'minutes' => 6, 'seconds' => 7);
  my %duration = ('years'   => 0,
                  'months'  => 0,
                  'weeks'   => 0,
                  'days'    => 0,
                  'hours'   => 0,
                  'minutes' => 0,
                  'seconds' => 0);

  @tab = split(/:/, $string);
  if ((int @tab) == 0) { return undef; }

  for (my $i=0; $i<(int @tab); $i++)
  {
    ## Remove leading and traling spaces.
    $tab[$i] =~ s/^\s*//;
    $tab[$i] =~ s/\s*$//;

    if ($tab[$i] =~ m/^(\d+)\s*(\w+)$/)
    {
      my $value =  $1;
      my $unit  =  lc($2);

      $unit =~ s/s?$/s/;
      # print "value=[$value], unit=[$unit]\n";
      unless(exists($duration{$unit})) { return undef; } ## The unit is unknown.
      if ($order{$unit} <= $lastIdx)   { return undef; } ## The unit has already been found
      $duration{$unit} = $value;
      $lastIdx         = $order{$unit};
    }
    else { return undef; }
  }

  # foreach my $k (%duration) { print "o $k => " . $duration{$k} . "\n"; }
  return DateTime::Duration->new(%duration);
}

# [PRIVATE]
# This function parses a date. The syntax used to define the date is:
# $year[:$month[:$day[:$hour[:$minute[:$second]]]]]
# With: $year    = year|\d+
#       $month   = month|\d+
#       $day     = day|\d+
#       $hour    = hour|\d+
#       $minute  = minute|\d+
#       $second  = second|\d+
# @param $string String that represents the date.
# @return Upon successful completion, the function returns an object of the class DateTime.
#         Otherwize, the function returns the value undef.

sub parseDate
{
  my ($string) = @_;
  my $res      = undef;
  my @tab      = ();
  my %date     = ('year'    => undef,
                  'month'   => 1,
                  'day'     => 1,
                  'hour'    => 0,
                  'minute'  => 0,
                  'second'  => 0);
  my %parsers  = ('year'    => \&getYear,
                  'month'   => \&getMonth,
                  'day'     => \&getDay,
                  'hour'    => \&getHour,
                  'minute'  => \&getMinute,
                  'second'  => \&getSecond);
  my @position = ('year', 'month', 'day', 'hour', 'minute', 'second');

  @tab = split(/:/, $string);
  for (my $i=0; $i<(int @tab); $i++)
  {
    if ($tab[$i] =~ m/^(([a-z]+)|(\d+))$/i)
    {
      my $tag   = $2;
      my $value = $3;

      if (defined($tag))
      {
        my $function = undef;

        $tag = lc($tag);
        unless ($tag eq $position[$i]) { return undef; }
        $function   = $parsers{$tag};
        $date{$tag} = &{$function}('NOW');
      }
      else { $date{$position[$i]} = $value; }
    }
    else { return undef; }
  }

  $res = DateTime->new(%date);
  $res->set_time_zone($tz);

  return $res;
}

# [PRIVATE]
# This function returns the year's value, interpreted from the date's syntax.
# NOW means "the current year".
# @param $y The string that represents the year (in absolute or relative notation).
# @return The function returns a value the represents the correct year's value.

sub getYear
{
  my ($y) = @_;

  if ($y =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->year();
  }

  if ($y =~ /^[0-9]+$/) { return $y; }

  return undef;
}

# [PRIVATE]
# This function returns the month's value, interpreted from the date's syntax.
# NOW means "the current month".
# @param $m The string that represents the month (in absolute or relative notation).
# @return The function returns a value the represents the correct month's value.

sub getMonth
{
  my ($m) = @_;

  if ($m =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->month();
  }

  if ($m =~ /^[0-9]+$/) { return $m; }

  return undef;
}

# [PRIVATE]
# This function returns the day's value, interpreted from the date's syntax.
# NOW means "the current day".
# @param $d The string that represents the day (in absolute or relative notation).
# @return The function returns a value the represents the correct day's value.

sub getDay
{
  my ($d) = @_;

  if ($d =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->day();
  }

  if ($d =~ /^[0-9]+$/) { return $d; }

  return undef;
}

# [PRIVATE]
# This function returns the hour's value, interpreted from the date's syntax.
# NOW means "the current hour".
# @param $h The string that represents the hour (in absolute or relative notation).
# @return The function returns a value the represents the correct hour's value.

sub getHour
{
  my ($h) = @_;

  if ($h =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->hour();
  }

  if ($h =~ /^[0-9]+$/) { return $h; }

  return undef;
}

# [PRIVATE]
# This function returns the minute's value, interpreted from the date's syntax.
# NOW means "the current minute".
# NOW-N means "N minutes before the current minute".
# @param $m The string that represents the minute (in absolute or relative notation).
# @return The function returns a value the represents the correct minute's value.

sub getMinute
{
  my ($m) = @_;

  if ($m =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->minute();
  }

  if ($m =~ /^[0-9]+$/) { return $m; }

  return undef;
}

# [PRIVATE]
# This function returns the second's value, interpreted from the date's syntax.
# NOW means "the current second".
# @param $s The string that represents the second (in absolute or relative notation).
# @return The function returns a value the represents the correct second's value.

sub getSecond
{
  my ($s) = @_;

  if ($s =~ /^NOW$/i)
  {
    my $now = DateTime->now();
    $now->set_time_zone($tz);
    return $now->second();
  }

  if ($s =~ /^[0-9]+$/) { return $s; }

  return undef;
}

# [TEST]
# This function should be used to test this module.

sub test_parseDate
{
  my $date       = $ARGV[0];
  my $dateObject = parseDate($date);

  unless(defined($dateObject)) { print "[$date] is not correct!\n"; exit 1; }
  print "Date <$date>: " . $dateObject->datetime . "\n";
  exit 0;
}

# [TEST]
# This function should be used to test this module.

sub test_parseDuration
{
  my $duration       = $ARGV[0];
  my $durationObject = parseDuration($duration);

  unless(defined($durationObject)) { print "[$duration] is not correct!\n"; exit 1; }
  exit 0;
}

# [TEST]
# This function should be used to test this module.

sub printExamples
{
  my @dates =
  qw (
   +NOW
   -NOW
   +2000
   +2000:month
   +2000:02
   +year:02
   -year:02
   +year:month:day
   +year:month:day:hour
   +year:month-1year
   +year:month-2months
   -year:month-2months
   +year:month-1day
   +year:month-2days
   +NOW-3seconds
   -2009:01:01:02:02:02
   +year-1second
   +year-1day
   +year-1month
   +year-1week
   +year:12:25+10days
  );

  foreach my $date (@dates)
  {
    print $date . ' => ' . printDate($date) . "\n";
  }
}

1;