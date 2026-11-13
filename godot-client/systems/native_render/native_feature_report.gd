extends RefCounted
# Startup/configuration evidence only. No entity copy, world store or per-frame scan.
const REGISTRY_PATH:="res://systems/native_data/client_feature_registry.json"
const LightInputs=preload("res://systems/native_render/native_light_input_registry.gd")
const RenderThreadInfo=preload("res://systems/native_render/render_thread_info.gd")
var requested: Dictionary={}
var resolved: Dictionary={}
var errors: Array=[]
var capabilities: Dictionary={}
var registry_sha:=""
var thread:=RenderThreadInfo.new()
var configured:=false

func configure(arguments: PackedStringArray,host_request: Dictionary={}) -> bool:
	if configured:return false
	configured=true;requested=host_request.duplicate(true)
	var text:=FileAccess.get_file_as_string(REGISTRY_PATH)
	var source: Variant=JSON.parse_string(text)
	if not source is Dictionary or source.get("version")!=1 or not source.get("features") is Array:
		errors.append("Native feature registry is unavailable or unsupported");return false
	registry_sha=FileAccess.get_sha256(REGISTRY_PATH)
	var definitions: Dictionary={};var supplied: Dictionary={}
	for row: Dictionary in source.features:
		definitions[str(row.name)]=row;resolved[str(row.name)]={"value":row.get("default"),"explicit":false,"target":row.target}
	for argument in arguments:
		if not argument.begins_with("--"):continue
		var pair:=argument.trim_prefix("--").split("=",true,1);var name: String=pair[0]
		if not definitions.has(name):continue
		var definition: Dictionary=definitions[name]
		if supplied.has(name):errors.append("Repeated native feature --"+name);continue
		supplied[name]=true
		var value: Variant=pair[1] if pair.size()==2 else definition.get("nativeBare",definition.get("bare"))
		if value==null:errors.append("Native feature --"+name+" requires a value");continue
		var valid:=false
		if definition.get("type")=="integer":
			valid=str(value).is_valid_int() and str(int(value))==str(value) and int(value)>=int(definition.minimum) and int(value)<=int(definition.maximum)
		else:valid=definition.get("choices",[]).has(value)
		if not valid:errors.append("Invalid native feature --"+name+"="+str(value));continue
		resolved[name]={"value":value,"explicit":true,"target":definition.target}
	for name: String in supplied:
		for dependency: String in definitions[name].get("requires",{}):
			if resolved[dependency].value!=definitions[name].requires[dependency]:errors.append("Native feature --"+name+" requires --"+dependency+"="+str(definitions[name].requires[dependency]))
	capabilities.light_input_registry=LightInputs.probe()
	capabilities.classes={}
	for class_name_value: String in ["NwnBuiltinLightInputRegistry","NwnParticleSceneSnapshot","NwnParticlePoseLease","NwnParticleEligibilityLease","NwnFrameProbe","NwnParticleSceneBoundary","NwnRigSkinPublisher","NwnFramePacing"]:
		var present:=ClassDB.class_exists(class_name_value)
		var methods: Dictionary={}
		if present:
			for method: Dictionary in ClassDB.class_get_method_list(class_name_value,true):
				methods[str(method.name)]={"arguments":method.get("args",[]).size(),"return_type":method.get("return",{}).get("type"),"static":(int(method.get("flags",0))&METHOD_FLAG_STATIC)!=0}
		capabilities.classes[class_name_value]={"present":present,"instantiable":ClassDB.can_instantiate(class_name_value) if present else false,"ref_counted":ClassDB.is_parent_class(class_name_value,"RefCounted") if present else false,"methods":methods}
		capabilities.classes[class_name_value].abi_versions={}
		for abi_method: String in ["abi_version","direct_abi_version"]:
			if present and methods.has(abi_method) and bool(methods[abi_method].get("static",false)):
				capabilities.classes[class_name_value].abi_versions[abi_method]=ClassDB.class_call_static(class_name_value,abi_method)
	if resolved["light-input-registry"].value=="builtin" and not capabilities.light_input_registry.available:errors.append(capabilities.light_input_registry.reason)
	thread.request()
	return errors.is_empty()

func render_core_observation() -> Dictionary:
	var arguments:=OS.get_cmdline_user_args();var flags: Array=[]
	for value in ["--particle-scene-boundary=native","--particle-scene-direct=pod","--particle-setup-boundary=bound","--particle-hot-parameters=bound","--visibility-chain-cache=epochs","--light-input-read=typed","--light-input-proof=segments","--light-pair-layer-repair=exact","--light-pair-filter=consumers","--pair-record-reuse=exact","--rig-skin-publisher=native","--skeleton-force-pass=once","--particle-resident-text=borrow","--particle-empty-clips=skip","--light-dictionary-read=single","--light-input-lifetime=guarded"]:
		if arguments.has(value):flags.append(value)
	var totals: Dictionary={}
	if ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","feature_totals"):
		totals=ClassDB.class_call_static("NwnFrameProbe","feature_totals")
	return {"flags":flags,"feature_totals":totals,"scope":"Cold selected flags and actual completed-render counters; zero use can be legitimate before world admission or in an empty scene."}

func snapshot() -> Dictionary:
	var render_thread:=thread.snapshot()
	var expected: String=str(requested.get("render-thread",{}).get("value","default"))
	var verification:="not-requested"
	if expected!="default":
		if DisplayServer.get_name()=="headless":verification="headless-not-a-gpu-thread-proof"
		elif not render_thread.get("observed",false):verification="pending"
		else:verification="matched" if bool(render_thread.separate)==(expected=="separate") else "mismatch"
	var native_options: Dictionary={}
	for name: String in resolved:
		if resolved[name].target=="native":native_options[name]=resolved[name].duplicate()
	return {"version":1,"configured":configured,"valid":errors.is_empty(),"errors":errors.duplicate(),"registry":{"path":REGISTRY_PATH,"sha256":registry_sha},"requested":requested.duplicate(true),"parsed_native_options":native_options,"parsed_option_scope":"Explicit=false entries are declared normal-launch policy defaults, not observations of native owners. Actual owners and saved presentation preferences are reported separately.","capabilities":capabilities.duplicate(true),"render_core":render_core_observation(),"engine":Engine.get_version_info(),"debug_build":OS.is_debug_build(),"executable":OS.get_executable_path(),"rendering":{"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"display":DisplayServer.get_name(),"render_thread":render_thread,"render_thread_requirement":verification},"scope":"Startup capability/configuration evidence. Actual world owner and feature-use counters are reported separately; no FPS acceptance."}
