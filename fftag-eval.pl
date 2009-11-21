#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use List::MoreUtils qw/uniq/;
use List::Util qw/sum/;

use TreebankUtil::Node qw/spans node_reader/;
use TreebankUtil qw/nonterminals
                    fftag_groups
                    fftags
                    is_fftag
                    fftag_group_members
                    propbank_labels
                    is_propbank_label
                    propbank_label_groups
                    propbank_label_group_members/;

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

 -a,--all       Print all tag information instead of just summaries
 -p,--propbank  Use propbank labels instead of form-function tags
 -s,--scoring   Use partial scoring file

EOF

my ($print_all, $use_propbank);
my ($scoring_fn, $scoring_fh, $scoring_table);

GetOptions( "all"       => \$print_all,
            "propbank"  => \$use_propbank,
            "help"      => sub { print $usage; exit 0 },
            "scoring=s" => \$scoring_fn, )
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

sub load_scoring_table {
    my $fh = shift;
    my %table = map { $_ => {} } nonterminals;
    while (<$fh>) {
        my ($nonterminal, $tag, $prob) = split;
        $nonterminal =~ m{([^_]+)};
        $nonterminal = $1;
        if (is_fftag($tag)) {
            my $existing = 
                $table{$nonterminal}->{$tag} || 0;
            if ($prob > $existing) {
                $table{$nonterminal}->{$tag} = $prob;
            }
        }
    }
    return \%table;
}

sub compare_spans {
    my @gold_spans = @{$_[0]};
    my $gold_line = $_[1];
    my @test_spans = @{$_[2]};
    my $test_line = $_[3];
    my %scores = %{$_[4]};

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
        for (keys %$gold_tags) {
            $scores{$_}->{gold}++;
            if ($test_with_tags{$gold_span}->{$_}) {
                if ($scoring_table) {
                    $gold_span =~ m{\((\w+) };
                    $scores{$_}->{correct}
                        += $scoring_table->{$1}->{$_};
                } else {
                    $scores{$_}->{correct}++;
                }
            }
        }
        for (keys %{$test_with_tags{$gold_span}}) {
            $scores{$_}->{test_guesses}++;
        }
    }

    return %scores;
}

sub compute_stats {
    my %scores = %{$_[0]};

    $scores{TOTAL} = { correct      => 0,
                       test_guesses => 0,
                       gold         => 0, };
    for (values %scores) {
        $scores{TOTAL}->{correct} += $_->{correct};
        $scores{TOTAL}->{test_guesses} += $_->{test_guesses};
        $scores{TOTAL}->{gold} += $_->{gold};
    }

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

if ($scoring_fn) {
    open $scoring_fh, '<', $scoring_fn
        or die "Can't open scoring file \"$scoring_fn\"\n";
    $scoring_table = load_scoring_table($scoring_fh);
    close $scoring_fh;
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
my $reader = node_reader({ Tags       => [$use_propbank ?
                                              propbank_labels : fftags],
                           Separators => ['xx', '-'], });
while (!eof($gold_fh) && !eof($test_fh)) {
    $gold_line = <$gold_fh>;
    $test_line = <$test_fh>;
    %scores = compare_spans([spans({ Line        => $gold_line,
                                     NodeReader  => $reader, })],
                            $gold_line,
                            [spans({ Line        => $test_line,
                                     NodeReader  => $reader, })],
                            $test_line,
                            \%scores);
}

unless (eof($gold_fh) && eof($test_fh)) {
    warn("Line mismatch: " . (eof($gold_fh) ? "gold" : "test") . " shorter.\n");
}

%scores = compute_stats(\%scores);

my @groups = $use_propbank ? propbank_label_groups : fftag_groups;
my $group_members = $use_propbank ? \&propbank_group_members : \&fftag_group_members;

print "Group or tag\tPrec\tRecall\tFMeasure\n";
for my $group (@groups, "TOTAL") {
    printf STDOUT "$group\t%.2f\t%.2f\t%.2f\n",
        $scores{$group}->{precision},
        $scores{$group}->{recall},
        $scores{$group}->{fmeasure};
    if ($print_all) {
        for my $tag (sort { $a cmp $b } $group_members->($group)) {
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
