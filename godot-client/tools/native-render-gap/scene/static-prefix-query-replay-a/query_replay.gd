extends RefCounted
# PRIVATE SOURCE ONLY. No driver/activation seam. Actual same-process queries
# only; never manufacture/replay frontend movement IDs or move scene objects.
const MAX_QUERIES:=128
const ARGUMENT_BYTES:=40 # f32*6 + f64 radius + signed i64 exclude.
const MAX_RESULT_BYTES:=16*1024*1024
var _owner: WeakRef
var _owner_id:=0
var _connection:=0
var _ticket: Dictionary={}
var _scope: PackedByteArray=PackedByteArray()
var _records: Array=[]
var _seen:=0
var _capped:=0
var _capturing:=false
var _sealed:=false
var _inside_replay:=false
var _failed:=false
var _errors: Array=[]
var _actor: PackedByteArray=PackedByteArray()
var _camera: PackedByteArray=PackedByteArray()
var _geometry: PackedByteArray=PackedByteArray()
var _phase:=""
var _cursor:=0
var _passes: Dictionary={}
func _main()->bool:return OS.get_thread_caller_id()==OS.get_main_thread_id()
func _reject(reason: String)->Dictionary:
	_failed=true;_capturing=false;_inside_replay=false
	if _errors.size()<16:_errors.append(reason)
	return {"accepted":false,"reason":reason}
static func encode_arguments(from: Vector3,to: Vector3,radius: float,exclude: int)->PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(ARGUMENT_BYTES)
	for index in 3:bytes.encode_float(index*4,from[index]);bytes.encode_float(12+index*4,to[index])
	bytes.encode_double(24,radius);bytes.encode_s64(32,exclude)
	return bytes
static func decode_arguments(bytes: PackedByteArray)->Dictionary:
	if bytes.size()!=ARGUMENT_BYTES:return {}
	return {"from":Vector3(bytes.decode_float(0),bytes.decode_float(4),bytes.decode_float(8)),"to":Vector3(bytes.decode_float(12),bytes.decode_float(16),bytes.decode_float(20)),"radius":bytes.decode_double(24),"exclude":bytes.decode_s64(32)}
func _same_owner(owner: Node)->bool:return is_instance_valid(owner) and _owner!=null and _owner.get_ref()==owner and owner.get_instance_id()==_owner_id
func _scope_bytes(owner: Node)->PackedByteArray:
	if not is_instance_valid(owner) or not is_instance_valid(owner.world):return PackedByteArray()
	var world=owner.world
	var scope: Array=owner.spatial_ticket.get("scope",[])
	if scope!=[world.get_instance_id(),int(world.generation),int(world.area_id)]:return PackedByteArray()
	var bytes:=PackedByteArray();bytes.resize(48)
	var values: Array=[owner.get_instance_id(),world.get_instance_id(),_connection,int(world.generation),int(world.area_id),int(owner.spatial_ticket.get("epoch",-1))]
	for index in values.size():bytes.encode_s64(index*8,int(values[index]))
	return bytes
func _witness(owner: Node,exclude: int)->PackedByteArray:
	if not owner.source_rows.has(exclude):return PackedByteArray()
	var value: Variant=owner.source_rows[exclude].get("witness")
	if not value is Array or value.size()!=2 or not value[0] is int or not value[1] is int:return PackedByteArray()
	var bytes:=PackedByteArray();bytes.resize(16);bytes.encode_s64(0,value[0]);bytes.encode_s64(8,value[1]);return bytes
func begin_capture(owner: Node,connection: int)->Dictionary:
	if not _main():return _reject("Main thread required")
	if _owner!=null or _capturing or _sealed:return _reject("One fresh helper per owner/session capture required")
	if not is_instance_valid(owner) or not is_instance_valid(owner.world) or not owner.ready():return _reject("Current ready indexed collision owner required")
	_owner=weakref(owner);_owner_id=owner.get_instance_id();_connection=connection;_ticket=owner.spatial_ticket.duplicate(true)
	_scope=_scope_bytes(owner)
	if _scope.size()!=48:return _reject("Current world/ticket scope unavailable")
	_capturing=true
	return {"accepted":true,"maximum_queries":MAX_QUERIES,"scope_hex":_scope.hex_encode()}
func capture_query(owner: Node,from: Vector3,to: Vector3,radius: float,exclude: int)->void:
	# Future opt-in entry hook calls this before the ORIGINAL prefix. Capturing
	# is disabled during replay; hook must never change original return behavior.
	if _inside_replay or not _capturing or _failed:return
	if not _main():_reject("Capture called off main thread");return
	if not _same_owner(owner) or _scope_bytes(owner)!=_scope or owner.spatial_ticket!=_ticket:_reject("Capture scope/owner retired");return
	_seen+=1
	if _records.size()>=MAX_QUERIES:_capped+=1;return
	if not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius<0:_reject("Actual query arguments outside finite nonnegative diagnostic domain");return
	var witness: PackedByteArray=_witness(owner,exclude)
	if witness.size()!=16:_reject("Actual exclusion source lifetime unavailable");return
	_records.append({"arguments":encode_arguments(from,to,radius,exclude),"witness":witness,"captured_frame":Engine.get_process_frames(),"ordinal":_seen})
func _queue_problem(owner: Node)->String:
	if not owner.ready() or owner.closed:return "Collision owner not ready"
	if owner.source_batch or not owner.dirty_groups.is_empty():return "Collision publication/batch in progress"
	if not owner.requests.is_empty() or not owner.pending_models.is_empty() or not owner.model_queue.is_empty() or not owner.wanted_models.is_empty():return "Collision model work remains queued"
	if not is_instance_valid(owner.assets) or owner.assets.closed or not owner.assets.pending.is_empty() or not owner.assets.running.is_empty():return "Collision asset worker work remains"
	return ""
func _actor_bytes(owner: Node)->PackedByteArray:
	var world=owner.world
	if not world.ready_for_control() or not world.motion.objects.has(world.controlled_id):return PackedByteArray()
	var state: Dictionary=world.motion.objects[world.controlled_id]
	if bool(state.get("active",true)) or int(state.get("script",-1))!=0 or bool(state.get("driveHeld",false)):return PackedByteArray()
	if not state.get("lifetime") is int or int(state.lifetime)<1:return PackedByteArray()
	if not state.get("position") is Vector3 or not state.get("render") is Vector3:return PackedByteArray()
	if not state.position.is_finite() or not state.render.is_finite():return PackedByteArray()
	var received: Variant=world.desired.get(world.controlled_id,{}).get("object",{}).get("replicated",{}).get("position")
	if not received is Array or received.size()!=3:return PackedByteArray()
	for coordinate in received:if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):return PackedByteArray()
	# Native same-process values; no JSON round trip, tolerance or pose writes.
	return var_to_bytes([int(world.controlled_id),int(state.get("lifetime",-1)),state.position,state.render,received.duplicate(),state.get("orientation"),state.get("targetOrientation"),state.get("path",[]).duplicate(true)])
func _geometry_bytes(owner: Node)->PackedByteArray:
	# Derived binding.world_bounds/signature, index last-query diagnostics and
	# profile counters intentionally excluded: actual prefix calls change them.
	return var_to_bytes([owner.spatial_ticket,int(owner.publication_revision),int(owner.preview_revision),owner.model_versions,owner.static_groups.size(),owner.source_rows.size()])
func _guard(owner: Node,context: Dictionary,check_sealed: bool)->String:
	if not _main():return "Replay requires main thread"
	if _failed:return "Helper already rejected"
	if not _same_owner(owner) or _scope_bytes(owner)!=_scope or owner.spatial_ticket!=_ticket:return "Same-process world/owner/ticket scope changed"
	if context.get("offline_replay")!=true or context.get("timeline_delivered")!=true or context.get("movement_gates_passed")!=true:return "Original offline timeline/acceptance gates not complete"
	if int(context.get("connection",-1))!=_connection:return "Session connection changed"
	if context.get("keyboard_released")!=true or context.get("all_scene_assets_idle")!=true:return "Input held or caller scene worker barrier absent"
	if not context.get("camera_signature") is PackedByteArray or context.camera_signature.is_empty():return "Current native camera signature required"
	var queued: String=_queue_problem(owner)
	if not queued.is_empty():return queued
	var actor: PackedByteArray=_actor_bytes(owner)
	if actor.is_empty():return "Controlled actor not idle/current"
	if check_sealed and actor!=_actor:return "Controlled actor received/simulation/render/lifetime changed"
	if check_sealed and context.camera_signature!=_camera:return "Terminal camera signature changed"
	if check_sealed and _geometry_bytes(owner)!=_geometry:return "Source/model geometry publication changed"
	for record in _records:
		var arguments: Dictionary=decode_arguments(record.arguments)
		if _witness(owner,int(arguments.exclude))!=record.witness:return "Captured exclusion lifetime changed"
	return ""
func seal_after_timeline(owner: Node,context: Dictionary)->Dictionary:
	_capturing=false
	if _records.is_empty():return _reject("No actual captured prefix queries")
	var problem: String=_guard(owner,context,false)
	if not problem.is_empty():return _reject(problem)
	if not owner.world.snapshot(false).get("object_visuals_complete",false):return _reject("Actual world visuals incomplete")
	_actor=_actor_bytes(owner);_camera=context.camera_signature.duplicate();_geometry=_geometry_bytes(owner);_sealed=true
	return {"accepted":true,"query_count":_records.size(),"seen":_seen,"capped":_capped,"arguments_sha256":_arguments_digest(),"scope_hex":_scope.hex_encode()}
func begin_pass(owner: Node,context: Dictionary,label: String)->Dictionary:
	if not _sealed or _inside_replay or label not in ["prewarm","measure"] or _passes.has(label):return _reject("Fresh sealed prewarm/measure pass required")
	if label=="measure" and (not _passes.has("prewarm") or not _passes.prewarm.get("complete",false)):return _reject("Identical full-corpus prewarm required before timing")
	var problem: String=_guard(owner,context,true)
	if not problem.is_empty():return _reject(problem)
	_phase=label;_cursor=0
	_passes[label]={"complete":false,"calls":0,"batches":0,"query_batch_wall_usec":0,"result_bytes":0,"rows":0,"ready":0,"result_sha256":[],"begin_process_frames":Engine.get_process_frames(),"begin_ticks_usec":Time.get_ticks_usec()}
	return {"accepted":true,"phase":label,"query_count":_records.size()}
func replay_batch(owner: Node,context: Dictionary,maximum_queries: int=4)->Dictionary:
	if not _sealed or _inside_replay or _phase.is_empty() or maximum_queries<1 or maximum_queries>4:return _reject("Bounded nonreentrant replay batch required")
	var metric: Dictionary=_passes[_phase]
	if metric.complete:return _reject("Pass already complete")
	var problem: String=_guard(owner,context,true)
	if not problem.is_empty():return _reject(problem)
	var count:=mini(maximum_queries,_records.size()-_cursor)
	var arguments_list: Array=[]
	var results: Array=[];results.resize(count)
	for offset in count:arguments_list.append(decode_arguments(_records[_cursor+offset].arguments))
	_inside_replay=true
	var began:=Time.get_ticks_usec()
	for offset in count:
		var arguments: Dictionary=arguments_list[offset]
		# Direct prefix API only. Never query()/query_preview() stale Callables,
		# session.walkTo(), preview_drive(), input messages, Node pose or camera.
		results[offset]=owner.static_candidates(arguments.from,arguments.to,float(arguments.radius),int(arguments.exclude))
	var elapsed:=Time.get_ticks_usec()-began
	_inside_replay=false
	# Wall time includes the identical small call/argument/result storage glue;
	# it is an owned query-batch measurement, not a pure native/kernel timer.
	metric.query_batch_wall_usec+=elapsed;metric.calls+=count;metric.batches+=1
	_cursor+=count
	problem=_guard(owner,context,true)
	if not problem.is_empty():return _reject(problem)
	for result in results:
		if not result is Dictionary or not result.get("rows") is Array:return _reject("Prefix returned invalid diagnostic result")
		if result.get("ready")!=true:return _reject("Actual loaded prefix returned unready")
		var bytes: PackedByteArray=var_to_bytes(result)
		metric.result_bytes+=bytes.size()
		if metric.result_bytes>MAX_RESULT_BYTES:return _reject("Bounded result observation exceeded")
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);metric.result_sha256.append(digest.finish().hex_encode())
		metric.rows+=result.rows.size();metric.ready+=int(bool(result.get("ready",false)))
	if _cursor==_records.size():
		metric.complete=true;metric.end_process_frames=Engine.get_process_frames();metric.end_ticks_usec=Time.get_ticks_usec()
		if _phase=="measure" and metric.result_sha256!=_passes.prewarm.result_sha256:return _reject("Loaded prefix results changed since same-corpus prewarm")
	return {"accepted":true,"complete":metric.complete,"phase":_phase,"calls":metric.calls,"batches":metric.batches}
func _arguments_digest()->String:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	for record in _records:digest.update(record.arguments)
	return digest.finish().hex_encode()
func corpus_copy()->Array:
	# Copies only primitive byte packets/counters, no scene/data Object references.
	var result: Array=[]
	for record in _records:result.append({"arguments":record.arguments.duplicate(),"witness":record.witness.duplicate(),"ordinal":record.ordinal,"captured_frame":record.captured_frame})
	return result
func snapshot()->Dictionary:
	var arguments_hex: Array=[]
	for record in _records:arguments_hex.append(record.arguments.hex_encode())
	return {"failed":_failed,"errors":_errors.duplicate(),"capturing":_capturing,"sealed":_sealed,"replaying":_inside_replay,"seen":_seen,"capped":_capped,"query_count":_records.size(),"arguments_sha256":_arguments_digest(),"arguments_hex":arguments_hex,"scope_hex":_scope.hex_encode(),"passes":_passes.duplicate(true),"scope":"Private exact-argument loaded-geometry PREFIX query diagnostic. Derived collision caches/index diagnostics/counters change. No warmed walking/authority/public-server/FPS/native-parity claim."}
