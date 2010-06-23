{
    package TreebankUtil::Tree;
    use fields qw/_data _children/;
    use Data::Dumper;
    use strict;
    use warnings;
    use Exporter qw/import/;
    our @EXPORT_OK = qw/tree/;
    use TreebankUtil::Node qw/node_reader/;
    use TreebankUtil qw/nonterminals fftags/;

    sub new {
        my $t = shift;
        unless (ref $t) {
            $t = fields::new($t);
        }
        $t->{_children} = [];
        return $t;
    }

    sub prepend_child {
        my TreebankUtil::Tree $t = shift;
        unshift @{$t->{_children}}, @_;
        return $t;
    }

    sub append_child {
        my TreebankUtil::Tree $t = shift;
        push @{$t->{_children}}, @_;
        return $t;
    }

    sub children {
        my TreebankUtil::Tree $t = shift;
        if (@_) {
            $t->{_children} = \@_;
        }
        return @{$t->{_children}};
    }

    sub is_leaf {
        my TreebankUtil::Tree $t = shift;
        return 0 == scalar(@{$t->{_children}});
    }

    sub is_preterminal {
	my TreebankUtil::Tree $t = shift;
	my @children = $t->children;
	if (1 == scalar(@children) && ref $children[0]) {
	    return $children[0]->is_leaf;
	}
	return 0;
    }

    sub data {
        my TreebankUtil::Tree $t = shift;
        if (@_) {
            $t->{_data} = shift;
        }
        return $t->{_data};
    }

=head2 visit

Runs the provided subref with the parameter of this tree node,
then recursively calls visit with the same parameter on each of
its children.

=cut
    sub visit {
        $_[1]->($_[0]);
        for ($_[0]->children) {
            $_->visit($_[1])
                if ref $_;
        }
    }

=head2 tree

=over

=item Line: the line to build the tree from

=item TagSeparators: an arrayref of valid tag separators.

=item Nonterminals: an arrayref of the nonterminals to allow in
the tree (default standard Penn treebank set).

=item Tags: an arrayref of the tags to allow in the tree
(default standard Penn Treebank form-function tag set).

=item NodeReader: a subref that takes a string and returns a
TreebankUtil::Node built from it. (Specify this instead of
C<Separators>, C<Nonterminals>, and C<Tags>, if you want. See
L<TreebankUtil::Node/node_reader>.)

=back

=cut
    sub tree {
        my %args = %{shift()};
        my $line = $args{Line};
        my $i = 0;
        if ($args{_start}) {
            $i = $args{_start};
        }
        my $reader;
        if ($args{NodeReader}) {
            $reader = $args{NodeReader};
        } else {
            $reader = node_reader(\%args);
            $args{NodeReader} = $reader;
        }

        my $expect_nonterminal = 1;
        my $head = TreebankUtil::Tree->new;

        while ($i < length($line) - 1) {
            my $ss = substr($line, $i, 1);
            if ('(' eq $ss) {
                $i++;
                my $child;
                $args{_start} = $i;
                ($child, $i) = tree(\%args);
                $head->append_child($child);
            } elsif (')' eq $ss) {
                $i++;
                return ($head, $i);
            } elsif ($ss eq ' ') {
                $i++;
            } else {
                my $l = 1;
                my $char = substr($line, $i + $l, 1);
                while ($char ne ' ' && $char ne ')') {
                    $l++;
                    $char = substr($line, $i + $l, 1);
                }

                if ($expect_nonterminal) {
                    $head->data($reader->(substr($line, $i, $l)));
                    $expect_nonterminal = 0;
                } else {
                    $head->append_child(substr($line, $i, $l));
                }

                $i += $l;
            }
        }

        if (!$head->data) {
            $head = ($head->children)[0];
        }
        return wantarray ? ($head, $i) : $head;
    }

    sub stringify {
        my TreebankUtil::Tree $tree = shift;
        my $tag_joiner = shift || '-';

        if (ref $tree) {
            my $h;
            if (ref $tree->data) {
                $h = '(' . join($tag_joiner, $tree->data->head, $tree->data->tags);

                return join(' ', $h, map { (ref $_ ? $_->stringify($tag_joiner) : $_) } $tree->children) . ')';
            } else {
                return '()';
            }
        } else {
            return $tree;
        }
    }
}

1;

__END__
