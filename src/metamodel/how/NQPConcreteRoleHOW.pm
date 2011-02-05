# This implements a concrete, parameterized instance of a role that
# can be composed into a class or mixed into an object.
knowhow NQPConcreteRoleHOW {
    ##
    ## Attributes
    ##

    # Name of the concrete role.
    has $!name;

    # What parametric role it was instantiated from.
    has $!instance_of;

    # Attributes and methods.
    has %!attributes;
    has %!methods;
    has @!multi_methods_to_incorporate;

    # Have we been composed?
    has $!composed;


    ##
    ## Declarative
    ##

    # Creates a new instance of this meta-class.
    method new(:$name!, :$instance_of!) {
        my $obj := pir::repr_instance_of__PP(self);
        $obj.BUILD(:name($name), :instance_of($instance_of));
        $obj
    }

    method BUILD(:$name!, :$instance_of!) {
        $!name := $name;
        $!instance_of := $instance_of;
    }

    # Create a new meta-object instance, and then a new type object
    # to go with it, and return that.
    method new_type(:$name = '<anon>', :$repr = 'P6opaque', :$instance_of!) {
        my $metarole := self.new(:name($name), :instance_of($instance_of));
        pir::repr_type_object_for__PPS($metarole, $repr);
    }

    method add_method($obj, $name, $code_obj) {
        if %!methods{$name} {
            pir::die("This role already has a method named " ~ $name);
        }
        %!methods{$name} := $code_obj;
    }

    method add_multi_method($obj, $name, $code_obj) {
        my %todo;
        %todo<name> := $name;
        %todo<code> := $code_obj;
        @!multi_methods_to_incorporate[+@!multi_methods_to_incorporate] := %todo;
        $code_obj;
    }

    method add_attribute($obj, $meta_attr) {
        my $name := $meta_attr.name;
        if %!attributes{$name} {
            pir::die("This role already has an attribute named " ~ $name);
        }
        %!attributes{$name} := $meta_attr;
    }

    method add_parent($obj, $parent) {
        pir::die("A role cannot inherit from a class")
    }

    method add_role($obj, $role) {
        pir::die("Roles doing roles is not yet implemented in NQP")
    }

    # Compose the role. Beyond this point, no changes are allowed.
    method compose($obj) {
        $!composed := 1;
        $obj
    }


    ##
    ## Introspecty
    ##

    method methods($obj, :$local!) {
        my @meths;
        for %!methods {
            @meths.push($_.value);
        }
        @meths
    }

    method method_table($obj) {
        %!methods
    }

    method name($obj) {
        $!name
    }

    method attributes($obj, :$local!) {
        my @attrs;
        for %!attributes {
            @attrs.push($_.value);
        }
        @attrs
    }
}
