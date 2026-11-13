extends Node
# Native prediction geometry, independent of highlighting/picking. Reads the
# active original WOK/PWK/DWK and appearance tables. Conservative capsule/face
# tests are a Godot adaptation; exact original polygon scratch behavior remains
# separate research. The server always owns accepted movement.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Spatial=preload("res://systems/native_render/drive_spatial_index.gd")
const DriveProfile=preload("res://systems/native_render/frame_profile.gd")
const PreviewArithmetic=preload("res://systems/native_render/drive_preview_arithmetic.gd")
const HeightIndex=preload("res://systems/native_render/drive_height_index.gd")
const TerrainSurface=preload("res://systems/native_render/terrain_surface.gd")
const MOTION_PAD:=2.0 # Conservative broadphase slack; exact circles stay current.
const EMPTY_MODEL_BOUNDS: Array=[] # Read-only fallback; no query mutates states.
const HEIGHT_PLAN_MAX_FACES:=250000
const PREVIEW_WORKER_MAX_TILES:=128
const PREVIEW_WORKER_MAX_FACES:=12000
const PREVIEW_WORKER_CACHE_MAX_TILES:=512
const PREVIEW_WORKER_CACHE_MAX_FACES:=48000
var world
var assets
var tables: Dictionary={}
var requests: Dictionary={}
var models: Dictionary={}
var tiles: Dictionary={}
var objects: Dictionary={}
var closed:=false
var spatial:=Spatial.new()
var spatial_ticket: Dictionary={}
var source_rows: Dictionary={}
var source_errors: Dictionary={}
var creature_ids: Dictionary={}
var model_users: Dictionary={}
var model_bounds: Dictionary={}
var model_versions: Dictionary={}
var static_groups: Dictionary={}
var dirty_groups: Dictionary={}
var source_batch:=false
var wanted_models: Dictionary={}
var model_queue: Array=[]
var pending_models: Dictionary={}
var publication_revision:=0
var source_serial:=0
var next_order:=0
var sources_synchronized:=false
var retained_flat_control:=false # Diagnostic comparison only; same narrow phase.
var _received_full: Dictionary={}
var _reindex: Dictionary={}
var _reindex_after_full:=false
const REINDEX_BUDGET_US:=3500
const REINDEX_MAX_SOURCES:=2048
const REINDEX_MAX_CREATURES:=1600
const REINDEX_MAX_GROUP_ENTRIES:=512
var reindex_fallbacks:={"count":0,"reasons":{}}
func _note_reindex_fallback(reason: String)->void:
	reindex_fallbacks.count=int(reindex_fallbacks.count)+1
	reindex_fallbacks.reasons[reason]=int(reindex_fallbacks.reasons.get(reason,0))+1
var _height_plan_worker: Thread
var _height_plan_enabled:=OS.get_cmdline_user_args().has("--drive-height-plan=worker")
var _preview_height_index_enabled:=OS.get_cmdline_user_args().has("--drive-preview-height-index=on")
var _worker_surface_cache_enabled:=OS.get_cmdline_user_args().has("--drive-preview-surface-cache=on")
var _height_plan_source: Dictionary={}
var _height_plan: Dictionary={}
var _height_plan_attempted_id:=0
var _height_plan_stats:={"starts":0,"ready":0,"fallbacks":0,"samples":0,"faces":0,"source_misses":0,"start_errors":0,"snapshot_ms":0.0,"worker_ms":0.0}
var _worker_surface_cache: Dictionary={}
var _worker_surface_cache_stats:={"resets":0,"tile_hits":0,"tile_copies":0,"mesh_hits":0,"mesh_copies":0,"table_hits":0,"table_copies":0,"copy_ms":0.0}

static func _build_height_plan(materials: Dictionary,walk: Dictionary) -> Dictionary:
	# Worker input is a private copy of integer material IDs and plain booleans.
	# It never touches the world, Nodes, WOK meshes or the live material table.
	var began:=Time.get_ticks_usec()
	var result: Dictionary={}
	for key in materials:
		var allowed:=PackedInt32Array();var blocked:=PackedInt32Array()
		var ids: PackedInt32Array=materials[key]
		for index in ids.size():
			if bool(walk[int(ids[index])]):allowed.append(index)
			else:blocked.append(index)
		result[key]={"allowed":allowed,"blocked":blocked,"faces":ids.size()}
	return {"plans":result,"worker_ms":(Time.get_ticks_usec()-began)/1000.0}

func _height_plan_current(surface) -> bool:
	return not _height_plan_source.is_empty() and is_instance_valid(surface) and surface.get_script()==TerrainSurface and not surface.closed and surface.ready() and _height_plan_source.ref.get_ref()==surface and is_same(surface.definition,_height_plan_source.definition) and is_same(surface.meshes,_height_plan_source.meshes) and is_same(surface.table,_height_plan_source.table) and is_same(surface.table.get("orderedRows"),_height_plan_source.table_rows)

func _prepare_height_plan(surface) -> void:
	if not _height_plan_enabled or not is_instance_valid(surface) or surface.get_script()!=TerrainSurface or not surface.ready():return
	if _height_plan_worker!=null:
		if _height_plan_worker.is_alive():return
		var completed: Variant=_height_plan_worker.wait_to_finish();_height_plan_worker=null
		if _height_plan_current(surface) and completed is Dictionary and completed.get("plans") is Dictionary:
			_height_plan=completed.plans;_height_plan_stats.worker_ms=float(completed.worker_ms);_height_plan_stats.ready+=1
		else:_height_plan.clear();_height_plan_attempted_id=0;_height_plan_stats.source_misses+=1
	if not _height_plan.is_empty() and _height_plan_current(surface):return
	if _height_plan_attempted_id==surface.get_instance_id():return
	_height_plan_attempted_id=surface.get_instance_id();_height_plan.clear()
	var snapshot_began:=Time.get_ticks_usec()
	var materials: Dictionary={};var material_refs: Dictionary={};var walk: Dictionary={};var faces:=0
	for key in surface.meshes:
		var mesh: Variant=surface.meshes[key]
		if not mesh is Dictionary or not mesh.get("faces") is Array or not mesh.get("materials") is Array:return
		var source_faces: Array=mesh.faces;var source_materials: Array=mesh.materials
		if source_faces.size()!=source_materials.size() or faces+source_faces.size()>HEIGHT_PLAN_MAX_FACES:return
		faces+=source_faces.size()
		var ids:=PackedInt32Array()
		for value in source_materials:
			var material:=int(value);ids.append(material)
			if not walk.has(material):walk[material]=Surface.walkable(surface.table,material)
		materials[key]=ids;material_refs[key]=source_materials
	if materials.is_empty():return
	_height_plan_stats.snapshot_ms=(Time.get_ticks_usec()-snapshot_began)/1000.0
	_height_plan_source={"ref":weakref(surface),"definition":surface.definition,"meshes":surface.meshes,"table":surface.table,"table_rows":surface.table.get("orderedRows"),"material_refs":material_refs}
	_height_plan_stats.faces=faces
	_height_plan_worker=Thread.new()
	var err:=_height_plan_worker.start(_build_height_plan.bind(materials,walk))
	if err!=OK:_height_plan_worker=null;_height_plan_source.clear();_height_plan_stats.start_errors+=1
	else:_height_plan_stats.starts+=1

func _drive_height(surface,point: Vector3,previous: float) -> float:
	if _height_plan.is_empty() or not _height_plan_current(surface):
		_height_plan_stats.fallbacks+=1
		return surface.height(point,previous)
	var x:=floori(point.x/10.0);var y:=floori(point.y/10.0)
	if x<0 or y<0 or x>=int(surface.definition.width) or y>=int(surface.definition.height):
		surface.stats.queries+=1;surface.stats.outside_queries+=1;_height_plan_stats.samples+=1;return previous
	var tile_source: Dictionary=surface.definition.tiles[y*int(surface.definition.width)+x]
	var key: String=str(tile_source.model)
	var mesh: Variant=surface.meshes.get(key)
	var plan: Dictionary=_height_plan.get(key,{})
	if not mesh is Dictionary or plan.is_empty() or not is_same(mesh.materials,_height_plan_source.material_refs.get(key)) or mesh.faces.size()!=int(plan.faces) or mesh.materials.size()!=int(plan.faces):
		_height_plan_stats.fallbacks+=1;return surface.height(point,previous)
	# Identical coordinate, edge, plane and f32 operation order to
	# TileSurface.height and TerrainSurface.height; only Walk lookup is moved
	# to a bounded data worker, preserving both pass and source-face order.
	surface.stats.queries+=1;_height_plan_stats.samples+=1
	var local: Array=Surface.canonical([Surface.f(Surface.f(point.x)-Surface.f(Surface.f(x)*10)),Surface.f(Surface.f(point.y)-Surface.f(Surface.f(y)*10))],int(tile_source.orientation))
	var px:=Surface.f(local[0]);var py:=Surface.f(local[1])
	for indices: PackedInt32Array in [plan.allowed,plan.blocked]:
		for index in indices:
			var face: Array=mesh.faces[index];var a: Array=mesh.vertices[face[0]];var b: Array=mesh.vertices[face[1]];var c: Array=mesh.vertices[face[2]]
			if Surface.edge(a,b,px,py)>=0 and Surface.edge(b,c,px,py)>=0 and Surface.edge(c,a,px,py)>=0:
				var n: Array=mesh.normals[index]
				var value:=0.0 if n[2]==0 else Surface.f(-Surface.f(Surface.f(Surface.f(n[1]*py)+Surface.f(Surface.f(n[0]*px)+Surface.f(mesh.constants[index]))))/n[2])
				return Surface.f(value+Surface.f(tile_source.position.y))
	return Surface.f(0.0+Surface.f(tile_source.position.y))

# Entry-only caller fences this fresh world's scene services. One source or
# spatial group per step; existing synchronous full/delta methods stay intact.
func begin_received_full() -> bool:
	invalidate_preview_geometry()
	if not ensure_spatial_scope():return false
	_cancel_reindex(true)
	_received_full={"phase":"begin_groups","keys":static_groups.keys(),"index":0,"present":{},"order":0}
	source_batch=true;spatial.begin_batch(spatial_ticket);sources_synchronized=false
	return true

func received_full_step() -> bool:
	if _received_full.is_empty():return true
	if closed:cancel_received_full();return true
	var state: Dictionary=_received_full;var index:=int(state.index)
	match str(state.phase):
		"begin_groups":
			if index<state.keys.size():
				var group: Dictionary=static_groups[state.keys[index]];group.index.begin_batch(group.ticket);state.index=index+1;return false
			state.phase="sources";state.keys=world.desired.keys();state.index=0
		"sources":
			if index<state.keys.size():
				var id:=int(state.keys[index]);state.index=index+1;state.present[id]=true
				sync_source(id,world.desired[id].object,int(state.order));state.order=int(state.order)+1;return false
			state.phase="absent";state.keys=source_rows.keys();state.index=0
		"absent":
			if index<state.keys.size():
				var id:=int(state.keys[index]);state.index=index+1
				if not state.present.has(id):forget_source(id)
				return false
			state.phase="errors";state.keys=source_errors.keys();state.index=0
		"errors":
			if index<state.keys.size():
				var id:=int(state.keys[index]);state.index=index+1
				if not state.present.has(id):source_errors.erase(id)
				return false
			spatial.end_batch(spatial_ticket);state.phase="end_groups";state.keys=static_groups.keys();state.index=0
		"end_groups":
			if index<state.keys.size():
				var key: String=state.keys[index];state.index=index+1
				var group: Dictionary=static_groups[key];group.index.end_batch(group.ticket);dirty_groups[key]=true;return false
			source_batch=false;state.phase="bounds";state.keys=dirty_groups.keys();state.index=0
		"bounds":
			if index<state.keys.size():
				var key: String=state.keys[index];state.index=index+1
				if static_groups.has(key):static_groups[key].bounds=static_groups[key].index.root_bounds()
				return false
			dirty_groups.clear();next_order=int(state.order);sources_synchronized=true;_received_full={}
			if _reindex_after_full:
				_reindex_after_full=false;reindex_sources()
			return true
	return false

func cancel_received_full() -> void:
	_received_full={};sources_synchronized=false
var stats:={"queries":0,"blocked":0,"reasons":{},"models":0,"missing":0,"errors":[],"native_only":true,"exact_polygon_parity":false}
func deny(reason: String,from: Vector3,to: Vector3) -> bool:
	stats.blocked+=1; stats.reasons[reason]=int(stats.reasons.get(reason,0))+1
	stats.last_blocked={"reason":reason,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z]}; return false
func configure(owner,source,cache_path: String) -> void:
	world=owner; assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(source); assets.cache_directory=cache_path
	assets.completed.connect(prepared)
	ensure_spatial_scope();set_process(false)
	for name in ["appearance","placeables","genericdoors","doortypes"]: requests[assets.request(name,2017,"2da")]={"table":name,"ticket":spatial_ticket.duplicate(true)}
func prepared(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id): return
	var job: Dictionary=requests[id]; requests.erase(id)
	if job.get("ticket",{})!=spatial_ticket or not spatial.snapshot().active:return
	invalidate_preview_geometry()
	if job.has("model"):pending_models.erase(job.model)
	if not str(result.error).is_empty():
		stats.errors.append({"resource":job.get("table",job.get("model","")),"reason":str(result.error)})
		if job.has("model"): publish_model(str(job.model),{"error":str(result.error)})
		return
	if job.has("table"):
		tables[job.table]=result.value
		if tables.size()==4:reindex_sources()
	else: publish_model(str(job.model),result.value); stats.models+=1
func ready() -> bool:
	var available: bool=not closed and sources_synchronized and source_errors.is_empty() and tables.size()==4 and not spatial_ticket.is_empty() and is_instance_valid(world) and is_instance_valid(world.surface) and world.surface.ready()
	if available:_prepare_height_plan(world.surface)
	return available
func _process(_delta: float) -> void:
	var began:=preload("res://systems/native_render/frame_profile.gd").begin()
	if not _reindex.is_empty():
		var reindex_began:=Time.get_ticks_usec()
		while not _reindex.is_empty():
			var spatial_phase_before:=str(spatial._finalize.get("phase",""))
			_reindex_step()
			var spatial_phase_after:=str(spatial._finalize.get("phase",""))
			if spatial_phase_before!="build" and spatial_phase_after=="build" or spatial_phase_before=="build" and spatial_phase_after!="build":break
			if Time.get_ticks_usec()-reindex_began>=REINDEX_BUDGET_US:break
	if not closed and is_instance_valid(assets) and tables.size()==4:
		for i in 32:
			if model_queue.is_empty() or assets.pending.size()+assets.running.size()>=assets.maximum_pending: break
			var key: String=model_queue.pop_front()
			if not wanted_models.has(key):continue
			var spec: Dictionary=wanted_models[key];wanted_models.erase(key)
			demand(spec)
	if model_queue.is_empty() and _reindex.is_empty():set_process(false)
	preload("res://systems/native_render/frame_profile.gd").finish("callback_drive_geometry",began)
func ensure_spatial_scope()->bool:
	if closed or not is_instance_valid(world) or int(world.generation)<0 or int(world.area_id)<0:return false
	var scope: Array=[world.get_instance_id(),int(world.generation),int(world.area_id)]
	if spatial_ticket.get("scope",[])==scope and spatial.snapshot().active:return true
	spatial_ticket=spatial.begin(scope)
	invalidate_preview_geometry()
	_cancel_reindex(false);_reindex_after_full=false
	_worker_surface_cache={}
	source_rows.clear();source_errors.clear();creature_ids.clear();model_users.clear();objects.clear();wanted_models.clear();model_queue.clear();pending_models.clear();static_groups.clear();dirty_groups.clear();source_batch=false
	next_order=0;sources_synchronized=false
	return bool(spatial_ticket.get("ready",false))
static func received_lifetime(value: Variant)->int:
	if (value is int or value is float) and is_finite(float(value)) and float(value)>0 and float(value)<=9007199254740991.0 and float(value)==floor(float(value)):return int(value)
	return -1
func bump_revision()->int:
	publication_revision+=1
	return publication_revision
func sync_full()->void:
	invalidate_preview_geometry()
	if not ensure_spatial_scope():return
	_cancel_reindex(true)
	begin_source_batch()
	var present: Dictionary={}
	var order:=0
	for key in world.desired:
		var id:=int(key);present[id]=true
		sync_source(id,world.desired[key].object,order);order+=1
	for id in source_rows.keys():
		if not present.has(id):forget_source(int(id))
	for id in source_errors.keys():
		if not present.has(id):source_errors.erase(id)
	end_source_batch()
	next_order=order;sources_synchronized=true
func sync_delta(changed: Array,removed: Array)->void:
	invalidate_preview_geometry()
	if not ensure_spatial_scope():return
	for value in removed:forget_source(int(value))
	for object in changed:
		var id:=int(object.id)
		if not world.desired.has(id):forget_source(id);continue
		var order: int=source_rows[id].order if source_rows.has(id) else next_order
		if not source_rows.has(id):next_order+=1
		sync_source(id,world.desired[id].object,order)
	flush_group_bounds()
	if _reindex.is_empty():sources_synchronized=true
func forget_source(id: int)->void:
	invalidate_preview_geometry()
	source_errors.erase(id)
	if not source_rows.has(id):return
	var binding: Dictionary=source_rows[id]
	leave_static_group(binding,true)
	spatial.remove(spatial_ticket,id,binding.witness,bump_revision())
	var key:=str(binding.get("model_key",""))
	if model_users.has(key):model_users[key].erase(id)
	source_rows.erase(id);creature_ids.erase(id);objects.erase(id)
func sync_source(id: int,object: Dictionary,order: int)->void:
	invalidate_preview_geometry()
	if int(object.get("objectType",0)) not in [5,9,10] or object.get("replicationRemoved",false):forget_source(id);return
	var previous: Dictionary=source_rows.get(id,{})
	var witness: Array=[]
	var witness_source:="received"
	if object.has("nativeLifetime") or object.has("clientKnownLifetime"):
		var native:=received_lifetime(object.get("nativeLifetime"))
		var known:=received_lifetime(object.get("clientKnownLifetime"))
		if native<0 or known<0:
			source_errors[id]="Invalid received source lifetime"
			if not previous.is_empty():previous.invalid_source=true
			return
		witness=[native,known]
	elif not previous.is_empty() and previous.witness_source=="private-local":witness=previous.witness.duplicate();witness_source="private-local"
	else:
		source_serial+=1;witness=[0x7fffffffffffffff,source_serial];witness_source="private-local"
	source_errors.erase(id)
	var replaced: bool=previous.is_empty() or previous.witness!=witness or previous.witness_source!=witness_source
	if replaced and not previous.is_empty():forget_source(id);previous={}
	if not previous.is_empty() and int(previous.get("source_type",0))!=int(object.objectType):
		leave_static_group(previous,false)
		spatial.withdraw(spatial_ticket,id,witness,bump_revision(),false,order)
		var old_key:=str(previous.get("model_key",""))
		if model_users.has(old_key):model_users[old_key].erase(id)
		objects.erase(id)
		previous={"id":id,"witness":witness,"witness_source":witness_source,"new_lifetime":false,"model_key":"","published":false}
	var binding: Dictionary=previous if not previous.is_empty() else {"id":id,"witness":witness,"witness_source":witness_source,"new_lifetime":true,"model_key":"","published":false}
	binding.object=object;binding.order=order;binding.invalid_source=false;binding.source_type=int(object.objectType)
	source_rows[id]=binding
	if int(object.objectType)==5:creature_ids[id]=true
	else:creature_ids.erase(id)
	if tables.size()==4:refresh_source(id)
func dimensions_for(object: Dictionary)->Vector2:
	var data:=row("appearance",int(object.get("appearance",{}).get("appearance",-1)))
	return Vector2(maxf(0,float(Rules.cell(data,"PERSPACE","0"))),maxf(0,float(Rules.cell(data,"HEIGHT","0"))))
func reindex_sources()->void:
	invalidate_preview_geometry()
	if not _received_full.is_empty():
		_reindex_after_full=true
		return
	_cancel_reindex(true)
	if source_rows.size()>REINDEX_MAX_SOURCES or creature_ids.size()>REINDEX_MAX_CREATURES:
		_note_reindex_fallback("source-limit" if source_rows.size()>REINDEX_MAX_SOURCES else "creature-limit")
		begin_source_batch()
		for id in source_rows.keys():refresh_source(int(id))
		end_source_batch()
		return
	sources_synchronized=false;source_batch=true
	spatial.begin_batch(spatial_ticket)
	_reindex={"phase":"begin_groups","keys":static_groups.keys(),"index":0,"started":{},"ended":{},"spatial_done":false}
	set_process(true)
func _reindex_step()->void:
	if _reindex.is_empty():return
	var state: Dictionary=_reindex;var index:=int(state.index)
	match str(state.phase):
		"begin_groups":
			if index<state.keys.size():
				var key: String=state.keys[index];state.index=index+1
				if static_groups.has(key):
					var group: Dictionary=static_groups[key]
					group.index.begin_batch(group.ticket);state.started[key]=true
				return
			state.phase="rows";state.keys=source_rows.keys();state.index=0
		"rows":
			if index<state.keys.size():
				var id:=int(state.keys[index]);state.index=index+1
				if source_rows.has(id):refresh_source(id)
				return
			state.phase="end_spatial";state.index=0
		"end_spatial":
			if spatial.begin_staged_end_batch(spatial_ticket):state.phase="finish_spatial"
			else:
				spatial.end_batch(spatial_ticket);state.spatial_done=true
				state.phase="end_groups";state.keys=static_groups.keys();state.index=0
		"finish_spatial":
			if spatial.staged_end_batch_step(spatial_ticket):
				state.spatial_done=true;state.phase="end_groups";state.keys=static_groups.keys();state.index=0
		"end_groups":
			if index<state.keys.size():
				var key: String=state.keys[index];state.index=index+1
				if static_groups.has(key) and state.started.has(key) and not state.ended.has(key):
					var group: Dictionary=static_groups[key]
					var entries:=int(group.index.snapshot().entries)
					if entries>REINDEX_MAX_GROUP_ENTRIES:_note_reindex_fallback("group-limit")
					if entries>128 and entries<=REINDEX_MAX_GROUP_ENTRIES and group.index.begin_staged_end_batch(group.ticket):
						state.phase="finish_group";state.group_key=key
					else:
						group.index.end_batch(group.ticket);state.ended[key]=true;dirty_groups[key]=true
				return
			for key in static_groups:
				if state.started.has(key) and not state.ended.has(key):
					state.keys.append(key);return
			source_batch=false;state.phase="bounds";state.keys=dirty_groups.keys();state.index=0
		"finish_group":
			var key: String=str(state.group_key)
			if not static_groups.has(key):state.phase="end_groups";return
			var group: Dictionary=static_groups[key]
			if group.index.staged_end_batch_step(group.ticket):
				state.ended[key]=true;dirty_groups[key]=true;state.phase="end_groups";state.erase("group_key")
		"bounds":
			if index<state.keys.size():
				var key: String=state.keys[index];state.index=index+1
				if dirty_groups.has(key):
					if static_groups.has(key):static_groups[key].bounds=static_groups[key].index.root_bounds()
					dirty_groups.erase(key)
				return
			if not dirty_groups.is_empty():state.keys=dirty_groups.keys();state.index=0;return
			_reindex={};sources_synchronized=true
func _cancel_reindex(finish_batch: bool)->void:
	if _reindex.is_empty():return
	var state: Dictionary=_reindex
	if finish_batch:
		if not bool(state.spatial_done):spatial.abort_batch_for_rebuild(spatial_ticket)
		for key in state.started:
			if static_groups.has(key) and not state.ended.has(key):
				var group: Dictionary=static_groups[key]
				group.index.abort_batch_for_rebuild(group.ticket);dirty_groups[key]=true
	source_batch=false;_reindex={}
	if finish_batch:flush_group_bounds()
func refresh_source(id: int)->void:
	invalidate_preview_geometry()
	if not source_rows.has(id) or tables.size()!=4:return
	var binding: Dictionary=source_rows[id]
	if binding.get("invalid_source",false):return
	var object: Dictionary=binding.object
	if int(object.objectType)==5:
		binding.dimensions=dimensions_for(object);sync_motion_id(id);return
	var spec:=descriptor(object)
	var key: String=str(spec.model)+(":door" if spec.door else ":placeable") if not spec.is_empty() else ""
	var previous_key:=str(binding.model_key)
	if previous_key!=key:
		if model_users.has(previous_key):model_users[previous_key].erase(id)
		objects.erase(id)
	binding.spec=spec;binding.model_key=key;binding.pose=Objects.pose(object)
	if not key.is_empty():
		if not model_users.has(key):model_users[key]={}
		model_users[key][id]=true
		if not models.has(key):queue_model(spec)
	publish_binding(binding)
func sync_motion_id(id: int)->void:
	if not source_rows.has(id) or not creature_ids.has(id) or tables.size()!=4:return
	var binding: Dictionary=source_rows[id]
	if binding.get("invalid_source",false):return
	var motion: Dictionary=world.motion.objects.get(id,{})
	if motion.is_empty():invalidate_preview_geometry();withdraw_binding(binding);return
	var render: Vector3=motion.render
	var point:=Vector2(render.x,render.y)
	var dimensions: Vector2=binding.get("dimensions",Vector2.ZERO)
	if binding.get("point")!=point:invalidate_preview_geometry()
	binding.point=point
	if binding.get("index_center") is Vector2 and binding.get("published_radius")==dimensions.x and binding.get("published_order")==binding.order and binding.get("published",false):
		var center: Vector2=binding.index_center
		if absf(point.x-center.x)<=MOTION_PAD and absf(point.y-center.y)<=MOTION_PAD:return
	binding.published_radius=dimensions.x;binding.index_center=point
	var result:=spatial.upsert_creature(spatial_ticket,id,binding.witness,bump_revision(),point,dimensions.x+MOTION_PAD,bool(binding.new_lifetime),int(binding.order))
	finish_publication(binding,result)
func sync_motion()->void:
	if closed or not sources_synchronized and _reindex.is_empty():return
	for id in creature_ids:sync_motion_id(int(id))
func queue_model(spec: Dictionary)->void:
	var key:=str(spec.model)+(":door" if spec.door else ":placeable")
	if models.has(key) or pending_models.has(key) or wanted_models.has(key):return
	wanted_models[key]=spec.duplicate();model_queue.append(key)
	if is_instance_valid(assets):set_process(true)
func publish_model(key: String,value: Dictionary)->void:
	invalidate_preview_geometry()
	if closed or spatial_ticket.is_empty() or not spatial.snapshot().active:return
	models[key]=value;model_bounds.erase(key);pending_models.erase(key)
	model_versions[key]=int(model_versions.get(key,0))+1
	cache_model_bounds(key)
	# Per-model data only. Source centers stay indexed across resource arrival;
	# known footprint inflation changes immediately without N user transforms.
func cache_model_bounds(key: String)->void:
	if model_bounds.has(key):return
	var result: Array=[]
	var model: Dictionary=models.get(key,{})
	if model.is_empty() or model.has("error"):return
	for state in model.get("states",[]):
		if state.faces.is_empty():result.append({"empty":true});continue
		var minimum:=Vector3(INF,INF,INF)
		var maximum:=Vector3(-INF,-INF,-INF)
		for point: Vector3 in state.vertices:minimum=minimum.min(point);maximum=maximum.max(point)
		if minimum.is_finite() and maximum.is_finite():
			var x:=maxf(absf(minimum.x),absf(maximum.x));var y:=maxf(absf(minimum.y),absf(maximum.y))
			result.append({"min":minimum,"max":maximum,"radius":sqrt(x*x+y*y)})
		else:result.append({"pending":true})
	model_bounds[key]=result
func world_bounds(local: Dictionary,pose: Dictionary)->Dictionary:
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=Vector3(-INF,-INF,-INF)
	var rotation:=Basis(Vector3.UP,float(pose.rotation))
	for corner in 8:
		var p:=Vector3(local.max.x if corner&1 else local.min.x,local.max.y if corner&2 else local.min.y,local.max.z if corner&4 else local.min.z)
		p=rotation*Vector3(p.x,p.z,-p.y)+pose.position
		var nwn:=Vector3(p.x,-p.z,p.y)
		minimum=minimum.min(nwn);maximum=maximum.max(nwn)
	var magnitude:=1.0
	for coordinate in [minimum.x,minimum.y,minimum.z,maximum.x,maximum.y,maximum.z]:magnitude=maxf(magnitude,absf(float(coordinate)))
	var margin:=magnitude*0.000003814697265625
	minimum-=Vector3.ONE*margin;maximum+=Vector3.ONE*margin
	return {"min":minimum,"max":maximum}
func withdraw_binding(binding: Dictionary)->void:
	invalidate_preview_geometry()
	if binding.get("withdrawn",false) and binding.get("published_order")==binding.order:return
	var result:=spatial.withdraw(spatial_ticket,int(binding.id),binding.witness,bump_revision(),bool(binding.new_lifetime),int(binding.order))
	finish_publication(binding,result);binding.published=false;binding.withdrawn=bool(result.get("accepted",false))
func finish_publication(binding: Dictionary,result: Dictionary)->void:
	invalidate_preview_geometry()
	if not result.get("accepted",false):source_errors[int(binding.id)]=str(result.get("reason","Spatial publication failed"));binding.published=false;return
	source_errors.erase(int(binding.id));binding.new_lifetime=false;binding.published=true;binding.withdrawn=false;binding.published_order=binding.order
func publish_binding(binding: Dictionary)->void:
	invalidate_preview_geometry()
	if binding.get("invalid_source",false):return
	if binding.pose.is_empty() or binding.spec.is_empty():leave_static_group(binding,false);return
	var key:=str(binding.model_key)
	if str(binding.get("group_key",""))!=key:leave_static_group(binding,false)
	var group:=static_group(key)
	var position: Vector3=binding.pose.position
	var point:=Vector3(position.x,-position.z,0)
	var signature: Array=[key,point,binding.order]
	if binding.get("anchor_signature",[])==signature and binding.get("published",false):return
	var result: Dictionary=group.index.upsert_shape(group.ticket,int(binding.id),binding.witness,bump_revision(),"static",point,point,true,int(binding.order))
	finish_publication(binding,result);binding.group_key=key;binding.anchor_signature=signature;dirty_groups[key]=true
	binding.point=Vector2(point.x,point.y)
func static_group(key: String)->Dictionary:
	if static_groups.has(key):return static_groups[key]
	var index:=Spatial.new()
	var group:={"index":index,"ticket":index.begin(spatial_ticket.scope),"bounds":{}}
	if source_batch:
		index.begin_batch(group.ticket)
		if not _reindex.is_empty():_reindex.started[key]=true
	static_groups[key]=group;return group
func leave_static_group(binding: Dictionary,retired: bool)->void:
	invalidate_preview_geometry()
	var key:=str(binding.get("group_key",""))
	if static_groups.has(key):
		var group: Dictionary=static_groups[key]
		if retired:group.index.remove(group.ticket,int(binding.id),binding.witness,bump_revision())
		else:group.index.withdraw(group.ticket,int(binding.id),binding.witness,bump_revision())
		dirty_groups[key]=true
	binding.group_key="";binding.erase("anchor_signature")
func begin_source_batch()->void:
	invalidate_preview_geometry()
	source_batch=true;spatial.begin_batch(spatial_ticket)
	for group in static_groups.values():group.index.begin_batch(group.ticket)
func end_source_batch()->void:
	invalidate_preview_geometry()
	spatial.end_batch(spatial_ticket)
	for key in static_groups:
		var group: Dictionary=static_groups[key]
		group.index.end_batch(group.ticket);dirty_groups[key]=true
	source_batch=false;flush_group_bounds()
func flush_group_bounds()->void:
	if source_batch:return
	for key in dirty_groups:
		if static_groups.has(key):static_groups[key].bounds=static_groups[key].index.root_bounds()
	dirty_groups.clear()
func retire_index()->void:
	cancel_received_full()
	_cancel_reindex(false);_reindex_after_full=false
	invalidate_preview_geometry()
	_worker_surface_cache={}
	if not spatial_ticket.is_empty():spatial.clear(spatial_ticket)
	spatial_ticket={};sources_synchronized=false
	source_rows.clear();source_errors.clear();creature_ids.clear();model_users.clear();wanted_models.clear();model_queue.clear();static_groups.clear();dirty_groups.clear();source_batch=false;set_process(false)
func row(table: String,index: int) -> Dictionary:
	var rows: Array=tables.get(table,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func dimensions(id: int) -> Vector2:
	if source_rows.has(id) and source_rows[id].get("dimensions") is Vector2:return source_rows[id].dimensions
	var object: Dictionary=world.desired.get(id,{}).get("object",{}); var data:=row("appearance",int(object.get("appearance",{}).get("appearance",-1)))
	return Vector2(maxf(0,float(Rules.cell(data,"PERSPACE","0"))),maxf(0,float(Rules.cell(data,"HEIGHT","0"))))
func descriptor(object: Dictionary) -> Dictionary:
	var kind:=int(object.objectType); var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{})); var data: Dictionary={}
	if kind==9: data=row("placeables",int(state.get("appearance",fixed.get("appearance",-1))))
	elif kind==10:
		var type:=int(state.get("doorType",0)); data=row("genericdoors" if type==0 else "doortypes",int(state.get("genericType",0)) if type==0 else type)
		if str(Rules.cell(data,"VisibleModel","1"))=="0": return {}
	else: return {}
	var name:=str(Rules.cell(data,"ModelName",Rules.cell(data,"Model",""))).to_lower()
	if name in ["","****"]: return {}
	return {"model":name,"door":kind==10,"state":int(state.get("doorOpenState",0))}
func demand(spec: Dictionary) -> void:
	var key:=str(spec.model)+(":door" if spec.door else ":placeable")
	if models.has(key) or pending_models.has(key): return
	if not is_instance_valid(assets):return
	var type:=2052 if spec.door else 2053
	if not assets.catalog.has_resource(str(spec.model),type): publish_model(key,{"states":[]}); stats.missing+=1; return
	var id: int=assets.request(str(spec.model),type,"dwk-surface-v1" if spec.door else "pwk-surface-v1")
	if id>=0: requests[id]={"model":key,"ticket":spatial_ticket.duplicate(true)};pending_models[key]=true
static func triangle(a: Vector3,b: Vector3,c: Vector3) -> Dictionary:
	# Geometry owned by this collision view is immutable until its existing cache
	# entry is replaced/retired. Cache only the exact original XY arithmetic.
	var points: Array=[Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(c.x,c.y)]
	return {"a":a,"b":b,"c":c,"min":a.min(b).min(c),"max":a.max(b).max(c),"xy_points":points,"xy_area":cross(points[1]-points[0],points[2]-points[0]),"xy_edges":[points[1]-points[0],points[2]-points[1],points[0]-points[2]]}
func tile(index: int) -> Array:
	if tiles.has(index): return tiles[index]
	var source: Dictionary=world.surface.definition.tiles[index]; var mesh: Dictionary=world.surface.meshes[source.model]; var vertices: Array=[]
	var width:=int(world.surface.definition.width); var x:=index%width; var y:=index/width
	for original in mesh.vertices:
		var p: Array=Surface.canonical([original[0],original[1]],(4-int(source.orientation))%4)
		vertices.append(Vector3(p[0]+x*10,p[1]+y*10,float(original[2])+source.position.y))
	var result: Array=[]
	for i in mesh.faces.size():
		var face: Array=mesh.faces[i]; var value:=triangle(vertices[face[0]],vertices[face[1]],vertices[face[2]])
		value.walk=Surface.walkable(world.surface.table,int(mesh.materials[i])); result.append(value)
	tiles[index]=result; return result
func obstacle(id: int,object: Dictionary,spec: Dictionary) -> Dictionary:
	var key:=str(spec.model)+(":door" if spec.door else ":placeable"); var pose:=Objects.pose(object)
	if pose.is_empty(): return {}
	var signature: Array=[key,spec.state,pose.position,pose.rotation]
	if objects.has(id) and objects[id].signature==signature: return objects[id]
	stats.lazy_shapes=int(stats.get("lazy_shapes",0))+1
	var model: Dictionary=models.get(key,{})
	if model.is_empty() or model.has("error"): return {"pending":true,"position":pose.position}
	var states: Array=model.get("states",[]); var state:=int(spec.state) if spec.door else 0
	if state<0 or state>=states.size(): return {}
	var result:={"signature":signature,"triangles":[],"min":Vector3(INF,INF,INF),"max":Vector3(-INF,-INF,-INF)}; var vertices: Array=[]
	for source in states[state].vertices:
		var p: Vector3=Basis(Vector3.UP,float(pose.rotation))*Vector3(source.x,source.z,-source.y)+pose.position
		var nwn:=Vector3(p.x,-p.z,p.y); vertices.append(nwn); result.min=result.min.min(nwn); result.max=result.max.max(nwn)
	for face in states[state].faces: result.triangles.append(triangle(vertices[face[0]],vertices[face[1]],vertices[face[2]]))
	objects[id]=result; return result
# Per-input temporary geometry view. The ordinary query/authority path remains
# unrestricted. This class still owns all data; no second world registry exists.
var preview_revision:=0
var preview_revision_valid:=true
var preview_stats:={"collections":0,"probes":0,"initial_clears":0,"reused_clears":0,"fallback_clears":0,"collection_failures":0}
func invalidate_preview_geometry()->void:
	if preview_revision==0x7fffffffffffffff:preview_revision_valid=false
	else:preview_revision+=1
func preview_geometry_current(ticket: Dictionary,id: int,witness: Array,revision: int,published: int,frame: int)->bool:
	return preview_revision_valid and preview_revision==revision and publication_revision==published and Engine.get_process_frames()==frame and ready() and spatial_ticket==ticket and ticket.get("scope",[])==[world.get_instance_id(),int(world.generation),int(world.area_id)] and source_rows.has(id) and source_rows[id].witness==witness
static func preview_inside(point: Vector3,minimum: Vector3,maximum: Vector3)->bool:
	return point.is_finite() and point.x>=minimum.x and point.x<=maximum.x and point.y>=minimum.y and point.y<=maximum.y
func query_preview(id: int,from: Vector3,target: Vector3,render: Vector3,radius_override: float=-1)->Callable:
	# Capture exactly the ordinary query's dimensions/ticket/witness. The first
	# probe is the original unrestricted call; free movement prepares no envelope.
	if not ready() or not source_rows.has(id):return Callable()
	var dims:=dimensions(id);var radius:=dims.x if radius_override<0 else radius_override
	var ticket:=spatial_ticket.duplicate(true);var witness: Array=source_rows[id].witness.duplicate()
	var transaction: Dictionary={"initial":true,"attempted":false,"view":{}}
	return func(a: Vector3,b: Vector3):
		preview_stats.probes+=1;DriveProfile.count("count_drive_preview_probes",1)
		if transaction.initial:
			transaction.initial=false;preview_stats.initial_clears+=1;DriveProfile.count("count_drive_preview_initial_clears",1)
			return indexed_clear(ticket,id,witness,a,b,radius,dims.y if radius_override<0 else radius_override,radius_override<0)
		if not transaction.attempted:
			transaction.attempted=true
			transaction.view=prepare_preview_view(ticket,id,witness,from,target,render,radius,radius_override<0)
		var view: Dictionary=transaction.view
		if not view.is_empty() and preview_geometry_current(ticket,id,witness,int(view.revision),int(view.published),int(view.frame)) and preview_inside(a,view.minimum,view.maximum) and preview_inside(b,view.minimum,view.maximum):
			preview_stats.reused_clears+=1;DriveProfile.count("count_drive_preview_reused_clears",1)
			return clear(a,b,radius,dims.y if radius_override<0 else radius_override,view.geometry.obstacles,view.geometry.creatures,view.geometry.pending,view.arithmetic,view.height_index)
		preview_stats.fallback_clears+=1;DriveProfile.count("count_drive_preview_fallback_clears",1)
		return indexed_clear(ticket,id,witness,a,b,radius,dims.y if radius_override<0 else radius_override,radius_override<0)

# Snapshot only the blocked, multi-probe case. The first clearance stays on
# the owner thread, preserving its exact unrestricted query and immediate free
# movement behavior. All copied worker values are plain arrays/dictionaries.
# A failed snapshot returns an empty packet and the caller retains the old path.
func _preview_worker_surface_cache(surface,definition: Dictionary,width: int,height: int) -> Dictionary:
	var cache: Dictionary=_worker_surface_cache
	if cache.is_empty() or cache.ref.get_ref()!=surface or not is_same(cache.definition,definition) or not is_same(cache.mesh_source,surface.meshes) or int(cache.width)!=width or int(cache.height)!=height or cache.rows.size()>PREVIEW_WORKER_CACHE_MAX_TILES or cache.meshes.size()>PREVIEW_WORKER_CACHE_MAX_TILES or int(cache.faces)>PREVIEW_WORKER_CACHE_MAX_FACES:
		# Replace the whole cache. A running worker can continue reading old
		# detached values held by its packet; no shared value is mutated.
		cache={"ref":weakref(surface),"definition":definition,"mesh_source":surface.meshes,"width":width,"height":height,"rows":{},"meshes":{},"triangles":{},"faces":0,"table":{}}
		_worker_surface_cache=cache;_worker_surface_cache_stats.resets+=1
	if cache.table!=surface.table:
		var began:=Time.get_ticks_usec()
		cache.table=surface.table.duplicate(true)
		_worker_surface_cache_stats.table_copies+=1;_worker_surface_cache_stats.copy_ms+=(Time.get_ticks_usec()-began)/1000.0
	else:_worker_surface_cache_stats.table_hits+=1
	return cache

func prepare_worker_preview(id: int,from: Vector3,target: Vector3,render: Vector3,radius_override: float=-1)->Dictionary:
	if not ready() or not source_rows.has(id):return {}
	var began:=Time.get_ticks_usec()
	var dims:=dimensions(id);var radius:=dims.x if radius_override<0 else radius_override
	var clear_query:=query_preview(id,from,target,render,radius_override)
	if not clear_query.is_valid():return {}
	var first_clear: bool=clear_query.call(from,target)
	if first_clear:return {"immediate":true,"path":{"target":target,"factor":1.0},"snapshot_ms":(Time.get_ticks_usec()-began)/1000.0}
	var first_reason: String=str(stats.get("last_blocked",{}).get("reason",""))
	var ticket:=spatial_ticket.duplicate(true);var witness: Array=source_rows[id].witness.duplicate()
	var view:=prepare_preview_view(ticket,id,witness,from,target,render,radius,radius_override<0)
	if view.is_empty():return {}
	var surface=world.surface
	if not is_instance_valid(surface) or not surface.ready():return {}
	var definition: Dictionary=surface.definition
	var width:=int(definition.width);var height:=int(definition.height)
	if width<=0 or height<=0 or not definition.get("tiles") is Array or definition.tiles.size()<width*height:return {}
	var minimum: Vector3=view.minimum;var maximum: Vector3=view.maximum
	var left:=maxi(0,floori((minimum.x-radius)/10));var right:=mini(width-1,floori((maximum.x+radius)/10))
	var bottom:=maxi(0,floori((minimum.y-radius)/10));var top:=mini(height-1,floori((maximum.y+radius)/10))
	if right<left or top<bottom or (right-left+1)*(top-bottom+1)>PREVIEW_WORKER_MAX_TILES:return {}
	var cache: Dictionary=_preview_worker_surface_cache(surface,definition,width,height) if _worker_surface_cache_enabled else {}
	var rows: Dictionary={};var triangles: Dictionary={};var meshes: Dictionary={};var faces:=0
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			var index:=y*width+x
			var source: Dictionary=definition.tiles[index]
			var key:=str(source.model)
			if not surface.meshes.has(key) or not surface.meshes[key] is Dictionary:return {}
			if _worker_surface_cache_enabled:
				if cache.rows.has(index) and cache.rows[index]==source:_worker_surface_cache_stats.tile_hits+=1
				else:
					var copy_began:=Time.get_ticks_usec();cache.rows[index]=source.duplicate(true)
					_worker_surface_cache_stats.tile_copies+=1;_worker_surface_cache_stats.copy_ms+=(Time.get_ticks_usec()-copy_began)/1000.0
				rows[index]=cache.rows[index]
			else:rows[index]=source.duplicate(true)
			if not meshes.has(key):
				if _worker_surface_cache_enabled:
					if cache.meshes.has(key) and cache.meshes[key]==surface.meshes[key]:_worker_surface_cache_stats.mesh_hits+=1
					else:
						var copy_began:=Time.get_ticks_usec();cache.meshes[key]=surface.meshes[key].duplicate(true)
						_worker_surface_cache_stats.mesh_copies+=1;_worker_surface_cache_stats.copy_ms+=(Time.get_ticks_usec()-copy_began)/1000.0
					meshes[key]=cache.meshes[key]
				else:meshes[key]=surface.meshes[key].duplicate(true)
			var prepared: Array=tile(index)
			faces+=prepared.size()
			if faces>PREVIEW_WORKER_MAX_FACES:return {}
			if _worker_surface_cache_enabled:
				if cache.triangles.has(index) and cache.triangles[index]==prepared:_worker_surface_cache_stats.tile_hits+=1
				else:
					var copy_began:=Time.get_ticks_usec()
					if cache.triangles.has(index):cache.faces-=cache.triangles[index].size()
					cache.triangles[index]=prepared.duplicate(true);cache.faces+=prepared.size()
					_worker_surface_cache_stats.tile_copies+=1;_worker_surface_cache_stats.copy_ms+=(Time.get_ticks_usec()-copy_began)/1000.0
				triangles[index]=cache.triangles[index]
			else:triangles[index]=prepared.duplicate(true)
	var surface_copy:={"width":width,"height":height,"tiles":rows,"meshes":meshes,"table":cache.table if _worker_surface_cache_enabled else surface.table.duplicate(true),"triangles":triangles}
	var packet:={"from":from,"target":target,"render":render,"minimum":minimum,"maximum":maximum,"radius":radius,"height":dims.y if radius_override<0 else radius_override,"include_creatures":radius_override<0,"first_clear":false,"first_reason":first_reason,"geometry":view.geometry.duplicate(true),"surface":surface_copy}
	return {"packet":packet,"ticket":ticket,"witness":witness,"id":id,"revision":int(view.revision),"published":int(view.published),"surface_ref":weakref(surface),"snapshot_ms":(Time.get_ticks_usec()-began)/1000.0,"faces":faces,"tiles":rows.size()}

# This check intentionally does more than compare Dictionary/Array identity.
# Original WOK vertices and object bindings can be edited in place; a worker
# result is accepted only when the copied source and current selected geometry
# are still exactly equal. Caller must additionally check its input serial and
# controlled-motion state before applying an asynchronous result.
func worker_preview_current(snapshot: Dictionary)->bool:
	if snapshot.is_empty() or not snapshot.has("packet") or not ready():return false
	var ticket: Dictionary=snapshot.ticket;var id: int=snapshot.id;var witness: Array=snapshot.witness
	if not preview_revision_valid or preview_revision!=int(snapshot.revision) or publication_revision!=int(snapshot.published) or spatial_ticket!=ticket:return false
	if ticket.get("scope",[])!=[world.get_instance_id(),int(world.generation),int(world.area_id)] or not source_rows.has(id) or source_rows[id].witness!=witness:return false
	var surface=snapshot.surface_ref.get_ref()
	if not is_instance_valid(surface) or surface!=world.surface or not surface.ready():return false
	var copy: Dictionary=snapshot.packet.surface
	if int(surface.definition.width)!=int(copy.width) or int(surface.definition.height)!=int(copy.height) or surface.table!=copy.table:return false
	if surface.definition.tiles.size()<int(copy.width)*int(copy.height):return false
	for index in copy.tiles:
		if surface.definition.tiles[index]!=copy.tiles[index]:return false
	for key in copy.meshes:
		if not surface.meshes.has(key) or surface.meshes[key]!=copy.meshes[key]:return false
	for index in copy.triangles:
		if not tiles.has(index) or tiles[index]!=copy.triangles[index]:return false
	var view:=prepare_preview_view(ticket,id,witness,snapshot.packet.from,snapshot.packet.target,snapshot.packet.render,float(snapshot.packet.radius),bool(snapshot.packet.include_creatures))
	return not view.is_empty() and view.geometry==snapshot.packet.geometry and view.minimum==snapshot.packet.minimum and view.maximum==snapshot.packet.maximum
func prepare_preview_view(ticket: Dictionary,id: int,witness: Array,from: Vector3,target: Vector3,render: Vector3,radius: float,include_creatures: bool)->Dictionary:
	if not from.is_finite() or not target.is_finite() or not render.is_finite() or not is_finite(radius) or radius<0:return {}
	var revision:=preview_revision;var published:=publication_revision;var frame:=Engine.get_process_frames()
	if not preview_geometry_current(ticket,id,witness,revision,published,frame):return {}
	var length:=preload("res://systems/network_motion.gd").length32(target-from)
	if not is_finite(length):return {}
	# Generous ordinary-input envelope. Correctness never relies on a normalizer
	# rounding bound: every actual endpoint is checked below, and escapes use the
	# unchanged unrestricted query. Z is intentionally not used for broadphase.
	var magnitude:=1.0
	for coordinate in [from.x,from.y,target.x,target.y,render.x,render.y]:magnitude=maxf(magnitude,absf(coordinate))
	var reach:=float(length)*2.0+magnitude*0.00001+0.0001
	if not is_finite(reach):return {}
	var minimum:=Vector3(minf(from.x,minf(target.x,render.x-reach)),minf(from.y,minf(target.y,render.y-reach)),0)
	var maximum:=Vector3(maxf(from.x,maxf(target.x,render.x+reach)),maxf(from.y,maxf(target.y,render.y+reach)),0)
	if not minimum.is_finite() or not maximum.is_finite():return {}
	# These are the actual float32 synthetic query endpoints. The containment
	# test uses precisely these bounds, including any outward/inward rounding.
	var began:=DriveProfile.begin();var geometry:=collect_preview_geometry(ticket,id,minimum,maximum,radius,include_creatures)
	DriveProfile.finish("drive_preview_collection",began);DriveProfile.count("count_drive_preview_collections",1)
	preview_stats.collections+=1
	if not geometry.get("ready",false) or not preview_geometry_current(ticket,id,witness,revision,published,frame):
		preview_stats.collection_failures+=1;return {}
	var arithmetic: PreviewArithmetic=null
	if PreviewArithmetic.worthwhile(world.surface,minimum,maximum):
		arithmetic=PreviewArithmetic.new();arithmetic.configure(from,world.surface,preview_stats)
	var height_index: HeightIndex=null
	if _preview_height_index_enabled and not _height_plan_enabled and HeightIndex.worthwhile(world.surface,minimum,maximum):
		height_index=HeightIndex.new()
		if not height_index.configure(world.surface):height_index=null
	return {"minimum":minimum,"maximum":maximum,"revision":revision,"published":published,"frame":frame,"geometry":geometry,"arithmetic":arithmetic,"height_index":height_index}
func collect_preview_geometry(ticket: Dictionary,id: int,minimum: Vector3,maximum: Vector3,radius: float,include_creatures: bool)->Dictionary:
	var phase_began:=DriveProfile.begin()
	var candidates:=spatial.query_flat_control(ticket,minimum,maximum,radius,id,include_creatures) if retained_flat_control else spatial.query(ticket,minimum,maximum,radius,id,include_creatures)
	DriveProfile.finish("drive_dynamic_query_ms",phase_began)
	if not candidates.ready:return {"ready":false}
	phase_began=DriveProfile.begin()
	var statics:=static_candidates(minimum,maximum,radius,id)
	DriveProfile.finish("drive_static_query_ms",phase_began)
	if not statics.ready:return {"ready":false}
	phase_began=DriveProfile.begin()
	candidates.rows.append_array(statics.rows)
	candidates.rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.order)<int(b.order))
	DriveProfile.finish("drive_candidate_sort_ms",phase_began)
	DriveProfile.count("count_drive_candidate_inputs",candidates.rows.size())
	stats.broadphase_queries=int(stats.get("broadphase_queries",0))+1
	stats.broadphase_candidates=int(stats.get("broadphase_candidates",0))+candidates.rows.size()
	var obstacles: Array=[];var creatures: Array=[];var pending: Array=[]
	phase_began=DriveProfile.begin()
	for selected in candidates.rows:
		var key:=int(selected.id)
		if not source_rows.has(key) or source_rows[key].witness!=selected.witness:
			DriveProfile.finish("drive_shape_prepare_ms",phase_began);return {"ready":false}
		var binding: Dictionary=source_rows[key]
		if selected.kind=="pending":pending.append(binding.point)
		elif selected.kind=="creature":creatures.append({"point":binding.point,"radius":float(binding.published_radius)+radius})
		else:
			var version:=int(model_versions.get(str(binding.model_key),0))
			if int(binding.get("precise_version",-1))!=version:objects.erase(key);binding.precise_version=version
			var shape:=obstacle(key,binding.object,binding.spec)
			if shape.get("pending",false):
				DriveProfile.finish("drive_shape_prepare_ms",phase_began);return {"ready":false}
			if not shape.is_empty() and not shape.triangles.is_empty():obstacles.append(shape)
	DriveProfile.finish("drive_shape_prepare_ms",phase_began)
	return {"ready":true,"obstacles":obstacles,"creatures":creatures,"pending":pending}

func query(id: int,radius_override: float=-1) -> Callable:
	if not ready() or not source_rows.has(id): return Callable()
	var dims:=dimensions(id); var radius:=dims.x if radius_override<0 else radius_override
	var ticket:=spatial_ticket.duplicate(true)
	var witness: Array=source_rows[id].witness.duplicate()
	return func(from: Vector3,to: Vector3):
		return indexed_clear(ticket,id,witness,from,to,radius,dims.y if radius_override<0 else radius_override,radius_override<0)
func indexed_clear(ticket: Dictionary,id: int,witness: Array,from: Vector3,to: Vector3,radius: float,height: float,include_creatures: bool)->bool:
	if not ready() or ticket!=spatial_ticket or not source_rows.has(id) or source_rows[id].witness!=witness:return false
	var geometry:=collect_preview_geometry(ticket,id,from,to,radius,include_creatures)
	if not geometry.ready:return false
	return clear(from,to,radius,height,geometry.obstacles,geometry.creatures,geometry.pending)
func static_candidates(from: Vector3,to: Vector3,radius: float,exclude: int)->Dictionary:
	DriveProfile.count("count_drive_model_group_inputs",static_groups.size())
	var result:={"ready":true,"rows":[]}
	var min_x:=minf(from.x,to.x);var max_x:=maxf(from.x,to.x)
	var min_y:=minf(from.y,to.y);var max_y:=maxf(from.y,to.y)
	for model_key in static_groups:
		var group: Dictionary=static_groups[model_key]
		var bounds: Dictionary=group.bounds
		if bounds.is_empty():continue
		var pending: bool=not models.has(model_key)
		if not pending:
			var model: Dictionary=models[model_key]
			pending=model.is_empty() or model.has("error")
		var states: Array=model_bounds.get(model_key,EMPTY_MODEL_BOUNDS)
		var footprint:=12.0 if pending else 0.0
		if not pending:
			for state in states:
				if state.get("pending",false):result.ready=false;return result
				footprint=maxf(footprint,float(state.get("radius",0)))
		var expansion:=footprint+(0.0 if pending else radius)
		if not pending:
			var magnitude:=maxf(1.0,footprint)
			# Same bound/float/maxf order, without a temporary Array or a second
			# set of Dictionary reads in the overlap test. No cross-query cache.
			var group_min_x:=float(bounds.min_x);var group_min_y:=float(bounds.min_y)
			var group_max_x:=float(bounds.max_x);var group_max_y:=float(bounds.max_y)
			magnitude=maxf(magnitude,absf(group_min_x));magnitude=maxf(magnitude,absf(group_min_y))
			magnitude=maxf(magnitude,absf(group_max_x));magnitude=maxf(magnitude,absf(group_max_y))
			expansion+=magnitude*0.000003814697265625
			if group_min_x>max_x+expansion or group_max_x<min_x-expansion or group_min_y>max_y+expansion or group_max_y<min_y-expansion:continue
		elif float(bounds.min_x)>max_x+expansion or float(bounds.max_x)<min_x-expansion or float(bounds.min_y)>max_y+expansion or float(bounds.max_y)<min_y-expansion:continue
		var selected: Dictionary=group.index.query_flat_control(group.ticket,from,to,expansion,exclude,false) if retained_flat_control else group.index.query(group.ticket,from,to,expansion,exclude,false)
		if not selected.ready:result.ready=false;return result
		for row in selected.rows:
			var binding: Dictionary=source_rows.get(int(row.id),{})
			if binding.is_empty() or binding.witness!=row.witness:result.ready=false;return result
			if pending:row.kind="pending";result.rows.append(row);continue
			var state_index:=int(binding.spec.state) if binding.spec.door else 0
			if state_index<0 or state_index>=states.size() or states[state_index].get("empty",false):continue
			var signature: Array=[model_key,int(model_versions.get(model_key,0)),state_index,binding.pose.position,binding.pose.rotation]
			if binding.get("bounds_signature",[])!=signature:
				binding.world_bounds=world_bounds(states[state_index],binding.pose);binding.bounds_signature=signature
			var box: Dictionary=binding.world_bounds
			if box.min.x>max_x+radius or box.max.x<min_x-radius or box.min.y>max_y+radius or box.max.y<min_y-radius:continue
			result.rows.append(row)
	return result
static func cross(a: Vector2,b: Vector2) -> float: return a.x*b.y-a.y*b.x
static func interval(from: Vector2,to: Vector2,tri: Dictionary) -> Vector2:
	# External/older triangle dictionaries retain the original uncached path.
	var cached: bool=tri.has("xy_points")
	var points: Array=tri.xy_points if cached else [Vector2(tri.a.x,tri.a.y),Vector2(tri.b.x,tri.b.y),Vector2(tri.c.x,tri.c.y)]
	var area: float=tri.xy_area if cached else cross(points[1]-points[0],points[2]-points[0])
	if absf(area)<0.0000001: return Vector2(1,-1)
	var low:=0.0; var high:=1.0; var sign_value:=1.0 if area>0 else -1.0
	for i in 3:
		var edge: Vector2=tri.xy_edges[i] if cached else points[(i+1)%3]-points[i]; var a:=sign_value*cross(edge,from-points[i]); var b:=sign_value*cross(edge,to-points[i]); var d:=b-a
		if absf(d)<0.0000001:
			if a< -0.00001: return Vector2(1,-1)
		elif d>0: low=maxf(low,-a/d)
		else: high=minf(high,-a/d)
	return Vector2(low,high)
static func point_distance(point: Vector2,a: Vector2,b: Vector2) -> float:
	var delta:=b-a; var t:=clampf((point-a).dot(delta)/delta.length_squared(),0,1) if delta.length_squared()>0 else 0.0
	return point.distance_squared_to(a+delta*t)
static func segment_distance(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> float:
	var den:=cross(b-a,d-c)
	if absf(den)>0.00000001:
		var t:=cross(c-a,d-c)/den; var u:=cross(c-a,b-a)/den
		if t>=0 and t<=1 and u>=0 and u<=1: return 0.0
	return minf(minf(point_distance(a,c,d),point_distance(b,c,d)),minf(point_distance(c,a,b),point_distance(d,a,b)))
static func hits(from: Vector2,to: Vector2,tri: Dictionary,radius: float,low: float,high: float) -> bool:
	if tri.max.z<low or tri.min.z>high: return false
	if maxf(from.x,to.x)+radius<tri.min.x or minf(from.x,to.x)-radius>tri.max.x or maxf(from.y,to.y)+radius<tri.min.y or minf(from.y,to.y)-radius>tri.max.y: return false
	var inside:=interval(from,to,tri)
	if inside.x<=inside.y and inside.y>=0 and inside.x<=1: return true
	var points: Array=tri.xy_points if tri.has("xy_points") else [Vector2(tri.a.x,tri.a.y),Vector2(tri.b.x,tri.b.y),Vector2(tri.c.x,tri.c.y)]
	for i in 3:
		if segment_distance(from,to,points[i],points[(i+1)%3])<radius*radius: return true
	return false
func clear(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array,arithmetic: PreviewArithmetic=null,height_index: HeightIndex=null) -> bool:
	DriveProfile.count("count_drive_clear_calls",1)
	var began:=DriveProfile.begin()
	if arithmetic!=null and not arithmetic.accepts(world.surface,from):arithmetic=null
	var result:=_clear_geometry(from,to,radius,height,obstacles,creatures,pending,arithmetic,height_index)
	if arithmetic!=null:arithmetic.publish()
	DriveProfile.finish("drive_clear_total_ms",began)
	return result
func _clear_geometry(from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array,creatures: Array,pending: Array,arithmetic: PreviewArithmetic=null,height_index: HeightIndex=null) -> bool:
	stats.queries+=1
	var phase_began:=DriveProfile.begin()
	var a:=Vector2(from.x,from.y); var b:=Vector2(to.x,to.y)
	for p in pending:
		if point_distance(p,a,b)<144:
			DriveProfile.finish("drive_clear_prefix_ms",phase_began);return deny("pending_object",from,to)
	for creature in creatures:
		if point_distance(creature.point,a,b)<=float(creature.radius)*float(creature.radius):
			DriveProfile.finish("drive_clear_prefix_ms",phase_began);return deny("creature",from,to)
	DriveProfile.finish("drive_clear_prefix_ms",phase_began)
	phase_began=DriveProfile.begin()
	var start_z: float
	if arithmetic!=null:start_z=arithmetic.start_height(world.surface,from,from.z)
	else:DriveProfile.count("count_drive_height_samples",1);start_z=_drive_height(world.surface,from,from.z) if _height_plan_enabled else world.surface.height(from,from.z)
	var end_z: float=height_index.height(world.surface,to,from.z) if height_index!=null else _drive_height(world.surface,to,from.z) if _height_plan_enabled else world.surface.height(to,from.z);DriveProfile.count("count_drive_height_samples",1)
	var low:=minf(start_z,end_z)-0.1; var high:=maxf(start_z,end_z)+height+0.1
	DriveProfile.finish("drive_height_ms",phase_began);DriveProfile.count("count_drive_height_queries",2)
	phase_began=DriveProfile.begin()
	var intervals: Array=[];var coverage_pending: Array=[];var coverage_end:=0.0;var coverage_tracking:=true
	var floor_complete:=false;var skipped_walkable:=0;var definition: Dictionary=world.surface.definition
	var left:=maxi(0,floori((minf(a.x,b.x)-radius)/10)); var right:=mini(int(definition.width)-1,floori((maxf(a.x,b.x)+radius)/10))
	var bottom:=maxi(0,floori((minf(a.y,b.y)-radius)/10)); var top:=mini(int(definition.height)-1,floori((maxf(a.y,b.y)+radius)/10))
	for y in range(bottom,top+1):
		for x in range(left,right+1):
			var tile_index:=y*int(definition.width)+x
			var triangle_inputs: Array=tile(tile_index)
			var terms: Variant=arithmetic.tile_terms(tile_index,triangle_inputs) if arithmetic!=null else null
			DriveProfile.count("count_drive_tile_triangle_inputs",triangle_inputs.size())
			for triangle_index in triangle_inputs.size():
				var tri: Dictionary=triangle_inputs[triangle_index]
				if tri.walk:
					# A connected union reaching the original endpoint proves floor
					# coverage. Keep visiting every nonwalkable face: coverage cannot
					# hide a blocking polygon. The small pending set bounds extra work;
					# unusual face order falls back to the original complete sort.
					if floor_complete:skipped_walkable+=1;continue
					var span: Vector2=terms.interval(a,b,triangle_index,tri) if terms!=null and tri.has("xy_points") else interval(a,b,tri)
					if span.x<=span.y:
						if span.y<=coverage_end:continue
						if coverage_tracking:
							if span.x<=coverage_end+0.00001:
								coverage_end=maxf(coverage_end,span.y)
								var pending_index:=0
								while pending_index<coverage_pending.size():
									var pending_span: Vector2=coverage_pending[pending_index]
									if pending_span.x<=coverage_end+0.00001:
										coverage_end=maxf(coverage_end,pending_span.y);coverage_pending.remove_at(pending_index);pending_index=0
									else:pending_index+=1
								floor_complete=coverage_end>=0.99999
							elif coverage_pending.size()<8:coverage_pending.append(span)
							else:coverage_tracking=false;coverage_pending.clear()
						if not floor_complete:intervals.append(span)
				elif hits(a,b,tri,radius,low,high):
					DriveProfile.count("count_drive_walkable_intervals_skipped",skipped_walkable)
					DriveProfile.finish("drive_tile_coverage_ms",phase_began);return deny("tile_polygon",from,to)
	DriveProfile.count("count_drive_walkable_intervals_skipped",skipped_walkable)
	var end:=1.0 if floor_complete else 0.0
	if not floor_complete:
		intervals.sort_custom(func(x,y):return x.x<y.x)
		for span in intervals:
			if span.x>end+0.00001: break
			end=maxf(end,span.y)
	DriveProfile.finish("drive_tile_coverage_ms",phase_began)
	if end<0.99999: return deny("floor_coverage",from,to)
	phase_began=DriveProfile.begin()
	for shape in obstacles:
		if maxf(a.x,b.x)+radius<shape.min.x or minf(a.x,b.x)-radius>shape.max.x or maxf(a.y,b.y)+radius<shape.min.y or minf(a.y,b.y)-radius>shape.max.y: continue
		DriveProfile.count("count_drive_obstacle_triangle_inputs",shape.triangles.size())
		for tri in shape.triangles:
			if hits(a,b,tri,radius,low,high):
				DriveProfile.finish("drive_obstacle_triangles_ms",phase_began);return deny("object_polygon",from,to)
	DriveProfile.finish("drive_obstacle_triangles_ms",phase_began)
	return true
func snapshot() -> Dictionary:
	var state:=stats.duplicate(true); state.pending=requests.size(); state.ready=ready() if not closed else false
	state.reindex_fallbacks=reindex_fallbacks.duplicate(true)
	state.spatial=spatial.snapshot();state.source_errors=source_errors.duplicate();state.sources=source_rows.size();state.model_users=model_users.size();state.queued_models=model_queue.size()
	state.static_groups=static_groups.size();state.static_entries=0;state.static_last_bulk_ms=0.0
	state.preview_geometry=preview_stats.duplicate()
	if _worker_surface_cache_enabled:
		state.preview_worker_surface_cache=_worker_surface_cache_stats.duplicate()
		state.preview_worker_surface_cache.merge({"tiles":_worker_surface_cache.get("rows",{}).size(),"meshes":_worker_surface_cache.get("meshes",{}).size(),"faces":int(_worker_surface_cache.get("faces",0))})
	if _height_plan_enabled:state.height_plan=_height_plan_stats.duplicate()
	state.preview_height_index={"requested":_preview_height_index_enabled,"active":_preview_height_index_enabled and not _height_plan_enabled,"builds_process":HeightIndex.total_builds,"samples_process":HeightIndex.total_samples,"fallbacks_process":HeightIndex.total_fallbacks,"mutation_fallbacks_process":HeightIndex.mismatch_fallbacks,"scope":"Process totals for opt-in repeated preview end-height index; compare deltas within one isolated client."}
	for group in static_groups.values():
		var info: Dictionary=group.index.snapshot()
		state.static_entries+=int(info.entries);state.static_last_bulk_ms+=float(info.last_bulk_ms)
	return state
func detach_prepared_data() -> Dictionary:
	var payload:={"tables":tables.duplicate(),"models":models.duplicate(),"tiles":tiles.duplicate(),"objects":objects.duplicate(),"model_bounds":model_bounds.duplicate()}
	tables={}; models={}; tiles={}; objects={};model_bounds={};_worker_surface_cache={}; return payload
func close() -> void:
	if closed: return
	closed=true
	if _height_plan_worker!=null:_height_plan_worker.wait_to_finish();_height_plan_worker=null
	_height_plan.clear();_height_plan_source.clear()
	retire_index()
	if is_instance_valid(assets): assets.close()
	requests.clear(); models.clear();model_bounds.clear();model_versions.clear();pending_models.clear();objects.clear(); tiles.clear(); tables.clear(); world=null
func _exit_tree() -> void: close()
