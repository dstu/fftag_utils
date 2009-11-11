#!/usr/bin/perl

use strict;
use warnings;

use TreebankUtil qw/fftags/;
use TreebankUtil::Node;
use TreebankUtil::Tree qw/tree/;

use Getopt::Long;
use File::Basename;

my $name = basename $0;

my $usage = <<"EOF";
$name: transform form-function tag annotations in WSJ-style files

Usage: $name [options] [infile]

Change trees with form-function tag annotations. The following
schema are available:

Scheme 1: ("NP-SBJ" ...) => ("NP" "sbj_1" ...)
Scheme 2: ("NP-SBJ" ...) => ("NP" ("SBJ" "sbj_1") ...)
Scheme 3: ("NP-SBJ" ...) => ("NP" ("TAGS" (SBJ "sbj_1")) ...)

If infile not specified, reads from standard in. Writes to
standard out.

Options:
 --scheme, -s: select scheme number from above
 --clear, --no-clear: clear tags after scheme is applied (default don't)
 --positive-only, -p: only make nodes for positive tag occurrences

EOF

my ($scheme, $clear_tags, $positive_only);

my %SCHEMES =
    ( 1 => sub {
          # (NP-SBJ ...) => (NP sbj_1 ...)
          my ($node, $data, $tags) = @_;
          return $node
              unless ref $node;
          while (my ($k, $v) = each %$tags) {
              $node->prepend_child(lc($k) . "_$v");
          }

          return $node;
      },
      2 => sub {
          # (NP-SBJ ...) => (NP (SBJ sbj_1) ...)
          my ($node, $data, $tags) = @_;
          return $node
              unless ref $node;
          my ($new_child, $new_node);
          while (my ($k, $v) = each %$tags) {
              $new_child = TreebankUtil::Tree->new;
              $new_node = TreebankUtil::Node->new;
              $new_node->set_head($k);
              $new_child->data($new_node);
              $new_child->append_child(lc($k) . "_$v");

              $node->prepend_child($new_child);
          }

          return $node;
      },
      3 => sub {
          # (NP-SBJ ...) => (NP (TAGS sbj_1) ...)
          my ($node, $data, $tags) = @_;
          return $node
              unless ref $node;
          my $tag_child = TreebankUtil::Tree->new;
          my $new_node = TreebankUtil::Node->new;
          $new_node->set_head("TAGS");
          $tag_child->data($new_node);
          my $new_child;
          while (my ($k, $v) = each %$tags) {
              $new_node = TreebankUtil::Node->new;
              $new_node->set_head($k);

              $new_child = TreebankUtil::Tree->new;
              $new_child->data($new_node);
              $new_child->append_child(lc($k) . "_$v");

              $tag_child->append_child($new_child);
          }
          $node->prepend_child($tag_child)
              unless $tag_child->is_leaf;

          return $node;
      }, );

GetOptions( "scheme=i" => sub { $scheme = $SCHEMES{$_[1]} },
            "clear!"   => \$clear_tags,
            "positive-only" => \$positive_only,
            "help"     => sub { print $usage; exit 0 },)
    or die "$usage\n";

unless ($scheme) {
    die "Invalid scheme. Must choose one of: (" . join(' ', sort keys(%SCHEMES)) . ")\n";
}

sub transform_tree {
    my $root = $_[0];
    my @to_transform = ($root);
    my $transformer = $_[1];
    my ($tree, $data, $tags);
    my %temp_tags;
    while (@to_transform) {
        $tree = shift @to_transform;
        next
            unless ref $tree;
        push @to_transform, $tree->children;
        $data = $tree->data;
        if ($positive_only) {
            $tags = {map { $_ => 1 } $data->tags};
        } else {
            %temp_tags = map { $_ => 1 } $data->tags;
            $tags = {};
            for (fftags) {
                $tags->{$_} = $temp_tags{$_} ? 1 : 0;
            }
        }
        $tree = $transformer->($tree,
                               $data,
                               $tags);
        $data->clear_tags
            if $clear_tags;
    }

    return $root;
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

    my $tree = tree({ Line => $_,
                      FFSeparator => 'xx|-', });
    $tree = transform_tree($tree, $scheme);
    print $tree->stringify('xx') . "\n";
}

close $in_fh
    if $in_fn;

__END__
