# -*-cperl-*-
use strict;
use warnings FATAL => 'all';

use lib './t/lib';
use lib '../t/lib';
use MungoTestUtils;


use Apache::Test qw();
use Apache::TestRequest qw(GET POST);
use Test::More import => [qw(is ok is_deeply diag)];


use Test::More; # will use done_testing to count tests

# 10-upload.t
# Goal: Exercise Mungo's file upload capabilities

=for page list

=cut


my $test_count = 0;

my %expectations;
my %file_expectations = (
                         field_seen => 0,
                         looks_like_file => 0,
                         file_size => 0,
                         begin_seen => 0,
                         end_seen => 0,
                         content_type => undef,
                        );
my %seen_expectations = (
                         field_seen => 1,
                         looks_like_file => 1,
                         file_size => 0,
                         begin_seen => 1,
                         end_seen => 1,
                         content_type => 'text/plain',
                        );
foreach (1..9) {
    $expectations{'file_test_' . $_} = { %file_expectations };
}


my %tests = (
             # upload zero files
             #
             'zero-size' => {
                             label => "Upload one zero-sized file",
                             files => {
                                       file_test_1 => 0,
                                      },
                             expected => {
                                          %expectations,
                                          file_test_1 => {
                                                          %file_expectations,
                                                          field_seen => 1,
                                                          looks_like_file => 1,
                                                         },
                                         },
                             #skip => 1,
                            },

             # upload one "small" file (in-memory mode)
             'single-small' => {
                                label => "Upload one small-sized file",
                                files => {
                                          file_test_1 => 5192,
                                         },
                                expected => {
                                             %expectations,
                                             file_test_1 => {
                                                             %seen_expectations,
                                                             file_size => 5192,
                                                            },
                                            },
                                #skip => 1,
                               },

              # upload one large file (trigger on-file-mode)
             'single-large' => {
                                label => "Upload one large-sized file",
                                files => {
                                          file_test_1 => 200_000,
                                         },
                                expected => {
                                             %expectations,
                                             file_test_1 => {
                                                             %seen_expectations,
                                                             file_size => 200_000,
                                                            },
                                            },
                                #skip => 1,
                               },

              # upload multiple small files, below threshold
             'multi-small' => {
                               label => "Upload several small-sized files",
                               files => {
                                         file_test_1 => 5192,
                                         file_test_2 => 2123,
                                         file_test_3 => 786,
                                         file_test_4 => 10100,
                                        },
                               expected => {
                                            %expectations,
                                            file_test_1 => { %seen_expectations, file_size => 5192, },
                                            file_test_2 => { %seen_expectations, file_size => 2123, },
                                            file_test_3 => { %seen_expectations, file_size => 786, },
                                            file_test_4 => { %seen_expectations, file_size => 10100, },
                                           },
                               #skip => 1,
                              },

              # upload multiple large files, above threshold
             'multi-large' => {
                               label => "Upload several large-sized files",
                               files => {
                                         file_test_1 => 128_000,
                                         file_test_2 => 200_000,
                                         file_test_3 => 156_000,
                                         file_test_4 => 1010,
                                        },
                               expected => {
                                            %expectations,
                                            file_test_1 => { %seen_expectations, file_size => 128_000, },
                                            file_test_2 => { %seen_expectations, file_size => 200_000, },
                                            file_test_3 => { %seen_expectations, file_size => 156_000, },
                                            file_test_4 => { %seen_expectations, file_size => 1010, },
                                           },
                               #skip => 1,
                              },
             );

my $mech = make_mech();


foreach my $test_name (sort keys %tests) {
    if ($tests{$test_name}{skip}) {
        next;
    }
    my $url = '/10-upload/' . $test_name . '.asp';

    # Make temp files to upload
    my %sizes_by_field = %{$tests{$test_name}{files}};
    my %file_names_by_field 
      = map { $_ => make_dummy_file($sizes_by_field{$_}) }
        keys %sizes_by_field;

    # Fetch form
    $mech->get_ok($url, "Fetch of $url should be OK");
    $test_count++;
    $mech->form_number(1);

    # Populate upload slots
    foreach my $upload_field (keys %file_names_by_field) {
        # diag("using $file_names_by_field{$upload_field} for $upload_field");
        $mech->field($upload_field, $file_names_by_field{$upload_field});
    }

    # Submit form
    my $response = $mech->submit();

    # Delete temp files
    foreach my $name (values %file_names_by_field) {
        unlink $name;
    }

    is($response->code, 200, "Submit to file-summary should be HTTP status 200");
    $test_count++;
    my $content = $response->content();
    my $expected = $tests{$test_name}{expected};
    my $file_info;
    #diag($content);
    eval $content;
    ok(!$@, "Evalling the return hould not throw an error - got '$@'");
    $test_count++;

  FILE_FIELD:
    foreach my $file_field (keys %{$tests{$test_name}{files}}) {
        my %got = %{$file_info->{$file_field}};
        my %expected = %{$tests{$test_name}{expected}{$file_field}};
        my $label = $tests{$test_name}{label};

        # Was it seen?
        is($got{field_seen}, $expected{field_seen}, "$label - field seen test");
        $test_count++;
        unless ($expected{field_seen}) { next FILE_FIELD; }

        # Did it look like a file?
        is($got{looks_like_file}, $expected{looks_like_file}, "$label - got a file handle test");
        $test_count++;
        unless ($expected{looks_like_file}) { next FILE_FIELD; }

        # Right MIME type?
        if ($expected{file_size}) {
            is($got{content_type}, $expected{content_type}, "$label - should have right content type");
            $test_count++;
        }

        # Was the start marker seen?
        is($got{begin_seen}, $expected{begin_seen}, "$label - should see BEGIN MARKER ");
        $test_count++;

        # Was the end marker seen?
        is($got{end_seen}, $expected{end_seen}, "$label - should see END MARKER");
        $test_count++;

        # Right size?
        is($got{file_size}, $expected{file_size}, "$label - file size test");
        $test_count++;
    }
}

done_testing($test_count);
