package Slic3r::Model;
use Moo;

use Slic3r::Geometry qw(X Y Z);

has 'materials' => (is => 'ro', default => sub { {} });
has 'objects'   => (is => 'ro', default => sub { [] });

sub add_object {
    my $self = shift;
    
    my $object = Slic3r::Model::Object->new(model => $self, @_);
    push @{$self->objects}, $object;
    return $object;
}

# flattens everything to a single mesh
sub mesh {
    my $self = shift;
    
    my $vertices = [];
    my $facets = [];
    foreach my $object (@{$self->objects}) {
        my @instances = $object->instances ? @{$object->instances} : (undef);
        foreach my $instance (@instances) {
            my @vertices = @{$object->vertices};
            if ($instance) {
                # save Z coordinates, as rotation and translation discard them
                my @z = map $_->[Z], @vertices;
                
                if ($instance->rotation) {
                    # transform vertex coordinates
                    my $rad = Slic3r::Geometry::deg2rad($instance->rotation);
                    @vertices = Slic3r::Geometry::rotate_points($rad, undef, @vertices);
                }
                @vertices = Slic3r::Geometry::move_points($instance->offset, @vertices);
                
                # reapply Z coordinates
                $vertices[$_][Z] = $z[$_] for 0 .. $#z;
            }
            
            my $v_offset = @$vertices;
            push @$vertices, @vertices;
            foreach my $volume (@{$object->volumes}) {
                push @$facets, map {
                    my $f = [@$_];
                    $f->[$_] += $v_offset for -3..-1;
                    $f;
                } @{$volume->facets};
            }
        }
    }
    
    return Slic3r::TriangleMesh->new(
        vertices => $vertices,
        facets   => $facets,
    );
}

package Slic3r::Model::Material;
use Moo;

has 'model'         => (is => 'ro', weak_ref => 1, required => 1);
has 'attributes'    => (is => 'rw', default => sub { {} });

package Slic3r::Model::Object;
use Moo;

has 'model'     => (is => 'ro', weak_ref => 1, required => 1);
has 'vertices'  => (is => 'ro', default => sub { [] });
has 'volumes'   => (is => 'ro', default => sub { [] });
has 'instances' => (is => 'rw');

sub add_volume {
    my $self = shift;
    
    my $volume = Slic3r::Model::Volume->new(object => $self, @_);
    push @{$self->volumes}, $volume;
    return $volume;
}

sub add_instance {
    my $self = shift;
    
    $self->instances([]) if !defined $self->instances;
    push @{$self->instances}, Slic3r::Model::Instance->new(object => $self, @_);
    return $self->instances->[-1];
}

package Slic3r::Model::Volume;
use Moo;

has 'object'        => (is => 'ro', weak_ref => 1, required => 1);
has 'material_id'   => (is => 'rw');
has 'facets'        => (is => 'rw', default => sub { [] });

sub mesh {
    my $self = shift;
    return Slic3r::TriangleMesh->new(
        vertices => $self->object->vertices,
        facets   => $self->facets,
    );
}

package Slic3r::Model::Instance;
use Moo;

has 'object'    => (is => 'ro', weak_ref => 1, required => 1);
has 'rotation'  => (is => 'rw', default => sub { 0 });
has 'offset'    => (is => 'rw');

1;
