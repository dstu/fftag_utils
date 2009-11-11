{
    package TreebankUtil::Tree;
    use fields qw/_data _children/;
    use Data::Dumper;
    use strict;
    use warnings;
    use Exporter qw/import/;
    our @EXPORT_OK = qw/tree/;
    use TreebankUtil::Node;

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

    sub data {
        my TreebankUtil::Tree $t = shift;
        if (@_) {
            $t->{_data} = shift;
        }
        return $t->{_data};
    }

=pod

=head3 visit

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

=pod

=head3 tree

=over

=item Line: the line to build the tree from

=item FFSeparator: the fftag separator regex.

=back

=cut
    sub tree {
        my %args = %{shift()};
        my $line = $args{Line};
        my $ff_separator = '-';
        if ($args{FFSeparator}) {
            $ff_separator = $args{FFSeparator};
        }
        my $i = 0;
        if ($args{_start}) {
            $i = $args{_start};
        }

        my $expect_nonterminal = 1;
        my $head = TreebankUtil::Tree->new;

        while ($i < length($line) - 1) {
            my $ss = substr($line, $i, 1);
            if ('(' eq $ss) {
                $i++;
                my $child;
                ($child, $i) = tree({ Line        => $line,
                                      FFSeparator => $ff_separator,
                                      _start      => $i, });
                $head->append_child($child);
            } elsif (')' eq $ss) {
                $i++;
                return ($head, $i);
            } elsif ($ss =~ m/[\s]/) {
                $i++;
            } else {
                my $l = 1;
                while (substr($line, $i, $l) !~ m/[\s\)]/) {
                    $l++;
                }
                $l--;

                if ($expect_nonterminal) {
                    $head->data(TreebankUtil::Node->new({ TagString   => substr($line, $i, $l),
                                                          FFSeparator => $ff_separator, }));
                    $expect_nonterminal = 0;
                } else {
                    $head->append_child(substr($line, $i, $l));
                }

                $i += $l;
            }
        }

        if (!$head->data) {
            # warn "bad data node: $line @ $i = " . substr($line, $i) . " (total length: " . length($line) . ")\n";
            # warn "children: " . ($head->children)[0]->data->head;
            # warn Dumper($head);
            $head = ($head->children)[0];
        }
        return wantarray ? ($head, $i) : $head;
    }

    sub stringify {
        my TreebankUtil::Tree $tree = shift;
        my $tag_joiner = shift;

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
