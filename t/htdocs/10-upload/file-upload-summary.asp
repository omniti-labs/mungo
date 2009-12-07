<%
   use Data::Dumper;
   my $f = $Request->Form();

   #print STDERR Dumper($f);


   # Expect up to 9 file fields named file_test_N
   my %results;

  NUM:
   foreach my $num (1..9) {
       my $name = 'file_test_' . $num;
       $results{$name}  = {
                   field_seen => 0,
                   looks_like_file => 0,
                   file_size => 0,
                   begin_seen => 0,
                   end_seen => 0,
                  };
       my $field = $f->{$name};
       #$results{$name}{field} = $field;  # Enable this for diagnostics
       unless ($field) {
          next NUM;
       }

       $results{$name}{field_seen}  = 1;

       my $handle = $field->{handle};
       unless ($handle 
               && UNIVERSAL::can($handle, 'read')
              ) {
          next NUM;
       }

       $results{$name}{looks_like_file} = 1;
       $results{$name}{content_type} = $field->{'content-type'};
       my $total_size = 0;
       my $last_chunk = '';
       my $chunk = '';
       while (my $chunk_size = $handle->read($chunk, 1024)) {
          $total_size += $chunk_size;
          if ($chunk =~ /BEGIN MARKER/) {
             $results{$name}{begin_seen}++;
          }
          $last_chunk = $chunk;          
       }
       if ($last_chunk =~ /END MARKER/) {
          $results{$name}{end_seen}++;
       }
       $results{$name}{file_size} = $total_size;
   }

%>
<%= Data::Dumper->Dump([\%results], ['file_info']); %>
