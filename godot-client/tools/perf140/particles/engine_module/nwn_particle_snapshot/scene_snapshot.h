#pragma once
#include "core/object/ref_counted.h"
#include "core/variant/variant.h"

class NwnParticleSceneSnapshot : public RefCounted {
 GDCLASS(NwnParticleSceneSnapshot, RefCounted);
protected:
 static void _bind_methods();
public:
 static PackedByteArray snapshot_nodes(const PackedInt64Array &ids, const PackedByteArray &roles);
 static int64_t abi_version();
};
