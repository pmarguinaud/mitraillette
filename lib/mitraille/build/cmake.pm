package mitraille::build::cmake;

use File::Basename;
use Data::Dumper;
use Cwd;

use strict;

use base qw (mitraille::build);

use mitraille::util qw (slurpl);

sub getExecutablePath
{
  my ($self, $exec) = @_;

  if ($self->{executablePath}{$exec})
    {
      return $self->{executablePath}{$exec};
    }

  my @install = do 
  { 
    my $fh = 'FileHandle'->new ("<$self->{path}/build/install_manifest.txt")
          || 'FileHandle'->new ("<$self->{path}/install_manifest.txt");
    $fh ? <$fh>  : ()
  };

  chomp for (@install);

  # Use build directory if not installed

  unless (@install)
    {
      my $path = $self->{path};
      for my $bin (<$path/bin/*>)
        {
          push @install, $bin;
        }
    }

  for my $path (@install)
    {
      if ($exec eq &basename ($path))
        {
          $self->{executablePath}{$exec} = $path;
          return $path;
        }
    }

  die ("Executable $exec was not found in $self->{path}");
}

sub getInstallPath
{
  my $self = shift;
  my $path = $self->getExecutablePath ('MASTERODB');

  for (1 .. 2)
    {
      $path = &dirname ($path);
    }
 
  return $path;
}

sub getLabel
{
  my $self = shift;

  my @cmd = ('git', -C => $self->{path}, qw (branch --show-current));

  my $branch = `@cmd`;

  return $branch unless ($?);

  return &basename ($self->{path});
}

# Cycle of the sources (eg 50): CMAKE_PROJECT_VERSION_MAJOR in CMakeCache.txt, or
# the major number of VERSION.txt in the source directory

sub getCycle
{
  my $self = shift;

  my ($cache) = grep { -f } ("$self->{path}/CMakeCache.txt", "$self->{path}/build/CMakeCache.txt");
  return unless ($cache);

  my %cache = map { m/^(\w+):\w+=(.*)$/o ? ($1, $2) : () } &slurpl ($cache);

  return $cache{CMAKE_PROJECT_VERSION_MAJOR} if ($cache{CMAKE_PROJECT_VERSION_MAJOR});

  my $version = "$cache{CMAKE_HOME_DIRECTORY}/VERSION.txt";
  return unless (-f $version);

  my ($major) = ((&slurpl ($version))[0] =~ m/^(\d+)/o);
  return $major;
}

1;
