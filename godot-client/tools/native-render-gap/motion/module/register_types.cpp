#include "register_types.h"
#include "motion_numeric.h"
#include "core/object/class_db.h"
void initialize_nwn_motion_numeric_module(ModuleInitializationLevel level) {
 if(level==MODULE_INITIALIZATION_LEVEL_SCENE) { GDREGISTER_CLASS(NwnMotionNumeric); }
}
void uninitialize_nwn_motion_numeric_module(ModuleInitializationLevel) {}
