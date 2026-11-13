extends RefCounted
# SOURCE-ONLY integration cache. Numeric calculations only, never a world store.
# A binding's source arrays/table are immutable after the data owner's publish.
# Owner notifications explicitly invalidate replacement/republication; consumers
# only receive a numeric float or null, never native resources/source dictionaries.
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const INPUT_BOUND:=16*1024*1024
var enabled:=OS.get_cmdline_user_args().has("--terrain-height=native") and not OS.get_cmdline_user_args().has("--terrain-height=script")
var maximum_bytes:=64*1024*1024
var maximum_entries:=256
var _entries: Dictionary={}
var _bytes:=0
var _closed:=false
var _configured:=0
var _active_owners:=0
var _binding_hits:=0
var _native_queries:=0
var _native_hits:=0
var _fallback_queries:=0
var _unsupported_bindings:=0
var _budget_fallback:=0
var _invalidations:=0
func _on_main()->bool:return OS.get_thread_caller_id()==OS.get_main_thread_id()
func _retire(entry: Dictionary)->void:
	var native: RefCounted=entry.get("native")
	if native!=null:native.call("retire")
func invalidate(resource: String)->void:
	if not _on_main() or not _entries.has(resource):return
	var entry: Dictionary=_entries[resource]
	if entry.get("native")!=null:_active_owners-=1
	_retire(entry);_bytes-=int(entry.get("bytes",0));_entries.erase(resource);_invalidations+=1
func clear()->void:
	if not _on_main():return
	for resource in _entries.keys():invalidate(str(resource))
func close()->void:
	if not _on_main():return
	clear();_closed=true
func _binding(mesh: Dictionary,table: Dictionary)->Dictionary:
	return {"mesh":mesh,"table":table,"vertices":mesh.get("vertices"),"faces":mesh.get("faces"),"normals":mesh.get("normals"),"constants":mesh.get("constants"),"materials":mesh.get("materials"),"rows":table.get("orderedRows"),"default":table.get("defaultValue","0")}
func _same(entry: Dictionary,mesh: Dictionary,table: Dictionary)->bool:
	if not is_same(entry.get("mesh"),mesh) or not is_same(entry.get("table"),table):return false
	for field in ["vertices","faces","normals","constants","materials"]:
		if not is_same(entry.get(field),mesh.get(field)):return false
	return is_same(entry.get("rows"),table.get("orderedRows")) and entry.get("default")==table.get("defaultValue","0")
static func _number(value: Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func _coordinate(value: Variant)->bool:
	# Original edge() subtracts pairs of source coordinates before f(). Two
	# integer Variants would subtract as int64, which cannot safely be replaced
	# by first converting each large endpoint to double. Decoded WOK XY values
	# are floats. Keep unusual integer-authored sources on the original path.
	return value is float and is_finite(value)
static func _index(value: Variant,count: int)->bool:
	return _number(value) and float(value)>=0 and float(value)<count and float(value)==floor(float(value))
static func _material(value: Variant)->bool:
	return _number(value) and float(value)>=-9223372036854775808.0 and float(value)<9223372036854775808.0
static func _classification_value(value: Variant)->bool:
	if not (value==null or value is String or value is StringName or value is int or value is float or value is bool):return false
	var text:=str(value)
	if not text.is_valid_float():return true
	var scalar:=float(text)
	return is_finite(scalar) and scalar>=-9223372036854775808.0 and scalar<9223372036854775808.0
func _pack(mesh: Dictionary,table: Dictionary)->Dictionary:
	for field in ["vertices","faces","normals","constants","materials"]:
		if not mesh.get(field) is Array:return {}
	var count: int=mesh.faces.size()
	if count>2000000 or count*81>INPUT_BOUND:return {}
	if mesh.normals.size()!=count or mesh.constants.size()!=count or mesh.materials.size()!=count:return {}
	var rows: Variant=table.get("orderedRows",[])
	if not rows is Array or not _classification_value(table.get("defaultValue","0")):return {}
	var numbers:=PackedFloat64Array();numbers.resize(count*10)
	var mask:=PackedByteArray();mask.resize(count)
	var classified: Dictionary={}
	for index in count:
		var face: Variant=mesh.faces[index];var normal: Variant=mesh.normals[index]
		if not face is Array or face.size()!=3 or not normal is Array or normal.size()!=3:return {}
		var base:=index*10
		for corner in 3:
			if not _index(face[corner],mesh.vertices.size()):return {}
			var vertex: Variant=mesh.vertices[int(face[corner])]
			# Vertex Z is deliberately never read by the original inner height.
			if not vertex is Array or vertex.size()<2 or not _coordinate(vertex[0]) or not _coordinate(vertex[1]):return {}
			numbers[base+corner*2]=float(vertex[0]);numbers[base+corner*2+1]=float(vertex[1])
		for axis in 3:
			if not _number(normal[axis]):return {}
			numbers[base+6+axis]=float(normal[axis])
		if not _number(mesh.constants[index]) or not _material(mesh.materials[index]):return {}
		numbers[base+9]=float(mesh.constants[index])
		var material:=int(mesh.materials[index])
		if not classified.has(material):
			if material>=0 and material<rows.size():
				if not rows[material] is Dictionary or not _classification_value(rows[material].get("Walk",table.get("defaultValue","0"))):return {}
			# The authoritative conversion remains in the original data function.
			classified[material]=Surface.walkable(table,material)
		mask[index]=1 if classified[material] else 0
	return {"faces":numbers,"walk":mask}
func _prepare(resource: String,mesh: Dictionary,table: Dictionary)->Dictionary:
	var began:=Timing.begin();var result:=_prepare_unprofiled(resource,mesh,table)
	Timing.finish("terrain_height_prepare",began);return result
func _prepare_unprofiled(resource: String,mesh: Dictionary,table: Dictionary)->Dictionary:
	var entry:=_binding(mesh,table);entry.native=null;entry.bytes=0
	if _entries.size()>=maximum_entries or _bytes>=maximum_bytes:_budget_fallback+=1;return {}
	if not ClassDB.class_exists(&"NwnTerrainHeight"):
		Kernel.available()
	if not ClassDB.class_exists(&"NwnTerrainHeight"):_unsupported_bindings+=1;_entries[resource]=entry;return entry
	var data:=_pack(mesh,table)
	if data.is_empty():_unsupported_bindings+=1;_entries[resource]=entry;return entry
	data.maximum_bytes=maximum_bytes-_bytes
	var native: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight")
	var result: Variant=native.call("configure",data)
	if not result is Dictionary or not result.get("supported",false):
		native.call("retire");_unsupported_bindings+=1;_entries[resource]=entry;return entry
	var charge:=int(result.get("payload_bytes",0))
	if charge<=0 or charge>maximum_bytes-_bytes:
		native.call("retire");_budget_fallback+=1;return {}
	entry.native=native;entry.bytes=charge;_bytes+=charge;_configured+=1;_active_owners+=1;_entries[resource]=entry;return entry
func calculate(resource: String,mesh: Dictionary,table: Dictionary,local: Array)->Variant:
	if not _on_main():return null
	if not enabled or _closed:return null
	if local.size()<2 or not _number(local[0]) or not _number(local[1]):_fallback_queries+=1;return null
	var entry: Dictionary=_entries.get(resource,{})
	if not entry.is_empty() and not _same(entry,mesh,table):invalidate(resource);entry={}
	if entry.is_empty():entry=_prepare(resource,mesh,table)
	else:_binding_hits+=1
	var native: RefCounted=entry.get("native")
	if native==null:_fallback_queries+=1;return null
	_native_queries+=1
	var began:=Timing.begin()
	var value: Variant=native.call("query",float(local[0]),float(local[1]))
	Timing.finish("terrain_height_native_query",began)
	if not value is float or not is_finite(value):_fallback_queries+=1;return null
	_native_hits+=1;return value
func snapshot()->Dictionary:
	# Cold numeric diagnostics only; never expose entry/native/source bindings.
	if not _on_main():return {"available":false,"supported":false}
	return {"enabled":enabled,"closed":_closed,"available":ClassDB.class_exists(&"NwnTerrainHeight"),"entries":_entries.size(),"active_owners":_active_owners,"payload_bytes":_bytes,"maximum_payload_bytes":maximum_bytes,"maximum_entries":maximum_entries,"maximum_input_bytes":INPUT_BOUND,"configured":_configured,"binding_hits":_binding_hits,"native_queries":_native_queries,"native_hits":_native_hits,"fallback_queries":_fallback_queries,"unsupported_bindings":_unsupported_bindings,"budget_fallback":_budget_fallback,"invalidations":_invalidations}
