package Trio::ReportWizard::Report;

use strict;
no warnings;

use base qw( Trio::ReportWizard::Class );

use Text::Xslate;
use HTML::Template::Pro;
use JSON::XS;
use Spreadsheet::WriteExcel;
use Scalar::Util;

use Encode qw(encode decode);

use Trio::ReportWizard::Data::Dimension;
use Trio::ReportWizard::Data::Datatype;
use Trio::ReportWizard::DB::Postgres;

################### DATABASE ##################

sub db {
  my $self = shift;

  return $self->{__db} if (exists $self->{__db});

  my $dsn = 'DBI:Pg:dbname=iecr;host=localhost';

  $self->{__dbh} = DBI->connect( $dsn, 'postgres','', { PrintError => 0, RaiseError => 1, pg_server_prepare => 0 },) or die "$DBI::errstr";
  $self->{__db} = Trio::ReportWizard::DB::Postgres->new( dbh => $self->{__dbh} );

  return $self->{__db};
}

################# PRIVATE METHODS #############

sub __select_groups {
  my ($self, %params) = @_;

  my $sgroups = [];
  $self->{'__'.$params{'prefix'}} = [];

  my $groups = $self->__groups();

  my %control = ();
  my @selected = ();

  for (my $i = 0; $i < $params{'max'}; $i++) {
    my $hgroup = $self->params($params{'prefix'}.'_'.($i+1));

    foreach my $group (@{$groups || []}) {
      if ($group->{id} eq $hgroup && !exists $control{$group->{id}} && $group->{id} ne 'empty') {
        push @selected, $group;
        $control{$group->{id}}++;
      }
    }
  }

  unless (scalar(@selected)) {
    push @selected, $groups->[0];
  }

  for (my $i = 0; $i < $params{'max'}; $i++) {
    foreach my $group (@{$groups || []}) {
      my $selected_id = exists $selected[$i] ? $selected[$i]->{id} : 'empty';

      push @{$sgroups->[$i]->{group}}, { id => $group->{id}, name => $group->{name}, selected => $group->{id} eq $selected_id ? 1 : 0};
    }
  }

  $self->{'__'.$params{'prefix'}} = \@selected;

  return wantarray ? @{$sgroups || []} : $sgroups;
}

sub __dimensions {
  my ($self) = @_;

  return wantarray ? @{$self->{_dimensions} || []} : $self->{_dimensions} if (defined $self->{_dimensions});

  $self->{_dimensions} = [ Trio::ReportWizard::Data::Dimension->new(id => 'empty', name => '---', column => '9999999', type => [ 'group' ]), @{$self->dimensions() || []} ];

  return wantarray ? @{$self->{_dimensions} || []} : $self->{_dimensions};
}

sub __datatypes {
  my ($self) = @_;

  return wantarray ? @{$self->{_datatypes} || []} : $self->{_datatypes} if (defined $self->{_datatypes});

  $self->{_datatypes} = $self->datatypes();

  my $at_least_one = 0;
  foreach my $datatype (@{ $self->{_datatypes} || [] }) {
    if ($self->params('generate')) {
      $datatype->{selected} = $self->params($datatype->id()) ? 1 : 0;
    }
    $at_least_one = 1 if ($datatype->{selected});
  }

  unless ($at_least_one) {
    foreach my $datatype (@{ $self->{_datatypes} || [] }) {
      $datatype->{selected} = 1;
    }
  }

  return wantarray ? @{$self->{_datatypes} || []} : $self->{_datatypes};
}

sub __fast_datatypes {
  my ($self) = @_;

  return wantarray ? @{$self->{_fdatatypes} || []} : $self->{_fdatatypes} if (defined $self->{_fdatatypes});

  $self->{_fdatatypes} = {};
  my $idx = 0;

  for ( @{$self->__datatypes() || []} ) {
    $_->{idx} = $idx++;
    $self->{_fdatatypes}->{ $_->{id} } = $_;
  }

  return wantarray ? @{$self->{_fdatatypes} || []} : $self->{_fdatatypes};
}

sub __groups {
  my ($self) = @_;

  return wantarray ? @{$self->{_groups} || []} : $self->{_groups} if (defined $self->{_groups});

  $self->{_groups} = [];

  for (@{$self->__dimensions() || []}) {
    push @{$self->{_groups}}, $_ if ($_->is_of_type('group'));
  }

  return wantarray ? @{$self->{_groups} || []} : $self->{_groups};
}

sub __filters {
  my ($self) = @_;

  return wantarray ? @{$self->{_filters} || []} : $self->{_filters} if (defined $self->{_filters});

  $self->{_filters} = [];

  for (@{$self->__dimensions() || []}) {
    push @{$self->{_filters}}, $_ if ($_->is_of_type('filter'));
  }

  return wantarray ? @{$self->{_filters} || []} : $self->{_filters};
}

sub __restrictions {
  my ($self) = @_;

  return wantarray ? @{$self->{_restrictions} || []} : $self->{_restrictions} if (defined $self->{_restrictions});

  $self->{_restrictions} = [];
      
  for (@{$self->__dimensions() || []}) { 
    push @{$self->{_restrictions}}, $_ if ($_->is_of_type('restriction'));
  }
              
  return wantarray ? @{$self->{_restrictions} || []} : $self->{_restrictions};
}

sub __hgroups {
  my ($self) = @_;

  return wantarray ? @{$self->{_hgroups} || []} : $self->{_hgroups} if (defined $self->{_hgroups});

  $self->{_hgroups} = $self->__select_groups( prefix => 'hgroup', max => 3);

  return wantarray ? @{$self->{_hgroups} || []} : $self->{_hgroups}; 
}

sub __vgroups {
  my ($self) = @_;

  return wantarray ? @{$self->{_vgroups} || []} : $self->{_vgroups} if (defined $self->{_vgroups});

  $self->{_vgroups} = $self->__select_groups( prefix => 'vgroup', max => 6);

  return wantarray ? @{$self->{_vgroups} || []} : $self->{_vgroups}; 
}

sub __rowgroups {
  my ($self) = @_;

  return wantarray ? @{$self->{__vgroup} || []} : $self->{__vgroup} if (defined $self->{__vgroup});

  $self->__hgroups();

  return wantarray ? @{$self->{__vgroup} || []} : $self->{__vgroup};
}

sub __colgroups {
  my ($self) = @_;

  return wantarray ? @{$self->{__hgroup} || []} : $self->{__hgroup} if (defined $self->{__hgroup});

  $self->__vgroups();

  return wantarray ? @{$self->{__hgroup} || []} : $self->{__hgroup};
}

sub __generate_sql_query {
  my ($self) = @_;

  my $query = "";

  #Lets GENERATE DIMENSIONS

  my @expressions = map { $_->{column}.' AS '.$_->{id} } ( @{$self->__colgroups() || []}, @{$self->__rowgroups() || []});
  my @dtypes = ();

  my @groups = ();
  for ( @{$self->__colgroups() || []}, @{$self->__rowgroups() || []} ) {
    push @groups, $_->{column} if ($_->{id} ne 'empty');
  }

  my @dtypes = ();
  for ( @{$self->__datatypes() || []} ) { 
    push @expressions, $_->{value} if ($_->{selected} || $_->{hidden});
    push @dtypes, $_->{value} if ($_->{selected} || $_->{hidden});
  }

  my @filters = ();
  foreach my $filter (@{$self->__filters() || []}) {
    my @selected = ();
    my $is_custom = 0;

    foreach my $data (@{$filter->{data} || []}) {
      $is_custom = 1 if $data->{custom};
    }

    if ($is_custom) {
      foreach my $data (@{$filter->{data} || []}) {
        push @selected, $data->{custom} if (($data->{selected} || $data->{hidden}) && $data->{custom});
      }
    
      push @filters, '('.join(' OR ', map { $_ } @selected).')' if (scalar(@selected));
    } else {
      foreach my $data (@{$filter->{data} || []}) {
        push @selected, $data->{id} if (($data->{selected} || $data->{hidden}) && $data->{id});
      }

      push @filters, $filter->{column}.' IN ('.join(',', map { "'$_'" } @selected).')' if (scalar(@selected));
    }
  }

  foreach my $filter (@{$self->__restrictions() || []}) {
    my @selected = ();
    foreach my $data (@{$filter->{data} || []}) {
      push @selected, $data->{id} if ($data->{selected} && defined $data->{id});
    }
    push @filters, $filter->{column}.' IN ('.join(',', map { "'$_'" } @selected).')' if (scalar(@selected));
  }

  $query .= "SELECT ";
  $query .= join(",",@expressions);
  $query .= $self->table_sql();
  $query .= 'WHERE '.join(' AND ', @filters) if (scalar(@filters));
  $query .= " GROUP BY ".join(",",@groups) if (scalar(@groups));
  $query .= " ORDER BY ".join(",",@groups) if (scalar(@groups));

  print STDERR "$query\n";

  $self->{__expression} = \@expressions;
  $self->{__sql_groups} = \@groups;
  $self->{__sql_dtypes} = \@dtypes;

  $self->post_generate_query(\$query);

  return $query;
}

sub __process_report {
  my ($self) = @_;

  my $dont_group_rows = $self->params('dont_group_rows');

  my $data = { 
    cols => {}, 
    rows => {}, 
    headers => [], 
    row_cells => [],
    rowgroups => [ map { { id => $_->{id}, name => $_->{name} } } @{$self->__rowgroups() || []} ],
    ydim_size => scalar(@{$self->__rowgroups() || []}), 
    xdim_size => scalar(@{$self->__colgroups() || []}),
    dont_group_rows => $dont_group_rows,
  };

  my @expressions = map { $_->{column}.' AS '.$_->{id} } ( @{$self->__colgroups() || []}, @{$self->__rowgroups() || []});

  if ($self->params('generate')) {
    $self->log('GENERATING');
    my $next = $self->get_data();

    while (my $row = $next->()) {
      my $i = 0;
      my $j = 0;

      # WE START BY PICKING UP THE HORIZONTAL GROUP CELLS
      my $col_ptr = $data;
      my $row_ptr = $data;

      my @xkey = ();
      my $parent = undef;

      for (@{ $self->__colgroups() || []}) {
        push @xkey, $row->[$i];

        $col_ptr->{cols}->{$row->[$i]} = { 
          id => $_->id(), 
          value => $self->__transl($_->{id}, $row->[$i]), 
          has_values => 0,
          parent => $parent,
          pos => "xdim_$i",
          __key => join("##",(@xkey))
        } unless defined $col_ptr->{cols}->{$row->[$i]};

        $parent = $col_ptr->{cols}->{$row->[$i]};
        $col_ptr = $col_ptr->{cols}->{$row->[$i]};
        $i++;
      }

      for ( @{$self->__datatypes() || []} ) {
        next unless ($_->{selected} && $_->{id});

        $col_ptr->{cols}->{"col_".sprintf("%02d",$j)} = {
          id => $_->id(), 
          value => $_->name(),
          parent => undef,
	        has_values => 0, 
          pos => "col_".sprintf("%02d",$j), 
          __key => join("##",(@xkey, $_->id()))  
        } unless defined $col_ptr->{cols}->{$row->[$i]};

        $j++;
      }

      #ADDING UP 

      #LET'S WORK ON THE ROWS NOW
      $parent = undef;      
      my @ykey = ();
      my $y_cnt = 1;

      for (@{$self->__rowgroups() || []}) {
        push @ykey, $row->[$i];

        $row_ptr->{rows}->{$row->[$i]} = {
          id => $_->id(),
          value => $self->__transl($_->{id}, $row->[$i]),
          has_values => 0,
          parent => $parent,
          pos => "xdim_$y_cnt",
          __xkey => \@xkey,
          __ykey => [ map { $_ } @ykey ],
        } unless defined $row_ptr->{rows}->{$row->[$i]};

        $parent = $row_ptr->{rows}->{$row->[$i]};
        $row_ptr = $row_ptr->{rows}->{$row->[$i]};
        $i++;
        $y_cnt++;
      }

      for ( @{$self->__datatypes() || []} ) {
        next unless (($_->{selected} || $_->{hidden}) && $_->{id});

        $row_ptr->{data}->{ join("##",(@xkey, $_->id())) } = { 
          id => $_->id(), 
          value => $row->[$i],
          align => 'right',
          parent => $parent,
          classes => [],
          data => [],
      	  __xkey => \@xkey,
      	  __ykey => \@ykey,
        };

        $i++;
      }
    }
  }

  $self->log( "### BEFORE RO1 TOTAL SIZE:".(total_size($data)/1024)." KBytes\n" );
  # WE NOW CREATE A SIMPLE SORTED ACCESS TO OUR REPORT HEADERS
  # MAX UP TO 5 LEVELS
  # THIS PROCESS PROBABLY CAN BE DONE ON THE MAIN GET DATA CICLE TO REVIEW
  $self->build_cols( $data, $data, 0 );
  #CREATING SORTED ACESS TO DATA OUR ROWS
  $self->build_rows( $data, $data, { dims => {}, data => {} }, 0 );
  $data->{pivot_header} = $data->{headers}->[scalar(@{$data->{headers}}) - 1];

  if ($self->no_total_y() && $self->params('dont_group_rows')) {
    @{$data->{row_cells}} = sort { $self->_sort_rows_final($a, $b) } @{$data->{row_cells} || []};
  }

  $self->log( "### AFTER RO2 TOTAL SIZE:".(total_size($data)/1024)." KBytes\n" );

  return $data;
}

sub build_cols {
  my ($self, $container, $parent, $level) = @_;

  my $ncols = 0;
  my $nitems = 0;
  my $last_inserted_col = undef;

  #ADDING UP TOTALIZERS
  my $num_levels = scalar(@{ $self->__colgroups() || []});

  if ( $level < $num_levels ) {
    my $template_col = undef;
    #LET'S GET THE TEMPLATE COLUMN TO USE FOR KEYS OVER HERE
    foreach my $col_idx (sort keys %{$parent->{cols} || {}}) {
      $template_col = $parent->{cols}->{$col_idx};
      last;
    }

    #DO WE HAVE MORE THAN ONE COLUMN ? ONLY THEN DO WE ADD A NEW TOTAL COLUMN
    if (scalar keys %{$parent->{cols} || {}} > 1) {
      my $total_col = {
        id => $template_col->{id},
        parent => $template_col->{parent},
        value => 'Total',
        rowspan => ($num_levels - $level),
        pos => $template_col->{pos},
        is_total_x => 1,
        cols => {}, 
      };

      my $curr_level = $level + 1;
      my $curr_total = $total_col;

      #WE FILL UP THE DESCENT COLUMNS UP TO THE PENULTIMATE LEVEL WITH STUB COLUMNS.

      while ($curr_level < $num_levels ) {
        $curr_total->{cols}->{total_x} = {
          id => $template_col->{id},
          value => 'Total',
          skip => 1,
          is_total_x => 1,
          cols => {}, #THIS IS AN ELEMENT THAT NEEDS TO BE REMOVED LATER ON
        }; 
        $curr_total = $curr_total->{cols}->{total_x};
        $curr_level++;
      }

      #LETS ADD UP THE DATATYPES COLUMNS TO THE FINAL LEVEL OF THIS TOTAL COLUMN
      my $j = 0;

      my @__key = split('##', $template_col->{__key});
      $__key[-1] = '' if (scalar @__key);

      for ( @{$self->__datatypes() || []} ) {
        next unless ($_->{selected} && $_->{id});

        $curr_total->{cols}->{"col_".sprintf("%02d",$j)} = {
          id => $_->id(),
          value => $_->name(),
          parent => undef,
          has_values => 0,
          pos => "col_".sprintf("%02d",$j),
          __key => join("##",(@__key, $_->id()))
        };

        $j++;
      }

      $parent->{cols}->{total_x} = $total_col;
    }
  }

  #CALCULATE COLSPANS

  foreach my $col_idx (sort {$a cmp $b } keys %{$parent->{cols} || {}}) {
    my $col = $parent->{cols}->{$col_idx};
    my $curr_ncols = 0;

    if (scalar keys %{$col->{cols} || {}}) { 
      $curr_ncols = $self->build_cols($container, $col, $level + 1);
    } else {
      $curr_ncols ||= 1; #THIS IS A FINAL COLUMN ON THE LAST LEVEL SO IT IS A DATATYPE
    }

    $nitems++;
    $ncols += $curr_ncols;
    $col->{colspan} = $curr_ncols;

    push @{$container->{headers}->[$level]}, $col;
  }

  return $ncols;
}

sub _sort_rows_final {
  my $self = shift;
  my ($a,$b) = @_;

  my $hash_to_use = $self->{__sort_key__} =~ /xdim\_/ ? 'dims' : 'data';
  $self->{__sort_type} = "" if ($self->{__sort_key__} =~ /xdim\_/);

  if ($self->{__sort_direction__} eq 'up') {
    if ($self->{__sort_type} eq 'numeric') {
      return $a->{is_total_y} <=> $b->{is_total_y} || $a->{ $hash_to_use }->{$self->{__sort_key__}}->{value} <=> $b->{ $hash_to_use }->{$self->{__sort_key__}}->{value};
    } else {
      return $a->{is_total_y} <=> $b->{is_total_y} || $a->{ $hash_to_use }->{$self->{__sort_key__}}->{value} cmp $b->{ $hash_to_use }->{$self->{__sort_key__}}->{value};
    }
  } else {
    if ($self->{__sort_type} eq 'numeric') {
      return $a->{is_total_y} <=> $b->{is_total_y} || $b->{ $hash_to_use }->{$self->{__sort_key__}}->{value} <=> $a->{ $hash_to_use }->{$self->{__sort_key__}}->{value};
    } else {
      return $a->{is_total_y} <=> $b->{is_total_y} || $b->{ $hash_to_use }->{$self->{__sort_key__}}->{value} cmp $a->{ $hash_to_use }->{$self->{__sort_key__}}->{value};
    }
  }

  return 0
}

sub _sort_rows {
  my $self = shift;
  my ($a,$b,$rows) = @_;

  my $sorted = 0;

  if (exists $rows->{$a}->{data} && exists $rows->{$b}->{data}) {
    if (exists $rows->{$a}->{data}->{$self->{__sort_key__}} && exists $rows->{$b}->{data}->{$self->{__sort_key__}}) {
      $sorted = 1;

      if ($self->{__sort_direction__} eq 'up') {
        if ($self->{__sort_type} eq 'numeric') {
          return $rows->{$a}->{data}->{$self->{__sort_key__}}->{value} <=> $rows->{$b}->{data}->{$self->{__sort_key__}}->{value};
        } else {
          return $rows->{$a}->{data}->{$self->{__sort_key__}}->{value} cmp $rows->{$b}->{data}->{$self->{__sort_key__}}->{value};
        }
      } else {
        if ($self->{__sort_type} eq 'numeric') {
          return $rows->{$b}->{data}->{$self->{__sort_key__}}->{value} <=> $rows->{$a}->{data}->{$self->{__sort_key__}}->{value};
        } else {
          return $rows->{$b}->{data}->{$self->{__sort_key__}}->{value} cmp $rows->{$a}->{data}->{$self->{__sort_key__}}->{value};
        }
      }
    }
  }

  if ($rows->{$a}->{id} eq $self->{__sort_field__}) {
    if ($self->{__sort_direction__} eq 'up') {
      return $rows->{$a}->{value} cmp $rows->{$b}->{value};
    } else {
      return $rows->{$b}->{value} cmp $rows->{$a}->{value};
    }
  }

  return ($rows->{$a}->{value} <=> $rows->{$b}->{value} ||$rows->{$a}->{value} cmp $rows->{$b}->{value});
}

sub build_rows {
  my ($self, $container, $data, $curr, $level) = @_;

  my $nrows = 0;
  my $first_inserted_row = undef;
  my $total = undef;
  my $row_pos = undef;

  $level += 1;

  foreach my $row_idx (keys %{$data->{rows} || {}}) {
    #PREFORMAT DATA
    my $row = $data->{rows}->{$row_idx}; #CURRENT ROW
    $self->__format_row( $row->{data} );
  }

  foreach my $row_idx (sort { $self->_sort_rows($a, $b, $data->{rows}) } keys %{$data->{rows} || {}}) {

  foreach my $row_idx (sort { $self->_sort_rows($a, $b, $data->{rows}) } keys %{$data->{rows} || {}}) {
    my $row = $data->{rows}->{$row_idx}; #CURRENT ROW
    my $row_to_insert = undef;
    my $subtotal = undef;
    my $curr_nrows = 0;

    $curr->{dims}->{ $row->{pos} } = $row;
    $row_pos = $row->{pos};

    #CALCULATE HORIZONTAL TOTALIZER DATA 
    foreach my $key (keys %{ $row->{data} || {} }) {
      my @__key = split('##',$key);

      my @new_key = @__key;
      for (my $i = scalar(@__key)-2; $i >= 0; $i--) {
        $new_key[$i] = '';
        my $total_key = join("##", map { $_ eq '__DONE__' ? () : $_ } @new_key);
        $new_key[$i] = '__DONE__';

        if (defined $row->{data} && $row->{data}->{$total_key}) {
          if ($self->__fast_datatypes()->{$row->{data}->{$key}->{id}}->{output_type} ne 'numeric') {
            $row->{data}->{$total_key}->{value} .= '||'.$row->{data}->{$key}->{value} if ($row->{data}->{$key}->{value}); 
          } else {
            $row->{data}->{$total_key}->{value} += $row->{data}->{$key}->{value};
          }
        } else {
          #THIS IS CREATING GARBAGE
          $row->{data}->{$total_key} = { %{ $row->{data}->{$key} }, __xkey => [ $new_key[0..(scalar(@new_key)-2)] ], is_total_x => 1 };
        }
      }
    }

    if ($row->{data}) {
      $row_to_insert = { dims => { map { $_ => { id => $curr->{dims}->{$_}->{id}, value => $curr->{dims}->{$_}->{value} } } keys %{$curr->{dims} || {} } }, data => $row->{data} };
      $row_to_insert->{dims}->{ $row->{pos} }->{rowspan} = 1;

      push @{$container->{row_cells}}, $row_to_insert;

      $subtotal = $row_to_insert;
      $curr_nrows = 1;
    } else {
      #RECURSIVIDADE AQUI RECEBO AS RESPOTAS DE SUBNIVEIS LOGO CALCULO TOTAIS AQUI
      ($curr_nrows, $row_to_insert, $subtotal) = $self->build_rows( $container, $row, $curr, $level );
    }

    foreach my $key (keys %{ $subtotal->{data} || {} }) {
      my @__key = split('##',$key);

      if (defined $total->{data} && $total->{data}->{$key}) {
        if ($self->__fast_datatypes()->{$total->{data}->{$key}->{id}}->{output_type} ne 'numeric') {
          $total->{data}->{$key}->{value} .= '||'.$subtotal->{data}->{$key}->{value} if ($subtotal->{data}->{$key}->{value}) ;
        } else {
          $total->{data}->{$key}->{value} += $subtotal->{data}->{$key}->{value};
        }
      } else {
        $total->{data}->{$key} = { %{ $subtotal->{data}->{$key} }, is_total_y => 1, __ykey => $data->{__ykey} };
      }
    }

    #FORMATING HORIZ TOTAL DATA

    $first_inserted_row = $row_to_insert unless defined $first_inserted_row;
    $nrows += $curr_nrows;

    #ADDS PROPER ROWSPAN
    if ($curr_nrows) {
      $row_to_insert->{dims}->{ $row->{pos} }->{rowspan} = $curr_nrows;
    }
  }

  if ($nrows > 1) {
    $nrows++;

    my $ypos = $row_pos;
    $ypos =~ s/xdim\_(.*?)/$1/g;

    $total->{is_total_y} = 1;
    $total->{dims}->{$row_pos} = { id => $curr->{dims}->{$row_pos}->{id}, value => 'TOTAL', rowspan => 1, colspan => $container->{ydim_size}-$ypos+1 };

    if ($self->params('dont_group_rows')) {
      #ADDING LEFT ITEM SINCE NO ROWSPANS EXIST
      foreach my $dim (keys %{$curr->{dims} || {} }) {
        next if ($dim ge $row_pos);

        $total->{dims}->{$dim} = { id => $curr->{dims}->{$row_pos}->{id}, value => $curr->{dims}->{$dim}->{value}, rowspan => 1, is_total_y => 1 };
      }
    }

    $self->__format_row( $total->{data} );

    if ($self->no_total_y()) {
      push @{$container->{row_cells}}, $total if ($level == 1);
    } else {
      push @{$container->{row_cells}}, $total;
    }

#    push @{$container->{row_cells}}, $total if (!$self->no_total_y());
  }

  return $nrows, $first_inserted_row, $total;
}

sub transl {
  my $self = shift;
  my $type = shift;
  my $value = shift;

  return $value;
}

sub __transl {
  my $self = shift;
  my $type = shift;
  my $value = shift;

  my %transl_tab = ();

  $type =~ s/\\\,/,/g;

  return "------" if ($type eq 'empty');
  unless (defined $self->{__trsl_tab}->{$type}) {
    my $dimensions = $self->__dimensions();

    foreach my $dim (@{$dimensions || []}) {
      next unless ($dim->{id} eq $type);

      $self->{__trsl_tab}->{$type} = {};

      foreach my $row (@{$dim->{data} || []}) {
        next unless $row->{id} || $row->{id} eq '0';
        $self->{__trsl_tab}->{$type}->{$row->{id}} = $row->{name};
      }
    }
  }

  my $ret_value = defined $self->{__trsl_tab}->{$type}->{$value} ? $self->{__trsl_tab}->{$type}->{$value} : $self->transl($type, $value);

  return $ret_value ? $ret_value : $value;
}

sub _sort_cols_final {
  my $self = shift;
  my ($row, $a, $b ) = @_;

  return $self->__fast_datatypes()->{$row->{$a}->{id}}->{idx} <=> $self->__fast_datatypes()->{$row->{$b}->{id}}->{idx};
}

sub __format_row {
  my ($self, $row) = @_;
#COCO

  foreach my $key (sort { $self->_sort_cols_final($row, $a, $b) } keys %{ $row || {} }) {
#  foreach my $key (sort keys %{ $row || {} }) {
    if ($row->{$key}->{is_total_y}) {
      if ($self->__fast_datatypes()->{$row->{$key}->{id}}->{no_total_y}) {
        $row->{$key}->{value} = '----';
        $row->{$key}->{align} = 'right';
        next;
      }
    } 

    if ($row->{$key}->{is_total_x}) {
      if ($self->__fast_datatypes()->{$row->{$key}->{id}}->{no_total_x}) {
        $row->{$key}->{value} = '----';
        $row->{$key}->{align} = 'right';
        next;
      }
    }

    if ( $self->__fast_datatypes()->{$row->{$key}->{id}}->{fn} || 
         $self->__fast_datatypes()->{$row->{$key}->{id}}->{mover_fn} ||
         $self->__fast_datatypes()->{$row->{$key}->{id}}->{click_fn} 
    ) {
      my $shortcut = $self->__fast_datatypes()->{$row->{$key}->{id}};

      $shortcut->{fn}($row, $key, $shortcut->{id}) if (defined $shortcut->{fn});
      $shortcut->{mover_fn}($row, $key, $shortcut->{id}) if (defined $shortcut->{mover_fn});
      $shortcut->{click_fn}($row, $key, $shortcut->{id}) if (defined $shortcut->{click_fn});
    }

    if ($self->__fast_datatypes()->{$row->{$key}->{id}}->{output_type} ne 'numeric') {
      $row->{$key}->{fvalue} = $row->{$key}->{value};
      $row->{$key}->{align} = 'left';
    } else {
#      $row->{$key}->{value} = sprintf("%.2f", $row->{$key}->{value});
      $row->{$key}->{fvalue} = $self->format_number($row->{$key}->{value});
    }
  }



  return $row;
}

sub __get_value_for_group {
  my ($self, $cell, $id) = @_;

  my $pos = 0;
  foreach my $rowgroup (@{ $self->__rowgroups() || []}) {
    return $cell->{__ykey}->[$pos] if ($rowgroup->{id} eq $id);
    $pos++;
  }

  $pos = 0;
  foreach my $colgroup (@{ $self->__colgroups() || []}) {
    return $cell->{__xkey}->[$pos] if ($colgroup->{id} eq $id);
    $pos++;
  }

  return undef;
}


######################## PUBLIC METHODS ###########################

sub init {
  my ($self, %params) = @_;

  $self->{query} = $self->{query};
  $self->{session} = $params{session};

  $self->{__sort_direction__} = $self->{query}->param('sort_direction');
  $self->{__sort_key__} = $self->{query}->param('sort_key');
  $self->{__sort_field__} = $self->{query}->param('sort_field');

  $self->pre_init(\%params);

  $self->__filters();
  $self->__hgroups();
  $self->__vgroups();
  $self->__datatypes();

  $self->{__sort_direction__} = $self->{query}->param('sort_direction');
  $self->{__sort_key__} = $self->{query}->param('sort_key');
  $self->{__sort_field__} = $self->{query}->param('sort_field');
  $self->{__sort_type} = 'text';

  for ( @{$self->__datatypes() || []} ) {
    $self->{__sort_type} = $_->{output_type} if ($_->{id} eq $self->{__sort_field__});
  }
}

sub params {
  my ($self, $name, $value) = @_;

  if (defined $value && $value) {
    $self->{query}->param(-name => $name, -value => $value);
  } else {
    if (defined $name && $name) {
      return $self->{query}->param($name);
    }
  }

  return wantarray ? %{$self->{query}->Vars || {}} : $self->{query}->Vars;
}

sub generate {
  my ($self) = @_;

  my $result = undef;

  print STDERR "START GENERATING\n";

  eval {
    $result = $self->__process_report();
  };

  print STDERR $@;

  print STDERR "FINISH GENERATION\n";

  if ($@ =~ /errstr/) {
    print STDERR "#DATABASE ERROR RETRY PLEASE\n";
    $result = $self->__process_report();
  }

  if ($self->params('format') eq 'json') {
    my $js = JSON::XS->new->pretty(0)->indent(0)->allow_blessed(1)->convert_blessed(1);
    return $js->encode( $self->__filters() || [] );
  }

  my $format = $self->params('format') ? $self->params('format') : 'html';

  return $self->output_shtml($result) if ($format eq 'shtml');
  return $self->output_html($result) if ($format eq 'html');
  return $self->output_xls($result) if ($format eq 'xls'); 
}

sub get_data {
  my ($self) = @_;

  my $sth = $self->db()->dbh->prepare($self->__generate_sql_query());
  $sth->execute();

  return sub {
    my $row;
    eval {
      $row = $sth->fetchrow_arrayref();
    };
    if ($@) {
      return undef;
    } else {
      $sth->finish() unless $row;
      return $row;
    }
  } 
}

sub output_shtml {
  my $self = shift;
  my $result = shift;

  my $tx = Text::Xslate->new(
    syntax => 'TTerse',
    path      => [ '/projects/weckoffice/site/tmpl/report_wizard/' ],
  );

  return $tx->render('report.tt', { data => $result, items => [ 'N', 'S' ] });
}

sub output_html {
  my $self = shift;
  my $result = shift;

  my $tx = Text::Xslate->new(
    syntax => 'TTerse',
    path      => [ '/projects/weckoffice/site/tmpl/report_wizard/' ],
  );

  my $template = HTML::Template::Pro->new(
    filename           => '/projects/weckoffice/site/tmpl/report_wizard.tmpl',
    loop_context_vars  => 1,
    die_on_bad_params  => 0,
    global_vars        => 1,
  );

  $template->param(
    report_name => $self->report_name() || undef,
    result      => $result || undef,
    single_filters => [ map { $_->{is_multiple} ? () : $_ } @{ $self->__filters() || [] } ],
    multip_filters => [ map { $_->{is_multiple} ? $_ : () } @{ $self->__filters() || [] } ],
    hgroups     => $self->__hgroups() || [],
    vgroups     => $self->__vgroups() || [],
    datatypes   => $self->__datatypes() || [],
    dont_group_rows => $self->params('dont_group_rows') || undef,
    report_html => $tx->render('report.tt', { data => $result, items => [ 'N', 'S' ] }) || undef,
    %{ $self->{__extra_template_args} || {} },
    $self->extra_data(),
  );

  return $template->output;
}

sub output_xls {
  my $self = shift;
  my $result = shift;

  my $fname = "/tmp/".int(rand(10000000))."xls.xls";

  my $workbook  = Spreadsheet::WriteExcel->new($fname);
  my $worksheet = $workbook->add_worksheet();

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $worksheet->write_string(0, 0, "Relatorio ".$self->report_name()." gerado em $mday/".($mon+1)."/".($year+1900)." ".sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec));

  my $mhformat = $workbook->add_format(
                                    border  => 6,
                                    bold    => 1,
                                    valign  => 'vcenter',
                                    align   => 'center',
                                   );

  my $hformat = $workbook->add_format(
                                    border  => 6,
                                    bold    => 1,
                                    valign  => 'vcenter',
                                    align   => 'center',
                                   );

  my $dlformat = $workbook->add_format(
                                    border  => 6,
                                    bold    => 0,
                                    valign  => 'vcenter',
                                    align   => 'left',
				    num_format => '0.00'
                                   );

  my $drformat = $workbook->add_format(
                                    border  => 6,
                                    bold    => 0,
                                    valign  => 'vcenter',
                                    align   => 'right',
				    num_format => '0.00'
                                   );

  my $data = $result;
  my $start_y = 2;
  my $start_x = 0;

  $worksheet->merge_range($start_y, 0, $start_y, 1, 'Filtros', $mhformat);
  $start_y++;

  for my $filter (@{$self->__filters() || []}) {
    $worksheet->write_string($start_y, 0, $filter->{name}, $hformat);

    my @selections = ();
    for my $data (@{$filter->{data} || []}) {
      push @selections, $data->{name} if ($data->{selected});
    }

    $worksheet->write_string($start_y, 1, join(",",@selections), $dlformat);
    $start_y++
  }

  my $max_y = $start_y;
  $start_y = 2;

  if (scalar @{ $self->__colgroups() || []}) {
    $worksheet->write_string($start_y, 4, 'Horizontal', $hformat);
    $start_y++;
    for (@{ $self->__colgroups() || []}) {
      $worksheet->write_string($start_y++, 4, $_->{name}, $hformat); 
    }
  }

  $start_y++;

  if (scalar @{ $self->__rowgroups() || []}) {
    $worksheet->write_string($start_y, 4, 'Vertical', $hformat);
    $start_y++;
    for (@{ $self->__rowgroups() || []}) {
      $worksheet->write_string($start_y++, 4, $_->{name}, $hformat);
    }
  }

  $start_y = $max_y > $start_y ? $max_y : $start_y;
  $start_y++;

  if (scalar @{$data->{headers} || []} > 0) {
    my $first = 1;
    my $y_pos = $start_y;

    #CABECALHOS

    for my $header_row (@{$data->{headers} || []}) {
      my $x_pos = $start_x;

      if ($first) {
        for my $rowgroup (@{$data->{rowgroups} || []}) {
      	  $worksheet->merge_range($y_pos, $x_pos, $y_pos + $data->{xdim_size}, $x_pos, $rowgroup->{name}, $mhformat);
          $x_pos++;
	  #NEED TO ADD ROWSPAN OF 3
        }
	$start_x = $x_pos;
	$first = 0;
      }

      foreach my $col (@{$header_row || []}) {
        if ($col->{colspan} > 1) {
          $worksheet->merge_range($y_pos, $x_pos, $y_pos, $x_pos + $col->{colspan} - 1, $col->{value}, $mhformat);
	} else {
	  $worksheet->write_string($y_pos, $x_pos, $col->{value}, $hformat);
	}
        $x_pos = $x_pos + ($col->{colspan} || 1);
      }
      $y_pos++;
    }
    #LINHAS
    #
    $start_x = 0;

    for my $row (@{$data->{row_cells} || []}) {
      my $x_pos = $start_x;

#      foreach my $dim (sort keys %{$row->{dims} || []}) {
      for my $idx (1..$data->{ydim_size}) {
        my $dim = "xdim_".$idx;

        if ($row->{dims}->{$dim}->{rowspan} || $row->{dims}->{$dim}->{colspan}) {
	  if ($row->{dims}->{$dim}->{rowspan} > 1 || $row->{dims}->{$dim}->{colspan} > 1) {
            $row->{dims}->{$dim}->{rowspan} ||= 1;
            $row->{dims}->{$dim}->{colspan} ||= 1;

            $worksheet->merge_range($y_pos, $x_pos, $y_pos + $row->{dims}->{$dim}->{rowspan} - 1, $x_pos + $row->{dims}->{$dim}->{colspan} - 1, $row->{dims}->{$dim}->{value}, $mhformat);
	  } else {
	    $worksheet->write_string($y_pos, $x_pos, $row->{dims}->{$dim}->{value}, $hformat);
	  }
	}
	$x_pos++;
      }

      my $format = undef;

      for my $col (@{$data->{pivot_header} || []}) {
        my $tmp = $col->{__key};

        if ($row->{data}->{$tmp}->{align} eq 'left') {
	  $format = $dlformat;
	  $worksheet->write_string($y_pos, $x_pos, $row->{data}->{$tmp}->{value}, $format);
	} else {
	  $format = $drformat;
	  if (Scalar::Util::looks_like_number($row->{data}->{$tmp}->{value})) {
            $worksheet->write_number($y_pos, $x_pos, $row->{data}->{$tmp}->{value}, $format);
	  } else {
	    $worksheet->write_string($y_pos, $x_pos, $row->{data}->{$tmp}->{value}, $format);
	  }
	}
	$x_pos++;
      }

      $y_pos++;
    }
  }


  $workbook->close();

  return $fname;
}

sub dimensions {
  return wantarray ? () : {};
}

sub datatypes {
  return wantarray ? () : [];
}

sub init_datatype {
  my $self = shift;

  return Trio::ReportWizard::Data::Datatype->new( report => $self, @_ );
}

sub init_dimension {
  my $self = shift;

  return Trio::ReportWizard::Data::Dimension->new( report => $self, @_ );
}

sub report_name {
  return "Relatorio Base";
}

sub log {
  my $self = shift;
  my $txt = shift;

#  open(FH,">>/tmp/mylog");
#  print FH $txt;
#  close FH;
}

sub post_generate_query {}

sub no_total_y { 0 }

sub format_number {
  my ($self,$num) = @_;

  return sprintf("%.2f", $num);
}

sub extra_data {
  return ();
}

1;
