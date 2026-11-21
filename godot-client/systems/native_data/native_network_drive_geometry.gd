extends RefCounted

# NetworkDriveGeometry's resolver-owned projection. Meshes are supplied by the
# existing area-ready surface and PWK/DWK cache before a synchronous input tick.
const ObstacleAssembly=preload("res://systems/native_data/drive_obstacle_assembly.gd")
const AreaGeometry=preload("res://systems/native_data/native_drive_area_geometry.gd")
const AreaCollision=preload("res://systems/native_data/native_area_collision.gd")
const ObjectSurface=preload("res://systems/native_data/native_object_drive_surface.gd")
const ClientDrive=preload("res://systems/native_data/client_drive_collision.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const INVALID:=0x7f000000
const ASSEMBLY_STATS={"submitted":0,"completed":0,"hits":0,"stale":0,"misses":0,"sync_builds":0,"door_overlays":0,"worker_duration_ms":0.0,
	"prefix_hits":0,"prefix_records":0,"suffix_records":0,"prefix_verify_ms":0.0,"suffix_duration_ms":0.0,
	"sparse_pose_rows":0,"sparse_repair_ms":0.0,"sparse_fallbacks":0}

var world: Variant
var geometry:=AreaGeometry.new()
var cache_inputs: Array=[]
var cache: Dictionary={}
var _cache_identity: Dictionary={}
var creature_membership: Dictionary={}
var _projected_rows: Array=[]
var _projected_bearings:=PackedInt64Array()
var _bits:=PackedByteArray()
var _prewarm_started:=false
var _prewarm_inputs: Variant
var _prewarm_missing: Array=[]
var _prewarm_task:=-1
var _prewarm_job: ObstacleAssembly
var _assembly_stats:=ASSEMBLY_STATS.duplicate()
var report_prewarm_mismatch:=OS.get_cmdline_user_args().has("--drive-obstacle-prewarm-diagnostics")
var prewarm_prefix_enabled:=OS.get_cmdline_user_args().has("--drive-obstacle-prewarm-prefix")
var prewarm_sparse_enabled:=OS.get_cmdline_user_args().has("--drive-obstacle-prewarm-sparse")

func configure(owner: Variant)->void:
	if _prewarm_task>=0:_join_prewarm()
	_prewarm_job=null
	_prewarm_started=false
	_prewarm_inputs=null
	_prewarm_missing=[]
	if owner!=null:_assembly_stats=ASSEMBLY_STATS.duplicate()
	world=owner
	var diagnostic:=Callable()
	if owner!=null:diagnostic=func(message:String,detail:Dictionary):owner.drive_geometry_warning(message,detail)
	geometry.configure(owner.surface if owner!=null else null,diagnostic)
	cache_inputs.clear();cache={};_cache_identity={};creature_membership.clear()
	_projected_rows=[]
	_projected_bearings=PackedInt64Array()
	_bits.resize(16)

static func f(value: float)->float:return Vector3(value,0.0,0.0).x
static func _array(value: Variant)->Array:
	if value is Vector3:return [value.x,value.y,value.z]
	return value.duplicate() if value is Array else []
static func _state(object: Dictionary)->Dictionary:return object.get("replicated",{}) if object.get("replicated") is Dictionary else {}
static func _fixed(object: Dictionary)->Dictionary:
	var source: Variant=object.get("staticState")
	if source==null:source=object.get("lightState",{})
	return source if source is Dictionary else {}
static func _position(object: Dictionary)->Array:
	var state:=_state(object);var fixed:=_fixed(object)
	var value: Variant=state.get("position")
	if value==null:value=fixed.get("position")
	return _array(value)
static func _bearing(state: Dictionary,fixed: Dictionary)->float:
	var raw: Variant=state.get("orientation")
	if raw==null:raw=fixed.get("orientation")
	var vector: Variant=raw if raw is Array else raw.get("vector") if raw is Dictionary else null
	return atan2(float(vector[1]),float(vector[0])) if vector is Array and vector.size()>=2 else f(float(raw.get("yaw",0.0))*PI/180.0) if raw is Dictionary else 0.0
static func _table_row(table: Variant,index: int)->Dictionary:
	var rows: Array=table.get("orderedRows",[]) if table is Dictionary else []
	return rows[index] if index>=0 and index<rows.size() and rows[index] is Dictionary else {}
static func _door_label_row(table: Variant,index: int)->Dictionary:
	return table.get("rows",{}).get(index,{}) if table is Dictionary else {}
static func _model_name(row: Dictionary,primary: String,secondary: String="")->String:
	var value:=str(Rules.cell(row,primary,Rules.cell(row,secondary,"")))
	return "" if value in ["","****"] else value.to_lower()

func _full_objects()->Array:
	if world==null or not is_instance_valid(world) or world.closed or world.retiring or not world.raw_object_enumerate.is_valid():return []
	return world.raw_object_enumerate.call()

func _same_scalar(value: Variant,previous: Variant)->bool:
	if typeof(value)!=typeof(previous) or value!=previous:return false
	if value==null or value is int:return true
	if not value is float or not is_finite(value):return false
	if value!=0.0:return true
	# A new capture must preserve the sign of a zero component even when the
	# geometry cache's existing Variant equality would consider them equal.
	_bits.encode_double(0,value)
	_bits.encode_double(8,previous)
	return _bits.decode_u64(0)==_bits.decode_u64(8)

func _same_position(value: Variant,previous: Array)->bool:
	if previous.size()!=3 or not (value is Vector3 or value is Array and value.size()==3):return false
	return _same_scalar(value[0],previous[0]) and _same_scalar(value[1],previous[1]) and _same_scalar(value[2],previous[2])

func _obstacle_inputs()->Variant:
	var result: Array=[]
	var bearings:=PackedInt64Array()
	var reused_rows:=0
	var orientation_builds:=0
	for value in _full_objects():
		if not value is Dictionary:continue
		var object: Dictionary=value
		if bool(object.get("replicationRemoved",false)) or int(object.get("areaId",-1))!=world.area_id:continue
		var type:=int(object.get("objectType",0))
		if type not in [9,10]:continue
		var state:=_state(object)
		var fixed:=_fixed(object)
		var position: Variant=state.get("position")
		if position==null:position=fixed.get("position")
		if not (position is Vector3 or position is Array and not position.is_empty()):
			result.append(null)
			bearings.append(-1)
			continue
		var angle:=_bearing(state,fixed)
		if not is_finite(angle):return ObjectSurface.native_placement_orientation(angle)
		# Native placement rounds bearing to float32 before every trigonometric
		# calculation. Equal raw float32 bits give identical output.
		_bits.encode_float(0,angle)
		var bearing:=_bits.decode_u32(0)
		var slot:=result.size()
		var previous: Variant=_projected_rows[slot] if slot<_projected_rows.size() else null
		var same_bearing: bool=previous is Dictionary and _projected_bearings[slot]==bearing
		var id:=int(object.id)
		var appearance: Variant
		var door_type: Variant
		var generic_type: Variant
		var door_state: Variant
		if type==9:
			appearance=state.get("appearance")
			if appearance==null:appearance=fixed.get("appearance")
		else:
			door_type=state.get("doorType")
			generic_type=state.get("genericType")
			door_state=state.get("doorOpenState")
			if door_state==null:door_state=0
		var same_row: bool=same_bearing and previous.type==type and previous.id==id and _same_position(position,previous.position)
		if same_row:
			same_row=_same_scalar(appearance,previous.appearance) if type==9 else (
				_same_scalar(door_type,previous.doorType) and _same_scalar(generic_type,previous.genericType) and _same_scalar(door_state,previous.doorOpenState))
		bearings.append(bearing)
		if same_row:
			# Retry consumers only read these resolver-owned rows. Every capture
			# still has its own ordered array and changed rows get fresh storage.
			result.append(previous)
			reused_rows+=1
			continue
		var orientation: Variant=previous.orientation if same_bearing else ObjectSurface.native_placement_orientation(angle)
		if orientation is Dictionary:return orientation
		if not same_bearing:orientation_builds+=1
		var input: Dictionary={"type":type,"id":id,"position":_array(position),"orientation":orientation}
		if type==9:input.appearance=appearance
		else:
			input.doorType=door_type
			input.genericType=generic_type
			input.doorOpenState=door_state
		result.append(input)
	_projected_rows=result
	_projected_bearings=bearings
	FrameProfile.count("count_drive_obstacle_rows_reused",reused_rows)
	FrameProfile.count("count_drive_obstacle_orientation_builds",orientation_builds)
	return result

func _model(input: Dictionary,ready_only: bool=false)->Dictionary:
	var collision=world.drive_collision
	var name: String=""
	if int(input.type)==9:
		var appearance: Variant=input.get("appearance")
		if not appearance is int:return {"error":"Native placeable appearance ModelName is unavailable"}
		var row:=_table_row(collision.tables.get("placeables"),appearance)
		name=_model_name(row,"ModelName")
		if name.is_empty():return {"error":"Native placeable appearance ModelName is unavailable"}
		name=name.substr(0,16)
	else:
		var door_type: Variant=input.get("doorType")
		if not door_type is int:return {"error":"Native drive door model unavailable"}
		var index: Variant=input.get("genericType") if door_type==0 else door_type
		if not index is int:return {"error":"Native drive door model unavailable"}
		var row:=_door_label_row(collision.tables.get("genericdoors" if door_type==0 else "doortypes"),index)
		if row.is_empty():return {"error":"Native drive door model unavailable"}
		if str(Rules.cell(row,"VisibleModel","1"))=="0":return {"skip":true}
		name=_model_name(row,"ModelName","Model")
		if name.is_empty():return {"error":"Native drive door model unavailable"}
	if not world.catalog.has_resource(name,2053 if int(input.type)==9 else 2052):
		return {"skip":true} if int(input.type)==9 else {"error":"Native drive door mesh is unavailable"}
	var key:=name+(":placeable" if int(input.type)==9 else ":door")
	if not collision.models.has(key):
		if ready_only:return {"pending":true,"modelKey":key}
		collision.demand({"model":name,"door":int(input.type)==10})
		if not collision.models.has(key):
			if not collision.requests.values().any(func(job: Dictionary):return str(job.get("model",""))==key):
				if str(collision.assets.failure)=="Native asset queue is full":return {"pending":true}
				return {"error":str(collision.assets.failure) if not str(collision.assets.failure).is_empty() else "Native drive model request failed"}
			return {"pending":true}
	var model: Dictionary=collision.models[key]
	if model.has("error"):
		return {"skip":true} if int(input.type)==9 and str(model.error).contains("not found") else {"error":str(model.error)}
	if not model.get("states") is Array:return {"error":"Native object walkmesh is unavailable"}
	return {"surface":model,"modelKey":key}

func worker_task()->int:
	return _prewarm_task

func assembly_snapshot()->Dictionary:
	return _assembly_stats.duplicate()

func _prewarm_scope()->Array:
	return [world.get_instance_id(),int(world.generation),int(world.area_id),world.drive_collision.get_instance_id()]

func _collect_prewarm()->void:
	if _prewarm_task<0 or not WorkerThreadPool.is_task_completed(_prewarm_task):return
	_join_prewarm()

func _join_prewarm()->void:
	WorkerThreadPool.wait_for_task_completion(_prewarm_task)
	_prewarm_task=-1
	_assembly_stats.completed+=1
	_assembly_stats.worker_duration_ms=_prewarm_job.elapsed_us/1000.0
	FrameProfile.record("drive_obstacle_worker_job_duration_ms",_assembly_stats.worker_duration_ms)
	FrameProfile.count("count_drive_obstacle_worker_completed",1)

func advance_prewarm()->void:
	if _prewarm_task>=0:
		_collect_prewarm()
		if _prewarm_task<0 and not cache.is_empty():_prewarm_job=null
		return
	if _prewarm_started and _prewarm_inputs==null:return
	if not cache.is_empty():
		_prewarm_inputs=null
		_prewarm_missing.clear()
		_prewarm_started=true
		return
	if world==null or not is_instance_valid(world) or world.closed or world.retiring or not is_instance_valid(world.surface) or not is_instance_valid(world.drive_collision):
		return
	if world.drive_collision.tables.size()!=4:return
	if not _prewarm_started:
		if not world.raw_object_enumerate.is_valid() or not world.desired.has(world.controlled_id) or world.received_snapshot_active():return
		var capture_phase:=FrameProfile.begin()
		_prewarm_inputs=_obstacle_inputs()
		_prewarm_started=true
		FrameProfile.finish("drive_obstacle_warm_capture_ms",capture_phase)
		if not _prewarm_inputs is Array or _prewarm_inputs.is_empty():
			_prewarm_inputs=null
			return
	for key in _prewarm_missing:
		if not world.drive_collision.models.has(key):return
	var phase:=FrameProfile.begin()
	# Let the ordinary area asset owner demand its models. Prewarm belongs
	# behind required loading work and never adds a resource request.
	var resolved:=_resolve_obstacles(_prewarm_inputs,true)
	FrameProfile.finish("drive_obstacle_warm_resolve_ms",phase)
	if resolved.has("pending"):
		_prewarm_missing=resolved.missing
		return
	if not resolved.has("error"):
		phase=FrameProfile.begin()
		_prewarm_job=ObstacleAssembly.new(_prewarm_scope(),_prewarm_inputs,resolved.records)
		_prewarm_task=WorkerThreadPool.add_task(_prewarm_job.run,false,"Native movement obstacle assembly")
		if _prewarm_task<0:_prewarm_job=null
		else:
			_assembly_stats.submitted+=1
			FrameProfile.count("count_drive_obstacle_worker_submitted",1)
		FrameProfile.finish("drive_obstacle_warm_copy_ms",phase)
	_prewarm_inputs=null
	_prewarm_missing.clear()

func _take_prewarm(identity: Dictionary,inputs: Array,resolved: Array)->Dictionary:
	_collect_prewarm()
	if _prewarm_task>=0 or _prewarm_job==null:
		_assembly_stats.misses+=1
		FrameProfile.count("count_drive_obstacle_worker_misses",1)
		return {}
	var job:=_prewarm_job
	_prewarm_job=null
	var phase:=FrameProfile.begin()
	var active: bool=not world.closed and not world.retiring
	var current: bool=active and job.identity==identity
	FrameProfile.finish("drive_obstacle_warm_verify_ms",phase)
	if not current:
		if prewarm_prefix_enabled and active and cache.is_empty():
			var began:=Time.get_ticks_usec()
			var plan:=job.plan_appended_suffix(identity,inputs,prewarm_sparse_enabled)
			_assembly_stats.prefix_verify_ms=(Time.get_ticks_usec()-began)/1000.0
			FrameProfile.record("drive_obstacle_prewarm_prefix_verify_ms",_assembly_stats.prefix_verify_ms)
			if not plan.is_empty():
				began=Time.get_ticks_usec()
				var appended:=job.append_owned_suffix(resolved,plan.poses)
				if not appended.is_empty():
					var elapsed_us:=Time.get_ticks_usec()-began
					_assembly_stats.suffix_duration_ms=(elapsed_us-job.sparse_pose_elapsed_us)/1000.0
					_assembly_stats.prefix_hits+=1
					_assembly_stats.prefix_records=job.identity.model_keys.size()
					_assembly_stats.suffix_records=resolved.size()-_assembly_stats.prefix_records
					_assembly_stats.sparse_pose_rows=plan.poses.size()
					_assembly_stats.sparse_repair_ms=job.sparse_pose_elapsed_us/1000.0
					FrameProfile.record("drive_obstacle_prewarm_suffix_ms",_assembly_stats.suffix_duration_ms)
					if not plan.poses.is_empty():
						FrameProfile.record("drive_obstacle_prewarm_sparse_ms",_assembly_stats.sparse_repair_ms)
						FrameProfile.count("count_drive_obstacle_worker_sparse_pose_rows",_assembly_stats.sparse_pose_rows)
					FrameProfile.count("count_drive_obstacle_worker_prefix_hits",1)
					return appended
				_assembly_stats.sparse_fallbacks+=1
		_assembly_stats.stale+=1
		FrameProfile.count("count_drive_obstacle_worker_stale",1)
		if report_prewarm_mismatch and not _assembly_stats.has("stale_mismatch"):
			var began:=FrameProfile.begin()
			var mismatch:=ObstacleAssembly.mismatch_summary(job.identity,identity)
			mismatch.closed=bool(world.closed)
			mismatch.retiring=bool(world.retiring)
			_assembly_stats.stale_mismatch=mismatch
			FrameProfile.finish("drive_obstacle_prewarm_diagnostic_ms",began)
		return {}
	_assembly_stats.hits+=1
	FrameProfile.count("count_drive_obstacle_worker_hits",1)
	return job.result

func obstacles(captured_inputs: Variant=null)->Dictionary:
	if world==null or not is_instance_valid(world) or not is_instance_valid(world.drive_collision):return {"error":"Native drive geometry is unavailable"}
	if world.drive_collision.tables.size()!=4:
		for failure in world.drive_collision.stats.errors:
			if str(failure.get("resource","")) in ["appearance","placeables","genericdoors","doortypes"]:return {"error":str(failure.get("reason","Native drive table is unavailable"))}
		return {"pending":true}
	# A resource wait belongs to the original query's physical input snapshot.
	# A later replication tick may start a different query with new poses.
	var phase:=FrameProfile.begin()
	var inputs: Variant=captured_inputs if captured_inputs is Array else _obstacle_inputs()
	FrameProfile.finish("drive_obstacle_inputs_ms",phase)
	if inputs is Dictionary:return inputs
	phase=FrameProfile.begin()
	var reused: bool=not cache.is_empty() and inputs==cache_inputs
	FrameProfile.finish("drive_obstacle_compare_ms",phase)
	if reused:
		FrameProfile.count("count_drive_obstacle_cache_hits",1)
		return cache
	phase=FrameProfile.begin()
	var resolved:=_resolve_obstacles(inputs)
	FrameProfile.finish("drive_obstacle_resources_ms",phase)
	if resolved.has("error") or resolved.has("pending"):return resolved
	phase=FrameProfile.begin()
	var identity:=ObstacleAssembly.geometry_identity(_prewarm_scope(),inputs,resolved.records)
	FrameProfile.finish("drive_obstacle_geometry_identity_ms",phase)
	var reuse_geometry: bool=not cache.is_empty() and not world.closed and not world.retiring and identity==_cache_identity
	var built:=cache if reuse_geometry else _take_prewarm(identity,inputs,resolved.records)
	phase=FrameProfile.begin()
	if built.is_empty():
		# A ready authoritative query never waits on an opportunistic worker.
		_assembly_stats.sync_builds+=1
		FrameProfile.count("count_drive_obstacle_sync_builds",1)
		built=ObstacleAssembly.assemble(resolved.records)
	else:
		built=ObstacleAssembly.overlay_door_states(built,resolved.records)
		if reuse_geometry:
			_assembly_stats.door_overlays+=1
			FrameProfile.count("count_drive_obstacle_door_overlays",1)
	if not built.has("error"):
		cache_inputs=inputs.duplicate(true)
		_cache_identity=identity
		built.inputs=inputs
		cache=built
	FrameProfile.finish("drive_obstacle_geometry_ms",phase)
	return built

func _resolve_obstacles(inputs: Array,ready_only: bool=false)->Dictionary:
	var records: Array=[]
	var pending:=false
	var missing: Dictionary={}
	for input in inputs:
		if input==null:continue
		var result:=_model(input,ready_only)
		if result.has("error"):return result
		if result.has("pending"):
			pending=true
			if ready_only:missing[result.modelKey]=true
		records.append({"input":input,"result":result})
	if pending and ready_only:return {"pending":true,"missing":missing.keys()}
	if pending:return {"pending":true,"inputs":inputs}
	return {"records":records}

func _current_objects(actor: Dictionary,acknowledgement: bool)->Dictionary:
	var objects: Dictionary={}
	if acknowledgement:return objects
	for value in _full_objects():
		if not value is Dictionary:continue
		var object: Dictionary=value
		if bool(object.get("replicationRemoved",false)) or int(object.get("areaId",-1))!=world.area_id:continue
		var id:=int(object.get("id",-1))
		var motion: Dictionary=world.motion.objects.get(id,{})
		var position:=_array(motion.get("render"))
		if position.is_empty():position=_position(object)
		if position.is_empty():
			var light: Variant=object.get("lightState")
			if light is Dictionary:position=_array(light.get("position"))
		if position.is_empty():continue
		var appearance: Variant=object.get("appearance")
		var index: Variant=appearance.get("appearance") if appearance is Dictionary else null
		var radius: Dictionary=MovementRate.native_float_entry(world.drive_collision.tables.get("appearance"),index,"PERSPACE") if int(object.get("objectType",0))==5 else {"value":0.0}
		objects[id]={"id":id,"objectType":int(object.get("objectType",0)),"position":position,"radius":radius.get("value",0.0)}
	return objects

func query(actor: Dictionary,acknowledgement: bool=false,captured_inputs: Variant=null)->Dictionary:
	if world==null or not is_instance_valid(world) or not is_instance_valid(world.surface) or not world.surface.ready():return {"pending":true}
	if geometry.surface!=world.surface:geometry.configure(world.surface)
	var obstacle_phase:=FrameProfile.begin() if acknowledgement else 0
	var projected:=obstacles(captured_inputs)
	FrameProfile.finish("path_ack_obstacle_projection_ms",obstacle_phase)
	if projected.has("error") or projected.has("pending"):return projected
	var appearance: Variant=actor.get("appearance")
	var index: Variant=appearance.get("appearance") if appearance is Dictionary else null
	var radius:=1.0/64.0
	var height:=1.0/64.0
	if not acknowledgement:
		var radius_result:=MovementRate.native_float_entry(world.drive_collision.tables.get("appearance"),index,"PERSPACE")
		var height_result:=MovementRate.native_float_entry(world.drive_collision.tables.get("appearance"),index,"HEIGHT")
		if radius_result.has("error"):return radius_result
		if height_result.has("error"):return height_result
		radius=float(radius_result.value)
		height=float(height_result.value)
	var objects:=_current_objects(actor,acknowledgement)
	var membership: Dictionary={"ids":objects.keys(),"cursor":int(creature_membership.get("cursor",-1))}
	if not acknowledgement:creature_membership=membership
	var area: Dictionary={"id":world.area_id,"width":int(world.surface.definition.width),"height":int(world.surface.definition.height)}
	var providers:=geometry.providers()
	var store=projected.store;var doors: Dictionary=projected.doors
	providers.noNonWalkWorld=func(start:Array,end:Array,low:float,high:float,space:float,_ignored:int):
		return AreaCollision.no_non_walk_polys_detailed(store,start,end,low,high,space,INVALID,{"id":INVALID},0,null,0,{"doorPolygons":func(id:int,door_start:Array,door_end:Array,door_low:float,door_high:float,door_radius:float):return ObjectSurface.no_door_polygons(doors[id],door_start,door_end,door_low,door_high,door_radius,{22:0,50:1,51:2}) if doors.has(id) else 1})
	providers.noCreatures=func(start:Array,end:Array,id:int,space:float):
		return ClientDrive.client_creature_line(membership,start,end,space,id,{"object":func(oid:int):return objects.get(oid),"radius":func(value:Dictionary):return value.radius,"owner":func(_oid:int):return actor})
	providers.extensionWalkable=func(start:Array,end:Array,_space:float):return await ClientDrive.client_drive_edge(area,start,end,providers)
	var failure: Dictionary={"error":""}
	return {"failure":failure,"clear":func(start:Variant,end:Variant):
		if not str(failure.error).is_empty():return false
		var result: Variant=await ClientDrive.client_drive_line(area,_array(start),_array(end),radius,height,int(actor.id),0 if acknowledgement else 1,providers)
		if result is Dictionary:
			failure.error=str(result.get("error","Native client drive line failed"))
			return false
		return int(result)==1}
