#####################################################################
## AUTHOR: Mary Ehlers, regina.verbae@gmail.com
## ABSTRACT: Simple FIFO queue
#####################################################################

package Piper::Queue;

use v5.16;
use warnings;

use Types::Standard qw(ArrayRef);

use Moo;

with 'Piper::Role::Queue';

has queue => (
    is => 'ro',
    isa => ArrayRef,
    default => sub { [] },
);

=head1 CONSTRUCTOR

=head2 new

=cut

=head1 METHODS

=head2 dequeue($num)

Remove and return $num items from the queue.  If
$num not provided, defaults to 1.

=cut

sub dequeue {
    my ($self, $num) = @_;
    splice @{$self->queue}, 0, $num // 1;
}

=head2 enqueue(@items)

Insert @items onto the queue.

=cut

sub enqueue {
    my $self = shift;
    push @{$self->queue}, @_;
}

=head2 ready

Returns the number of elements in the queue.

=cut

sub ready {
    my ($self) = @_;
    return scalar @{$self->queue};
}

1;
