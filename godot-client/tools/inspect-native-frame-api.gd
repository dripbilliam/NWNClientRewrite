extends SceneTree
# Read-only installed-engine API inventory. No scene or GPU benchmark, network,
# runtime patching, or claim of performance/correctness acceptance.
func _initialize() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var classes: Dictionary={}
	for name in ["RenderingServer","EngineDebugger","Performance","Engine"]:
		var methods: Array=[]; var constants: Dictionary={}
		for method in ClassDB.class_get_method_list(name):
			var key:=str(method.name)
			if "profil" in key or "render_time" in key or "frame_setup" in key or "sync" in key or "frame_drawn" in key or "monitor" in key:
				methods.append({"name":key,"args":method.get("args",[]),"return":method.get("return",{})})
		for key in ClassDB.class_get_integer_constant_list(name):
			if "PIPELINE" in str(key) or "TIME_" in str(key): constants[str(key)]=ClassDB.class_get_integer_constant(name,key)
		classes[name]={"methods":methods,"constants":constants}
	var settings: Array=[]
	for property in ProjectSettings.get_property_list():
		var key:=str(property.name)
		if key.begins_with("rendering/") and ("profil" in key or "thread" in key or "frame" in key): settings.append({"name":key,"value":ProjectSettings.get_setting(key)})
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"classes":classes,"render_settings":settings,"network_connections":0,"scope":"Installed API availability only; no performance acceptance"},"\t")); file.close(); quit()
