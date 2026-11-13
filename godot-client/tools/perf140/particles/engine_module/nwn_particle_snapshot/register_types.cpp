#include "register_types.h"
#include "scene_snapshot.h"
#include "core/object/class_db.h"

void initialize_nwn_particle_snapshot_module(ModuleInitializationLevel level) {
 if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
  GDREGISTER_CLASS(NwnParticleSceneSnapshot);
 }
}
void uninitialize_nwn_particle_snapshot_module(ModuleInitializationLevel) {}
