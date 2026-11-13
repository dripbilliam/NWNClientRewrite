#include "register_types.h"
#include "frame_probe.h"
#include "core/object/class_db.h"
void initialize_nwn_frame_probe_module(ModuleInitializationLevel level) {
 if (level == MODULE_INITIALIZATION_LEVEL_SCENE) { GDREGISTER_CLASS(NwnFrameProbe); }
}
void uninitialize_nwn_frame_probe_module(ModuleInitializationLevel) {}
