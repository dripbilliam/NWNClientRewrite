extends RefCounted
# Optional isolated extension. Payloads belong to an immutable collision-cache
# entry; callers MUST invalidate before replacing, mutating, or releasing it.
# Missing/unsupported capability returns {} to the existing local inner loop.
const CLASS_NAME:="NwnDriveNumericBatch"
const VERSION:=1
const SCHEMA:="nwn-drive-numeric-v1"
const MAXIMUM_BYTES:=64*1024*1024
const MAXIMUM_ENTRIES:=512
var enabled:=false
var provenance: Dictionary={}
var entries: Dictionary={}
var payload_bytes:=0
var counters:={"bindings":0,"queries":0,"fallbacks":0,"rejected":0}

static func envelope(value: Variant)->bool:
	return value is Dictionary and value.get("version") is int and value.version==VERSION and value.get("schema") is String and value.schema==SCHEMA and value.get("supported") is bool
static func valid_capabilities(value: Variant)->bool:
	if not envelope(value) or not value.supported:return false
	for field in ["abi","float_bytes","double_bytes"]:
		if not value.get(field) is int:return false
	return value.abi==1 and value.float_bytes==4 and value.double_bytes==8 and value.get("math") is String and value.math=="engine-vector2-f32-strict-f64" and value.get("floor") is bool and value.floor and value.get("obstacle") is bool and value.obstacle and value.get("height") is bool and not value.height
static func request()->Dictionary:
	return {"version":VERSION,"schema":SCHEMA}
func configure()->void:
	clear();enabled=false;provenance={}
	if OS.has_feature("double"):return
	var engine:=Engine.get_version_info()
	if engine.major!=4 or engine.minor!=7 or engine.patch!=2:return
	if not ClassDB.class_exists(CLASS_NAME) or not ClassDB.can_instantiate(CLASS_NAME):return
	var owner: Variant=ClassDB.instantiate(CLASS_NAME)
	if not owner is RefCounted or not owner.has_method("dispatch"):return
	# The distinct class and exact two-argument dictionary ABI are mandatory.
	var valid_method:=false
	for method in owner.get_method_list():
		if method.name=="dispatch":
			valid_method=method.args.size()==2 and method.args[0].type==TYPE_INT and method.args[1].type==TYPE_DICTIONARY and method["return"].type==TYPE_DICTIONARY
	if not valid_method:return
	var capability: Variant=owner.dispatch(0,request())
	if valid_capabilities(capability) and capability.get("module_path") is String:
		var module_path: String=capability.module_path
		if module_path.is_absolute_path() and FileAccess.file_exists(module_path):
			var digest:=FileAccess.get_sha256(module_path)
			if digest.length()==64:
				provenance={"module_path":module_path,"sha256":digest,"extensions":Array(GDExtensionManager.get_loaded_extensions())}
				enabled=true
	owner.dispatch(5,request())
func bind(key: String,triangles: Array,tile: bool)->void:
	if not enabled:return
	if entries.has(key) and is_same(entries[key].source,triangles) and entries[key].tile==tile:return
	invalidate(key)
	if entries.size()>=MAXIMUM_ENTRIES:return
	# A failed entry is remembered for this exact immutable binding, preventing
	# repeated preparation/repacking on every input when it cannot be supported.
	var entry:={"source":triangles,"tile":tile,"owner":null,"bytes":0,"faces":triangles.size()}
	entries[key]=entry
	if payload_bytes>=MAXIMUM_BYTES:return
	var owner: Variant=ClassDB.instantiate(CLASS_NAME)
	if not owner is RefCounted:return
	var input:=request();input.triangles=triangles;input.tile=tile;input.maximum_bytes=MAXIMUM_BYTES-payload_bytes
	var result: Variant=owner.dispatch(1,input)
	if not envelope(result) or not result.supported or not result.get("faces") is int or result.faces!=triangles.size() or not result.get("payload_bytes") is int or result.payload_bytes<1 or result.payload_bytes>input.maximum_bytes or not result.get("tile") is bool or result.tile!=tile:
		owner.dispatch(5,request());counters.rejected+=1;return
	entry.owner=owner;entry.bytes=result.payload_bytes;payload_bytes+=int(entry.bytes);counters.bindings+=1
func query(key: String,a: Vector2,b: Vector2,radius: float,low: float,high: float,tile: bool)->Dictionary:
	if not enabled or not entries.has(key) or entries[key].owner==null or entries[key].tile!=tile:
		counters.fallbacks+=1;return {}
	var entry: Dictionary=entries[key]
	var input:=request();input.a=a;input.b=b;input.radius=radius;input.low=low;input.high=high
	var result: Variant=entry.owner.dispatch(2 if tile else 3,input);counters.queries+=1
	if not envelope(result) or not result.supported or not result.get("blocked") is bool:
		counters.fallbacks+=1;return {}
	if tile:
		if not result.get("intervals") is Array or result.intervals.size()>entry.faces or (result.blocked and not result.intervals.is_empty()):
			counters.fallbacks+=1;return {}
		for span in result.intervals:
			if not span is Vector2 or not is_finite(span.x) or not is_finite(span.y) or span.x>span.y:
				counters.fallbacks+=1;return {}
	return result
func invalidate(key: String)->void:
	if not entries.has(key):return
	var entry: Dictionary=entries[key]
	if entry.owner!=null:entry.owner.dispatch(5,request())
	payload_bytes-=int(entry.bytes);entries.erase(key)
func clear()->void:
	for key in entries.keys():invalidate(str(key))
func snapshot()->Dictionary:
	return {"version":VERSION,"schema":SCHEMA,"enabled":enabled,"entries":entries.size(),"payload_bytes":payload_bytes,"maximum_bytes":MAXIMUM_BYTES,"height":false,"counts":counters.duplicate(),"provenance":provenance.duplicate(true)}
