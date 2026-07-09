package mitraille::printer;

use strict;

sub new
{
  my $class = shift;
  my $self = bless {count => 0, @_}, $class;
  
  $self->{fhout} ||= \*STDOUT;

  unless (-t $self->{fhout})
    {
      $self->{color} = 0;
    }

  return $self;
}

sub center
{
  my ($s, $n) = @_; 
  my $i = 0;
  while (length ($s) < $n) 
    {   
      $s = $i % 2 ? " $s" : "$s ";
      $i++;
    }   
  return $s; 
}

sub colored
{
  my ($self, $color, $text) = @_;
  return $text;
}

sub separator
{
  return "   ";
}

sub line
{
  my $self = shift;

  my @len = @{ $self->{length} };
  my @jus = @{ $self->{justify} };

  my $col = 0;

  my $line = '';

  my $separator = $self->separator ();

  for (my $i = 0; $i <= $#_; $i++)
    {
      $line .= $separator;

      my $color = '';
      if ($_[$i] =~ m{^<(.*)>$}goms)
        {
          $color = $1;
          $i++;
        }
      my $str = $_[$i];

      my ($jus, $len) = ($jus[$col], $len[$col]);

      if ($jus && $len)
        {
          if ($jus eq 'center')
            {
              $str = &center ($str, $len);
            }
          elsif ($jus eq 'left')
            {
              $str = sprintf ("%-${len}.${len}s", $str);
            }
          elsif ($jus eq 'right')
            {
              $str = sprintf ("%${len}.${len}s", $str);
            }
        }
      elsif ($len)
        {
          $str = sprintf ("%-${len}.${len}s", $str);
        }

      if ($color && $self->{color})
        {
          $line .= $self->colored ([$color], $str);
        }
      else
        {
          $line .= $str;
        }

      $col++;
    }

  while ($col <= $#len)
    {
      $line .= $separator;
      $line .= ' ' x $len[$col];
      $col++;
    }

  $line .= $separator;

  if ($self->interval () && (($self->{count} % $self->interval ()) == 0))
    {
      $line =~ s/ /./go;
    }

  $self->{fhout}->print ("$line\n");

  $self->{count}++;
}

1;
