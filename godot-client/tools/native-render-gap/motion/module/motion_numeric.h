#pragma once
#include "core/object/ref_counted.h"
#include "core/math/vector3.h"
#include "core/variant/dictionary.h"
class NwnMotionNumeric : public RefCounted {
 GDCLASS(NwnMotionNumeric,RefCounted);
protected:
 static void _bind_methods();
public:
 // Pure arithmetic only. Empty means unsupported: caller runs its old body.
 static Dictionary facing_step(Vector3 old,Vector3 target,int64_t animation,int64_t dt,const Dictionary &options);
 static Dictionary inspect();
};
