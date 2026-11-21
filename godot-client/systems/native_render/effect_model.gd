extends "res://systems/native_render/actor_instance.gd"
# Private original model; native run/controller/skin owner, no GLB staging.
const VisualNodePose=preload("res://systems/native_data/visual_node_pose.gd")
var installed:=false
var playback_limitations: Array=[]
var anchor_node: Node3D
var anchor_flags:=0
var anchor_scale:=Vector3.ONE
var anchor_inherit_scale:=false
var bundle_data: Dictionary={}
var reuse_binding_inputs:=not OS.get_cmdline_user_args().has("--effect-bindings=reference")
var binding_reused:=0
var binding_publications:=0
var binding_valid:=false
var binding_anchor_transform:=Transform3D.IDENTITY
var binding_output_transform:=Transform3D.IDENTITY
var binding_input_scale:=Vector3.ONE
var binding_input_inherit:=false
var binding_input_flags:=0
var reference_scene_owner: WeakRef
func bind_reference_scene_root(root: Node) -> void:
	# ModelReferenceScene receives its owned scene root at construction. Keep
	# this owner distinct from the nested actor/physical reference graph.
	if reference_scene_owner==null and is_instance_valid(root):reference_scene_owner=weakref(root)
func reattach_references(target: Node3D,model_index: int=0) -> bool:
	if not retired and reference_scene_owner!=null:
		var owner: Variant=reference_scene_owner.get_ref()
		if not is_instance_valid(owner) or get_parent()!=null and get_parent()!=owner:
			failure="Reference Gob base transform requires the owned scene root"
			return false
	return super.reattach_references(target,model_index)
func _ready() -> void:
	# Creature/model rigs publish their physical Parts at priority0. Attachments
	# consume those current transforms before particle simulation at priority20.
	# Tree insertion order otherwise leaves held-shield arrows one frame behind.
	process_priority=10
	if reuse_binding_inputs:set_process(is_instance_valid(anchor_node))
func load_model(bundle: Dictionary,pool) -> bool:
	bundle_data=bundle
	installed=install([{"bundle":bundle,"anchor":"","follow":true}],pool,0,{})
	# The old scene advances actor pose, then attachment, then visual-owned
	# animation. This private rig must follow this model's priority-10 binding.
	if installed and is_instance_valid(rigs):rigs.process_priority=12
	return installed
func play_effect_clip(clip: Variant,speed: float,flags: int,time: float) -> bool:
	return installed and not retired and rigs.play_native(0,0,clip,speed,flags,time)
func clip_length(clip: String) -> float:
	for row in bundle_data.get("value",{}).get("rig_asset",{}).get("clips",[]):
		if str(row.name).to_lower()==clip.to_lower(): return float(row.length)
	return 0.0
func has_scene_clip(name: String) -> bool:
	var wanted:=name.to_lower()
	for row in bundle_data.get("value",{}).get("rig_asset",{}).get("clips",[]):
		if str(row.name)==wanted:return true
	return false
func scene_clip_length(name: String) -> float:
	for row in bundle_data.get("value",{}).get("rig_asset",{}).get("clips",[]):
		if str(row.name)==name:return float(row.length)
	return 0.0
func node_for(_id: int,name: String) -> Node3D: return rigs.node_for(0,0,name) if is_instance_valid(rigs) else null
func physical_root_count() -> int:
	# visual_scene_pose.js::part counts only direct physical model children at
	# query time. Loading a multi-root model itself remains valid.
	if not installed or retired:return 0
	var nodes: Array=bundle_data.get("value",{}).get("nodes",[])
	var count:=0
	for row in nodes:
		if not str(row.get("name","")).is_empty() and int(row.get("parentIndex",row.get("parent",-1)))<0:count+=1
	return count
func set_part_local_pose(name: String,p: Array,q: Array) -> bool:
	var node:=node_for(0,name)
	return node!=null and rigs.set_manual_pose(0,node,VisualNodePose.local_to_godot_position(p),VisualNodePose.local_to_godot_quaternion(q))
func set_part_world_pose(name: String,p: Array,q: Array) -> bool:
	return VisualNodePose.set_world_pose(rigs,node_for(0,name),p,q)
func reset_part_world_orientation(name: String) -> bool:
	var node:=node_for(0,name)
	return VisualNodePose.reset_world_orientation(rigs,node)
func attach_to(target: Node3D,flags: int=0,inherit_scale: bool=false) -> bool:
	if not installed or retired or not is_instance_valid(target) or flags not in [0,3]: return false
	anchor_node=target; anchor_flags=flags; anchor_scale=scale; anchor_inherit_scale=inherit_scale
	binding_valid=false
	set_meta("native_light_anchor",weakref(target))
	global_transform=Transform3D(Basis(target.global_basis.orthonormalized().get_rotation_quaternion()).scaled(anchor_scale*(target.global_basis.get_scale() if anchor_inherit_scale else Vector3.ONE)),target.global_position)
	if reuse_binding_inputs:set_process(true)
	return true
func detach() -> void:
	anchor_node=null
	binding_valid=false
	if reuse_binding_inputs:set_process(false)
	if has_meta("native_light_anchor"): remove_meta("native_light_anchor")
func _process(_delta: float) -> void:
	if not is_instance_valid(anchor_node):
		if reuse_binding_inputs:binding_valid=false;set_process(false)
		return
	var source_transform:=anchor_node.global_transform
	# Mode3 intentionally consumes this model's rotation each update. Retain its
	# numeric evaluation path; mode0 can reuse an exact unchanged anchor/output.
	if reuse_binding_inputs and anchor_flags==0 and binding_input_flags==anchor_flags and binding_valid and source_transform==binding_anchor_transform and global_transform==binding_output_transform and anchor_scale==binding_input_scale and anchor_inherit_scale==binding_input_inherit:
		binding_reused+=1;return
	var rotation: Quaternion=(global_basis if anchor_flags==3 else anchor_node.global_basis).orthonormalized().get_rotation_quaternion()
	global_transform=Transform3D(Basis(rotation).scaled(anchor_scale*(anchor_node.global_basis.get_scale() if anchor_inherit_scale else Vector3.ONE)),anchor_node.global_position)
	if reuse_binding_inputs:
		binding_valid=true;binding_anchor_transform=source_transform;binding_output_transform=global_transform;binding_input_scale=anchor_scale;binding_input_inherit=anchor_inherit_scale;binding_input_flags=anchor_flags;binding_publications+=1
func retire() -> void:
	detach(); visible=false; set_process(false); reference_scene_owner=null; super.retire()
