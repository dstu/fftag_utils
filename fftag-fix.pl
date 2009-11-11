#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil::Tree qw/tree/;

use Data::Dumper;

use Getopt::Long;
use File::Basename;

my $name = basename $0;

my $usage = <<"EOF";
$name: mutate form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Automatically strips trace annotations (=1, etc.).

When reading a file, accepts "xx" or "-" as joiner between
label and fftag. (I.e., either "NP-SBJ" or "NPxxSBJ".)

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 --joiner, -j   specify string to join annotations with
                (for output; default "-")
 --keep, -k     specify only tags to keep (-k tag1 tag2 ...)
 --strip, -s    strip tags
 --replace, -r  replace tags with generic tag SBJ

EOF

my $joiner = "-";
my $strip;
my $replace;
my @keeptags;

GetOptions( "joiner"  => \$joiner,
            "strip"   => \$strip,
            "replace" => \$replace,
            "keep=s@" => \@keeptags,
            "help"    => sub { print $usage; exit 0 },)
    or die "$usage\n";

@keeptags = split(/,/, join(',', @keeptags));

if ($strip && @keeptags) {
    die "Can't specify --strip and --keep together!\n";
}

if ($strip && $replace) {
    die "Can't specify --strip and --replace together!\n";
}

if ($replace && @keeptags) {
    die "Can't specify --replace and --keep together!\n";
}

my $in_fn = shift;
my $in_fh;
if ($in_fn) {
    open $in_fh, '<', $in_fn
        or die "Can't open input file $in_fn\n";
} else {
    $in_fh = \*STDIN;
}

my @elements;
my @tags;
my $tag;
while (<$in_fh>) {
    chomp;

    my $head = tree({ Line        => $_,
                      FFSeparator => 'xx|-', });
    if ($strip) {
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data) {
                              $_[0]->data->clear_tags
                          }
                      } );
    } elsif ($replace) {
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data && $_[0]->data->tags) {
                              $_[0]->data->clear_tags;
                              $_[0]->data->set_tags("SBJ");
                          }
                      } );
    } elsif (@keeptags) {
        my %keeptags = map { $_ => 1 } @keeptags;
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data) {
                              my @t = grep { $keeptags{$_} } $_[0]->data->tags;
                              $_[0]->data->set_tags(@t);
                          }
                      } );
    }
    print $head->stringify($joiner), "\n";
}

close $in_fh
    if $in_fn;

__END__
