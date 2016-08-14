#####################################################################
## AUTHOR: Mary Ehlers, regina.verbae@gmail.com
## ABSTRACT: 
#####################################################################

package Piper::Role::Instance;

use v5.22;
use warnings;

use List::AllUtils qw(part);
use Piper::Path;
use Piper::Queue;
use Types::Standard qw(ConsumerOf InstanceOf);

use Moo::Role;

with qw(Piper::Role::Queue);

requires 'pending';

requires 'process_batch';

# Metric for "how full" the pending queue is
requires 'pressure';

has parent => (
    is => 'rwp',
    isa => ConsumerOf['Piper::Role::Instance'],
    # Setting a parent will introduce a self-reference
    weak_ref => 1,
    required => 0,
    predicate => 1,
);

sub is_enabled {
    my ($self) = @_;

    return 0 if !$self->enabled;
    # Check all the parents...
    my $par = $self;
    while ($par->has_parent) {
        $par = $par->parent;
        return 0 if !$par->enabled;
    }
    return 1;
}

has path => (
    is => 'lazy',
    isa => InstanceOf['Piper::Path'],
);

sub _build_path {
    my ($self) = @_;

    return $self->has_parent
        ? $self->parent->path->child($self->label)
        : Piper::Path->new($self->label);
}

sub get_batch_size {
    my ($self) = @_;
    my $size = $self->has_batch_size
        ? $self->batch_size
        : $self->has_parent
            ? $self->parent->get_batch_size
            : 50;
    return $size;
}

sub is_exhausted {
    my ($self) = @_;
    return !$self->isnt_exhausted;
}

sub isnt_exhausted {
    my ($self) = @_;
    
    # Try to get something ready
    while(!$self->ready and $self->pending) {
        $self->process_batch;
    }

    return $self->ready ? 1 : 0;
}

has drain => (
    is => 'lazy',
    isa => InstanceOf['Piper::Queue'],
    builder => sub { Piper::Queue->new() },
    handles => [qw(dequeue ready)],
);

sub find_segment {
    my ($self, $location) = @_;
    
    $location = Piper::Path->new($location);
    my $parent = $self->can('descendant') ? $self : $self->parent;
    my $segment = $parent->descendant($location);
    while (!defined $segment and $parent->has_parent) {
        $parent = $parent->parent;
        $segment = $parent->descendant($location);
    }

    return $segment;
}

around enqueue => sub {
    my ($orig, $self, @args) = @_;

    if (!$self->is_enabled) {
        # Bypass - go straight to drain
        $self->INFO("Skipping disabled process", @args);
        $self->drain->enqueue(@args);
        return;
    }

    my @items;
    if ($self->has_filter) {
        my ($skip, $queue) = part {
            $self->filter->($_)
        } @args;

        @items = @$queue if defined $queue;

        if (defined $skip) {
            $self->INFO("Filtered items to next handler", @$skip);
            $self->drain->enqueue(@$skip);
        }
    }
    else {
        @items = @args;
    }

    return unless @items;

    $self->INFO("Queueing items", @items);
    $self->$orig(@items);
};

# Cute little trick to auto-insert the instance object
# as first argument, since $self will become the logger
# object and lose access to paths/labels/etc.
around [qw(INFO DEBUG WARN ERROR)] => sub {
    my ($orig, $self) = splice @_, 0, 2;
    if (ref $_[0]) {
        $self->$orig(@_);
    }
    else {
        $self->$orig($self, @_);
    }
};

1;
