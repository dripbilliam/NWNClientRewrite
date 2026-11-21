extends RefCounted

# Owns detached source rows and model dictionaries. The worker never reads the
# world, the asset queue or the render/physics scene.
const CollisionStore=preload("res://systems/native_data/native_area_collision_store.gd")
const ObjectSurface=preload("res://systems/native_data/native_object_drive_surface.gd")
const DOOR_ANIMATIONS: Array[int]=[22,50,51,72]
const MAX_SPARSE_POSES:=4

var identity: Dictionary
var records: Array=[]
var result: Dictionary={}
var elapsed_us:=0
var thread_id:=0
var input_count:=0
var sparse_pose_elapsed_us:=0

func _init(owner_scope: Array,inputs: Array,resolved: Array)->void:
	identity=geometry_identity(owner_scope,inputs,resolved)
	input_count=inputs.size()
	var models: Dictionary={}
	for index in resolved.size():
		var record: Dictionary=resolved[index]
		var key:=str(record.result.get("modelKey",""))
		if key.is_empty():continue
		if not models.has(key):
			var surface: Dictionary=record.result.surface
			models[key]=surface.duplicate(true)
		records.append({"input":record.input.duplicate(true),"result":{"surface":models[key],"modelKey":key},"resolved_index":index})

static func _geometry_input_bytes(inputs: Array)->PackedByteArray:
	var broad:=inputs.duplicate()
	for index in inputs.size():
		var input: Variant=inputs[index]
		if not input is Dictionary or int(input.type)!=10 or not input.has("doorOpenState"):continue
		# Bounds include all DWK states. Keep every other input byte and slot.
		var row: Dictionary=input.duplicate()
		row.doorOpenState=null
		broad[index]=row
	return var_to_bytes(broad)

static func geometry_identity(owner_scope: Array,inputs: Array,resolved: Array)->Dictionary:
	var model_keys: Array[String]=[]
	var model_bytes: Dictionary={}
	for record in resolved:
		var key:=str(record.result.get("modelKey",""))
		model_keys.append(key)
		if not key.is_empty() and not model_bytes.has(key):model_bytes[key]=var_to_bytes(record.result.surface)
	return {"scope":owner_scope,"inputs":_geometry_input_bytes(inputs),"model_keys":model_keys,"model_bytes":model_bytes}

func plan_appended_suffix(current: Dictionary,inputs: Array,allow_sparse: bool)->Dictionary:
	if result.is_empty() or result.has("error") or identity.scope!=current.scope or inputs.size()<=input_count:return {}
	var previous_keys: Array=identity.model_keys
	if current.model_keys.slice(0,previous_keys.size())!=previous_keys:return {}
	for key in identity.model_bytes:
		if not current.model_bytes.has(key) or identity.model_bytes[key]!=current.model_bytes[key]:return {}
	var prefix:=_geometry_input_bytes(inputs.slice(0,input_count))
	if prefix==identity.inputs:return {"poses":[]}
	if not allow_sparse:return {}
	return _sparse_pose_plan(bytes_to_var(identity.inputs),bytes_to_var(prefix))

static func _sparse_pose_plan(previous: Array,current: Array)->Dictionary:
	var poses: Array[int]=[]
	var record_index:=0
	for index in previous.size():
		var before: Variant=previous[index]
		var after: Variant=current[index]
		if before==null or after==null:
			if before!=after:return {}
			continue
		if var_to_bytes(before)!=var_to_bytes(after):
			if poses.size()>=MAX_SPARSE_POSES or not _only_pose_changed(before,after):return {}
			poses.append(record_index)
		record_index+=1
	return {"poses":poses} if not poses.is_empty() else {}

static func _only_pose_changed(before: Dictionary,after: Dictionary)->bool:
	if before.keys()!=after.keys():return false
	var unchanged:=after.duplicate()
	for field in ["position","orientation"]:
		var vector: Variant=after[field]
		if not vector is Array or vector.size()!=3:return false
		unchanged[field]=before[field]
	return var_to_bytes(unchanged)==var_to_bytes(before)

func append_owned_suffix(resolved: Array,poses: Array)->Dictionary:
	# Take the completed result before private repair. If any slot cannot be
	# proven, discard the whole result so ordinary assembly can start fresh.
	var owned:=result
	result={}
	if not poses.is_empty():
		var began:=Time.get_ticks_usec()
		for index in poses:
			if not _repair_private_pose(owned,resolved[index],index):return {}
		sparse_pose_elapsed_us=Time.get_ticks_usec()-began
	return _assemble(resolved,identity.model_keys.size(),owned)

static func _unique_slot(ids: PackedInt64Array,count: int,id: int)->int:
	if id==CollisionStore.INVALID:return -1
	var slot:=ids.find(id)
	if slot<0 or slot>=count:return -1
	var next:=ids.find(id,slot+1)
	return slot if next<0 or next>=count else -1

static func _repair_private_pose(built: Dictionary,record: Dictionary,record_index: int)->bool:
	if record.result.has("skip"):return true
	# Use the full builder's normal add arithmetic. The hot-store replace
	# operation uses a different transform expression and is intentionally avoided.
	var rebuilt:=assemble([record])
	if rebuilt.has("error"):return false
	var target: CollisionStore=built.store
	var source: CollisionStore=rebuilt.store
	var id:=int(record.input.id)
	if int(record.input.type)==9:
		if source.object_count==0:return true
		var slot:=_unique_slot(target.object_ids,target.object_count,id)
		if slot<0 or target.vertex_counts[slot]!=source.vertex_count or target.face_counts[slot]!=source.face_count:return false
		var vertex_offset:=target.vertex_starts[slot]*3
		var bound_offset:=slot*6
		for index in source.vertex_count*3:
			if not is_finite(source.vertices[index]):return false
			target.vertices[vertex_offset+index]=source.vertices[index]
		for index in 6:target.bounds[bound_offset+index]=source.bounds[index]
	else:
		if source.door_count==0:return true
		var slot:=_unique_slot(target.door_ids,target.door_count,id)
		if slot<0 or built.door_records.get(id,-1)!=record_index:return false
		for index in 6:target.door_bounds[slot*6+index]=source.door_bounds[index]
		var old_clip: Dictionary=built.doors[id]
		old_clip.nativePosition=record.input.position
		old_clip.nativeOrientation=record.input.orientation
		# The ordinary final overlay publishes the authoritative animation.
	return true

static func _slot_difference(previous: Array,current: Array,encoded: bool=false)->int:
	var count:=absi(previous.size()-current.size())
	for index in mini(previous.size(),current.size()):
		if (var_to_bytes(previous[index])!=var_to_bytes(current[index]) if encoded else previous[index]!=current[index]):
			count+=1
	return count

static func _diagnostic_rows(rows: Array)->Dictionary:
	var order: Array=[]
	var objects: Dictionary={}
	var seen: Dictionary={}
	var null_count:=0
	for row in rows:
		if row==null:
			null_count+=1
			order.append(null)
			continue
		var id:=int(row.id)
		var rank:=int(seen.get(id,0))
		seen[id]=rank+1
		# Canonical registry IDs are unique. Preserve multiplicity in the
		# report even when a probe injects duplicate projected rows.
		var key: String="%d:%d" % [id,rank]
		order.append(key)
		objects[key]=row
	return {"order":order,"objects":objects,"null_count":null_count}

static func _diagnostic_scope(previous: Array,current: Array)->Array[String]:
	var changed: Array[String]=[]
	var components: Array[String]=["world_instance","generation","area_id","collision_owner"]
	for index in maxi(previous.size(),current.size()):
		if index>=previous.size() or index>=current.size() or previous[index]!=current[index]:
			changed.append(components[index] if index<components.size() else "other")
	return changed

static func mismatch_summary(previous: Dictionary,current: Dictionary)->Dictionary:
	# Run only on an explicitly requested, completed worker rejection. The
	# identity already carries the exact detached byte streams.
	var old_inputs: Array=bytes_to_var(previous.inputs)
	var new_inputs: Array=bytes_to_var(current.inputs)
	var old_rows:=_diagnostic_rows(old_inputs)
	var new_rows:=_diagnostic_rows(new_inputs)
	var added:=0
	var removed:=0
	var shared:=0
	var changed:=0
	var fields: Dictionary={"type":0,"position":0,"orientation":0,"appearance":0,"doorType":0,"genericType":0}
	var other_fields:=0
	var field_order:=0
	for key in new_rows.objects:
		if not old_rows.objects.has(key):added+=1
	for key in old_rows.objects:
		if not new_rows.objects.has(key):
			removed+=1
			continue
		shared+=1
		var before: Dictionary=old_rows.objects[key]
		var after: Dictionary=new_rows.objects[key]
		if var_to_bytes(before)==var_to_bytes(after):continue
		changed+=1
		var before_other:=before.duplicate()
		var after_other:=after.duplicate()
		for field in fields:
			if before.has(field)!=after.has(field) or var_to_bytes(before.get(field))!=var_to_bytes(after.get(field)):
				fields[field]+=1
			before_other.erase(field)
			after_other.erase(field)
		if var_to_bytes(before_other)!=var_to_bytes(after_other):other_fields+=1
		if before.keys()!=after.keys():field_order+=1
	var models_added:=0
	var models_removed:=0
	var models_changed:=0
	for key in current.model_bytes:
		if not previous.model_bytes.has(key):models_added+=1
	for key in previous.model_bytes:
		if not current.model_bytes.has(key):models_removed+=1
		elif previous.model_bytes[key]!=current.model_bytes[key]:models_changed+=1
	return {
		"scope_changes":_diagnostic_scope(previous.scope,current.scope),
		"inputs":{"captured":old_inputs.size(),"current":new_inputs.size(),
			"captured_null":old_rows.null_count,"current_null":new_rows.null_count,
			"ordered_membership_slots_changed":_slot_difference(old_rows.order,new_rows.order),
			"ordered_geometry_slots_changed":_slot_difference(old_inputs,new_inputs,true),
			"added":added,"removed":removed,"shared":shared,"shared_changed":changed,"fields":fields,
			"other_fields_changed":other_fields,"field_order_changed":field_order},
		"models":{"captured_slots":previous.model_keys.size(),"current_slots":current.model_keys.size(),
			"ordered_slots_changed":_slot_difference(previous.model_keys,current.model_keys),
			"added_payloads":models_added,"removed_payloads":models_removed,"changed_payloads":models_changed}
	}

func run()->void:
	thread_id=OS.get_thread_caller_id()
	var began:=Time.get_ticks_usec()
	result=assemble(records)
	records=[]
	elapsed_us=Time.get_ticks_usec()-began

static func door_animation(state: Variant)->int:
	var index:=int(state)
	return DOOR_ANIMATIONS[index] if index>=0 and index<DOOR_ANIMATIONS.size() else -1

static func overlay_door_states(built: Dictionary,resolved: Array)->Dictionary:
	if built.has("error"):return built
	# Queries can keep an earlier door dictionary after a retry or a different
	# snapshot publishes. Neither those rows nor the broad store are mutated.
	var output:=built.duplicate()
	var doors: Dictionary=built.doors
	for id in built.door_records:
		var animation:=door_animation(resolved[built.door_records[id]].input.doorOpenState)
		if animation==doors[id].nativeAnimation:continue
		if is_same(doors,built.doors):doors=doors.duplicate()
		var row: Dictionary=doors[id].duplicate()
		row.nativeAnimation=animation
		doors[id]=row
	output.doors=doors
	return output

static func door_polygon_surface(source: Dictionary)->Dictionary:
	# The same decoded DWK also serves picking as Vector3 vertices. Only
	# the legacy narrow drive predicate uses numeric three-element arrays.
	var projection:=source.duplicate()
	projection.states=[]
	for state in source.states:
		var copied: Dictionary=state.duplicate()
		copied.vertices=state.vertices.map(func(point):return [point.x,point.y,point.z] if point is Vector3 else point)
		projection.states.append(copied)
	return projection

static func assemble(records: Array)->Dictionary:
	return _assemble(records,0,{"store":CollisionStore.new(true),"doors":{},"door_records":{}})

static func _assemble(records: Array,first: int,built: Dictionary)->Dictionary:
	var store: CollisionStore=built.store
	var doors: Dictionary=built.doors
	var door_records: Dictionary=built.door_records
	var door_models: Dictionary={}
	for id in door_records:
		var key:=str(records[door_records[id]].result.get("modelKey",""))
		if not key.is_empty():door_models[key]=doors[id].nativeDoorSurface
	for index in range(first,records.size()):
		var record: Dictionary=records[index]
		var input: Dictionary=record.input
		var result: Dictionary=record.result
		if result.has("skip"):continue
		var surface: Dictionary=result.surface
		if int(input.type)==9:
			var states: Array=surface.get("states",[])
			if states.is_empty():continue
			var state: Dictionary=states[0]
			var vertices: Array=[]
			for vertex in state.get("vertices",[]):
				vertices.append([vertex.x,vertex.y,vertex.z] if vertex is Vector3 else vertex.duplicate() if vertex is Array else [])
			if not vertices.is_empty():
				var added: Variant=store.add(int(input.id),input.orientation,input.position,vertices,state.get("faces",[]))
				if added is Dictionary:return added
		else:
			var orientation: Array=input.orientation.duplicate()
			var box: Variant=ObjectSurface.door_mesh_bounding_box(surface,input.position,orientation)
			if box is Dictionary and box.has("error"):return box
			if int(box.status)!=0:
				var added: Variant=store.add_door_bounds(int(input.id),box.bounds[0],box.bounds[1])
				if added is Dictionary:return added
				var key:=str(result.get("modelKey",""))
				var narrow: Variant=door_models.get(key)
				if narrow==null:
					narrow=door_polygon_surface(surface)
					if not key.is_empty():door_models[key]=narrow
				door_records[int(input.id)]=int(record.get("resolved_index",index))
				doors[int(input.id)]={"nativePosition":input.position,"nativeOrientation":input.orientation,
					"nativeDoorSurface":narrow,"nativeAnimation":door_animation(input.doorOpenState)}
	return built
