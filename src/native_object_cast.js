// Canonical projection of the native AsNWSObject virtual cast. Sound16 also
// derives from CNWSObject (ctor1404f3600); its vtable+20 is the same identity
// leaf140382910. Modules/areas have separate casts. UUID admission is a
// different native predicate and must not be broadened with this one.
export function asNWSObject(object){return object&&(object.objectType>=5&&object.objectType<=14||object.objectType===16)?object:null;}
