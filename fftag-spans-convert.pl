#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil qw(fftags);
use TreebankUtil::Node qw(node_reader);
use TreebankUtil::Span;

my $usage = <<"EOU";
Usage: $0 <input file> [output file]

EOU

my $in_fn = shift
    or die "$usage\n";
my $out_fn = shift;
my $out_fh;
if ($out_fn) {
    open $out_fh, '>', $out_fn
        or die "can't open $out_fn: $!";
} else {
    $out_fh = \*STDOUT;
}

my $reader = node_reader({ Tags       => [fftags],
                           Separators => ['xx', '-'], });
my $spans = TreebankUtil::Span->read_trees_file($in_fn, $reader);

for (@$spans) {
    print $out_fh $_->stringify, "\n";
}

if ($out_fn) {
    close $out_fh
        or die "can't close $out_fn: $!";
}
__END__
