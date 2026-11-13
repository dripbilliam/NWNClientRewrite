extends RefCounted
# Explicit input-polling backend only. The existing Focus owner/history solver
# retain membership policy, native selection/fades and renderer publication.
const CanonicalWriter=preload("res://systems/native_render/model_point_light.gd")
const CANONICAL_WRITER_SHA:="e803135ef951ea13d3d83267f0d671d2072e2df4d676bdf320a98fd9b4d1b9f6"
const REVISION:="production-light-input-selection-v1"
const NATIVE_CLASS:=&"NwnBuiltinLightInputRegistry"
const FLAG:="--light-input-registry="
var requested:="script"
var effective:="unavailable"
var failure:=""
var fallback:="none"
var native: RefCounted
var closed:=false
var typed_requested:=false
var capabilities: Dictionary={}
var operations: Dictionary={"registered":0,"erased":0,"polls":0,"resets":0,"errors":0}

static func selection(arguments: PackedStringArray) -> Dictionary:
	var value:="script";var count:=0
	for argument in arguments:
		if argument=="--light-input-registry":return {"requested":"unavailable","error":"Light input registry requires script or builtin"}
		if not argument.begins_with(FLAG):continue
		count+=1;value=argument.trim_prefix(FLAG)
	if count>1:return {"requested":value,"error":"Light input registry was specified more than once"}
	return {"requested":value,"error":"" if value in ["script","builtin"] else "Unknown light input registry: "+value}
static func capability() -> Dictionary:
	var present:=ClassDB.class_exists(NATIVE_CLASS)
	var instantiable:=present and ClassDB.can_instantiate(NATIVE_CLASS)
	var ref_counted:=present and ClassDB.is_parent_class(NATIVE_CLASS,&"RefCounted")
	var method:=present and ClassDB.class_has_method(NATIVE_CLASS,&"dispatch")
	var signature:=false
	if method:
		for info in ClassDB.class_get_method_list(NATIVE_CLASS,true):
			if str(info.name)=="dispatch":signature=info.get("args",[]).size()==2 and int(info.get("return",{}).get("type",-1))==TYPE_DICTIONARY
	var available:=present and instantiable and ref_counted and method and signature
	var reason:=""
	if not present:reason="Native light input class is unavailable: "+str(NATIVE_CLASS)
	elif not instantiable or not ref_counted:reason="Native light input class is not an instantiable RefCounted"
	elif not method or not signature:reason="Native light input dispatch(operation,input)->Dictionary contract is unavailable"
	return {"class":str(NATIVE_CLASS),"available":available,"class_present":present,"instantiable":instantiable,"ref_counted":ref_counted,"dispatch":method,"signature":signature,"reason":reason}
static func probe() -> Dictionary:
	# Startup may call this before a world exists. No live lamp, disk or GPU work.
	var result:=capability()
	if not result.available:return result
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():result.available=false;result.reason="Native light input probe requires main thread";return result
	var owner=ClassDB.instantiate(NATIVE_CLASS)
	var initial: Variant=owner.call("dispatch",3,{})
	var update: Variant=owner.call("dispatch",1,{"planes":[],"view_changed":true})
	var retired: Variant=owner.call("dispatch",8,{})
	result.probed=true
	result.available=initial is Dictionary and not initial.has("error") and initial.get("members")==0 and initial.get("closed")==false and valid_update(update) and update.rows.is_empty() and update.removed.is_empty() and update.retired.is_empty() and retired is Dictionary and retired.get("closed")==true
	if not result.available:result.reason="Native light input dispatch probe differs from the accepted contract"
	owner=null;return result
static func valid_update(value: Variant) -> bool:
	return value is Dictionary and not value.has("error") and value.get("rows") is Array and value.get("removed") is Array and value.get("retired") is Array and value.get("reused") is int and value.get("view_tests") is int and value.get("polls") is int
func configure(arguments: PackedStringArray) -> bool:
	if native!=null or closed:return _fail("Light input selection is already active or closed")
	var choice:=selection(arguments);requested=choice.requested;capabilities=capability()
	if not str(choice.error).is_empty():return _fail(choice.error)
	if requested=="script":effective="script";return true
	if not capabilities.available:return _fail(capabilities.reason)
	native=ClassDB.instantiate(NATIVE_CLASS)
	var initial: Variant=native.call("dispatch",3,{})
	if not initial is Dictionary or initial.has("error") or initial.get("members")!=0 or initial.get("closed")!=false:
		native.call("dispatch",8,{});native=null;return _fail("Native light input registry constructor contract differs")
	typed_requested=arguments.has("--light-input-read=typed")
	if typed_requested:
		var enrolled: Variant=native.call("dispatch",6,{"script":CanonicalWriter,"sha256":CANONICAL_WRITER_SHA})
		if not enrolled is Dictionary or not bool(enrolled.get("accepted",false)):
			native.call("dispatch",8,{});native=null;return _fail("Typed light reader canonical source/schema enrollment rejected")
	effective="builtin";return true
func _fail(reason: String) -> bool:
	failure=reason;effective="unavailable";fallback="rejected";operations.errors+=1;return false
func _dispatch(operation: int,input: Dictionary) -> Dictionary:
	if closed or effective!="builtin" or native==null:return {"error":"Native light input owner is unavailable or closed"}
	var result: Variant=native.call("dispatch",operation,input)
	if not result is Dictionary:_fail("Native light input operation returned non-Dictionary data");return {"error":failure}
	if result.has("error"):_fail(str(result.error))
	return result
func register_light(id: int,source: int) -> Dictionary:
	operations.registered+=1;return _dispatch(0,{"id":id,"source":source})
func erase_light(id: int) -> Dictionary:
	operations.erased+=1;return _dispatch(2,{"id":id})
func reset_publications() -> Dictionary:
	operations.resets+=1;return _dispatch(4,{})
func poll(planes: Array,view_changed: bool) -> Dictionary:
	operations.polls+=1;var result:=_dispatch(1,{"planes":planes,"view_changed":view_changed})
	if result.has("error"):return result
	if not valid_update(result):_fail("Native light input poll contract differs");return {"error":failure}
	return result
func snapshot() -> Dictionary:
	var counts: Dictionary={}
	if native!=null:
		var value: Variant=native.call("dispatch",3,{})
		if value is Dictionary:counts=value.duplicate(true)
	var out: Dictionary={"revision":REVISION,"requested":requested,"effective":effective,"owner":"focus-script-polling" if effective=="script" else str(NATIVE_CLASS) if effective=="builtin" else null,"class":native.get_class() if native!=null else null,"capability":capabilities.duplicate(true),"fallback":fallback,"reason":failure,"closed":closed,"operations":operations.duplicate(),"counts":counts}
	if typed_requested:
		var diagnostics: Variant=native.call("dispatch",9,{}) if native!=null else {}
		out.typed_reader=diagnostics.duplicate(true) if diagnostics is Dictionary else {"error":"Typed light diagnostics unavailable"}
		if ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","feature_totals"):
			out.render_core_counters=ClassDB.class_call_static("NwnFrameProbe","feature_totals")
	return out
func close() -> void:
	if closed:return
	if native!=null:native.call("dispatch",8,{});native=null
	closed=true
