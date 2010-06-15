package TreebankUtil::TagResults;
use Moose;
use TreebankUtil::CounterTable;

has 'gold_spans' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'test_spans' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'valid_tags' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'groups'     => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'mismatched_gold_spans' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'mismatched_test_spans' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'matched_spans' => (is => 'rw', isa => 'ArrayRef');
has 'false_negatives' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'false_positives' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'true_positives' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'true_negatives' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'recall' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'precision' => (is => 'rw', isa => 'TreebankUtil::CounterTable');
has 'f_measure' => (is => 'rw', isa => 'TreebankUtil::CounterTable');

sub BUILD {
    my $t = shift;
    my ($match, $only_gold, $only_test)
        = TreebankUtil::Span->intersect_notags($t->gold_spans,
                                               $t->test_spans);
    $t->matched_spans($match);
    $t->mismatched_gold_spans($only_gold);
    $t->mismatched_test_spans($only_test);
    my $valid_tags = [@{$t->valid_tags}, keys(%{$t->groups})];

    ($match, $only_gold, $only_test)
        = TreebankUtil::Span->intersect([map { $_->[0] } @$match],
                                        [map { $_->[1] } @$match]);
    my $fn = TreebankUtil::CounterTable->new(keys => $valid_tags);
    my $fp = TreebankUtil::CounterTable->new(keys => $valid_tags);
    my $tp = TreebankUtil::CounterTable->new(keys => $valid_tags);
    my $total = TreebankUtil::CounterTable->new(keys => $valid_tags);
    # use Data::Dumper;
    # print "only_gold:\n", Dumper($only_gold);
    for (@$only_gold) {
        for my $t (@{$_->tags}) {
            $fn->increment($t);
        }
    }
    # print "only_test:\n", Dumper($only_test);
    for (@$only_test) {
        for my $t (@{$_->tags}) {
            $fp->increment($t);
        }
    }
    # print "match:\n", Dumper($match);
    for (@$match) {
        for my $t (@{$_->tags}) {
            $tp->increment($t);
        }
    }
    for (@{$t->gold_spans}) {
        for my $t (@{$_->tags}) {
            $total->increment($t);
        }
    }

    while (my ($group, $members) = each(%{$t->groups})) {
        for (@$members) {
            $fn->increment($group, $fn->count($_));
            $fp->increment($group, $fp->count($_));
            $tp->increment($group, $tp->count($_));
            $total->increment($group, $total->count($_));
        }
    }

    my $rec = TreebankUtil::CounterTable->new(keys => $valid_tags);
    my $prec = TreebankUtil::CounterTable->new(keys => $valid_tags);
    my $f1 = TreebankUtil::CounterTable->new(keys => $valid_tags);

    for (@{$valid_tags}) {
        my $p = 0;
        if ($tp->count($_) + $fp->count($_) != 0) {
            $p = ($tp->count($_) / ($tp->count($_) + $fp->count($_)));
        }
        $prec->count($_, $p);

        my $r = 0;
        if ($tp->count($_) + $fn->count($_) != 0) {
            $r = ($tp->count($_) / ($tp->count($_) + $fn->count($_)));
        }
        $rec->count($_, $r);

        $f1->count($_, 2 * ($p * $r) / ($p + $r))
            if ($p + $r) != 0;
    }

    $t->false_negatives($fn);
    $t->false_positives($fp);
    $t->true_positives($tp);
    $t->recall($rec);
    $t->precision($prec);
    $t->f_measure($f1);

    return $t;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
