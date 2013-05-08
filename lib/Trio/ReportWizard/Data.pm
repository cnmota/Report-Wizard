package Trio::ReportWizard::Data;

use strict;
use Carp qw(croak confess);

our $AUTOLOAD;

sub fields { return {} }

sub new {
  my ($class, %params) = @_;

  my $self = bless { }, ref($class) || $class;

  my $fields = $self->fields();

  foreach my $field (keys %{$fields || {}}) {
    $self->{$field} = defined $params{$field} ? $params{$field} : $fields->{$field}; 
  }

  $self->init(%params);

  return $self;
}

sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self) or croak "$self is not an object";

  my $name = $AUTOLOAD;
  $name =~ s/.*://;

  my $fields = $self->fields();
  $fields->{DESTROY} = 1;

  unless (exists $fields->{$name}) {
    croak "Can't access `$name' field in class $type";
  }

  if (@_) {
    return $self->{$name} = shift;
  } else {
    return $self->{$name};
  }
}

sub TO_JSON {
  my $self = shift;

  return { %$self };
}

sub init { }

1;
