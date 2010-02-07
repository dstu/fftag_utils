#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use List::Util qw/sum/;

use TreebankUtil::Node qw/spans node_reader/;
use TreebankUtil qw/nonterminals
                    fftags
                    propbank_labels/;

my $name = basename $0;
my $usage = <<"EOF";
$name: query treebank form-function tag statistics

Usage: $name [options] [files]

Trees are read in s-list format from files on command line, or
standard in if no files are specified.

Output is printed to standard out.

Options:
 -p,--propbank  Use propbank labels instead of form-function tags
 -n,--nulls     Include "NONE" counts in proportions
EOF

my ($use_propbank, $count_nulls);

GetOptions( "propbank" => \$use_propbank,
            "nulls"    => \$count_nulls,
            "help"     => sub { print $usage; exit 0 }, )
    or die "$usage\n";

my @fftags = $use_propbank ? propbank_labels : fftags;

my %scores = map { $_ => { map { $_ => 0 } (@fftags, "NONE") } } nonterminals;

my $reader = node_reader({ Tags => \@fftags,
                           Separators => ['xx', '-'], });

sub read_trees {
    my $fh = shift;
    while (<$fh>) {
        my $spans = spans({ Line => $_, NodeReader => $reader, });
        for my $head (map { $_->[0] } @$spans) {
            my @tags = $head->tags;
            if (@tags) {
                for my $tag (@tags) {
                    $scores{$head->head}->{$tag}++;
                }
            } elsif ($count_nulls) {
                $scores{$head->head}->{NONE}++;
            }
        }
    }
}

if (@ARGV) {
    for my $fn (@ARGV) {
        my $fh;
        open $fh, '<', $fn
            or die "Can't open file $fn: $!\n";
        read_trees($fh);
        close $fh
            or die "Can't close file $fn: $!\n";
    }
} else {
    read_trees(\*STDIN);
}

for my $nonterminal (sort(nonterminals())) {
    my $total = sum(values(%{$scores{$nonterminal}}));
    next unless $total;
    for my $tag (sort @fftags) {
        my $proportion = $total && $scores{$nonterminal}->{$tag} ? $scores{$nonterminal}->{$tag} / $total : 0.0;
        print "$nonterminal\t$tag\t$proportion\n";
    }
}

__END__
