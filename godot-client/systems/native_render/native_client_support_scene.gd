extends RefCounted
# Scoped adapter for native_client_support's client-height controller. The
# existing World/SceneGeometry owners retain all entities, geometry and poses.
# Root must supply published-static-scene availability/revision at existing
# boundaries. This is not a complete-assets/final-appearance readiness gate.
const Support=preload("res://systems/native_data/native_client_support.gd")
const SceneHit=preload("res://systems/native_render/projectile_scene.gd")
var _world: WeakRef
var _world_id:=0
var _generation:=-1
var _area_id:=-1
var _scope_guard: Callable
var _scene_ready: Callable
var _configured:=false
var _retired:=false
var _busy:=false
var _reuse_tile_witness:=false
var _query_revision:=-1
var _current_revision:=-1
var _reason:="Unconfigured client support scene"
var _stats:={"queries":0,"available":0,"unavailable":0,"scope_checks":0,"tile_queries":0,"rays":0,"last_branch":"","last_reason":""}

static func main_thread() -> bool:
	return OS.get_thread_caller_id()==OS.get_main_thread_id()

func configure(owner: Node,scope_guard: Callable,scene_ready: Callable) -> bool:
	if not main_thread() or _configured or _retired: return false
	if not is_instance_valid(owner) or not scope_guard.is_valid() or not scene_ready.is_valid(): return false
	if not owner.get("generation") is int or not owner.get("area_id") is int: return false
	_world=weakref(owner); _world_id=owner.get_instance_id()
	_generation=int(owner.get("generation")); _area_id=int(owner.get("area_id"))
	_reuse_tile_witness=OS.get_cmdline_user_args().has("--client-support-reuse-tile-witness")
	_scope_guard=scope_guard; _scene_ready=scene_ready; _configured=true; _reason=""
	return true

func _same_world(owner: Node) -> bool:
	return not _retired and is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.get_instance_id()==_world_id and owner.get("generation")==_generation and owner.get("area_id")==_area_id and owner.get("closed")==false and owner.get("retiring")==false

func _checked_world(revision: int=-1) -> Node:
	_stats.scope_checks+=1
	if not _configured or _retired or _world==null: _reason="Client support binding retired/unconfigured"; return null
	var owner: Node=_world.get_ref() as Node
	if not _same_world(owner): _reason="Client support world lifetime changed"; return null
	if not _scope_guard.is_valid() or not _scene_ready.is_valid(): _reason="Client support scope/readiness callback unavailable"; return null
	var current: Variant=_scope_guard.call()
	if not current is bool or not current or not _same_world(owner): _reason="Client support connection/scope changed"; return null
	var witness: Variant=_scene_ready.call()
	if not _same_world(owner): _reason="Client support world changed during readiness"; return null
	if not witness is Dictionary or not witness.get("available") is bool: _reason="Malformed client support readiness witness"; return null
	if not witness.available: _reason=str(witness.get("reason","Client support geometry not prepared")); return null
	if witness.get("scope")!="published-static-scene": _reason="Client support published-scene witness unavailable"; return null
	if not witness.get("revision") is int or int(witness.revision)<0: _reason="Client support source revision unavailable"; return null
	_current_revision=int(witness.revision)
	if revision>=0 and revision!=_current_revision: _reason="Client support source changed during projection"; return null
	_reason=""
	return owner

func _unavailable() -> Dictionary:
	return {"available":false,"reason":_reason}

func _tile(point: Vector3) -> Variant:
	var owner: Node
	if _reuse_tile_witness and _busy and _query_revision>=0:
		# The query validated the published scene before entering project().
		# Tile lookup only reads its definition. The next ray validates the
		# revision before touching geometry, and query() validates it again
		# before returning even when the tile branch has no ray.
		if _world!=null: owner=_world.get_ref() as Node
		if not _same_world(owner) or not _scope_guard.is_valid() or not _scene_ready.is_valid():
			_reason="Client support binding retired/changed during tile lookup"; return _unavailable()
		var current: Variant=_scope_guard.call()
		if not current is bool or not current or not _same_world(owner):
			_reason="Client support connection/scope changed during tile lookup"; return _unavailable()
	else:
		owner=_checked_world(_query_revision)
	if owner==null: return _unavailable()
	_stats.tile_queries+=1
	var surface: Variant=owner.get("surface")
	if not is_instance_valid(surface) or not surface.get("definition") is Dictionary:
		_reason="Client support tile definition unavailable"; return _unavailable()
	var definition: Dictionary=surface.get("definition")
	if not definition.get("width") is int or not definition.get("height") is int or not definition.get("tiles") is Array:
		_reason="Malformed client support tile definition"; return _unavailable()
	var x:=floori(point.x/10.0); var y:=floori(point.y/10.0)
	# Current GetTile bounds are the prepared area's own grid. The original
	# global coordinate-slot limit still requires its independent native gate;
	# unsupported >32 layouts remain explicit rather than guessed.
	if int(definition.width)>32 or int(definition.height)>32:
		_reason="Client support original coordinate-slot coverage unverified"; return _unavailable()
	if x<0 or y<0 or x>=int(definition.width) or y>=int(definition.height): return false
	var index:=y*int(definition.width)+x
	if index<0 or index>=definition.tiles.size() or not definition.tiles[index] is Dictionary:
		_reason="Client support tile slot not prepared"; return _unavailable()
	return true

static func vector_value(value: Variant) -> Variant:
	if not value is Array or value.size()!=3: return null
	for component in value:
		if not (component is float or component is int) or not is_finite(float(component)): return null
	var point:=Vector3(float(value[0]),float(value[1]),float(value[2]))
	return point if point.is_finite() else null

func _trace(start: Vector3,end: Vector3) -> Dictionary:
	var owner:=_checked_world(_query_revision)
	if owner==null: return _unavailable()
	_stats.rays+=1
	# Same existing static scene mask/mode adaptation: original WOK + terrain
	# physical MDL + published static model Parts, using current transforms.
	var hit: Dictionary=SceneHit.trace(owner,[start.x,start.y,start.z],[end.x,end.y,end.z],true,true)
	if _checked_world(_query_revision)==null: return _unavailable()
	if not hit.get("hit") is bool: _reason="Malformed static scene support response"; return _unavailable()
	if not hit.hit: return {"available":true,"hit":false}
	var position: Variant=vector_value(hit.get("position")); var normal: Variant=vector_value(hit.get("normal"))
	if position==null or normal==null: _reason="Malformed static scene support geometry"; return _unavailable()
	return {"available":true,"hit":true,"position":position,"normal":normal}

func query(candidate: Vector3,previous: float) -> Dictionary:
	if not main_thread(): return Support.unavailable(candidate,previous,"Client support query requires main thread")
	_stats.queries+=1
	if _busy:
		_stats.unavailable+=1; _stats.last_reason="Nested client support query"
		return Support.unavailable(candidate,previous,_stats.last_reason)
	_busy=true
	var owner:=_checked_world()
	if owner==null: return _finish(Support.unavailable(candidate,previous,_reason))
	_query_revision=_current_revision
	# The witness describes the scene actually published now, including any
	# retained old instance during replacement. It need not wait for far assets
	# or all desired entities. Missing owners are not a native null scene.
	if not is_instance_valid(owner.get("terrain")) or not is_instance_valid(owner.get("surface")):
		return _finish(Support.unavailable(candidate,previous,"Client support scene owners unavailable"))
	var result: Dictionary=Support.project(candidate,previous,{"available":true,"area_present":true,"scene_present":true,"tile":_tile,"trace":_trace})
	if _checked_world(_query_revision)==null: result=Support.unavailable(candidate,previous,_reason)
	return _finish(result)

func _finish(result: Dictionary) -> Dictionary:
	_busy=false; _query_revision=-1
	if result.get("available",false):
		_stats.available+=1; _stats.last_branch=str(result.get("branch","")); _stats.last_reason=""
	else:
		_stats.unavailable+=1; _stats.last_branch=""; _stats.last_reason=str(result.get("reason","Client support unavailable"))
	return result

func retire() -> bool:
	if not main_thread(): return false
	_retired=true; _world=null; _scope_guard=Callable(); _scene_ready=Callable()
	_reason="Client support binding retired"
	return true

func snapshot() -> Dictionary:
	if not main_thread(): return {"available":false,"reason":"Client support snapshot requires main thread"}
	var result: Dictionary=_stats.duplicate()
	result.merge({"configured":_configured,"retired":_retired,"world_instance":_world_id,"generation":_generation,"area_id":_area_id,"scope":"Existing static SceneGeometry adaptation; readiness/revision supplied by authoritative world owner; no world store"})
	return result
