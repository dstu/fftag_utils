{
    package TreebankUtil::Node;

=head1 NAME

TreebankUtil::Node - Class representing an internal node of a
treebank tree.

=head1 VERSION

Version 0.01

=cut

    our $VERSION = '0.01';

=head1 SYNOPSIS

This class represents a structured node in a treebank tree. A
node has a head, the actual grammatical label for the node, and
a set of tags.

The methods that read nodes from strings are strict, such that
you must specify what constitutes a valid node ahead of time.

=head1 EXPORT

None by default. Available functions are:

spans, node_reader

=head1 FUNCTIONS

=cut

    use strict;
    use warnings;

    use fields qw(_head _tags);

    use Exporter qw/import/;
    our @EXPORT_OK = qw/spans node_reader/;
    use TreebankUtil qw(nonterminals fftags);

=head2 new

Argument is a hashref. Keys are as L</node_reader>, except for:

=over

=item NodeString: a string that the node contents should be
extracted from. (Something like "NP-SBJ" or "VBZ".)

=back

If you're going to be creating a lot of nodes (as is the case if
you're reading trees from a treebank), calling C<< new >> like
this is wasteful. Consider getting a L</node_reader> and calling
its returned subref repeatedly.

=cut
    sub new {
        my TreebankUtil::Node  $t = shift;
        unless (ref $t) {
            $t = fields::new($t);
        }
        if (@_) {
            my %args = %{$_[0]};
            if ($args{NodeString}) {
                my ($head, $tags) = node_reader(\%args)->($args{NodeString})
                    or return $t;
                $t->head($head);
                $t->tags(@$tags);
            }
        }

        return $t;
    }

=head2 node_reader

    use TreebankUtil::Node qw/node_reader/;
    use TreebankUtil qw/nonterminals fftags/;
    my $reader = node_reader({ Nonterminals => [nonterminals],
                               Tags         => [fftags], });
    my @nodes;
    while (<STDIN>) {
      push @nodes, $reader->($_);
    }

Takes a hashref that may have the following keys:

=over

=item Nonterminals: specifies an arrayref of valid nonterminal
node labels (like NP or VP). Defaults to the Penn Treebank
nonterminal tags.

=item Tags: specifies an arrayref of valid annotation tags (like
Penn Treebank form-function tags or Propbank semantic role
labels). Defaults to the Penn Treebank form-function tags;

=item Separators: specifies an arrayref of valid
separators. Defaults to C<< [ "-" ] >>.

=back

Returns a subref that maps from strings to nodes, using the
specified parameters. Subref automatically chomps its input for
you.

If you're reading a lot of nodes, it's cheaper to use this
function than call L</new> repeatedly, as L</new> just calls
this, and rebuilding the regex to recognize nodes over and over
again is wasteful.

=cut
    sub node_reader {
        my %args = %{$_[0]};
        my $nonterminals = $args{Nonterminals} || [nonterminals];
        my $fftags = $args{Tags} || [fftags];
        my $separators = $args{separators} || ['-'];

        my $nonterminal_match = '(?:' . join('|', map { quotemeta } @$nonterminals) . ')';
        my $tag_match = '(?:' . join('|', map { quotemeta } @$fftags) . ')';
        my $separator_match = '(?:' . join('|', map { quotemeta } @$separators) . ')';

        my $head;
        my @tags;
        my $TAG_REGEX;
        {
            use re 'eval';
            $TAG_REGEX
                = qr{
                        ^($nonterminal_match)  # Find head
                        (?{ $head = $^N })
                        (?:$separator_match    # Tag(s) separated by head
                            ($tag_match)
                            (?{ push @tags, $^N }))*
                        (?:=\d+)?$             # End expression with possible trace
                }x;
        }
        croak("Can't build regex")
            unless $TAG_REGEX;

        return sub {
            my $s = shift;
            chomp $s;
            undef $head;
            @tags = ();
            if ($s =~ m{$TAG_REGEX}x) {
                my $n = TreebankUtil::Node->new;
                $n->head($head);
                $n->tags(@tags);
                return $n;
            } else {
                warn("Can't extract nonterminal and tags; ignoring node \"$s\"\n");
                return;
            }
        }
    }

    sub head {
        my TreebankUtil::Node $t = shift;
        if (@_) {
            $t->{_head} = shift;
        }
        return $t->{_head};
    }

    sub tags {
        my TreebankUtil::Node $t = shift;
        if (@_) {
            $t->{_tags} = { map { $_ => 1 } @_ };
        }
        return keys(%{$t->{_tags}});
    }

    sub clear_tags {
        my TreebankUtil::Node $t = shift;
        $t->{_tags} = {};
        return $t;
    }

    sub add_tag {
        my TreebankUtil::Node $t = shift;
        $t->{_tags}->{$_} = 1
            foreach @_;
        return $t;
    }

    sub del_tag {
        my TreebankUtil::Node $t = shift;
        delete $t->{_tags}->{$_}
            foreach @_;
        return $t;
    }

    sub has_tag {
        my TreebankUtil::Node $t = shift;
        return $t->{_tags}->{$_[0]};
    }

=head2 spans

Returns the spans of a line from the Penn treebank. In scalar
context, returns an arrayref.

This doesn't use information about fftags or nonterminals to do
anything intelligent; it just reads in a big s-list and figures
out what its spans are.

A span consists of an arrayref with three elements: the span
head (an instance of TreebankUtil::Node), the span begin index,
and the span end index.

Args should be a hashref. Valid keys are:

=over

=item Line: the line to get the spans for.

=item NodeReader: a function that takes a string and returns a
node, as returned by L</node_reader>.

=back

=cut
    sub spans {
        my %args = %{shift()};
        my $line = $args{Line};
        my $reader = $args{NodeReader};
        my @spans;
        my @open_spans;
        my $i = 0;
        my $expect_nonterminal;
        while ($line =~ m{(\(|                   # open paren
                              \)|                # close paren
                              [^\(\)\s]+)}gcx) { # anything else but whitespace
            if ('(' eq $1) {
                $expect_nonterminal = 1;
            } elsif ( ')' eq $1) {
                my $s = pop @open_spans;
                $s->[2] = $i;
                push @spans, $s
                    if $s->[0];
                $expect_nonterminal = 0;
            } else {
                if ($expect_nonterminal) {
                    my $n = $reader->($1);
                    push @open_spans, [$n, $i];
                    $expect_nonterminal = 0;
                } else {
                    $i++;
                }
            }
        }
        if (@open_spans) {
            warn("Open spans remain. Missing )?");
        }
        return wantarray ? @spans : \@spans;
    }

=head2 stringify

C<< print $my_node->stringify("xx"), "\n" >>

Returns a string representing the node. If a parameter is
specified, it is used to join the tag(s) of the node. Default is
to use "-".

=cut
    sub stringify {
        my TreebankUtil::Node $t = shift;
        my $joiner = shift || '-';
        return join($joiner, $t->head, $t->tags);
    }

=head1 AUTHOR

Stu Black, C<< <trurl at freeshell.org> >>

=head1 BUGS

None known. E-mail me.

=head1 SUPPORT

E-mail me.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Stu Black.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

}

1;

__END__
