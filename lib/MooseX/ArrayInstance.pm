#!/usr/bin/perl

package MooseX::ArrayInstance;
use Moose;

use Scalar::Util 'weaken', 'blessed';

use Algorithm::VTable;

use namespace::clean -except => 'meta';

extends qw(Moose::Meta::Instance);

our $GLOBAL_VTABLE = Algorithm::VTable->new( vtable_meta_symbol => "first", containers => [ ] );

around new => sub {
    my ( $next, $class, @args ) = @_;

    my $self = $class->$next(@args);
    
    #Carp::confess "constructed $self for " . $self->associated_metaclass->name if
    #$counts{$self->associated_metaclass->name}++;

    return $self;
};

sub DESTROY {
    my $self = shift;

    # class changed, recompute vtables

    if ( my $meta = $self->associated_metaclass ) { # global destruction
        #$counts{$meta->name};
        if ( $self->has_global_vtable ) {
            $GLOBAL_VTABLE = $GLOBAL_VTABLE->remove_classes( $meta->name );
        }
    }
}

has global_vtable => (
    isa => "Algorithm::VTable",
    is  => "ro",
    lazy_build => 1,
    predicate => "has_global_vtable",
    handles => [qw(symbol_name_index)],
);

sub _build_global_vtable {
    my $self = shift;

    my $class = $self->associated_metaclass->name;

    confess "can't have two meta instances for the same class ($class)"
        if exists $GLOBAL_VTABLE->containers_by_id->{$class};

    $GLOBAL_VTABLE = $GLOBAL_VTABLE->append_classes($class);
}

has vtable_container => (
    isa => "Algorithm::VTable::Container",
    is  => "ro",
    lazy_build => 1,
);

sub _build_vtable_container {
    my $self = shift;
    $self->global_vtable->containers_by_id->{ $self->associated_metaclass->name };
}

has slot_indexes => (
    isa => "HashRef[Int]",
    is  => "rw",
    lazy_build => 1,
);

sub _build_slot_indexes {
    my $self = shift;
    $self->global_vtable->container_slots($self->vtable_container);
}

has vtable => (
    isa => "ArrayRef[Maybe[Int]]",
    is  => "rw",
    lazy_build => 1,
);

sub _build_vtable {
    my $self = shift;

    my $var_spec = { sigil => '@', type => 'ARRAY', name => '__MOOSE_VTABLE' };

    my $vtable = $self->associated_metaclass->get_package_symbol($var_spec);

    @$vtable = @{ $self->global_vtable->container_table($self->vtable_container) };

    return $vtable;
}

sub create_instance {
    my $self = shift;
    $self->bless_instance_structure([ $self->vtable ]);
}

sub clone_instance {
    my ($self, $instance) = @_;
    $self->bless_instance_structure([ @$instance ]);
}


sub get_slot_index {
    my ( $self, $slot_name ) = @_;
    return $self->slot_indexes->{$slot_name};
}

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $instance->[$self->get_slot_index($slot_name)];
}

sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->[$self->get_slot_index($slot_name)] = $value;
}

sub initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    return;
}

sub deinitialize_slot {
    my ( $self, $instance, $slot_name ) = @_;
    delete $instance->[$self->get_slot_index($slot_name)];
}

sub is_slot_initialized {
    my ($self, $instance, $slot_name, $value) = @_;
    exists $instance->[$self->get_slot_index($slot_name)];
}

sub weaken_slot_value {
    my ($self, $instance, $slot_name) = @_;
    weaken $instance->[$self->get_slot_index($slot_name)];
}


sub inline_create_instance {
    my ($self, $class_variable) = @_;
    sprintf 'bless([Class::MOP::Class->initialize(%s)->get_meta_instance->vtable], %s)', $class_variable, $class_variable;
}

sub inline_slot_access {
    my ($self, $instance, $slot_name) = @_;
    my $name = eval $slot_name; # BLAH!
    if ( defined( my $index = $self->symbol_name_index($name) ) ) {
        return sprintf "%s->[ %s->[0][%s] ]", $instance, $instance, $index;
    } else {
        die "No such slot: $slot_name";
    }
}

__PACKAGE__->meta->make_immutable;

__PACKAGE__

__END__

=pod

=head1 NAME

MooseX::ArrayInstance - 

=head1 SYNOPSIS

	use MooseX::ArrayInstance;

=head1 DESCRIPTION

=cut


