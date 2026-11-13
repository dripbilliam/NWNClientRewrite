NwnBuiltinLightInputRegistry::NwnBuiltinLightInputRegistry() {
 for (const String &argument : OS::get_singleton()->get_cmdline_user_args()) {
  if (argument == "--light-input-read=typed") plain_requested = true;
 }
}
bool NwnBuiltinLightInputRegistry::plain_schema_valid() {
 if (plain_writer.is_null() || plain_writer->get_base_script().is_valid() || plain_writer->get_script_instance() != nullptr) return false;
 const auto &members = plain_writer->debug_get_member_indices();
 const StringName names[] = {props_name, state_name, revision_name};
 const Variant::Type types[] = {Variant::DICTIONARY, Variant::DICTIONARY, Variant::INT};
 for (int index = 0; index < 3; ++index) {
  const auto *member = members.getptr(names[index]);
  if (!member || member->getter || member->property_info.type != types[index]) return false;
 }
 return true;
}
Dictionary NwnBuiltinLightInputRegistry::enroll_plain_reader(const Variant &input) {
 Dictionary result; result[SNAME("accepted")] = false;
 if (closed) return failure("Native light input registry is closed");
 if (polling) return failure("Native light typed reader enrollment during polling");
 String error; Variant script_value, hash_value;
 if (!required(input, "script", script_value, error) || !required(input, "sha256", hash_value, error)) return failure(error);
 if (script_value.get_type() != Variant::OBJECT || hash_value.get_type() != Variant::STRING) return result;
 GDScript *script = Object::cast_to<GDScript>(script_value);
 if (!script || script->get_script_instance() != nullptr || script->get_base_script().is_valid()) return result;
 const String source = script->get_source_code();
 if (source.is_empty() || source.sha256_text() != String(hash_value)) return result;
 Ref<GDScript> previous_writer = plain_writer; const String previous_source = plain_source;
 plain_writer = Ref<GDScript>(script); plain_source = source;
 if (!plain_schema_valid()) { plain_writer = previous_writer; plain_source = previous_source; return result; }
 ++plain_claims; result[SNAME("accepted")] = true; return result;
}
GDScriptInstance *NwnBuiltinLightInputRegistry::plain_reader(Node3D *node) {
 if (!plain_requested || plain_writer.is_null() || Engine::get_singleton()->is_editor_hint()) return nullptr;
 // Public native Script identity query; unknown/subclass facades never have
 // their authored properties queried here and keep the original poll body.
 if (Object::cast_to<GDScript>(node->get_script()) != plain_writer.ptr()) return nullptr;
 const String source = plain_writer->get_source_code();
 if (source.ptr() != plain_source.ptr() || source.length() != plain_source.length()) { ++plain_source_rejections; return nullptr; }
 // Revalidate the compiled schema too: source can be restored without reload
 // after an earlier compiled getter edit. Text/COW identity alone is not proof.
 ++plain_schema_checks;
 if (!plain_schema_valid()) { ++plain_schema_rejections; return nullptr; }
 ScriptInstance *instance = node->get_script_instance();
 if (!instance || instance->is_placeholder() || instance->get_language() != GDScriptLanguage::get_singleton()) return nullptr;
 return static_cast<GDScriptInstance *>(instance);
}
