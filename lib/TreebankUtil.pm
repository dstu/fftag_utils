{
    package TreebankUtil;
    # use TreebankUtil::Node;
    # use TreebankUtil::Tree;
    use Exporter qw/import/;

    our @EXPORT_OK = qw(nonterminals nonterminal_regex
                        fftags is_fftag fftag_regex
                        fftag_groups fftag_group fftag_group_members
                        role_labels);

    my @NONTERMINALS = qw( TAGS
                           TOP
                           ROOT
                           S
                           NNP
                           ,
                           ADJP
                           VP
                           .
                           SBAR
                           ADVP
                           ``
                           ''
                           WHNP
                           PRP$
                           PRP
                           QP
                           #
                           SINV
                           :
                           PRT
                           FRAG
                           INTJ
                           X
                           PRN
                           -LRB-
                           -RRB-
                           SBARQ
                           WHPP
                           WHADVP
                           SQ
                           $
                           UCP
                           NNPS
                           LST
                           WHADJP
                           RRC
                           PRT|ADVP
                           ADVP|PRT
                           NX
                           NAC
                           CONJP
                           CC
                           CD
                           DT
                           EX
                           FW
                           IN
                           JJ
                           JJR
                           JJS
                           LS
                           MD
                           NN
                           NNS
                           NP
                           NPS
                           PDT
                           POS
                           PP
                           PP$
                           RB
                           RBR
                           RBS
                           RP
                           SYM
                           TO
                           UH
                           VB
                           VBD
                           VBG
                           VBN
                           VBP
                           VBZ
                           WDT
                           WP
                           WP$
                           WRB );

=pod

=head3 nonterminals

Returns the list of nonterminal tags that the Penn treebank uses.

=cut
    sub nonterminals { return @NONTERMINALS; }

=pod

=head3 nonterminal_regex

Returns a regular expression that will match a nonterminal tag.

=cut
    sub nonterminal_regex { my $r = join('|', map { quotemeta } @NONTERMINALS); return qr/$r/; }

    my @ROLE_LABELS = qw( );

=pod

=head3 role_labels

Returns the list of semantic role labels.

=cut
    sub role_labels { return @ROLE_LABELS; }

    my @FFTAGS = qw( ADV
                     BNF
                     CLF
                     CLR
                     DIR
                     DTV
                     EXT
                     HLN
                     LGS
                     LOC
                     MNR
                     NOM
                     PRD
                     PRP
                     PUT
                     SBJ
                     TMP
                     TPC
                     TTL
                     VOC );

    my @FFTAG_GROUPS = qw( SYNTACTIC
                           SEMANTIC
                           TOPIC
                           MISC
                           RELATED );

    my %FFTAG_GROUP = ( DTV => "SYNTACTIC",
                        LGS => "SYNTACTIC",
                        PRD => "SYNTACTIC",
                        PUT => "SYNTACTIC",
                        SBJ => "SYNTACTIC",
                        VOC => "SYNTACTIC",
                        NOM => "SEMANTIC",
                        ADV => "SEMANTIC",
                        BNF => "SEMANTIC",
                        DIR => "SEMANTIC",
                        EXT => "SEMANTIC",
                        LOC => "SEMANTIC",
                        MNR => "SEMANTIC",
                        PRP => "SEMANTIC",
                        TMP => "SEMANTIC",
                        TPC => "TOPIC",
                        CLF => "MISC",
                        HLN => "MISC",
                        TTL => "MISC",
                        CLR => "RELATED", );

=pod

=head3 fftags

Returns the list of form-function tags used in the Penn treebank.

=cut
    sub fftags { return @FFTAGS; }

=pod

=head3 is_fftag

Returns true iff argument is an fftag. (Case-sensitive.)

=cut
    sub is_fftag {
        for (fftags) {
            if ($_ eq $_[0]) {
                return 1;
            }
        }
        return undef;
    }

=pod

=head3 fftag_regex

Returns a regular expression that matches a nonterminal tag.

=cut
    sub fftag_regex { my $r = join('|', map { quotemeta } @FFTAGS); return qr/$r/; }

=pod

=head3 fftag_groups

Returns the function tag groups.

=cut
    sub fftag_groups { return @FFTAG_GROUPS; }

=pod

=head3 fftag_group

Returns the function tag group of its argument.

=cut
    sub fftag_group { return $FFTAG_GROUP{$_[0]}; }

=pod

=head3 fftag_group_members

Returns the members of the tag group.

=cut
    sub fftag_group_members { return grep { $_[0] eq $FFTAG_GROUP{$_} } fftags; }

}

1;

__END_
