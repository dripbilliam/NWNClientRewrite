#include "register_types.h"
#include "particle_reads.h"

#include "core/object/class_db.h"

void initialize_nwn_particle_reads_module(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        nwn_particle_reads_activate();
    }
}

void uninitialize_nwn_particle_reads_module(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        nwn_particle_reads_deactivate();
    }
}
