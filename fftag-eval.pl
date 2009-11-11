#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use List::MoreUtils qw/uniq/;
use List::Util qw/sum/;

use TreebankUtil::Node qw/spans/;
use TreebankUtil qw/fftag_groups
                    fftags
                    fftag_group_members/;
use TreebankUtil::Node;

my $name = basename $0;
my $usage = <<"EOF";
$name: evaluate form-function tag precision and recall

Usage: $name [options] <goldfile> [testfile]

If testfile is not specified, standard input is used.

Results (labeled precision, labeled recall, f-measure) are
printed to standard out.

This program will accept either "-" or "xx" as a delimiter for
form-function tags.

Options:

 -a,--all   Print all tag information instead of just summaries

EOF

my ($print_all, $print_mistakes);

GetOptions( "all"  => \$print_all,
            "help" => sub { print $usage; exit 0 },
#            "print-mistakes" => \$print_mistakes,
            )
    or die "$usage\n";

sub sets_equal {
    my %s1 = map { $_ => 1 } @{$_[0]};
    my %s2 = map { $_ => 1 } @{$_[1]};
    for (keys %s1) {
        if ($s2{$_}) {
            delete $s1{$_};
            delete $s2{$_};
        }
    }
    return scalar(keys(%s1)) == 0 && scalar(keys(%s2)) == 0;
}

sub compare_spans {
    my @gold_spans = @{$_[0]};
    my $gold_line = $_[1];
    my @test_spans = @{$_[2]};
    my $test_line = $_[3];
    my %scores = %{$_[4]};
    # my TreebankUtil::Node $g_n;
    # my TreebankUtil::Node $t_n;

    my %gold_with_tags;
    my %test_with_tags;
    for (@gold_spans) {
        my $label = $_->[0]->head;
        my $start = $_->[1];
        my $end = $_->[2];
        my $key = "($label $start $end)";
        if ($gold_with_tags{$key}) {
            $gold_with_tags{$key}->{$_} = 1
                foreach $_->[0]->tags;
        } else {
            $gold_with_tags{$key} = { map { $_ => 1 } $_->[0]->tags };
        }
    }
    for (@test_spans) {
        my $label = $_->[0]->head;
        my $start = $_->[1];
        my $end = $_->[2];
        my $key = "($label $start $end)";
        if ($test_with_tags{$key}) {
            $test_with_tags{$key}->{$_} = 1
                foreach $_->[0]->tags;
        } else {
            $test_with_tags{$key} = { map { $_ => 1 } $_->[0]->tags };
        }
    }

    while (my ($gold_span, $gold_tags) = each %gold_with_tags) {
        next
            unless $test_with_tags{$gold_span};
        # warn "common span: $gold_span";
        for (keys %$gold_tags) {
            $scores{$_}->{gold}++;
            # warn "gold span has tag $_...";
            if ($test_with_tags{$gold_span}->{$_}) {
                # warn "test span has tag $_!";
                $scores{$_}->{correct}++;
            } # else {
                # warn "test span lacks tag $_";
            # }
        }
        for (keys %{$test_with_tags{$gold_span}}) {
            $scores{$_}->{test_guesses}++;
        }
    }
    # for my $g (@gold_spans) {
    #     $g_n = $g->[0];
    #     for my $t (@test_spans) {
    #         $t_n = $t->[0];
    #         if ($g_n->head eq $t_n->head
    #             && $g->[1] == $t->[1]
    #             && $g->[2] == $t->[2]) {
    #             for  ($g_n->tags) {
    #                 $scores{$_}->{gold}++;
    #                 if ($t_n->has_tag($_)) {
    #                     $scores{$_}->{correct}++;
    #                 } else {
    #                     push @incorrect_absent, [$g, $t];
    #                 }
    #             }
    #             for ($t_n->tags) {
    #                 $scores{$_}->{test_guesses}++;
    #             }
    #         }
    #     }
    # }
    #
    # if ($print_mistakes) {
    #     for (@incorrect_absent) {
    #         print "tag mismatch:\n\tgold span: ", span2string($_->[0]), "\n\ttest span: ",span2string( $_->[1]), "\n";
    #         print "\tgold line: $gold_line\n\ttest line: $test_line\n";
    #     }
    # }

    return %scores;
}

# sub span2string {
#     my $span = shift;
#     return
#         sprintf '(%s, %d, %d)',
#             join('-', $span->[0]->head, $span->[0]->tags),
#             $span->[1],
#             $span->[2];
# }

sub compute_stats {
    my %scores = %{$_[0]};

    for (fftag_groups) {
        my @tags = fftag_group_members($_);
        my $v = { correct       => sum(map { $scores{$_}->{correct} } @tags),
                  test_guesses  => sum(map { $scores{$_}->{test_guesses} } @tags),
                  gold          => sum(map { $scores{$_}->{gold} } @tags), };
        $scores{$_} = $v;
    }

    for (values(%scores)) {
        if ($_->{test_guesses}) {
            $_->{precision} = $_->{correct} / $_->{test_guesses} * 100;
        } else {
            $_->{precision} = 0;
        }

        if ($_->{gold}) {
            $_->{recall} = $_->{correct} / $_->{gold} * 100;
        } else {
            $_->{recall} = 0;
        }

        if ($_->{precision} && $_->{recall} ) {
            $_->{fmeasure} = 2 * $_->{precision} * $_->{recall} / ($_->{precision} + $_->{recall});
        } else {
            $_->{fmeasure} = 0;
        }
    }
    return %scores;
}

my $gold_fn = shift;
if (!$gold_fn) {
    die "$usage\n";
}
my $gold_fh;
open $gold_fh, '<', $gold_fn
    or die "Can't open gold file \"$gold_fn\"\n";
my $test_fn = shift;
my $test_fh;

if ($test_fn) {
    open $test_fh, '<', $test_fn
        or die "Can't open test file \"$test_fn\"\n";
} else {
    $test_fh = \*STDIN;
}

my %scores;
for (fftags, fftag_groups) {
    my $v = { correct       => 0,
              test_guesses  => 0,
              gold          => 0, };
    $scores{$_} = $v;
}

my ($gold_line, $test_line);
while (!eof($gold_fh) && !eof($test_fh)) {
    $gold_line = <$gold_fh>;
    chomp $gold_line;
    $test_line = <$test_fh>;
    chomp $test_line;
    %scores = compare_spans([spans({ Line        => $gold_line,
                                    FFSeparator => 'xx|-', })],
                            $gold_line,
                            [spans({ Line        => $test_line,
                                    FFSeparator => 'xx|-', })],
                            $test_line,
                            \%scores);
}

unless (eof($gold_fh) && eof($test_fh)) {
    warn("Line mismatch: " . (eof($gold_fh) ? "gold" : "test") . " shorter.\n");
}

%scores = compute_stats(\%scores);

print "Group or tag\tPrecision\tRecall\tFMeasure\n";
for my $group (fftag_groups) {
    printf STDOUT "$group\t%.2f\t%.2f\t%.2f\n",
        $scores{$group}->{precision},
        $scores{$group}->{recall},
        $scores{$group}->{fmeasure};
    if ($print_all) {
        for my $tag (sort { $a cmp $b } fftag_group_members($group)) {
            printf STDOUT "$tag\t%.2f\t%.2f\t%.2f\n",
                $scores{$tag}->{precision},
                $scores{$tag}->{recall},
                $scores{$tag}->{fmeasure};
        }
    }
}

close $test_fh
    if $test_fn;
close $gold_fh;

__END__
