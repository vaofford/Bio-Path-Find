
package Bio::Path::Find::Role::HasConfig;

# ABSTRACT: role providing attributes for interacting with configurations

use Moose::Role;

use Config::Any;

use Bio::Path::Find::Types qw(
  BioPathFindConfigSingleton
  ConfigFromHash
  ConfigFromStr
  ConfigFromFile
);

use Bio::Path::Find::ConfigSingleton;

=head1 CONTACT

path-help@sanger.ac.uk

=head1 SYNOPSIS

Apply the C<Role> to your application class:

  package MyApp;

  use Moose;

  with 'Bio::Path::Find::Role::HasConfig';

  1;

In a script, instantiate an application object and hand it a hash ref for the
configuration:

  #!/usr/bin/env perl

  use MyApp;

  my %config_hash = (
    one => 1,
    two => [ 2, 3, 4 ],
  );

  say \%config_hash; # "HASH(0x5b42408)"

  my $app = MyApp->new( config => \%config_hash );

Then in another class in the same app:

  package MyApp::SomeClass;

  use Moose;
  use Data::Printer;

  with 'Bio::Path::Find::Role::HasConfig';

  sub my_method {
    my $self = shift;

    say $self->config; # "HASH(0x5b42408)"
  }

  1;

=head1 DESCRIPTION

This is a L<Role|Moose::Role> that adds a
L<config|Bio::Path::Find::Role::HasConfig::config> attribute to classes that
apply it. The C<config> attribute holds a reference to a singleton object,
L<Bio::Path::Find::ConfigSingleton>, which stores the real configuration.

This class relies on types defined in the path find type library,
L<Bio::Path::Find::Types>.

=head1 SEE ALSO

L<Bio::Path::Find::ConfigSingleton>
L<Bio::Path::Find::Types>

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr config

A reference to the singleton object that stores the application configuration.

B<Note> that the accessor, C<config>, is wrapped in a function that returns the
reference to the underlying hash, rather than the object itself.

=cut

has 'config' => (
  is      => 'rw',
  isa     => BioPathFindConfigSingleton->plus_coercions(ConfigFromHash)
                                       ->plus_coercions(ConfigFromFile)
                                       ->plus_coercions(ConfigFromStr),
  coerce  => 1,
  builder => '_build_config',
);

sub _build_config {
  return Bio::Path::Find::ConfigSingleton->instance;
}

# wrap up the "config" accessor so that we can return the configuration hash,
# rather than the singleton that stores it
around 'config' => sub {
  my $orig = shift;
  my $self = shift;

  # This is more than a little ugly...
  #
  # If the caller asks for $x->config( object => 1 ), hand back the raw
  # singleton object. Otherwise, if there are arguments, defer to the
  # Moose-generated writer, and if there are no arguments, hand back the
  # configuration hash from the singleton.

  if ( @_ ) {
    if ( scalar @_ == 2 and $_[0] eq 'object' and $_[1] ) {
      return $self->$orig;
    }
    else {
      return $self->$orig(@_);
    }
  }
  else {
    return $self->$orig->config_hash;
  }
};

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 clear_config

Clears the configuration singleton.

=cut

sub clear_config {
  my $self = shift;

  my $c = $self->config(object => 1);
  $c->_clear_instance;
}

#-------------------------------------------------------------------------------

1;
