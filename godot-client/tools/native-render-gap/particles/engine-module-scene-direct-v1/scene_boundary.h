#pragma once
#include "core/object/ref_counted.h"
#include "core/math/transform_3d.h"

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
 static int64_t pose_status();
 // Capability is checked before optional get_proc_address names are queried.
 // Existing ClassDB ABI1 and all fallback methods remain unchanged.
 static int64_t direct_abi_version();
};
