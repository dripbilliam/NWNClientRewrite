extends RefCounted
# Geometry-owner calculation cache only. Producers publish immutable triangle
# arrays; replacement, count change, source removal and scope retirement detach
# their derived resources. No entity/movement/received state is stored here.
var enabled:=OS.get_cmdline_user_args().has("--drive-clear=native")
var maximum_bytes:=64*1024*1024
var maximum_entries:=512
var entries: Dictionary={}
var bytes:=0
var stats:={"configured":0,"hits":0,"unsupported":0,"budget_fallback":0,"queries":0,"query_fallback":0}
func object_key(shape: Dictionary)->String:return "object:"+str(hash(shape.get("signature",[])))
func forget(key: String)->void:
	if not entries.has(key):return
	bytes-=int(entries[key].bytes);entries.erase(key)
func forget_shape(shape: Dictionary)->void:forget(object_key(shape))
func clear()->void:
	entries.clear();bytes=0
func batch(key: String,source: Array,tile: bool)->RefCounted:
	if not enabled or not ClassDB.class_exists(&"NwnSceneGeometry"):return null
	var cached: Dictionary=entries.get(key,{})
	if not cached.is_empty():
		if cached.tile==tile and cached.count==source.size() and is_same(cached.source,source):stats.hits+=1;return cached.native
		forget(key)
	if entries.size()>=maximum_entries or bytes>=maximum_bytes:stats.budget_fallback+=1;return null
	var native: RefCounted=ClassDB.instantiate(&"NwnSceneGeometry")
	var result: Variant=native.call("dispatch",3,{"triangles":source,"tile":tile,"maximum_bytes":maximum_bytes-bytes})
	if not result is Dictionary or not result.get("supported",false):stats.unsupported+=1;return null
	var charge:=int(result.get("payload_bytes",0))
	if charge<=0 or charge>maximum_bytes-bytes:stats.budget_fallback+=1;return null
	entries[key]={"source":source,"count":source.size(),"tile":tile,"native":native,"bytes":charge};bytes+=charge;stats.configured+=1
	return native
func query(native: RefCounted,a: Vector2,b: Vector2,radius: float,low: float,high: float,tile: bool)->Dictionary:
	if native==null:return {}
	stats.queries+=1
	var result: Variant=native.call("dispatch",4 if tile else 5,{"a":a,"b":b,"radius":radius,"low":low,"high":high})
	if not result is Dictionary or not result.get("supported",false):stats.query_fallback+=1;return {}
	return result
func snapshot()->Dictionary:
	var result:=stats.duplicate();result.merge({"enabled":enabled,"entries":entries.size(),"payload_bytes":bytes,"maximum_payload_bytes":maximum_bytes,"maximum_entries":maximum_entries,"scope":"Retained typed triangle calculations, not a second world registry; native payload bound is not RSS."});return result
