#!/usr/bin/env perl
#####################################################################
## AUTHOR: Mary Ehlers, regina.verbae@gmail.com
## ABSTRACT: Test the Piper::Instance module with pipes
#####################################################################

use v5.10;
use strict;
use warnings;

use Test::Most;

my $APP = "Piper::Instance";

use Piper;

#####################################################################

# Test descendant/find_segment
{
    my $MAIN = Piper->new(
        child_pipe => Piper->new(
            grand_pipe => Piper->new(
                great_proc => sub {},
            ),
            grand_proc => sub {},
        ),
        child_proc => sub {},
        { label => 'main' },
    )->init;

    my ($CHILD_PIPE, $CHILD_PROC) = @{$MAIN->children};
    my ($GRAND_PIPE, $GRAND_PROC) = @{$CHILD_PIPE->children};
    my $GREAT_PROC = $GRAND_PIPE->children->[0];

    my $A = Piper->new(
        B => Piper->new(
            A => Piper->new(
                B => sub {},
            ),
            B => sub {},
        ),
        C => sub {},
        { label => 'A' },
    )->init;

    my ($AB, $AC) = @{$A->children};
    my ($ABA, $ABB) = @{$AB->children};
    my $ABAB = $ABA->children->[0];

    subtest "$APP - descendant" => sub {
        my $ALL = [ $MAIN, $CHILD_PIPE, $GRAND_PIPE ];
        my %EXP = (
            'main' => [
                { search => [ 'main' ], from => [ $MAIN ],
                    undef => [ $CHILD_PIPE, $GRAND_PIPE ] },
            ],
            'main/child_pipe' => [
                { search => [ 'child_pipe' ], from => [ $MAIN, $CHILD_PIPE ],
                    undef => [ $GRAND_PIPE ] },
                { search => [ 'main/child_pipe' ], from => [ $MAIN ],
                    undef => [ $CHILD_PIPE, $GRAND_PIPE ] },
            ],
            'main/child_proc' => [
                { search => [ 'child_proc', 'main/child_proc' ], from => [ $MAIN ],
                    undef => [ $CHILD_PIPE, $GRAND_PIPE ] },
            ],
            'main/child_pipe/grand_pipe' => [
                { search => [ 'grand_pipe' ], from => $ALL, undef => [] },
                { search => [ 'child_pipe/grand_pipe' ], from => [ $MAIN, $CHILD_PIPE ],
                    undef => [ $GRAND_PIPE ] },
            ],
            'main/child_pipe/grand_proc' => [
                { search => [ 'grand_proc', 'child_pipe/grand_proc' ],
                    from => [ $MAIN, $CHILD_PIPE ], undef => [ $GRAND_PIPE ] },
                { search => [ 'main/child_pipe/grand_proc' ], from => [ $MAIN ],
                    undef => [ $CHILD_PIPE, $GRAND_PIPE ] },
            ],
            'main/child_pipe/grand_pipe/great_proc' => [
                { search => [ 'great_proc' ], from => $ALL, undef => [] },
                { search => [ 'grand_pipe/great_proc' ], from => $ALL, undef => [] },
                { search => [ 'child_pipe/grand_pipe/great_proc' ],
                    from => [ $MAIN, $CHILD_PIPE ], undef => [ $GRAND_PIPE ] },
                { search => [ 'main/child_pipe/grand_pipe/great_proc' ],
                    from => [ $MAIN ], undef => [ $CHILD_PIPE, $GRAND_PIPE ] },
            ],
        );

        for my $exp (keys %EXP) {
            for my $set (@{$EXP{$exp}}) {
                for my $loc (@{$set->{search}}) {
                    for my $FROM (@{$set->{from}}) {
                        is(
                            $FROM->descendant($loc),
                            $exp,
                            "Found $loc ($exp) descended from ".$FROM->label
                        );
                    }

                    for my $UNDEF (@{$set->{undef}}) {
                        is(
                            $UNDEF->descendant($loc),
                            undef,
                            "Could not find $loc ($exp) descended from ".$UNDEF->label
                        );
                    }
                }
            }
        }

        is($A->descendant('A'), 'A/B/A', 'search grandchildren before self');
        is($A->descendant('A/B'), 'A/B/A/B', 'search deeply before self');
        is($AB->descendant('B'), 'A/B/B', 'search children before self');

        # This wouldn't happen in find_segment, but it tests the referrer logic
        is($A->descendant('A/B', $AB), 'A/B', 'referrer blocks appropriate search');

        is($AB->descendant('B/B'), 'A/B/B', 'find double-name');

        my %UNDEF = (
            bad_name => [ $MAIN, $CHILD_PIPE, $GRAND_PIPE ],
            main => [ $CHILD_PIPE, $GRAND_PIPE ],
            'main/bad_name' => [ $MAIN, $CHILD_PIPE, $GRAND_PIPE ],
            'bad_name/main/child_pipe' => [ $MAIN, $CHILD_PIPE ],
        );

        for my $undef (keys %UNDEF) {
            for my $FROM (@{$UNDEF{$undef}}) {
                is($FROM->descendant($undef), undef, "$undef not found from ".$FROM->label);
            }
        }
    };

    subtest "$APP - find_segment" => sub {
        my $ALL = [ $MAIN, $CHILD_PIPE, $CHILD_PROC, $GRAND_PIPE, $GRAND_PROC, $GREAT_PROC ];
        my @EXP = qw(
            main
            main/child_pipe
            main/child_proc
            main/child_pipe/grand_pipe
            main/child_pipe/grand_proc
            main/child_pipe/grand_pipe/great_proc
        );

        for my $exp (@EXP) {
            for my $FROM (@$ALL) {
                my @parts = split('/', $exp);
                while (@parts) {
                    my $loc = join('/', @parts);
                    is($FROM->find_segment($loc), $exp, "Found '$loc' from ".$FROM->label);
                    shift @parts;
                }
            }
        }

        $ALL = [ $A, $AB, $AC, $ABA, $ABB, $ABAB ];
        my %EXP = (
            A => [
                { search => [ 'A' ], from => [], fail => $ALL }
            ],
            'A/B' => [
                { search => [ 'B' ], from => [ $A, $AC ], fail => [ $AB, $ABA, $ABB, $ABAB ] },
                { search => [ 'A/B' ], from => [], fail => $ALL },
            ],
            'A/C' => [
                { search => [ 'C', 'A/C' ], from => $ALL, fail => [] },
            ],
            'A/B/A' => [
                { search => [ 'A', 'B/A', 'A/B/A' ], from => $ALL, fail => [] },
            ],
            'A/B/B' => [
                { search => [ 'B' ], from => [ $AB, $ABB ], fail => [ $A, $AC, $ABA, $ABAB ] },
                { search => [ 'B/B', 'A/B/B' ], from => $ALL, fail => [] }, 
            ],
            'A/B/A/B' => [
                { search => [ 'B' ], from => [ $ABA, $ABAB ], fail => [ $A, $AB, $AC, $ABB ] },
                { search => [ 'A/B', 'B/A/B', 'A/B/A/B' ], from => $ALL, fail => [] },
            ],
        );

        for my $exp (keys %EXP) {
            for my $set (@{$EXP{$exp}}) {
                for my $loc (@{$set->{search}}) {
                    for my $FROM (@{$set->{from}}) {
                        is(
                            $FROM->find_segment($loc),
                            $exp,
                            "Found '$loc' ($exp) from ".$FROM->path
                        );
                    }

                    for my $FAIL (@{$set->{fail}}) {
                        isnt(
                            $FAIL->find_segment($loc),
                            $exp,
                            "Did not find '$loc' ($exp) from ".$FAIL->path
                        );
                    }
                }
            }
        }
    };
}

#####################################################################

# Test small case first
{
    subtest "$APP - one child only" => sub {
        my $SMALL = Piper->new(
            half => {
                batch_size => 2,
                filter => sub { $_ % 2 == 0 },
                handler => sub {
                    my ($instance, $batch) = @_;
                    return (map { int( $_ / 2 ) } @$batch);
                },
            },
            {
                label => 'main',
                batch_size => 4,
            }
        )->init();

        my $CHILD = $SMALL->children->[0];

        # Test path
        subtest "$APP - path" => sub {
            is($SMALL->path, 'main', 'pipe ok');
            is($CHILD->path, 'main/half', 'child ok');
        };

        # Test parentage
        subtest "$APP - parentage" => sub {
            ok(!$SMALL->has_parent, 'no parent for pipe');
            ok($CHILD->has_parent, 'child has parent');
            is($CHILD->parent->path, 'main', 'parent is pipe');
        };

        # Test get_batch_size
        subtest "$APP - get_batch_size" => sub {
            is($SMALL->get_batch_size, 4, 'pipe ok');
            is($CHILD->get_batch_size, 2, 'child overrides pipe');
        };

        # Test queueing
        subtest "$APP - queueing" => sub {
            ok(!$SMALL->pending, 'not yet pending');
            ok(!$SMALL->ready, 'not yet ready');
            is($SMALL->pressure, 0, 'no pressure');

            my @data = (1..3);
            $SMALL->enqueue(map { $_ * 2 } @data);

            is($SMALL->pending, 3, 'pending items');
            ok(!$SMALL->ready, 'still no ready');
            is($SMALL->pressure, 150, 'positive pressure');
        };

        # Test process_batch
        subtest "$APP - process_batch" => sub {
            $SMALL->process_batch;

            is($SMALL->pending, 1, 'removed from pending queue');
            is($SMALL->ready, 2, 'items processed successfully');

            $SMALL->process_batch;

            is($SMALL->pending, 0, 'removed un-full batch from pending queue');
            is($SMALL->ready, 3, 'un-full batch processed successfully');
        };

        # Test dequeue
        subtest "$APP - dequeue" => sub {
            is_deeply(
                [ $SMALL->dequeue(2) ],
                [ 1..2 ],
                'dequeue multiple'
            );

            is($SMALL->dequeue, 3, 'dequeue single');

            is_deeply(
                [ $SMALL->dequeue(2) ],
                [],
                'dequeue empty'
            );
        };

        # Test exhaustion
        subtest "$APP - exhaustion" => sub {
            ok(!$SMALL->isnt_exhausted, 'empty - isnt_exhausted');
            ok($SMALL->is_exhausted, 'empty - is_exhausted');

            $SMALL->enqueue(2);

            ok($SMALL->isnt_exhausted, 'queued - isnt_exhausted');
            ok(!$SMALL->is_exhausted, 'queued - is_exhausted');

            while ($SMALL->isnt_exhausted) {
                $SMALL->dequeue;
            }

            ok(!$SMALL->isnt_exhausted, 'emptied - isnt_exhausted');
            ok($SMALL->is_exhausted, 'emptied - is_exhausted');
        };

        # Test filtering
        subtest "$APP - filtering" => sub {
            # Odd numbers filtered out
            $SMALL->enqueue(1..5);

            is($SMALL->pending, 2, 'filtered not in pending');
            is($SMALL->ready, 3, 'filtered items ready');
            is_deeply(
                [ $SMALL->dequeue(5) ],
                [ 1, 3, 5 ],
                'filter succeeded'
            );

            $SMALL->process_batch;
            is($SMALL->ready, 2, 'non-filtered items processed');
            is_deeply(
                [ $SMALL->dequeue(2) ],
                [ 1, 2 ],
                'non-filtered items processed correctly'
            );
        };

        # Test disabling
        subtest "$APP - disabling" => sub {
            $SMALL->enabled(0);
            is($SMALL->is_enabled, 0, 'disabled pipe');
            is($CHILD->is_enabled, 0, 'child inherits disable from parent');

            $SMALL->enqueue(1..3);
            is($SMALL->pending, 0, 'nothing pending in disabled pipe');
            is($SMALL->ready, 3, 'items skipped disabled pipe');

            is_deeply(
                [ $SMALL->dequeue(3) ],
                [ 1..3 ],
                'skipped items dequeued unchanged'
            );

            $SMALL->enabled(1);
            $CHILD->enabled(0);
            is($SMALL->is_enabled, 1, 'parent does not inherit disable from child');
            is($CHILD->is_enabled, 0, 'child disabled');

            $SMALL->enqueue(1..3);
            is($SMALL->pending, 0, 'nothing pending in pipe with 1 non-enabled child');
            is($SMALL->ready, 3, 'items skipped 1 non-enabled child');

            is_deeply(
                [ $SMALL->dequeue(3) ],
                [ 1..3 ],
                'skipped items dequeued unchanged'
            );

            $CHILD->enabled(1);
        };

        # Test emit
        subtest "$APP - emit" => sub {
            $CHILD->emit(4..6);
            is_deeply(
                [ $SMALL->dequeue(3) ],
                [ 4..6 ],
                'fake emit - ok'
            );

            my $EMITTER = Piper->new(
                double => sub {
                    my ($instance, $batch) = @_;
                    $instance->emit(map { $_ * 2 } @$batch);
                    return;
                },
                {
                    batch_size => 2,
                }
            )->init();

            $EMITTER->enqueue(1..3);
            $EMITTER->process_batch;

            is_deeply(
                [ $EMITTER->dequeue(2) ],
                [ 2, 4 ],
                'full batch - emit ok'
            );

            $EMITTER->process_batch;
            is_deeply(
                [ $EMITTER->dequeue(2) ],
                [ 6 ],
                'partial batch - emit ok'
            );
        };

        # Test recycle
        subtest "$APP - recycle" => sub {
            $CHILD->recycle(2);
            is($SMALL->pending, 1, 'fake recycle - ok');
            $SMALL->process_batch;
            $SMALL->dequeue;

            my $RECYCLER = Piper->new(
                mod_power_2 => {
                    filter => sub { $_[0] % 2 == 0 },
                    handler => sub {
                        my ($instance, $batch) = @_;
                        my @things = map { int( $_ / 2 ) } @$batch;
                        for my $thing (@things) {
                            if ($thing > 0 and $thing % 2 == 0) {
                                $instance->recycle($thing);
                            }
                            else {
                                $instance->emit($thing);
                            }
                        }
                        return;
                    },
                },
                { batch_size => 3 },
            )->init();

            $RECYCLER->enqueue(2..4);
            $RECYCLER->process_batch;
            is($RECYCLER->pending, 1, 'recycle successful');
        };

        # Test eject
        subtest "$APP - eject" => sub {
            $CHILD->eject(2);
            is_deeply(
                [ $SMALL->dequeue ],
                [ 2 ],
                'ok'
            );
        };

        # Test inject
        subtest "$APP - inject" => sub {
            $CHILD->inject(2, 4, 6);
            is($SMALL->pending, 3, 'ok');
        };

        # Test injectAt
        subtest "$APP - injectAt" => sub {
            $SMALL->injectAt('half', 8, 10);
            is($CHILD->pending, 5, 'ok from pipe');
            $CHILD->injectAt('half', 12, 14);
            is($CHILD->pending, 7, 'ok from child');

            throws_ok {
                $SMALL->injectAt('bad', 1..4)
            } qr/Could not find bad to injectAt/, 'no inject with bad label';
        };

        # Test injectAfter
        subtest "$APP - injectAfter" => sub {
            $SMALL->injectAfter('half', 1..4);
            is($SMALL->ready, 4, 'ok from pipe');
            $CHILD->injectAfter('half', 5..8);
            is($SMALL->ready, 8, 'ok from child');

            throws_ok {
                $SMALL->injectAfter('bad', 1..4)
            } qr/Could not find bad to injectAfter/, 'no injectAfter with bad label';
        };
    };
}

#####################################################################

# Test args
{
    subtest "$APP - init args" => sub {
        my $argy = Piper->new(
            arg_check => {
                batch_size => 10,
                handler => sub {
                    my ($instance, $batch, @args) = @_;
                    if ($args[0] eq 'arg') {
                        $instance->emit(@$batch);
                    }
                    return;
                },
            },
        )->init('arg');

        is($argy->args->[0], 'arg', 'stored ok');

        $argy->enqueue(1..2);
        $argy->process_batch;
        is_deeply(
            [ $argy->dequeue(2) ],
            [ 1..2 ],
            'passthrough to handler ok'
        );
    };
}

#####################################################################

subtest "$APP - nested pipes" => sub {
    my $TEST = Piper->new(
        integer => Piper->new(
            add_three => sub {
                my ($instance, $batch, @args) = @_;
                my @return = map { $_ + 3 } @$batch;
                for my $item (@return) {
                    if ($item < 0) {
                        $instance->recycle($item);
                    }
                    else {
                        $instance->emit($item);
                    }
                }
                return;
            },
            make_even => {
                batch_size => 4,
                # Non-explicitly testing that pass-in still works with $_ closure
                filter => sub { $_[0] % 2 != 0 },
                handler => sub {
                    my ($instance, $batch, @args) = @_;
                    my @return = map { $_ - 1 } @$batch;
                    for my $item (@return) {
                        if ($item < 0) {
                            $instance->injectAt('add_three', $item);
                        }
                        else {
                            $instance->emit($item);
                        }
                    }
                    return;
                },
            },
            # Non-explicitly testing that filter $_ closure works
            { filter => sub { /^-?\d+$/ }, }
        ),
        {
            batch_size => 2,
            label => 'main',
        }
    )->init;

    my $CHILD = $TEST->children->[0];
    my $GRAND1 = $CHILD->children->[0];
    my $GRAND2 = $CHILD->children->[1];

    # Test path
    subtest "$APP - path" => sub {
        is($TEST->path, 'main', 'outside ok');
        is($CHILD->path, 'main/integer', 'first child ok');
        is($GRAND1->path,
            'main/integer/add_three', 'first grandchild ok'
        );
    };

    # Test parent predicate
    subtest "$APP - parent predicate" => sub {
        ok(!$TEST->has_parent, 'main no parent');
        ok($CHILD->has_parent, 'child has parent');
        ok($GRAND1->has_parent,
            'grandchild has parent'
        );

        is($CHILD->parent->path, 'main', "child's parent ok");
        is($GRAND1->parent->path,
            'main/integer', "grandchild's parent ok"
        );
    };

    # Test get_batch_size
    subtest "$APP - get_batch_size" => sub {
        is($TEST->get_batch_size, 2, 'main ok');
        is($CHILD->get_batch_size, 2, 'child inherited ok');
        is($GRAND2->get_batch_size,
            4, 'child override ok'
        );
    };

    # Test queueing
    subtest "$APP - queueing" => sub {
        ok(!$TEST->pending, 'not yet pending');
        ok(!$TEST->ready, 'not yet ready');
        is($TEST->pressure, 0, 'no pressure');

        $TEST->enqueue(1..5);

        is($TEST->pending, 5, 'pending items');
        ok(!$TEST->ready, 'still not ready');
        is($TEST->pressure, 250, 'positive pressure');
    };

    # Test process_batch
    subtest "$APP - process_batch" => sub {
        $TEST->process_batch;

        is($GRAND1->pending, 3, 'processed first grandchild batch');
        is($GRAND2->pending + $GRAND2->ready, 2, 'sent to next grandchild');
        
        $TEST->process_batch;
        is($GRAND1->pending, 1, 'processed first grandchild again');
        is($GRAND2->pending + $GRAND2->ready, 4, 'sent to next grandchild again');


        $TEST->process_batch;
        is($GRAND1->pending, 0, 'finished processing first grandchild');
        is($GRAND2->pending + $GRAND2->ready, 5, 'next grandchild waiting');


        $TEST->process_batch;
        is($GRAND2->pending, 0, 'processed next grandchild');
        is($TEST->ready, 5, 'all done processing');
    };

    # Test dequeue
    subtest "$APP - dequeue" => sub {
        is_deeply(
            [ $TEST->dequeue(4) ],
            [ 4, 6, 8, 4 ],
            'dequeue multiple'
        );

        is($TEST->dequeue, 6, 'dequeue single');

        is_deeply(
            [ $TEST->dequeue(2) ],
            [],
            'dequeue empty'
        );
    };

    # Test exhaustion
    subtest "$APP - exhaustion" => sub {
        ok(!$TEST->isnt_exhausted, 'empty - isnt_exhausted');
        ok($TEST->is_exhausted, 'empty - is_exhausted');

        $TEST->enqueue(1);

        ok($TEST->isnt_exhausted, 'queued - isnt_exhausted');
        ok(!$TEST->is_exhausted, 'queued - is_exhausted');

        while ($TEST->isnt_exhausted) {
            $TEST->dequeue;
        }
        
        ok(!$TEST->isnt_exhausted, 'emptied - isnt_exhausted');
        ok($TEST->is_exhausted, 'emptied - is_exhausted');
    };

    # Test filtering
    subtest "$APP - filtering" => sub {
        $TEST->enqueue(1..8);
        $TEST->process_batch;

        is($GRAND2->pending, 1, 'one item passed filter');
        is($GRAND2->ready, 1, 'one item skipped');

        $TEST->process_batch;
        $TEST->process_batch;
        $TEST->process_batch;

        is($GRAND2->pending, 4, 'expected items passed filter');
        is($GRAND2->ready, 4, 'expected items skipped');

        $TEST->process_batch;
        is_deeply(
            [ $TEST->dequeue(8) ],
            [ 4, 6, 8, 10, 4, 6, 8, 10 ],
            'expected output received - filter was successful'
        );
    };

    # Test disabling
    subtest "$APP - disabling" => sub {
        $TEST->enabled(0);
        ok(!$TEST->is_enabled, 'disabled pipe');
        ok(!$CHILD->is_enabled, 'child inherits disable from parent');
        ok(!$GRAND2->is_enabled, 'grandchild inherits disable from grandparent');

        $TEST->enqueue(1..3);
        ok(!$TEST->pending, 'nothing pending in disabled pipe');
        is($TEST->ready, 3, 'items skipped disabled pipe');

        is_deeply(
            [ $TEST->dequeue(3) ],
            [ 1..3 ],
            'skipped items dequeued unchanged'
        );

        $TEST->enabled(1);
        $CHILD->enabled(0);
        ok($TEST->is_enabled, 'parent does not inherit disable from child');
        ok(!$GRAND1->is_enabled, 'grandchild inherits disable from child');

        $TEST->enqueue(1..3);
        ok(!$TEST->pending, 'nothing pending in pipe with 1 non-enabled child');
        is_deeply(
            [ $TEST->dequeue(3) ],
            [ 1..3 ],
            'skipped items dequeued unchanged from pipe with 1 non-enabled child'
        );

        $CHILD->enabled(1);
        $GRAND2->enabled(0);
        ok($TEST->is_enabled, 'parent does not inherit disable from grandchild');
        ok($CHILD->is_enabled, 'child does not inherit disable from grandchild');
        ok($GRAND1->is_enabled, 'sibling does not inherit disable');

        $TEST->enqueue(1..2);
        ok($TEST->pending, 'pending with one enabled grandchild');
        $TEST->process_batch;
        is($TEST->ready, 2, 'items only went through one grandchild');
        is_deeply(
            [ $TEST->dequeue(2) ],
            [ 4..5 ],
            'items dequeued, only processed by first grandchild'
        );
    };
};

#####################################################################

done_testing();
