#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil::Tree qw/tree/;

use Data::Dumper;

use Getopt::Long;
use File::Basename;

my $name = basename $0;

# Numbers taken from WSJ sections 00-22
my %FFTAG_ORDER = 
    ( SBJ => 78189,
      TMP => 23059,
      PRD => 16656,
      LOC => 15816,
      CLR => 15621,
      ADV => 8089,
      DIR => 5716,
      MNR => 4262,
      NOM => 4209,
      TPC => 4056,
      PRP => 3521,
      LGS => 2925,
      EXT => 2226,
      TTL => 489,
      HLN => 484,
      DTV => 471,
      PUT => 247,
      CLF => 61,
      BNF => 52,
      VOC => 25 );

my $usage = <<"EOF";
$name: mutate form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Automatically strips trace annotations (=1, etc.).

When reading a file, accepts "xx" or "-" as joiner between
label and fftag. (I.e., either "NP-SBJ" or "NPxxSBJ".)

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 --joiner, -j    specify string to join annotations with
                 (for output; default "-")
 --keep, -k      specify only tags to keep (-k tag1 tag2 ...)
 --strip, -s     strip tags
 --replace, -r   replace tags with generic tag SBJ
 --one-tag, -o   make all occurrences of multiple tags just
                 one tag, choosing the most frequent tag in
                 the set

Special option:
 --exec, -e      code block to run for each tree, with \$_
                 holding the root of the tree. If this is
                 specified, nothing is printed to standard
                 out. (Write a print statement yourself.)

EOF

my $joiner = "-";
my $exec;
my $onetag;
my $strip;
my $replace;
my @keeptags;

GetOptions( "joiner=s" => \$joiner,
            "strip"    => \$strip,
            "replace"  => \$replace,
            "keep=s@"  => \@keeptags,
            "one-tag"  => \$onetag,
            "exec=s"   => \$exec,
            "help"     => sub { print $usage; exit 0 },)
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

    if ($onetag) {
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data && $_[0]->data->tags) {
                              my @t = sort { $FFTAG_ORDER{$b} <=> $FFTAG_ORDER{$a} } $_[0]->data->tags;
                              $_[0]->data->set_tags($t[0]);
                          }
                      } );
    }

    if ($exec) {
        undef $@;
        eval {
            $_ = $head;
            eval "$exec";
            die "$@"
                if $@;
        };
        die "$@"
            if $@;
    } else {
        print $head->stringify($joiner), "\n";
    }
}

close $in_fh
    if $in_fn;

__END__
