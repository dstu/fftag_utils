#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil qw/nonterminals fftags/;
use TreebankUtil::Node qw/node_reader/;
use TreebankUtil::Tree qw/tree/;
use TreebankUtil::Transform::PropagateFFTagsToHeadPreterminals;

use Getopt::Long;

my $usage = <<"EOU";
Usage: $0 [infile] [outfile]

Reads trees from infile (default standard in), transforms them
by propagating form-function tags down from phrasal nodes to
their headwords' preterminal nodes, and writes the resulting
trees to outfile (default standard out).
EOU

GetOptions( "help" => sub { print "$usage\n"; exit(0); } )
    or die "$usage\n";

my $in_fn = shift;
my $in_fh = \*STDIN;
if ($in_fn) {
    open $in_fh, '<', $in_fn
	or die "can't open \"$in_fn\": $!";
}

my $out_fn = shift;
my $out_fh = \*STDOUT;
if ($out_fn) {
    open $out_fh, '>', $out_fn
	or die "can't open \"$out_fn\": $!";
}

my $node_reader = node_reader({ Nonterminals => [nonterminals],
				Tags         => [fftags] });
my $transformer = TreebankUtil::Transform::PropagateFFTagsToHeadPreterminals->new;
while (<$in_fh>) {
    chomp $in_fh;
    my $tree = tree({ Line       => $_,
		      NodeReader => $node_reader });
    $tree = $transformer->transform($tree);
    print $out_fh $tree->stringify, "\n";
}

if ($in_fn) {
    close $in_fh
	or die "can't close \"$in_fn\": $!";
}

if ($out_fn) {
    close $out_fh
	or die "can't close \"$out_fn\": $!";
}

__END__
