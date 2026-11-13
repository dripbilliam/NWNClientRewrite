extends "res://systems/native_render/placeable_lights.gd"
# Private, opt-in experiment. No normal entry imports this source.
# Keep the complete original dirty/readiness/install/apply/attachment path.
# Only plans() can reuse an unchanged pure result at an existing dirty boundary.
var plan_cache_stats: Dictionary={"hits":0,"misses":0,"fallbacks":0,"invalidations":0}
var _cached_witness: Array=[]
var _cached_plans: Dictionary={}
var _cache_valid:=false
var _placeable_table: Dictionary={}
var _colour_table: Dictionary={}

func _invalidate_plans() -> void:
	_cache_valid=false
	_cached_witness=[];_cached_plans={};_placeable_table={};_colour_table={}
	plan_cache_stats.invalidations+=1

func configure(owner,source,shared_pool,cache_path: String,area_lights: Array) -> void:
	_invalidate_plans()
	super.configure(owner,source,shared_pool,cache_path,area_lights)

func prepared(id: int,result: Dictionary) -> void:
	# These private table/bundle fields have a single canonical writer. Wake and
	# error/readiness semantics remain in the original method, including FX-only
	# completion. A failed/nonmatching result never creates a cacheable table.
	if not closed and requests.has(id):_invalidate_plans()
	super.prepared(id,result)

static func _number_input(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))

static func _number_witness(value: Variant) -> Array:
	# Variant equality alone merges int/float and +/-0. Authored static plans
	# expose the original scalar and int64 appearance masking happens before
	# any float conversion. Preserve type and the complete finite float bits.
	if value is int:return ["int64",value]
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value)
	return ["float64",bytes]

static func _position_input(value: Variant) -> Array:
	# Only the three values actually read by the original are detached. Unknown
	# malformed/unavailable shapes take its live path; no new coercion/error.
	if not value is Array or value.size()<3:return []
	if not _number_input(value[0]) or not _number_input(value[1]) or not _number_input(value[2]):return []
	return [_number_witness(value[0]),_number_witness(value[1]),_number_witness(value[2])]

static func _orientation_input(value: Variant) -> Array:
	var vector: Variant=value.get("vector") if value is Dictionary else value
	if vector is Array and vector.size()>=2:
		if not _number_input(vector[0]) or not _number_input(vector[1]):return []
		return ["vector",_number_witness(vector[0]),_number_witness(vector[1])]
	if value is Dictionary:
		var yaw: Variant=value.get("yaw",0)
		if not _number_input(yaw):return []
		return ["yaw",_number_witness(yaw)]
	# Other ordinary scalar/null orientations select the original zero rotation.
	if value is float:return ["zero"] if is_finite(value) else []
	if value==null or value is int or value is bool or value is String:return ["zero"]
	return []

func _plan_witness() -> Array:
	if closed or not is_instance_valid(world):return []
	# Table graphs are private, published only by prepared(). Identity checks
	# also refuse silent whole-table replacement. No graph hash/copy is added.
	if not tables.get("placeables") is Dictionary or not tables.get("lightcolor") is Dictionary:return []
	var area_inputs: Array=[]
	for id in area_records:
		var light: Variant=area_records[id]
		if not light is Dictionary or not _number_input(light.get("appearance")):return []
		# Authored area plans expose the entire stored position Array. Only the
		# exact three-scalar canonical shape is enrolled; extra elements retain
		# the original path instead of accidentally reusing a truncated witness.
		if not light.get("position") is Array or light.position.size()!=3:return []
		var position_input:=_position_input(light.get("position"))
		if position_input.is_empty():return []
		area_inputs.append([id,_number_witness(light.appearance),position_input])
	var object_inputs: Array=[]
	for id in objects:
		var object: Variant=objects[id]
		if not object is Dictionary:return []
		var state: Variant=object.get("replicated",{})
		if not state is Dictionary:return []
		if not state.has("lightOn"):
			object_inputs.append([id,"absent"]);continue
		if not state.lightOn is bool:return []
		if not state.lightOn:
			object_inputs.append([id,"off"]);continue
		var fixed: Variant=object.get("staticState",object.get("lightState",{}))
		if not fixed is Dictionary:return []
		var appearance: Variant=state.get("appearance",fixed.get("appearance",-1))
		if not _number_input(appearance):return []
		var position_input:=_position_input(state.get("position",fixed.get("position")))
		var orientation_input:=_orientation_input(state.get("orientation",fixed.get("orientation")))
		if position_input.is_empty() or orientation_input.is_empty():return []
		object_inputs.append([id,"on",_number_witness(appearance),position_input,orientation_input])
	return [world.get_instance_id(),world.area_id,area_inputs,object_inputs]

func plans() -> Dictionary:
	# receive/receive_area remain inherited and continue dirtying/waking exactly
	# as before. Re-reading narrow inputs here catches in-place alias changes at
	# every original planning boundary, including instance-ready/removal wakes.
	var witness:=_plan_witness()
	if witness.is_empty():
		_invalidate_plans();plan_cache_stats.fallbacks+=1
		return super.plans()
	if _cache_valid and is_same(_placeable_table,tables.placeables) and is_same(_colour_table,tables.lightcolor) and witness==_cached_witness:
		plan_cache_stats.hits+=1
		return _cached_plans
	plan_cache_stats.misses+=1
	var result:=super.plans()
	_cached_witness=witness;_cached_plans=result
	_placeable_table=tables.placeables;_colour_table=tables.lightcolor
	_cache_valid=true
	# Original _process reads this private map and apply deep-copies its
	# configuration; neither mutates a plan. No public ClientAPI is changed.
	return result

func snapshot() -> Dictionary:
	# Existing cold World snapshot only. No new per-frame snapshot caller and no
	# cached plans/source dictionaries, world/model refs or table graphs escape.
	var result:=super.snapshot()
	result.plan_cache={"mode":"narrow-typed-plan-witness-v1","enabled":true,"retained_valid":_cache_valid,"stats":plan_cache_stats.duplicate(true)}
	return result

func close() -> void:
	_invalidate_plans()
	super.close()
