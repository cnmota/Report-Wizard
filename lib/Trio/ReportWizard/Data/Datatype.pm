package Trio::ReportWizard::Data::Datatype;

use strict;
no warnings;

use base qw(Trio::ReportWizard::Data);

sub fields {
  return {
    id           => undef,
    name         => undef,
    value        => undef,
    type         => undef,
    output_type  => undef,
    selected     => 0,
    hidden       => 0,
    implies      => undef,
    force        => 0,
    style        => undef,
    selected     => 0,
    hidden       => 0,
    fn           => undef,
    mover_fn     => undef,
    click_fn     => undef,
    no_total_x   => 0,
    no_total_y   => 0,
  };
}

1;
