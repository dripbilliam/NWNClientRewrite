extends RefCounted
# Startup/configuration evidence only. No entity copy, world store or per-frame scan.
const REGISTRY_PATH:="res://systems/native_data/client_feature_registry.json"
const LAUNCH_INPUT_LIMIT:=16384
const OBSERVED_OPTIONS:=["drive-collision","light-input-registry","drive-height-plan","drive-preview-height-index","world-snapshot-preparation"]
const LightInputs=preload("res://systems/native_render/native_light_input_registry.gd")
const RenderThreadInfo=preload("res://systems/native_render/render_thread_info.gd")
var requested: Dictionary={}
var resolved: Dictionary={}
var errors: Array=[]
var capabilities: Dictionary={}
var registry_sha:=""
var thread:=RenderThreadInfo.new()
var configured:=false
var launch_selection: Dictionary={}
var startup_verification: Dictionary={}

func configure(arguments: PackedStringArray,host_request: Dictionary={},launch_input: Variant=null) -> bool:
	if configured:return false
	configured=true;requested=host_request.duplicate(true)
	if launch_input!=null and not read_launch_selection(launch_input):return false
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
	if not launch_selection.is_empty() and errors.is_empty():
		startup_verification=verify_native_observation(snapshot(),false,false)
		if startup_verification.status=="rejected":errors.append_array(startup_verification.errors)
	return errors.is_empty()

func read_launch_selection(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>LAUNCH_INPUT_LIMIT or value.to_utf8_buffer().size()>LAUNCH_INPUT_LIMIT:
		errors.append("Native launcher startup selection is missing or exceeds its bound.");return false
	var selection: Variant=JSON.parse_string(value)
	if not selection is Dictionary or selection.get("version")!=1 or not selection.get("registry") is Dictionary or not selection.get("requested") is Dictionary or not selection.get("runtime") is Dictionary or not selection.get("renderCore") is Dictionary:
		errors.append("Native launcher startup selection is invalid.");return false
	var runtime: Dictionary=selection.runtime
	var core: Dictionary=selection.renderCore
	if not selection.registry.get("sha256") is String or not runtime.get("executable") is String or not runtime.get("executableSha256") is String or not runtime.get("expectedCapabilities",[]) is Array or not core.get("flags") is Array or not core.get("enabled") is bool or not core.get("typed") is bool:
		errors.append("Native launcher startup evidence is incomplete.");return false
	for name in OBSERVED_OPTIONS+["render-thread","detailed-profiling"]:
		var option: Variant=selection.requested.get(name)
		if not option is Dictionary or not option.get("value") is String or not option.get("explicit") is bool:
			errors.append("Native launcher selection is missing: "+name);return false
	launch_selection=selection
	requested=selection.requested.duplicate(true)
	return true

static func _fields(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _path_identity(value: String) -> String:
	return value.replace("\\","/").simplify_path().to_lower()

static func _safe_integer(value: Variant) -> bool:
	return value is int and value>=-9007199254740991 and value<=9007199254740991

static func _verification(failures: Array,thread_requirement: String="") -> Dictionary:
	var status:="rejected" if not failures.is_empty() else "pending" if thread_requirement=="pending" else "observed"
	return {"status":status,"errors":failures}

func verify_native_observation(observation: Dictionary,require_observed_thread: bool,session_initialized: bool=true) -> Dictionary:
	if observation.get("version")!=1 or observation.get("valid")!=true:
		return _verification(["Native feature observation is missing or invalid"])
	var failures: Array=[]
	var runtime: Dictionary=launch_selection.runtime
	var core: Dictionary=launch_selection.renderCore
	if _fields(observation.get("registry")).get("sha256")!=launch_selection.registry.sha256:
		failures.append("Native feature registry differs from launcher registry")
	if _path_identity(str(observation.get("executable","")))!=_path_identity(runtime.executable):
		failures.append("Observed native executable differs from selected executable")
	if _fields(observation.get("render_core")).get("flags")!=core.flags:
		failures.append("Actual accepted render-core flags differ from the selected bundle")
	if core.enabled and runtime.executableSha256!=core.get("engineSha256"):
		failures.append("Accepted render-core engine differs from selected executable")
	var parsed:=_fields(observation.get("parsed_native_options"))
	for name in OBSERVED_OPTIONS:
		if name in ["drive-height-plan","drive-preview-height-index"] and not requested[name].explicit:continue
		if _fields(parsed.get(name)).get("value")!=requested[name].value:
			failures.append("Native option was not applied: "+name)
	var thread_requirement:=verify_render_thread(observation,require_observed_thread,failures)
	var observed_capabilities:=_fields(observation.get("capabilities"))
	if requested["light-input-registry"].value=="builtin" and _fields(observed_capabilities.get("light_input_registry")).get("available")!=true:
		failures.append("Requested native light input registry is unavailable")
	verify_capabilities(observed_capabilities,runtime.get("expectedCapabilities",[]),failures)
	if session_initialized:
		var preparation:=_fields(observation.get("snapshot_preparation"))
		var policy: String=requested["world-snapshot-preparation"].value
		if preparation.get("requested")!=policy or preparation.get("enabled")!=(policy=="workers") or not preparation.get("diagnostic") is Dictionary:
			failures.append("Actual world snapshot preparation is missing or differs from requested policy")
		var profile: String=requested["detailed-profiling"].value
		if profile!="saved" and _fields(observation.get("presentation")).get("detailed_profiling")!=(profile=="on"):
			failures.append("Actual detailed profiling is missing or differs from requested policy")
	return _verification(failures,thread_requirement)

func verify_render_thread(observation: Dictionary,require_observed: bool,failures: Array) -> String:
	var rendering:=_fields(observation.get("rendering"))
	var state: String=str(rendering.get("render_thread_requirement",""))
	var requested_thread: String=requested["render-thread"].value
	if state not in ["not-requested","headless-not-a-gpu-thread-proof","pending","matched","mismatch"]:
		failures.append("Native render-thread requirement evidence is missing or unknown")
	if state=="mismatch":failures.append("Actual render thread differs from requested mode")
	if require_observed and requested_thread!="default" and state=="pending":
		failures.append("Requested render thread has not been observed")
	if state=="headless-not-a-gpu-thread-proof" and rendering.get("display")!="headless":
		failures.append("Headless thread limitation is invalid for a graphical runtime")
	if state=="matched":
		var evidence:=_fields(rendering.get("render_thread"))
		if evidence.get("observed")!=true or not _safe_integer(evidence.get("thread_id")) or not _safe_integer(evidence.get("main_thread_id")) or not evidence.get("separate") is bool or evidence.separate!=(evidence.thread_id!=evidence.main_thread_id):
			failures.append("Actual render-thread ID evidence is missing or inconsistent")
		elif evidence.separate!=(requested_thread=="separate"):
			failures.append("Observed render thread does not satisfy the requested mode")
	return state

static func verify_capabilities(observation: Dictionary,expected: Array,failures: Array) -> void:
	var classes:=_fields(observation.get("classes"))
	for entry in expected:
		var wanted:=_fields(entry)
		var class_name_value:=str(wanted.get("class",""))
		var actual:=_fields(classes.get(class_name_value))
		if actual.get("present")!=true:
			failures.append("Selected engine capability is absent: "+class_name_value);continue
		if wanted.get("instantiable")==true and actual.get("instantiable")!=true:
			failures.append("Engine capability is not instantiable: "+class_name_value)
		if wanted.get("parent")=="RefCounted" and actual.get("ref_counted")!=true:
			failures.append("Engine capability parent differs: "+class_name_value)
		var methods:=_fields(actual.get("methods"))
		for method in wanted.get("methods",[]):
			var signature:=_fields(method)
			var name:=str(signature.get("name",""))
			var observed:=_fields(methods.get(name))
			if observed.is_empty() or observed.get("arguments")!=signature.get("arguments") or signature.has("static") and observed.get("static")!=signature.get("static") or signature.get("returns")=="Dictionary" and observed.get("return_type")!=TYPE_DICTIONARY:
				failures.append("Engine capability method differs: "+class_name_value+"."+name)
		var abi:=_fields(wanted.get("abiVersions"))
		var actual_abi:=_fields(actual.get("abi_versions"))
		for name in abi:
			if actual_abi.get(name)!=abi[name]:failures.append("Selected engine ABI differs: "+class_name_value+"."+name)

static func world_selection(state: Dictionary,scope: Dictionary) -> Dictionary:
	var light:=_fields(_fields(state.get("focus_lighting")).get("light_input_registry"))
	var pool:=_fields(state.get("pool"))
	var collision:=_fields(state.get("drive_collision_configuration"))
	return {"scope":scope.duplicate(),"collision":collision.duplicate(true) if not collision.is_empty() else {"effective":"unavailable","reason":"No collision owner observation supplied"},"lighting":light.duplicate(true) if not light.is_empty() else {"effective":"unavailable","reason":"No lighting input owner observation supplied"},"renderCoreCounters":light.get("render_core_counters"),"modelConstruction":pool.get("template_construction"),"cache":pool.get("native_draw_cache")}

func verify_world_selection(selection: Dictionary) -> Dictionary:
	var failures: Array=[]
	if selection.collision.get("effective")!=requested["drive-collision"].value:failures.append("Actual collision owner differs from requested route")
	if selection.lighting.get("effective")!=requested["light-input-registry"].value:failures.append("Actual light-input owner differs from requested route")
	if launch_selection.renderCore.typed:
		var typed:=_fields(selection.lighting.get("typed_reader"))
		if not _safe_integer(typed.get("plain_claims")) or typed.plain_claims<1 or not _safe_integer(typed.get("plain_rows")) or typed.plain_rows<0:
			failures.append("Actual typed light enrollment/use evidence is unavailable")
		if not _fields(selection.get("renderCoreCounters")).get("available") is bool:
			failures.append("Accepted render-core cold actual-use counters are unavailable")
	return _verification(failures)

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
