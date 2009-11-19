#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use TreebankUtil qw/nonterminals fftags is_fftag role_labels/;
use TreebankUtil::Node;
use TreebankUtil::Tree qw/tree/;

use Getopt::Long;
use File::Basename;

my @mod_fftags = map { "TAG_$_" } (fftags, role_labels);

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

my $name = basename $0;

my $usage = <<"EOF";
$name: transform form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Change trees with form-function tag annotations. The following
schema are available:

Scheme 1: ("NP-SBJ" ...) => ("NP-SBJ" ...)
Scheme 2: ("NP-SBJ" ...) => ("NP" ("SBJ" "sbj_1") ...)
Scheme 3: ("NP-SBJ" ...) => ("NP" ("TAGS" (SBJ "sbj_1")) ...)
Scheme 4: ("NP-SBJ" ...) => ("SBJ" ("NP" ...))

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 --scheme, -s: select scheme number from above
 --clear, --no-clear: clear tags after scheme is applied (default don't)
 --output-join: string to join fftags with in output (default '-')

EOF

my ($scheme, $clear_tags);
my $out_joiner = '-';

sub transform4 {
    my $tree = shift;
    if (ref $tree && ref $tree->data) {
        $tree->children(map { transform4($_) } $tree->children);
        if ($tree->data->tags) {
            my @children = $tree->children;
            my @tags = ($tree->data,
                        map { my $n = TreebankUtil::Node->new;
                              $n->set_head("TAG_$_");
                              $n } sort { $FFTAG_ORDER{$a} <=> $FFTAG_ORDER{$b} } $tree->data->tags);
            $tree->data->clear_tags;
            my $new_tree;
            foreach (@tags) {
                $new_tree = TreebankUtil::Tree->new;
                $new_tree->data($_);
                $new_tree->children(@children);
                @children = ($new_tree);
            }
            return $new_tree;
        }
    }
    return $tree;
}

sub matches_one {
    my $w = shift;
    for (@_) {
        if ($w eq $_) {
            return 1;
        }
    }
    return;
}

sub transform4_undo {
    my $tree = shift;
    if (ref $tree && ref $tree->data) {
        if (matches_one($tree->data->head, @mod_fftags)) {
            if (1 != scalar($tree->children)) {
                croak("Bad tree: " . $tree->data->head . " expected 1 child, got " . scalar($tree->children) . ": " . $tree->stringify('-'));
            }
            my $child = ($tree->children)[0];
            $child->data->add_tag(map { } $tree->data->head, $tree->data->tags);
            return $child;
        } else {
            my @children;
            foreach my $child ($tree->children) {
               if (ref $child && matches_one($child->data->head, @mod_fftags)) {
                    if (1 != scalar($child->children)) {
                        croak("Bad tree: " . $child->data->head . " expected 1 child, got " . scalar($child->children) . ": " . $child->stringify('-'));
                    }
                    foreach my $grandchild ($child->children) {
                        $grandchild->data->add_tag($child->data->head, $child->data->tags)
                            if ref $grandchild;
                        push @children, $grandchild;
                    }
                } else {
                    push @children, $child;
                }
            }
            $tree->children(@children);
        }
    }
    return $tree;
}

my %SCHEMES =
    ( 1 => sub { return shift; },
      2 => sub {
          # (NP-SBJ ...) => (NP (SBJ sbj_1) ...)
          my $tree = shift;
          return $tree
              unless ref $tree && $tree->data->tags;
          for ($tree->data->tags) {
              my $new_child = TreebankUtil::Tree->new;
              $new_child->data(TreebankUtil::Node->new);
              $new_child->data->set_head($_);
              $new_child->children("$_" . "_1");
              $tree->prepend_child($new_child);
          }
          $tree->data->clear_tags;
          return $tree;
      },
      3 => sub {
          # (NP-SBJ ...) => (NP (TAGS sbj_1) ...)
          my $tree = shift;
          return $tree
              unless ref $tree && $tree->data->tags;

          my $tag_child = TreebankUtil::Tree->new;
          $tag_child->data(TreebankUtil::Node->new);
          $tag_child->data->set_head("TAGS");
          for ($tree->data->tags) {
              my $new_child = TreebankUtil::Tree->new;
              $new_child->data(TreebankUtil::Node->new);
              $new_child->data->set_head($_);
              $new_child->append_child($_ . "_1");
              $tag_child->append_child($new_child);
          }
          $tree->data->clear_tags;
          $tree->prepend_child($tag_child);

          return $tree;
      },
      4 => \&transform4,
      "4_undo" => \&transform4_undo, );

GetOptions( "scheme=s" => \$scheme,
            "clear!"   => \$clear_tags,
            "output-join=s" => \$out_joiner,
            "help"     => sub { print $usage; exit 0 },)
    or die "$usage\n";

unless ($SCHEMES{$scheme}) {
    die "Invalid scheme. Must choose one of: (" . join(' ', sort keys(%SCHEMES)) . ")\n";
}

sub transform_tree {
    my $tree = shift;
    my $transformer = shift;
    if (ref $tree && ref $tree->data) {
        my $new_tree = TreebankUtil::Tree->new;
        $new_tree->children(map { $transformer->($_) } map { transform_tree($_, $transformer) } $tree->children);
        $new_tree->data(TreebankUtil::Node->new);
        $new_tree->data->set_head($tree->data->head);
        $new_tree->data->set_tags($tree->data->tags);
        $new_tree = $transformer->($new_tree);
        return $new_tree;
    } else {
        return $tree;
    }
}

my $in_fn = shift;
my $in_fh;
if ($in_fn) {
    open $in_fh, '<', $in_fn
        or die "Can't open input file $in_fn\n";
} else {
    $in_fh = \*STDIN;
}

while (<$in_fh>) {
    chomp;

    my $tree;
    if ($scheme eq '4_undo') {
        $tree = tree({ Nonterminals => [fftags, nonterminals],
                       Line => $_,
                       FFSeparator => 'xx|-', });
    } else {
        $tree = tree({ Line => $_,
                       FFSeparator => 'xx|-', });
    }
    $tree = transform_tree($tree, $SCHEMES{$scheme});
    print $tree->stringify($out_joiner) . "\n";
}

close $in_fh
    if $in_fn;

__END__
