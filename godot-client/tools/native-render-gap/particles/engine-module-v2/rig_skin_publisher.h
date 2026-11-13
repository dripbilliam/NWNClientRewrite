#pragma once
#include "core/object/ref_counted.h"
#include "core/math/transform_3d.h"
#include "core/variant/dictionary.h"
#include "core/variant/array.h"
#include "core/templates/vector.h"

// Consumes the existing live ModelRigs entry after animation/manual/events and
// attachments. Scratch matrices are private; this owns no authoritative pose.
class NwnRigSkinPublisher : public RefCounted {
 GDCLASS(NwnRigSkinPublisher, RefCounted);
 Dictionary entry;
 Vector<Transform3D> rigid;
 Array continuation_skins;
 int64_t continuation_start=-1;
 bool configured=false,running=false;
 int64_t calls=0,completed=0,fallbacks=0,partial_failures=0,continuations=0,node_reads=0,bone_writes=0,force_calls=0;
 int64_t continue_legacy(int64_t p_start,const Array &p_skins);
protected:
 static void _bind_methods();
public:
 enum Result : int64_t { COMPLETE=0, FALLBACK=1, PARTIAL_FAILURE=2, REENTRANT=3 };
 static int64_t abi_version();
 bool configure(const Dictionary &p_entry);
 int64_t publish();
 Dictionary take_continuation();
 Dictionary inspect() const;
};
