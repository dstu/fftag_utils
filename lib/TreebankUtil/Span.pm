package TreebankUtil::Span;
use Moose;
use TreebankUtil::Node qw/spans/;
use Carp;

has 'line' => (is => 'ro', isa => 'Int', required => 1);
has 'start' => (is => 'ro', isa => 'Int', required => 1);
has 'end' => (is => 'ro', isa => 'Int', required => 1);
has 'label' => (is => 'ro', isa => 'Str', required => 1);
has 'tags' => (is => 'ro', isa => 'ArrayRef', required => 1);

=head2 intersect_notags

Intersects two arrayrefs of spans, without regarding their
tags. Returns the triple of (resulting arrayref, arrayref of
things which only appeared in first set, arrayref of things
which only appeared in second set).

=cut
sub intersect_notags {
    my $c = shift;
    my $s1 = shift;
    my $s2 = shift;
    my %set1 = map { $_->stringify_notags => $_ } @$s1;
    my %set2 = map { $_->stringify_notags => $_ } @$s2;
    my %paired_set1;
    my %paired_set2;
    while (my ($k, $v) = each %set1) {
        $paired_set1{$k} = [$v, $set2{$k}];
    }
    while (my ($k, $v) = each %set2) {
        $paired_set2{$k} = [$set1{$k}, $v];
    }
    return do_intersection(\%paired_set1, \%paired_set2);
}

sub do_intersection {
    my %set1 = %{shift()};
    my %set2 = %{shift()};
    my @matching;
    my @only_s1;
    my @only_s2;
    for (keys(%set2)) {
        if ($set1{$_}) {
            push @matching, $set1{$_};
        } else {
            push @only_s2, $set2{$_};
        }
    }
    for (keys(%set1)) {
        next
            if $set2{$_};
        push @only_s1, $set1{$_};
    }
    return (\@matching, \@only_s1, \@only_s2);
}

=head intersect

Intersects two arrayrefs of spans, regarding their tags. A span
with more than one tag is duplicated as many times as it has
tags. Returns the triple of (resulting arrayref, arrayref of
things which only appeared in first set, arrayref of things
which only appeared in second set).

=cut
sub intersect {
    my $c = shift;
    my $s1 = shift;
    my @s1_exploded;
    for (@$s1) {
        if (scalar(@{$_->tags}) > 0) {
            for my $t (@{$_->tags}) {
                push @s1_exploded, TreebankUtil::Span->new( line => $_->line,
                                                            start => $_->start,
                                                            end => $_->end,
                                                            label => $_->label,
                                                            tags => [$t] );
            }
        } else {
            push @s1_exploded, $_;
        }
    }
    my $s2 = shift;
    my @s2_exploded;
    for (@$s2) {
        if (scalar(@{$_->tags}) > 0) {
            for my $t (@{$_->tags}) {
                push @s2_exploded, TreebankUtil::Span->new( line => $_->line,
                                                            start => $_->start,
                                                            end => $_->end,
                                                            label => $_->label,
                                                            tags => [$t] );
            }
        } else {
            push @s2_exploded, $_;
        }
    }
    my %set1 = map { $_->stringify => $_ } @s1_exploded;
    my %set2 = map { $_->stringify => $_ } @s2_exploded;

    return do_intersection(\%set1, \%set2);
}

=head2 stringify_notags

C<$t->stringify_notags>

Returns a string representation of C<$t> uniquely characterizing
it, excluding its tags.

=cut
sub stringify_notags {
    my $t = shift;
    return sprintf('%d: (%s %d %d)',
                   $t->line,
                   $t->label,
                   $t->start,
                   $t->end);
}

=head2 stringify

C<$t->stringify>

Returns a string representation of C<$t> uniquely characterizing
it.

=cut
sub stringify {
    my $t = shift;
    my $tags = join('-', @{$t->tags});
    if ($tags) {
        return $t->stringify_notags . ' ' . $tags;
    } else {
        return $t->stringify_notags;
    }
}

=head2 from_string

C<TreebankUtil::Span->from_string($str)>

Returns a new instance of a span from C<$str>, which should be
of the same format as that given by L<#stringify>.

If more than one C<$str> is given, then a list of strings is
returned if called in array context. (If not, only the first
span is returned.)

Errors are reported with L<Carp>.

=cut
sub from_string {
    my $c = shift;
    my $recognizer = qr{
                            ^
                            (\d+):      # 1. line
                            \s+\(
                            (\S+)       # 2. label
                            \s+
                            (\d+)       # 3. start
                            \s+
                            (\d+)\)     # 4. end
                            (?:\s+
                                (\S+))? # 5. optional tags, separated by -
                            $
                    }x;
    my @spans;
    for my $string (@_) {
        if ($string =~ m{$recognizer}) {
            my @tags;
            @tags = split(/-/, $5)
                if $5;
            push @spans, TreebankUtil::Span->new(line => $1,
                                                 label => $2,
                                                 start => $3,
                                                 end => $4,
                                                 tags => \@tags);
        } else {
            croak("couldn't read span from string $string");
        }
    }

    if (wantarray) {
        return @spans;
    } else {
        return $spans[0];
    }
}

=head2 equal_notags

C<$t->equal_notags($a)>

Returns undef if C<$a> doesn't match C<$t>, not considering
their tags.

=cut
sub equal_notags {
    my $t = shift;
    my $o = shift;
    return
        $t->line == $o->line
            && $t->start == $o->start
                && $t->end == $o->end
                    && $t->label eq $o->label;
}

=head2 missing_tags_in

C<$t->missing_tags_in($o)>

Returns an arrayref of tags in $o that aren't in $t.

=cut
sub missing_tags_in {
    my $t = shift;
    my $o = shift;
    my %tt = map { $_ => 1 } @{$t->tags};
    my @missing;
    for (@{$o->tags}) {
        push @missing, $_
            unless $tt{$_};
    }
    return \@missing;
}

=head2 extra_tags_in

C<$t->extra_tags_in($o)>

Returns an arrayref of tags in $t that aren't in $o.

=cut
sub extra_tags_in {
    my $t = shift;
    my $o = shift;
    return $o->missing_tags($t);
}

=head2 matching_tags

C<$t->matching_tags($o)>

Returns an arrayref of the tags in C<$t> and C<$o> that match.

=cut
sub matching_tags {
    my $t = shift;
    my $o = shift;
    my %s = map { $_ => 1 } @{$t->tags};
    my @m;
    for (@{$o->tags}) {
        push @m, $_
            if $s{$_};
    }
    return \@m;
}

=head2 read_trees_file

C<TreebankUtil::read_trees_file($filename, $reader)>

Reads from C<$filename> using the node reader C<$reader> all the
spans in the file.

Returns an arrayref the spans so read.

=cut
sub read_trees_file {
    my $c = shift;
    my $filename = shift;
    my $reader = shift;
    my $in_fh;
    open $in_fh, '<', $filename,
        or die "Can't open $filename: $!";
    my $line_num = 0;
    my @spans;
    while (<$in_fh>) {
        chomp;
        $line_num++;
        my @line_spans = spans({ Line => $_,
                                 NodeReader => $reader, });
        for my $s (@line_spans) {
            push @spans, TreebankUtil::Span->new( line => $line_num,
                                                  start => $s->[1],
                                                  end => $s->[2],
                                                  label => $s->[0]->head,
                                                  tags => [$s->[0]->tags] );
        }
    }
    close $in_fh
        or die "Can't close $filename: $!";
    return \@spans;
}

1;
