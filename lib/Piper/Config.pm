#####################################################################
## AUTHOR: Mary Ehlers, regina.verbae@gmail.com
## ABSTRACT: Component configuration object for Piper
#####################################################################

package Piper::Config;

use v5.22;
use warnings;

use Types::Standard qw(ClassName);

use Moo;
use namespace::clean;

has queue_class => (
    is => 'lazy',
    isa => sub {
        my $value = shift;
        eval "require $value";
        ClassName->assert_valid($value);
        unless ($value->does('Piper::Role::Queue')) {
            die "queue_class '$value' does not consume role 'Piper::Role::Queue'\n";
        }
        return 1;
    },
    default => 'Piper::Queue',
);

has logger_class => (
    is => 'lazy',
    isa => sub {
        my $value = shift;
        eval "require $value";
        ClassName->assert_valid($value);
        unless ($value->does('Piper::Role::Logger')) {
            die "logger_class '$value' does not consume role 'Piper::Role::Logger'\n";
        }
        return 1;
    },
    default => 'Piper::Logger',
);

1;