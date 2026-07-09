package mitraille::build::pack;

use File::Basename;

use strict;

use base qw (mitraille::build);

sub getExecutablePath
{
  my ($self, $exec) = @_;
  return "$self->{path}/bin/$exec";
}

sub getLabel 
{
  my $self = shift;
  return &basename ($self->{path});
}

sub slurp
{
  my $f = shift;
  (my $fh = 'FileHandle'->new ("<$f")) or die ("Cannot open `$f'");
  local $/ =  undef; 
  my $text = <$fh>;
  return $text;
}

sub getGenesis
{
  my $self = shift;
  die unless (-f "$self->{path}/.genesis");
  chomp (my $genesis = &slurp ("$self->{path}/.genesis"));
  my @genesis = split (m/\s+/o, $genesis);
  return @genesis;
}

sub getCycle
{
  my $self = shift;
  my @genesis = $self->getGenesis ();
  for my $i (0 .. $#genesis)
    {
      return $genesis[$i+1] if ($genesis[$i] eq '-r');
    }
}

sub getVersion
{
  my $self = shift;
  my $cycle = $self->getCycle ();

  my %cycle2version =
  (
    '49t1' => 'CY49T1',
    '50'   => 'CY50',
  );

  return $cycle2version{$cycle};
}

sub getInstallPath
{
  my $self = shift;
  return $self->{path};
}

1;
