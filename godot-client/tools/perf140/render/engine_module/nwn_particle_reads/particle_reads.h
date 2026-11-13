#pragma once

#include "core/object/ref_counted.h"

// Discoverability/version only. The hot interface never receives this object.
class NwnParticleReadBridgeV1 : public RefCounted {
    GDCLASS(NwnParticleReadBridgeV1, RefCounted);

protected:
    static void _bind_methods();

public:
    static int64_t abi_revision();
};

// Called only by the engine module's normal SCENE lifecycle.
void nwn_particle_reads_activate();
void nwn_particle_reads_deactivate();
