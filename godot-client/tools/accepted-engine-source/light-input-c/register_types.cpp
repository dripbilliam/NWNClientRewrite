#include "register_types.h"
#include "light_input_registry.h"
#include "core/object/class_db.h"
void initialize_nwn_light_input_registry_module(ModuleInitializationLevel level) {
 if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
  GDREGISTER_CLASS(NwnBuiltinLightInputRegistry);
 }
}
void uninitialize_nwn_light_input_registry_module(ModuleInitializationLevel) {}
