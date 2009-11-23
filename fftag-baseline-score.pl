#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

use TreebankUtil qw/propbank_labels fftags nonterminals is_fftag/;
use TreebankUtil::Node qw/node_reader spans/;

use File::Basename;

my $name = basename $0;

my $usage = <<"EOF";
$name: compute fftag baseline score for a treeset

Usage: $name <scoring file> <goldfile...>

Options:
 -p,--propbank  Use propbank labels instead of form-function tags

EOF

my ($scoring_fn, $scoring_fh, $scoring_table);
my ($use_propbank);

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

GetOptions( "propbank"  => \$use_propbank,
            "help"      => sub { print $usage; exit 0 }, )
    or die "$usage\n";

die "$usage\n"
    unless $#ARGV >= 1;

$scoring_fn = shift;
open $scoring_fh, '<', $scoring_fn
    or die "Can't open scoring file \"$scoring_fn\"";
$scoring_table = load_scoring_table($scoring_fh);
close $scoring_fh
    or die "Can't close scoring file \"$scoring_fn\"";

my %totals;
my %node_counts;
my $reader = node_reader({ Tags => $use_propbank ? [propbank_labels] : [fftags] });
for my $gold_fn (@ARGV) {
    my $gold_fh;
    open $gold_fh, '<', $gold_fn
        or die "Can't open gold file \"$gold_fn\"";
    while (<$gold_fh>) {
        my @spannodes = map { $_->[0] } spans({ Line       => $_,
                                                NodeReader => $reader, });
        foreach my $n (@spannodes) {
            next
                unless $n->tags;
            my $nonterminal = $n->head;
            $node_counts{$nonterminal} = {}
                unless $node_counts{$nonterminal};
            $totals{$nonterminal} = {}
                unless $totals{$nonterminal};
            foreach my $tag ($n->tags) {
                if ($totals{$nonterminal}->{$tag}) {
                    $totals{$nonterminal}->{$tag}++;
                } else {
                    $totals{$nonterminal}->{$tag} = 1;
                }
                if ($node_counts{$nonterminal}->{$tag}) {
                    $node_counts{$nonterminal}->{$tag} += $scoring_table->{$nonterminal}->{$tag} || 0;
                } else {
                    $node_counts{$nonterminal}->{$tag} =  $scoring_table->{$nonterminal}->{$tag} || 0;
                }
            }
        }
    }
    close $gold_fh
        or die "Can't close gold file \"$gold_fn\"";
}

my $all_total = 0;
my $all_count = 0;
for my $nonterminal (sort keys %totals) {
    for my $tag (sort { $totals{$nonterminal}->{$b} <=> $totals{$nonterminal}->{$a} } keys %{$totals{$nonterminal}}) {
        $all_total += $totals{$nonterminal}->{$tag};
        $all_count += $node_counts{$nonterminal}->{$tag};
        printf STDOUT "%s\t%s\t%.02f\n",
            $nonterminal, $tag, $node_counts{$nonterminal}->{$tag} / $totals{$nonterminal}->{$tag};
    }
}
printf STDOUT "TOTAL\t\t%.02f\n", $all_count / $all_total;
