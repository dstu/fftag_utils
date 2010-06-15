#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use TreebankUtil::Span;
use TreebankUtil::TagResults;
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

my $usage = <<"EOU";
Usage: $0 <gold spans file> <test spans file>
EOU

my $gold_fn = shift;
if (!$gold_fn) {
    die "$usage\n";
}
my $test_fn = shift;
if (!$test_fn) {
    die "$usage\n";
}

my @gold_spans;
my @test_spans;
open my $gold_fh, '<', $gold_fn
    or die "can't open $gold_fn: $!";
open my $test_fh, '<', $test_fn
    or die "can't open $test_fn: $!";
my @lines = <$gold_fh>;
close $gold_fh
    or die "can't close $gold_fn: $!";
@gold_spans = TreebankUtil::Span->from_string(@lines);
@lines = <$test_fh>;
close $test_fh
    or die "can't close $test_fn: $!";
@test_spans = TreebankUtil::Span->from_string(@lines);

my %groups;
for my $g (fftag_groups) {
    $groups{$g} = [fftag_group_members($g)];
}

my $results = TreebankUtil::TagResults->new( gold_spans => \@gold_spans,
                                             test_spans => \@test_spans,
                                             valid_tags => [fftags],
                                             groups     => \%groups, );

my $matched_with_tag = 0;
my $matched_without_tag = 0;
for (map { $_->[0] } @{$results->matched_spans}) {
    if (@{$_->tags}) {
        $matched_with_tag++;
    } else {
        $matched_without_tag++;
    }
}

print "Correctly parsed: $matched_with_tag with tag, $matched_without_tag without.\n";

print "TAG\tPREC\tREC\tF1\n";
for my $g (fftag_groups) {
    printf "\%s\t\%.02f\t\%.02f\t\%.02f\n", $g, $results->precision->count($g) * 100,
        $results->recall->count($g) * 100, $results->f_measure->count($g) * 100;
}

__END__
