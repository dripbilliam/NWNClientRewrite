extends Node
# Load-only correctness probe. Never instantiate the renderer/session root.
var marks: Array[Dictionary]=[]
var failures: Array[String]=[]
func mark(phase: String) -> void:
	var value: Dictionary={"phase":phase,"ticks_usec":Time.get_ticks_usec(),"pid":OS.get_process_id()}
	marks.append(value)
	print("STARTUP_PROBE "+JSON.stringify(value))
func _enter_tree() -> void: mark("bootstrap_enter_tree")
func _ready() -> void:
	mark("bootstrap_ready")
	call_deferred("measure")
func measure() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair: PackedStringArray=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var report_path: String=str(args.get("startup-report",""))
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		push_error("Owned startup report path required")
		get_tree().quit(2)
		return
	if DisplayServer.get_name()!="headless": failures.append("Expected headless display")
	var extensions: PackedStringArray=GDExtensionManager.get_loaded_extensions()
	extensions.sort()
	if extensions!=PackedStringArray(["res://native/particle_kernel.gdextension","res://native/resource_index.gdextension"]): failures.append("Expected identical native extensions")
	var api: Node=get_tree().root.get_node_or_null("ClientAPI")
	var rest: Dictionary={}
	if api==null: failures.append("Original ClientAPI autoload missing")
	else:
		rest=api.call("rest_status")
		if bool(rest.get("enabled",true)) or bool(rest.get("listening",true)): failures.append("REST must remain disabled")
	mark("root_load_begin")
	var started: int=Time.get_ticks_usec()
	var resource: Resource=ResourceLoader.load("res://native_session_world.gd","Script",ResourceLoader.CACHE_MODE_IGNORE)
	var finished: int=Time.get_ticks_usec()
	mark("root_load_end")
	var script: Script=resource as Script
	var valid: bool=script!=null and script.can_instantiate()
	var methods: PackedStringArray=[]
	if valid:
		for method in script.get_script_method_list(): methods.append(str(method.get("name","")))
		methods.sort()
		if not methods.has("run"): failures.append("Expected root run method unavailable")
	else: failures.append("Root script could not be loaded")
	var data: Dictionary={"success":failures.is_empty(),"failures":failures,"marks":marks,"root_load_usec":finished-started,"root_resource_valid":valid,"root_methods":methods,"display":DisplayServer.get_name(),"engine":Engine.get_version_info(),"editor_feature":OS.has_feature("editor"),"debug_feature":OS.has_feature("debug"),"autoload_rest":rest,"native_extensions":extensions,"root_instances_created":0,"root_run_calls":0,"network_sessions":0,"key_access":0,"worlds":0,"complete":true}
	var file: FileAccess=FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write startup report")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.close()
	script=null
	resource=null
	mark("complete")
	get_tree().quit(0 if failures.is_empty() else 1)
