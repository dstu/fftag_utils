{
    package TreebankUtil;

=head1 NAME

TreebankUtil - Utilities for manipulating Penn Treebank-style data

=head1 VERSION

Version 0.01

=cut

    our $VERSION = '0.01';

=head1 SYNOPSIS

    use TreebankUtil qw/nonterminals/;

    my @labels = nonterminals;
    print "Default nonterminals: " . join(' ', @labels) . "\n";

=head1 EXPORT

nonterminals, nonterminal_regex, fftags, is_fftag, fftag_regex,
fftag_groups, fftag_group, fftag_group_members, fftag_count,
propbank_labels, is_propbank_label, propbank_label_regex,
propbank_label_groups, propbank_label_group
propbank_label_group_members, propbank_label_count,
tag_or_label_count

=head1 FUNCTIONS

=cut

    use Exporter qw/import/;

    our @EXPORT_OK = qw(nonterminals nonterminal_regex
                        fftags is_fftag fftag_regex
                        fftag_groups fftag_group fftag_group_members
                        fftag_count
                        propbank_labels is_propbank_label propbank_label_regex
                        propbank_label_groups propbank_label_group propbank_label_group_members
                        propbank_label_count
                        tag_or_label_count);

    # FIXME: TAGS, TOP, ROOT, and XXX may not be valid Penn
    # Treebank nonterminals, but they're useful, so I stuck them
    # here.
    my @NONTERMINALS = qw( TAGS
                           XXX
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

=head2 nonterminals

Returns the list of nonterminal tags that the Penn treebank
uses, plus "XXX", "ROOT", "TOP", and "TAGS".

=cut
    sub nonterminals { return @NONTERMINALS; }

=head2 nonterminal_regex

Returns a regular expression that will match a nonterminal tag.

=cut
    sub nonterminal_regex { my $r = join('|', map { quotemeta } @NONTERMINALS); return qr/$r/; }

    my @PROPBANK_LABELS = qw( A0
                              A1
                              A2
                              A3
                              A4
                              A5
                              AA
                              AM:TMP
                              AM:MOD
                              AM:ADV
                              AM:MNR
                              AM:NEG
                              AM:LOC
                              AM:DIS
                              AM:CAU
                              AM:EXT
                              AM:PNC
                              AM:DIR
                              AM:PRD
                              R:A0
                              R:A1
                              R:A2
                              R:A3
                              R:A4
                              R:A5
                              R:AA
                              R:AM:TMP
                              R:AM:MOD
                              R:AM:ADV
                              R:AM:MNR
                              R:AM:NEG
                              R:AM:LOC
                              R:AM:DIS
                              R:AM:CAU
                              R:AM:EXT
                              R:AM:PNC
                              R:AM:DIR
                              C:A0
                              C:A1
                              C:A2
                              C:A3
                              C:A4
                              C:A5
                              C:AA
                              C:AM:TMP
                              C:AM:MOD
                              C:AM:ADV
                              C:AM:MNR
                              C:AM:NEG
                              C:AM:LOC
                              C:AM:DIS
                              C:AM:CAU
                              C:AM:EXT
                              C:AM:PNC
                              C:AM:DIR );

    my @PROPBANK_GROUPS = qw ( PREDICATE
                               ADJUNCTIVE
                               CAUSATIVE
                               VERB
                               REFERENCE
                               CONTINUATION );

    my %PROPBANK_GROUP = ( 'A0' => "PREDICATE",
                           'A1' => "PREDICATE",
                           'A2' => "PREDICATE",
                           'A3' => "PREDICATE",
                           'A4' => "PREDICATE",
                           'A5' => "PREDICATE",
                           'AA' => "CAUSATIVE",
                           'AM-TMP' => "ADJUNCTIVE",
                           'AM-MOD' => "ADJUNCTIVE",
                           'AM-ADV' => "ADJUNCTIVE",
                           'AM-MNR' => "ADJUNCTIVE",
                           'AM-NEG' => "ADJUNCTIVE",
                           'AM-LOC' => "ADJUNCTIVE",
                           'AM-DIS' => "ADJUNCTIVE",
                           'AM-CAU' => "ADJUNCTIVE",
                           'AM-EXT' => "ADJUNCTIVE",
                           'AM-PNC' => "ADJUNCTIVE",
                           'AM-DIR' => "ADJUNCTIVE",
                           'R-A0' => "REFERENCE",
                           'R-A1' => "REFERENCE",
                           'R-A2' => "REFERENCE",
                           'R-A3' => "REFERENCE",
                           'R-A4' => "REFERENCE",
                           'R-A5' => "REFERENCE",
                           'R-AA' => "REFERENCE",
                           'R-AM-TMP' => "REFERENCE",
                           'R-AM-MOD' => "REFERENCE",
                           'R-AM-ADV' => "REFERENCE",
                           'R-AM-MNR' => "REFERENCE",
                           'R-AM-NEG' => "REFERENCE",
                           'R-AM-LOC' => "REFERENCE",
                           'R-AM-DIS' => "REFERENCE",
                           'R-AM-CAU' => "REFERENCE",
                           'R-AM-EXT' => "REFERENCE",
                           'R-AM-PNC' => "REFERENCE",
                           'R-AM-DIR' => "REFERENCE",
                           'C-A0' => "CONTINUATION",
                           'C-A1' => "CONTINUATION",
                           'C-A2' => "CONTINUATION",
                           'C-A3' => "CONTINUATION",
                           'C-A4' => "CONTINUATION",
                           'C-A5' => "CONTINUATION",
                           'C-AA' => "CONTINUATION",
                           'C-AM-TMP' => "CONTINUATION",
                           'C-AM-MOD' => "CONTINUATION",
                           'C-AM-ADV' => "CONTINUATION",
                           'C-AM-MNR' => "CONTINUATION",
                           'C-AM-NEG' => "CONTINUATION",
                           'C-AM-LOC' => "CONTINUATION",
                           'C-AM-DIS' => "CONTINUATION",
                           'C-AM-CAU' => "CONTINUATION",
                           'C-AM-EXT' => "CONTINUATION",
                           'C-AM-PNC' => "CONTINUATION",
                           'C-AM-DIR' => "CONTINUATION", );

    # Numbers still to be gathered.
    my %PROPBANK_COUNTS;

=head2 propbank_labels

Returns the list of propbank role labels.

=cut
    sub propbank_labels { return @PROPBANK_LABELS; }

=head2 is_propbank_label

Returns true iff its argument is a propbank
label. Case-sensitive.

=cut
    sub is_propbank_label {
        for (propbank_labels) {
            if ($_ eq $_[0]) {
                return 1;
            }
        }
        return;
    }

=head2 propbank_label_regex

Returns a regular expression that matches a propbank label

=cut
    sub propbank_label_regex { my $r = join('|', map { quotemeta } @PROPBANK_LABELS); return qr/$r/; }

=head2 propbank_label_groups

Returns the propbank label groups.

=cut
    sub propbank_label_groups { return @PROPBANK_GROUPS; }

=head2 propbank_group

Returns the propbank label group of its argument.

=cut
    sub propbank_label_group { return $PROPBANK_GROUP{$_[0]}; }

=head2 propbank_label_group_members

Returns the members of the given propbank label group.

=cut
    sub propbank_label_group_members { return grep { $_[0] eq $PROPBANK_GROUP{$_} } propbank_labels; }

=head2 propbank_label_count

Returns the count of the given propbank label, taken from WSJ sections 2-21.

=cut
    sub propbank_label_count { return $PROPBANK_COUNTS{$_[0]}; }

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

    # Numbers taken from WSJ sections 02-22
    my %TAG_COUNTS =
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

=head2 fftags

Returns the list of form-function tags used in the Penn treebank.

=cut
    sub fftags { return @FFTAGS; }

=head2 is_fftag

Returns true iff argument is an fftag. Case-sensitive.

=cut
    sub is_fftag {
        for (fftags) {
            if ($_ eq $_[0]) {
                return 1;
            }
        }
        return undef;
    }

=head2 fftag_regex

Returns a regular expression that matches a nonterminal tag.

=cut
    sub fftag_regex { my $r = join('|', map { quotemeta } @FFTAGS); return qr/$r/; }

=head2 fftag_groups

Returns the function tag groups.

=cut
    sub fftag_groups { return @FFTAG_GROUPS; }

=head2 fftag_group

Returns the function tag group of its argument.

=cut
    sub fftag_group { return $FFTAG_GROUP{$_[0]}; }

=head2 fftag_group_members

Returns the members of the tag group.

=cut
    sub fftag_group_members { return grep { $_[0] eq $FFTAG_GROUP{$_} } fftags; }

=head2 tag_count

Returns the number of times that the given fftag or semantic
role label appears in WSJ sections 2-21.

=cut
    sub fftag_count { return $TAG_COUNTS{$_[0]}; }

=head2 tag_or_label_count

Returns the count of its argument, which may be either an fftag
or a propbank label.

=cut
    sub tag_or_label_count {
        if ($use_propbank) {
            return propbank_label_count($_[0]);
        } else {
            return fftag_count($_[0]);
        }
    }

}

=head1 AUTHOR

Stu Black, C<< <trurl at freeshell.org> >>

=head1 BUGS

E-mail me. If it's after 2010, there is a very high chance I'm
not using or maintaining this anymore.

=head1 SUPPORT

Ask around your friendly CS department.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Stu Black.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;

__END__
