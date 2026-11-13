extends SceneTree
# Headless inspection only: no world, renderer geometry, server or resource build.
var extension: Resource
var checks: Array=[]
func check(value: bool,label: String) -> void: checks.append({"label":label,"passed":value})
func option(name: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"+name+"="):return argument.trim_prefix("--"+name+"=")
	return ""
func class_info(name: String) -> Dictionary:
	var present:=ClassDB.class_exists(name)
	var methods: Array=[]
	if present:
		for row in ClassDB.class_get_method_list(name,true):methods.append({"name":str(row.name),"arguments":row.get("args",[]).size(),"return_type":int(row.get("return",{}).get("type",-1))})
	return {"class":name,"present":present,"instantiable":present and ClassDB.can_instantiate(name),"ref_counted":present and ClassDB.is_parent_class(name,"RefCounted"),"methods":methods}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report:=option("report")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var builtin:={"light":class_info("NwnBuiltinLightInputRegistry"),"particle_snapshot":class_info("NwnParticleSceneSnapshot")}
	var light_operations: Dictionary={}
	if builtin.light.present and builtin.light.instantiable and builtin.light.ref_counted and ClassDB.class_has_method("NwnBuiltinLightInputRegistry","dispatch"):
		var owner: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
		light_operations["3"]=owner.call("dispatch",3,{})
		light_operations["1"]=owner.call("dispatch",1,{"planes":[],"view_changed":true})
		light_operations["4"]=owner.call("dispatch",4,{})
		var node:=Node3D.new() # Identity only; never added to the tree or polled.
		light_operations["0"]=owner.call("dispatch",0,{"id":node.get_instance_id(),"source":node.get_instance_id()})
		light_operations["2"]=owner.call("dispatch",2,{"id":node.get_instance_id()})
		light_operations["8"]=owner.call("dispatch",8,{})
		node.free();owner=null
		for operation in light_operations:check(light_operations[operation] is Dictionary and not light_operations[operation].has("error"),"Built-in light operation "+operation+" accepts safe empty/identity input")
		check(light_operations["3"].get("members")==0 and light_operations["0"].get("members")==1 and light_operations["2"].get("members")==0 and light_operations["8"].get("closed")==true,"Built-in light membership and close outcomes")
	if option("expect-builtin")=="true":check(not light_operations.is_empty(),"Selected engine exposes expected built-in light contract")
	var snapshot_abi: Variant=null
	if builtin.particle_snapshot.present and ClassDB.class_has_method("NwnParticleSceneSnapshot","abi_version"):
		snapshot_abi=ClassDB.class_call_static("NwnParticleSceneSnapshot","abi_version")
		var empty: Variant=ClassDB.class_call_static("NwnParticleSceneSnapshot","snapshot_nodes",PackedInt64Array(),PackedByteArray())
		check(snapshot_abi is int and empty is PackedByteArray and not empty.is_empty(),"Built-in particle snapshot returns ABI and empty POD buffer")
	extension=load("res://native/particle_kernel.gdextension")
	check(extension!=null and ClassDB.class_exists("NwnParticleKernel"),"Current main particle extension loads")
	var particles: Dictionary={}
	for name in ["NwnParticleKernel","NwnParticleOwner","NwnParticlePresentation","NwnParticleStreamRender","NwnParticleFrameGroup","NwnParticleCounters","NwnLightHistory","NwnParticlePoseLease","NwnParticleEligibilityLease"]:particles[name]=class_info(name)
	if ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","animation_keys_valid"):
		var valid: Variant=ClassDB.class_call_static("NwnParticleKernel","animation_keys_valid",PackedFloat32Array([0,1,2,3]),0,1,1,3)
		check(valid is bool and valid,"Current DLL executes a bounded packed-array ABI operation")
	var parsed: Array=[]
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--parse-script="):continue
		var file:=argument.trim_prefix("--parse-script=")
		var script:=load(file) as GDScript
		var okay:=script!=null and script.can_instantiate()
		parsed.append({"file":file,"loaded":okay,"sha256":FileAccess.get_sha256(file)})
		check(okay,"Current source script parses: "+file)
	var success:=true
	for row in checks:success=success and bool(row.passed)
	var output:={"success":success,"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),"display":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"arguments":OS.get_cmdline_args(),"thread_model_setting":ProjectSettings.get_setting("rendering/driver/threads/thread_model",null),"actual_gpu_thread_observed":null,"builtin":builtin,"light_operations":light_operations,"snapshot_abi":snapshot_abi,"current_particle_extension":particles,"parsed_scripts":parsed,"checks":checks,"scope":"Isolated headless capability/ABI and exact current-source parse evidence; no scene rendering, public connection, frame-rate, or GPU render-thread validation"}
	var handle:=FileAccess.open(report,FileAccess.WRITE)
	if handle==null:quit(3);return
	handle.store_string(JSON.stringify(output,"\t"));handle.close()
	quit(0 if success else 1)
