extends SceneTree
func _initialize() -> void:
	var settings: Dictionary = {}
	for row in ProjectSettings.get_property_list():
		var name := str(row.name)
		if "shader" in name and "cache" in name: settings[name] = ProjectSettings.get_setting(name)
	print("SHADER_CACHE_INVENTORY ",JSON.stringify({"userData":OS.get_user_data_dir(),"cache":OS.get_cache_dir(),"userShaderCache":ProjectSettings.globalize_path("user://shader_cache"),"projectShaderCache":ProjectSettings.globalize_path("res://.godot/shader_cache"),"editor":Engine.is_editor_hint(),"settings":settings}))
	quit()
