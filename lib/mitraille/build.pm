package mitraille::build;

use strict;
use Cwd;

use mitraille::build::pack;
use mitraille::build::cmake;

sub new
{
  my $class = shift;
  my %args = @_;

  $args{path} ||= &cwd ();
  $args{path} = 'File::Spec'->rel2abs ($args{path});

  if ($class eq __PACKAGE__)
    {
      if (-f "$args{path}/.genesis")
        {
          $class = 'mitraille::build::pack';
        }
      elsif (-f "$args{path}/install_manifest.txt")
        {
          $class = 'mitraille::build::cmake';
        }
      elsif (-f "$args{path}/build/install_manifest.txt")
        {
          $class = 'mitraille::build::cmake';
        }
      else
        {
          return;
        }
    }
  else
    {
      return bless \%args, $class;
    }
  
  return $class->new (%args);
}

sub getPath
{
  my $self = shift;
  return $self->{path};
}

1;
