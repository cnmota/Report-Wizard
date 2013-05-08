package Trio::ReportWizard::Data::Dimension;

use strict;
no warnings;

use base qw(Trio::ReportWizard::Data);

sub fields {
  return {
    id               => undef,
    name             => undef,
    column           => undef,
    with_all         => undef,
    is_multiple      => undef,
    use_opala_multiselect => undef,
    type             => [],
    has_horiz_total  => undef,
    has_vert_total   => undef,
    report           => undef,
    data             => undef,
  };
}

sub init {
  my $self = shift;

  if ($self->is_of_type('filter')) {
    if ($self->with_all() && !$self->use_opala_multiselect()) {
      @{$self->{data}} = ( {id => '', name => 'Todos' }, @{$self->{data}} );
    }

    my @selected_values = $self->{report}->{query}->param($self->id()) ? ref($self->{report}->{query}->param($self->id())) eq 'ARRAY' ? @{$self->{report}->{query}->param($self->id()) || []} : $self->{report}->{query}->param($self->id()) : ();

    unless ($self->use_opala_multiselect()) {
      push @selected_values, $self->{data}->[0]->{id} if (scalar @{ $self->{data} || []} && scalar @selected_values ==  0);
    }

    foreach my $value_id (@selected_values) {
      for (@{ $self->{data} || [] }) {
        $_->{selected} = 1 if (defined $_->{id} && $_->{id} eq $value_id) 
      }
    }
  }

  if ($self->is_of_type('restriction')) {
    for (@{ $self->{data} || [] }) {
      $_->{selected} = 1 if (defined $_->{id});
    }
  }
}

sub is_of_type {
  my $self = shift;
  my $type = shift;

  unless (defined $self->{__is_of_type}) {
    $self->{__is_of_type} = {};

    for my $itype ( @{$self->type() || []}) {
      $self->{__is_of_type}->{$itype} = 1;
    }
  }

  return $self->{__is_of_type}->{$type} || 0;
}

sub selected {
  my ($self) = @_;

  my @selected = ();

  if ($self->is_of_type('filter')) {
    foreach my $row (@{$self->{data}}) {
      push @selected, $row if ($row->{id} ne '' && defined $row->{selected} && $row->{selected} == 1);
    }
  }

  return wantarray ? @selected : \@selected;
}

1;
