#include "register_types.h"
#include "frame_pacing.h"
#include "core/object/class_db.h"
void initialize_nwn_frame_pacing_module(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE){GDREGISTER_CLASS(NwnFramePacing);}}
void uninitialize_nwn_frame_pacing_module(ModuleInitializationLevel){}
