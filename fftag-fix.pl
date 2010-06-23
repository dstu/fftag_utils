#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil qw/tag_or_label_count propbank_labels fftags/;
use TreebankUtil::Tree qw/tree/;
use TreebankUtil::Node qw/node_reader/;

use Data::Dumper;

use Getopt::Long;
use File::Basename;

my $name = basename $0;

my $usage = <<"EOF";
$name: mutate form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Automatically strips trace annotations (=1, etc.).

When reading a file, accepts "xx" or "-" as joiner between
label and fftag ("NP-SBJ" or "NPxxSBJ").

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 --joiner, -j    specify string to join annotations with
                 for output (default "-")
 -k,--keep       specify only tags to keep (-k tag1 tag2 ...)
 -s,--strip      strip tags
 -r,--replace    replace all tags with SBJ
 -o,--one-tag    reduce all occurrences of multiple tags to just
                 the most frequent one in the set
 --no-preterminals  strip fftags from preterminals
 --unary-test    replaces ff tags with unary chains
                 (this is for a baseline test)
 --propbank      use propbank labels


Special option:
 --exec, -e      code block to run for each tree, with \$_
                 holding the root of the tree. If this is
                 specified, nothing is printed to standard
                 out. (Write a print statement yourself.)

EOF

my $joiner = "-";
my $use_propbank;
my $exec;
my $onetag;
my $no_preterminals;
my $unary_test;
my $strip;
my $replace;
my @keeptags;

GetOptions( "joiner=s"   => \$joiner,
            "strip"      => \$strip,
            "replace"    => \$replace,
            "keep=s@"    => \@keeptags,
            "one-tag"    => \$onetag,
            "exec=s"     => \$exec,
	    "no-preterminals" => \$no_preterminals,
            "unary-test" => \$unary_test,
            "propbank"   => \$use_propbank,
            "help"       => sub { print $usage; exit 0 },)
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

if ($unary_test && (@keeptags || $strip || $replace)) {
    die "Can't specify --unary-test with --keep, --strip, or --replace!\n";
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
my $reader = node_reader({ Tags => [ $use_propbank ?
                                         propbank_labels : fftags ],
                           Separators => [ '-', 'xx' ] });
while (<$in_fh>) {
    my $head = tree({ Line        => $_,
                      NodeReader => $reader, });
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
                              $_[0]->data->tags("SBJ");
                          }
                      } );
    } elsif (@keeptags) {
        my %keeptags = map { $_ => 1 } @keeptags;
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data) {
                              my @t = grep { $keeptags{$_} } $_[0]->data->tags;
                              $_[0]->data->tags(@t);
                          }
                      } );
    } elsif ($unary_test) {
        $head = make_unary($head);
    }

    if ($onetag) {
        $head->visit( sub {
                          if (ref $_[0] && $_[0]->data && $_[0]->data->tags) {
                              my @t = sort { tag_or_label_count($b) <=> tag_or_label_count($a) } $_[0]->data->tags;
                              $_[0]->data->tags($t[0]);
                          }
                      } );
    }

    if ($no_preterminals) {
	$head->visit( sub {
			  if (ref $_[0] && $_[0]->is_preterminal && ref $_[0]->data) {
			      $_[0]->data->clear_tags;
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

sub make_unary {
    my $tree = shift;
    if (ref $tree && ref $tree->data) {
        $tree->children(map { make_unary($_) } $tree->children);
        if ($tree->data->tags) {
            my $new_tree = TreebankUtil::Tree->new;
            $tree->data->clear_tags;
            $new_tree->children($tree);
            $new_tree->data(TreebankUtil::Node->new({ TagString => $tree->data->head }));
            return $new_tree;
        }
    }
    return $tree;
}


__END__
