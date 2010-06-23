{
    package TreebankUtil::Transform::PropagateFFTagsToHeadPreterminals;
    use Moose;
    use Carp;
    use TreebankUtil::Tree;
    use TreebankUtil::Node;
    use constant LEFT  => 1;
    use constant RIGHT => -1;

    has 'rules' => (is => 'ro',
                    isa => 'HashRef[ArrayRef[CodeRef]]',
                    default => sub{ {} });

    sub make_simple_rule {
        my $l2r = shift;
        my %acclist = map { $_ => 1 } @_;
        return sub {
            my $tree = shift;
            return
                unless ref $tree;
            my @children;
            my $default;
            if ($l2r) {
                @children = $tree->children;
                $default = $children[0];
            } else {
                @children = reverse $tree->children;
                $default = $children[$#children];
            }

            return
                unless @children;

            for (@children) {
                if (ref $_ && ref $_->data && $acclist{$_->data->head}) {
                    return $_;
                }
            }

            return $default;
        }
    }

    sub BUILD {
        my $t = shift;
        $t->rules->{NP}
            = [            # If rightmost item is POS, that's it
                sub {
                    my $tree = shift;
                    my @children = $tree->children;
                    my $rc = $children[$#children];
                    if (ref $rc && ref $rc->data && $rc->data->head eq 'POS') {
                        return $rc;
                    } else {
                        return;
                    }
                },
                # Search from right to left for first child
                # which is NN, NNP, NNPS, NNS, NX, POS, or JJR
                make_simple_rule(0, qw(NN NNP NNPS NNS NX POS JJR)),
                # Search from left to right for first child
                # which is NP
                sub {
                    my $tree = shift;
                    for ($tree->children) {
                        if (ref $_ && ref $_->data && $_->data->head eq 'NP') {
                            return $_;
                        }
                    }
                    return;
                },
                # Search from right to left for first child
                # which is $, ADJP, or PRN
                make_simple_rule(0, qw(\$ ADJP PRN)),
                # Search from right to left for first child
                # which is a CD
                make_simple_rule(0, qw(CD)),
                # Search from right to left for the first child
                # which is JJ, JJS, RB, or QP
                make_simple_rule(0, qw(JJ JJS RB QWP)),
                # Else return last word
                sub {
                    my $tree = shift;
                    while (ref $tree  && $tree->children) {
                        my @children = $tree->children;
                        $tree = $children[$#children];
                    }
                    return $tree;
                }
                    ];          # end NP
        $t->rules->{ADJP}
            = [  # Search left to right for one of NNS QP NN S
                # ADVP JJ VBN VBG ADJP JJR NP JJS DT FW RBR RBS
                # SBAR RB
                make_simple_rule(1, qw(NNS QP NN S ADVP JJ VBN VBG ADJP JJR NP JJS DT FW RBR RBS SBAR RB))
                    ];
        $t->rules->{ADVP}
            = [ # Search right to left for one of RB RBR RBS FW ADVP TO CD JJR JJ IN NP JJS NN
                make_simple_rule(0, qw(RB RBR RBS FW ADVP TO CD JJR JJ IN NP JJS NN))
                    ];
        $t->rules->{CONJP}
            = [       # Search right to left for one of CC RB IN
                make_simple_rule(0, qw(CC RB IN))
                    ];
        $t->rules->{FRAG}
            = [ make_simple_rule(0) ];
        $t->rules->{INTJ}
            = [ make_simple_rule(1) ];
        $t->rules->{LST}
            = [           # Search right to left for one of LS :
                make_simple_rule(0, qw(LS :))
                    ];
        $t->rules->{NAC}
            = [ # Search left to right for one of NN NNS NNP NNPS NP NAC EX S CD QP PRP VBG JJ JJS JJR ADJP FW
                make_simple_rule(1, qw(NN NNS NNP NNPS NP NAC EX S CD QP PRP VBG JJ JJS JJR ADJP FW))
                    ];
        $t->rules->{PP}
            = [ # Search right to left for one of IN TO VBG VBN RP FW
                make_simple_rule(0, qw(IN TO VBG VBN RP FW))
                    ];
        $t->rules->{PRN}
            = [ make_simple_rule(1) ];
        $t->rules->{PRT}
            = [                 # Search right to left for RP
                make_simple_rule(0, qw(RP))
                    ];
        $t->rules->{QP}
            = [ # Search left to right for one of S IN NNS NN JJ RB DT CD NCD QP JJR JJS
                make_simple_rule(1, qw(S IN NNS NN JJ RB DT CD NCD QP JJR JJS))
                    ];
        $t->rules->{RRC}
            = [ # Search right to left for one of VP NP ADVP ADJP PP
                make_simple_rule(0, qw(VP NP ADVP ADJP PP))
                    ];
        $t->rules->{S}
            = [ # Search left to right for one of TO IN VP S SBAR ADJP UCP NP
                make_simple_rule(1, qw(TO IN VP S SBAR ADJP UCP NP))
                    ];
        $t->rules->{SBARQ}
            = [ # Search left to right for one of SQ S SINV SBARQ FRAG
                make_simple_rule(1, qw(SQ S SINV SBARQ FRAG))
                    ];
        $t->rules->{SINV}
            = [ # Search left to right for one of VBZ VBD VBP VB MD VP S SINV ADJP NP
                make_simple_rule(1, qw(VBZ VBD VBP VB MD VP S SINV ADJP NP))
                    ];
        $t->rules->{SQ}
            = [ # Search left to right for one of VBZ VBD VBP VB MD VP SQ
                make_simple_rule(1, qw(VBZ VBD VBP VB MD VP SQ))
                    ];
        $t->rules->{UCP}
            = [ make_simple_rule(0) ];
        $t->rules->{VP}
            = [ # Search left to right for one of TO VBD VBN MD VBZ VB VBG VBP VP ADJP NN NNS NP
                make_simple_rule(1, qw(TO VBD VBN MD VBZ VB VBG VBP VP ADJP NN NNS NP))
                    ];
        $t->rules->{WHADJP}
            = [ # Search left to right for one of CC WRB JJ ADJP
                make_simple_rule(1, qw(CC WRB JJ ADJP))
                    ];
        $t->rules->{WHADVP}
            = [         # Search right to left for one of CC WRB
                make_simple_rule(0, qw(CC WRB))
                    ];
        $t->rules->{WHNP}
            = [ # Search left to right for one of WDT WP WP$ WHADJP WHPP WHNP
                make_simple_rule(1, qw(WDT WP WP\$ WHADJP WHPP WHNP))
                    ];
        $t->rules->{WHPP}
            = [       # Search right to left for one of IN TO FW
                make_simple_rule(0, qw(IN TO FW))
                    ];
    }

    sub find_head_preterminals {
        my $t = shift;
        my $tree = shift;
        my $preterminal_lookup = shift // {};

        # Build from bottom up
        if (!ref($tree) || $tree->is_preterminal) {
            return $preterminal_lookup;
        } else {
            for ($tree->children) {
                $preterminal_lookup = $t->find_head_preterminals($_, $preterminal_lookup);
            }
        }

        # Find immediate head of this node
        my $rules = $t->rules->{$tree->data->head};
        my $head;
        for my $r (@$rules) {
            $head = $r->($tree);
            last if $head;
        }

        if ($head) {
            # Descend through table to find preterminal head of
            # this node
            while ($preterminal_lookup->{$head}) {
                $head = $preterminal_lookup->{$head};
            }
            $preterminal_lookup->{$tree} = $head;
        }

        return $preterminal_lookup;
    }

    sub apply_fftags_to_head_preterminals {
        my $t = shift;
        my $tree = shift;
        my $preterminal_lookup = shift;

        if (!ref($tree) || $tree->is_preterminal) {
            return $tree;
        }

        # Push fftags down tree
        my @tags = $tree->data->tags;
        if (@tags) {
            my $head = $preterminal_lookup->{$tree};
            $head->data->tags(@tags)
                if $head;
        }
        for ($tree->children) {
            $t->apply_fftags_to_head_preterminals($_, $preterminal_lookup);
        }
        return $tree;
    }

    sub transform {
        my $t = shift;
        my $tree = shift;
        my $preterminals = $t->find_head_preterminals($tree);
        return $t->apply_fftags_to_head_preterminals($tree, $preterminals);
    }

    __PACKAGE__->meta->make_immutable;

}

1;

__END__
