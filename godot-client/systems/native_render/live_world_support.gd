extends "res://systems/native_render/live_world_quiescent_candidate.gd"
# Native client support projection over published tile/initial-static Parts.
# Navigation and received server positions stay with their existing owners.
# Exact BSP tie order and uncommon model subtypes remain explicit limitations.
const SupportScene=preload("res://systems/native_render/native_client_support_scene_box.gd")
var client_support_scene
var client_support_revision:=0
var _support_terrain_id:=0
var _support_terrain_revision:=-1
var _support_writer_depth:=0
var _received_perception_started:=false
var _received_perception_objects: Array=[]
var _received_perception_controlled:=-1

func received_snapshot_scope_begin(objects: Array,controlled: int) -> void:
	_support_writer_depth+=1;client_support_revision+=1
	_received_perception_started=false
	_received_perception_objects=objects;_received_perception_controlled=controlled
	super.received_snapshot_scope_begin(objects,controlled)

func received_snapshot_scope_step() -> bool:
	if not super.received_snapshot_scope_step():return false
	if not is_instance_valid(effects):return true
	if not _received_perception_started:
		_received_perception_started=true
		effects.begin_received_perception(_received_perception_objects,_received_perception_controlled)
	return effects.received_perception_step()

func received_snapshot_scope_end(objects: Array,controlled: int,completed: bool) -> void:
	if not completed and is_instance_valid(effects):effects.cancel_received_perception()
	super.received_snapshot_scope_end(objects,controlled,completed)
	client_support_revision+=1;_support_writer_depth-=1
	_received_perception_started=false
	_received_perception_objects=[];_received_perception_controlled=-1

func open(source,area: Dictionary,epoch: int,cache_directory: String,shared_pool=null,entry: Dictionary={}) -> void:
	super.open(source,area,epoch,cache_directory,shared_pool,entry)
	if closed or retiring:return
	_bind_client_support()

func _bind_client_support() -> bool:
	if closed or retiring:return false
	client_support_scene=SupportScene.new()
	if client_support_scene.configure(self,_support_scope,_support_witness):
		motion.support_query=client_support_scene.query
		return true
	return false

func _support_scope() -> bool:
	return not closed and not retiring and is_inside_tree() and not is_queued_for_deletion()

func _support_witness() -> Dictionary:
	if not _support_scope() or _support_writer_depth>0 or not is_instance_valid(surface) or not surface.ready() or not is_instance_valid(terrain):
		return {"available":false,"reason":"Published terrain/scene scope is unavailable"}
	# Terrain owns its collision publication index. Observe its retained serial,
	# never count or scan the desired world to guess whether geometry is final.
	var index=terrain.collision_index
	if index==null:return {"available":false,"reason":"Published terrain index unavailable"}
	var index_id: int=int(index.get_instance_id())
	var revision:=int(index.serial)
	if index_id!=_support_terrain_id or revision!=_support_terrain_revision:
		_support_terrain_id=index_id;_support_terrain_revision=revision
		client_support_revision+=1
	return {"available":true,"scope":"published-static-scene","revision":client_support_revision}

func receive(objects: Array,controlled: int) -> void:
	_support_writer_depth+=1
	client_support_revision+=1
	super.receive(objects,controlled)
	if is_instance_valid(effects):effects.observe_perception(objects,controlled)
	client_support_revision+=1
	_support_writer_depth-=1

func receive_delta(objects: Array,removed: Array,controlled: int) -> void:
	_support_writer_depth+=1
	client_support_revision+=1
	super.receive_delta(objects,removed,controlled)
	if is_instance_valid(effects):effects.observe_perception(objects,controlled)
	client_support_revision+=1
	_support_writer_depth-=1

func remove_instance(id: int) -> void:
	_support_writer_depth+=1
	client_support_revision+=1
	super.remove_instance(id)
	client_support_revision+=1
	_support_writer_depth-=1

func apply_pose(id: int) -> void:
	# Static received pose changes happen at receive/adoption boundaries. The
	# ordinary per-frame creature loop does not cause a static geometry scan.
	var static_pose: bool=desired.get(id,{}).get("object",{}).has("staticState")
	if static_pose:
		_support_writer_depth+=1
		client_support_revision+=1
	super.apply_pose(id)
	if static_pose:
		client_support_revision+=1
		_support_writer_depth-=1

func _profile_process(delta: float) -> void:
	# Parent adoption/removal is synchronous. Fencing both sides also catches a
	# reentrant state update from a provider during a support-query fixture.
	client_support_revision+=1
	super._profile_process(delta)
	client_support_revision+=1

func snapshot(details: bool=true) -> Dictionary:
	var result:=super.snapshot(details)
	result.client_support_scene=client_support_scene.snapshot() if client_support_scene!=null else {"configured":false}
	result.client_support_scene.revision=client_support_revision
	result.client_support_scene.acceptance="Native controller and ordinary static-Part local checks; exact BSP tie order/exotic models and live bridges remain unverified"
	if is_instance_valid(effects) and effects.perception_visuals!=null:result.native_perception=effects.perception_visuals.snapshot()
	return result

func close() -> void:
	if client_support_scene!=null:client_support_scene.retire()
	motion.support_query=Callable()
	super.close()
