package TreebankUtil::CounterTable;
use Moose;
use Carp;

has 'keys' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'table' => (is => 'ro', isa => 'HashRef', default => sub { {} });

sub BUILD {
    my $t = shift;
    for (@{$t->keys}) {
        $t->table->{$_} = 0
            unless $t->table->{$_};
    }
}

=head2 increment

C<$t->increment($k, $v)>

Increments the count for C<$k> by C<$v>. If not specified, C<$v>
is taken to be 1.

=cut
sub increment {
    my $t = shift;
    my $k = shift;
    croak("Invalid key $k")
        unless exists($t->table->{$k});
    my $v = shift // 1;

    $t->table->{$k} += $v;
}

=head2 decrement

C<$t->decrement($k, $v)>

Decrements the count for C<$k> by C<$v>. If not given, C<$v> is
taken to be 1.

=cut
sub decrement {
    my $t = shift;
    my $k = shift;
    croak("Invalid key $k")
        unless exists($t->table->{$k});
    my $v = shift // 1;

    $t->table->{$k} -= $v;
}

=head2 count

C<$t->count($k, $v)>

If C<$v> is non-nil, sets the count for C<$k> to C<$v>. Returns
the new value (or the present value if no new value was set).

=cut
sub count {
    my $t = shift;
    my $k = shift;
    croak("Invalid key $k")
        unless exists($t->table->{$k});
    my $v = shift;
    if (defined($v)) {
        $t->table->{$k} = $v;
    }
    return $t->table->{$k};
}

1;
