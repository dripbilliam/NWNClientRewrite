#pragma once
#include "core/object/ref_counted.h"
#include "core/math/transform_3d.h"

// Main-thread, exact-call-boundary scene reads. No retained Object/Node pointers,
// scene snapshot, packed arrays, Dictionaries, or per-call heap allocations.
class NwnParticleSceneBoundary : public RefCounted {
 GDCLASS(NwnParticleSceneBoundary, RefCounted);
protected:
 static void _bind_methods();
public:
 enum Flags : int64_t { EXISTS=1, NODE3D=2, INSIDE=4, VISIBLE=8, PROCESSABLE=16, UNSUPPORTED=1LL<<30 };
 enum Status : int64_t { OK=0, ABSENT=1, WRONG_TYPE=2, UNSUPPORTED_THREAD=3, UNSUPPORTED_PRECISION=4 };
 static int64_t abi_version();
 static int64_t eligibility_flags(int64_t p_id);
 static Transform3D global_transform(int64_t p_id);
 // Read only when global_transform returned an all-NaN matrix. A legitimate
 // all-NaN transform still reports OK and is passed through unchanged.
 static int64_t pose_status();
};
