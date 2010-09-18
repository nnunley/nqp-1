/* This is the implementation of the KnowHOWREPR representation, which is used
 * as part of the object model bootstrap. It stores the state of a KnowHOW
 * meta-object. */

#define PARROT_IN_EXTENSION
#include "parrot/parrot.h"
#include "parrot/extend.h"
#include "../rakudoobject.h"
#include "KnowHOWREPR.h"

/* Creates a new type object of this representation, and associates it with
 * the given HOW. */
static PMC * type_object_for(PARROT_INTERP, PMC *self, PMC *HOW) {
    /* Create new object instance. */
    KnowHOWREPRInstance *obj = mem_allocate_zeroed_typed(KnowHOWREPRInstance);

    /* Build an STable. */
    PMC *st_pmc = create_stable(interp, self, HOW);
    STable *st  = STABLE_STRUCT(st_pmc);

    /* Create type object and point it back at the STable. */
    st->WHAT = wrap_object(interp, obj);
    obj->common.stable = st_pmc;

    return st->WHAT;
}

/* Creates a new instance based on the type object. */
static PMC * instance_of(PARROT_INTERP, PMC *self, PMC *WHAT) {
    KnowHOWREPRInstance *obj = mem_allocate_zeroed_typed(KnowHOWREPRInstance);
    obj->common.stable       = STABLE_PMC(WHAT);
    obj->methods             = pmc_new(interp, enum_class_Hash);
    obj->attributes          = pmc_new(interp, enum_class_ResizablePMCArray);
    return wrap_object(interp, obj);
}

/* Checks if a given object is defined (from the point of view of the
 * representation). */
static INTVAL defined(PARROT_INTERP, PMC *self, PMC *obj) {
    return !PMC_IS_NULL(((KnowHOWREPRInstance *)PMC_data(obj))->methods);
}

/* Gets the current value for an attribute. */
static PMC * get_attribute(PARROT_INTERP, PMC *self, PMC *obj, PMC *class_handle, STRING *name) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR does not support attribute storage");
}

/* Gets the current value for an attribute, obtained using the given hint.*/
static PMC * get_attribute_with_hint(PARROT_INTERP, PMC *self, PMC *obj, PMC *class_handle, STRING *name, INTVAL hint) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR does not support attribute storage");
}

/* Binds the given value to the specified attribute. */
static void bind_attribute(PARROT_INTERP, PMC *self, PMC *obj, PMC *class_handle, STRING *name, PMC *value) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR does not support attribute storage");
}

/* Binds the given value to the specified attribute, using the given hint. */
static void bind_attribute_with_hint(PARROT_INTERP, PMC *self, PMC *obj, PMC *class_handle, STRING *name, INTVAL hint, PMC *value) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR does not support attribute storage");
}

/* Gets the hint for the given attribute ID. */
static INTVAL hint_for(PARROT_INTERP, PMC *self, PMC *class_handle, STRING *name) {
    return NO_HINT;
}

/* Used with boxing. Sets an integer value, for representations that can hold
 * one. */
static void set_int(PARROT_INTERP, PMC *self, PMC *obj, INTVAL value) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot box a native int");
}

/* Used with boxing. Gets an integer value, for representations that can
 * hold one. */
static INTVAL get_int(PARROT_INTERP, PMC *self, PMC *obj) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot unbox to a native int");
}

/* Used with boxing. Sets a floating point value, for representations that can
 * hold one. */
static void set_num(PARROT_INTERP, PMC *self, PMC *obj, FLOATVAL value) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot box a native num");
}

/* Used with boxing. Gets a floating point value, for representations that can
 * hold one. */
static FLOATVAL get_num(PARROT_INTERP, PMC *self, PMC *obj) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot unbox to a native num");
}

/* Used with boxing. Sets a string value, for representations that can hold
 * one. */
static void set_str(PARROT_INTERP, PMC *self, PMC *obj, STRING *value) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot box a native string");
}

/* Used with boxing. Gets a string value, for representations that can hold
 * one. */
static STRING * get_str(PARROT_INTERP, PMC *self, PMC *obj) {
    Parrot_ex_throw_from_c_args(interp, NULL, EXCEPTION_INVALID_OPERATION,
            "KnowHOWREPR cannot unbox to a native string");
}

/* This Parrot-specific addition to the API is used to mark an object. */
void gc_mark(PARROT_INTERP, PMC *self, PMC *obj) {
    KnowHOWREPRInstance *instance = (KnowHOWREPRInstance *)PMC_data(obj);
    if (!PMC_IS_NULL(instance->common.stable))
        Parrot_gc_mark_PMC_alive(interp, instance->common.stable);
    if (!PMC_IS_NULL(instance->methods))
        Parrot_gc_mark_PMC_alive(interp, instance->methods);
    if (!PMC_IS_NULL(instance->attributes))
        Parrot_gc_mark_PMC_alive(interp, instance->attributes);
}

/* Initializes the KnowHOWREPR representation. */
PMC * KnowHOWREPR_initialize(PARROT_INTERP) {
    REPRCommonalities *repr;
    PMC *repr_pmc;

    /* Allocate and populate the representation function table. */
    repr = mem_allocate_typed(REPRCommonalities);
    repr->type_object_for = type_object_for;
    repr->instance_of = instance_of;
    repr->defined = defined;
    repr->get_attribute = get_attribute;
    repr->get_attribute_with_hint = get_attribute_with_hint;
    repr->bind_attribute = bind_attribute;
    repr->bind_attribute_with_hint = bind_attribute_with_hint;
    repr->hint_for = hint_for;
    repr->set_int = set_int;
    repr->get_int = get_int;
    repr->set_num = set_num;
    repr->get_num = get_num;
    repr->set_str = set_str;
    repr->get_str = get_str;
    repr->gc_mark = gc_mark;

    /* Wrap it in a PMC. */
    return wrap_repr(interp, repr);
}
