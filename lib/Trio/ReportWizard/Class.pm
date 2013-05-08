package Trio::ReportWizard::Class;

use strict;

sub new {
  my $class = shift;
  my %a = ( @_ );

  if ($a{_fromDB} && $a{ref} ) {
    my $self = bless $a{ref},  ref($class) || $class;
    $self->{_fromDB} = 1;
    $self->{sys} = $a{sys};

    return $self;
  } else {
    my $self = bless {%a}, ref($class) || $class;
    $self->init(%a);

    return $self;
  }
}

sub init {
  my $self = shift;
  return $self;
}

1;
