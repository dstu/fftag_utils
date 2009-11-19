{
    package TreebankUtil::Node;

    use strict;
    use warnings;

    use fields qw(_head _fftags);

    use Exporter qw/import/;
    our @EXPORT_OK = qw/spans/;
    use Carp qw/cluck/;
    use TreebankUtil qw(nonterminals fftags);

    # qr/^(nonterminal_regex())
    #    (?:(?:-|xx)(fftag_regex()))*/x;

=pod

=head3 new

Argument is a hashref. Keys are:

=over

=item Nonterminals: nonterminal node strings. Default standard Penn treebank nonterminals.

=item FFTags: fftag strings. Default standard Penn treebank fftags.

=item FFSeparator: fftag separator string. May be a regex. (Run through quotemeta if you have to!) Default "-".

=item TagString: a string that the node contents should be extracted from. (Something like NP-SBJ or VBZ or whatever.)

=back

=cut
    sub new {
        my TreebankUtil::Node  $t = shift;
        unless (ref $t) {
            $t = fields::new($t);
        }
        if (@_) {
            my %args = %{$_[0]};
            my $separator = '-';
            if ($args{FFSeparator}) {
                $separator = $args{FFSeparator};
            }
            my $nonterminals;
            if ($args{Nonterminals}) {
                $nonterminals = $args{Nonterminals};
            } else {
                $nonterminals = [ nonterminals ];
            }
            my $fftags;
            if ($args{FFTags}) {
                $fftags = $args{FFTags};
            } else {
                $fftags = [ fftags ];
            }
            if ($args{TagString}) {
                my ($head, $tags) = _extract_data($args{TagString}, $nonterminals, $fftags, $separator)
                    or cluck("Can't extract nonterminal and tags; ignoring tag \"$args{TagString}\"");
                $t->set_head($head);
                $t->set_tags(@$tags);
            }
        }

        return $t;
    }

    sub _extract_data {
        my ($s, $nonterminals, $fftags, $separator) = @_;
        my $nonterminal_match = join('|', map { quotemeta } @$nonterminals);
        my $tag_match = join('|', map { quotemeta } @$fftags);

        my $head;
        my @tags;
        my $TAG_REGEX;
        {
            use re 'eval';
            $TAG_REGEX
                = qr{
                        ^($nonterminal_match)         # Find head
                        (?{ $head = $^N })            # Remember it
                        (?:(?:$separator)             # Separator (begin optional)
                            ($tag_match)              # Tag
                            (?{ push @tags, $^N }))*  # Remember it (end optional)
                        (?:=\d+)?$                    # End expression with possible trace
                }x;
        }
        if ($s =~ $TAG_REGEX) {
            return ($head, \@tags);
        } else {
            return;
        }
    }

    sub set_head {
        my TreebankUtil::Node $t = shift;
        $t->{_head} = shift;
        return $t;
    }

    sub head {
        my TreebankUtil::Node $t = shift;
        return $t->{_head};
    }

    sub set_tags {
        my TreebankUtil::Node $t = shift;
        $t->{_fftags} = {map { $_ => 1 } @_};
        return $t;
    }

    sub tags {
        my TreebankUtil::Node $t = shift;
        return keys(%{$t->{_fftags}});
    }

    sub clear_tags {
        my TreebankUtil::Node $t = shift;
        $t->{_fftags} = {};
        return $t;
    }

    sub add_tag {
        my TreebankUtil::Node $t = shift;
        $t->{_fftags}->{$_} = 1
            foreach @_;
        return $t;
    }

    sub del_tag {
        my TreebankUtil::Node $t = shift;
        delete $t->{_fftags}->{$_}
            foreach @_;
        return $t;
    }

    sub has_tag {
        my TreebankUtil::Node $t = shift;
        return $t->{_fftags}->{$_[0]};
    }

=pod

=head3 spans

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

=item FFSeparator: the fftag separator regex. Default "-".

=back

=cut
    sub spans {
        my %args = %{shift()};
        my $line = $args{Line};
        my $ff_separator = '-';
        if ($args{FFSeparator}) {
            $ff_separator = $args{FFSeparator};
        }
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
                    my $n = TreebankUtil::Node->new({ TagString   => $1,
                                                      FFSeparator => $ff_separator, });
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
}

1;

__END__
