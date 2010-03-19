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
 -s,--substate  Use substate numbers instead of form-function tags
 -b,--binarized Allow '\@'-style binarization
 -c,--counts    Print counts instead of proportions
 -n,--nulls     Include "NONE" counts in proportions
EOF

my ($use_propbank, $use_substate, $allow_binarized, $count_nulls, $print_counts);

GetOptions( "propbank"  => \$use_propbank,
            "substate"  => \$use_substate,
            "binarized" => \$allow_binarized,
            "nulls"     => \$count_nulls,
            "counts"    => \$print_counts,
            "help"      => sub { print $usage; exit 0 }, )
    or die "$usage\n";

my @fftags;
if ($use_propbank) {
    @fftags = sort propbank_labels;
} elsif ($use_substate) {
    @fftags = (0..64);
} else {
    @fftags = sort fftags;
}

my @nonterminals = nonterminals;

if ($allow_binarized) {
    @nonterminals = (@nonterminals, map { "\@$_" } @nonterminals);
}

@nonterminals = sort @nonterminals;

my %scores = map { $_ => { map { $_ => 0 } (@fftags, "NONE") } } @nonterminals;

my $reader = node_reader({ Tags => \@fftags,
                           Nonterminals => \@nonterminals,
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

print "TAG\t";
if ($use_substate) {
    print "SUBSTATE\t";
} elsif ($use_propbank) {
    print "PROPBANK\t";
} else {
    print "FFTAG\t";
}
if ($print_counts) {
    print "COUNT\n";
} else {
    print "PROPORTION\n";
}

for my $nonterminal (@nonterminals) {
    if ($print_counts) {
        for my $tag (@fftags) {
            next
                unless $scores{$nonterminal}->{$tag};
            print "$nonterminal\t$tag\t$scores{$nonterminal}->{$tag}\n";
        }
    } else {
        my $total = sum(values(%{$scores{$nonterminal}}));
        next unless $total;
        for my $tag (@fftags) {
            my $proportion = $total && $scores{$nonterminal}->{$tag} ? $scores{$nonterminal}->{$tag} / $total : 0.0;
            print "$nonterminal\t$tag\t$proportion\n";
        }
    }
}

__END__
