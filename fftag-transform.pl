#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use TreebankUtil qw/nonterminals
                    fftags is_fftag
                    propbank_labels is_propbank_label
                    tag_or_label_count/;

use TreebankUtil::Node qw/node_reader/;
use TreebankUtil::Tree qw/tree/;

use Getopt::Long;
use File::Basename;

my $name = basename $0;

my $usage = <<"EOF";
$name: transform form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Transform trees with form-function tag annotations. The
following schema are available:

Scheme 1: (NP-SBJ ...) => (NP-SBJ ...)
Scheme 2: (NP-SBJ ...) => (NP (SBJ sbj_1) ...)
Scheme 3: (NP-SBJ ...) => (NP (TAGS (SBJ sbj_1)) ...)
Scheme 4: (NP-SBJ ...) => (SBJ (NP ...))

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 -s,--scheme    select scheme number from above
 -p,--propbank  use propbank labels instead of fftags
 --output-join  string to join fftags with in output
                (Default '-')

EOF

my ($scheme, $use_propbank);
my $out_joiner = '-';
my @base_fftags = fftags;
my @mod_fftags;

sub matches_one {
    my $w = shift;
    for (@_) {
        if ($w eq $_) {
            return 1;
        }
    }
    return;
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
              $new_child->data->head($_);
              $new_child->children(lc($_) . "_1");
              $tree->prepend_child($new_child);
          }
          $tree->data->clear_tags;
          return $tree;
      },
      3 => sub {
          # (NP-SBJ ...) => (NP (TAGS (SBJ sbj_1)) ...)
          my $tree = shift;
          return $tree
              unless ref $tree && $tree->data->tags;

          my $tag_child = TreebankUtil::Tree->new;
          $tag_child->data(TreebankUtil::Node->new);
          $tag_child->data->head("TAGS");
          for ($tree->data->tags) {
              my $new_child = TreebankUtil::Tree->new;
              $new_child->data(TreebankUtil::Node->new);
              $new_child->data->head($_);
              $new_child->append_child(lc($_) . "_1");
              $tag_child->append_child($new_child);
          }
          $tree->data->clear_tags;
          $tree->prepend_child($tag_child);

          return $tree;
      },
      4 => sub {
          # (NP-SBJ ...) => (TAG_SBJ (NP ...))
          # If a node has multiple tag annotations, the unary chain so
          # produced goes from most to least common nodes.
          my $tree = shift;
          return $tree
              unless ref $tree && $tree->data->tags;

          if ($tree->data->tags) {
              my @children = $tree->children;
              my @tags = ($tree->data,
                          map { my $n = TreebankUtil::Node->new;
                                $n->head("TAG_$_");
                                $n } sort { tag_or_label_count($a) <=> tag_or_label_count($b) } $tree->data->tags);
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

          return $tree;
      },
      "4_undo" => sub {
          my $tree = shift;
          return $tree
              unless ref $tree && !$tree->is_leaf;

          if (matches_one($tree->data->head, @mod_fftags)) {
              if (1 != scalar($tree->children)) {
                  croak("Bad tree: " . $tree->data->head . " expected 1 child, got " . scalar($tree->children) . ": " . $tree->stringify('-'));
              }
              my $child = ($tree->children)[0];
              $child->data->add_tag(substr($tree->data->head, 4), $tree->data->tags);
              return $child;
          } else {
              my @children;
              foreach my $child ($tree->children) {
                  if (ref $child && matches_one($child->data->head, @mod_fftags)) {
                      if (1 != scalar($child->children)) {
                          croak("Bad tree: " . $child->data->head . " expected 1 child, got " . scalar($child->children) . ": " . $child->stringify('-'));
                      }
                      foreach my $grandchild ($child->children) {
                          $grandchild->data->add_tag(substr($child->data->head, 4), $child->data->tags)
                              if ref $grandchild;
                          push @children, $grandchild;
                      }
                  } else {
                      push @children, $child;
                  }
              }
              $tree->children(@children);
          }

          return $tree;
      }, );

GetOptions( "scheme=s"      => \$scheme,
            "propbank"      => \$use_propbank,
            "output-join=s" => \$out_joiner,
            "help"          => sub { print $usage; exit 0 },)
    or die "$usage\n";

unless ($scheme && $SCHEMES{$scheme}) {
    die "Invalid scheme. Must choose one of: (" . join(' ', sort keys(%SCHEMES)) . ")\n";
}

if ($use_propbank) {
    @base_fftags = propbank_labels;
}
@mod_fftags = map { "TAG_$_" } @base_fftags;

sub transform_tree {
    my $tree = shift;
    my $transformer = shift;
    if (ref $tree && ref $tree->data) {
        my $new_tree = TreebankUtil::Tree->new;
        $new_tree->children(map { $transformer->($_) } map { transform_tree($_, $transformer) } $tree->children);
        $new_tree->data(TreebankUtil::Node->new);
        $new_tree->data->head($tree->data->head);
        $new_tree->data->tags($tree->data->tags);
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

my $reader;
my $separators = ['xx', '-'];
if ($scheme eq '4') {
    $reader = node_reader({ Tags       => \@base_fftags,
                            Separators => $separators, });
} elsif ($scheme eq '4_undo') {
    $reader = node_reader({ Tags       => \@mod_fftags,
                            Separators => $separators, });
} else {
    $reader = node_reader({ Tags       => \@base_fftags,
                            Separators => $separators, });
}

while (<$in_fh>) {
    my $tree = tree({ NodeReader => $reader, Line => $_, });
    $tree = transform_tree($tree, $SCHEMES{$scheme});
    print $tree->stringify($out_joiner) . "\n";
}

close $in_fh
    if $in_fn;

__END__
