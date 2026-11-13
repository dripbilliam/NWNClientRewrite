extends "res://systems/native_render/actor_instance.gd"
# Private original model; native run/controller/skin owner, no GLB staging.
var installed:=false
var playback_limitations: Array=[]
var anchor_node: Node3D
var anchor_flags:=0
var anchor_scale:=Vector3.ONE
var anchor_inherit_scale:=false
var bundle_data: Dictionary={}
func _ready() -> void:
	# Creature/model rigs publish their physical Parts at priority0. Attachments
	# consume those current transforms before particle simulation at priority20.
	# Tree insertion order otherwise leaves held-shield arrows one frame behind.
	process_priority=10
func load_model(bundle: Dictionary,pool) -> bool:
	bundle_data=bundle
	installed=install([{"bundle":bundle,"anchor":"","follow":true}],pool,0,{})
	return installed
func play_effect_clip(clip: Variant,speed: float,flags: int,time: float) -> bool:
	return installed and not retired and rigs.play_native(0,0,clip,speed,flags,time)
func clip_length(clip: String) -> float:
	for row in bundle_data.get("value",{}).get("rig_asset",{}).get("clips",[]):
		if str(row.name).to_lower()==clip.to_lower(): return float(row.length)
	return 0.0
func node_for(_id: int,name: String) -> Node3D: return rigs.node_for(0,0,name) if is_instance_valid(rigs) else null
func set_part_local_pose(name: String,p: Array,q: Array) -> bool:
	var node:=node_for(0,name)
	return node!=null and rigs.set_manual_pose(0,node,Vector3(p[0],p[2],-p[1]),Quaternion(q[1],q[3],-q[2],q[0]))
func reset_part_world_orientation(name: String) -> bool:
	var node:=node_for(0,name)
	if node==null: return false
	var p:=node.global_position; node.position=Vector3.ZERO; node.quaternion=Quaternion.IDENTITY
	var base:=node.global_position; var inverse:=node.global_basis.orthonormalized().get_rotation_quaternion().inverse()
	return rigs.set_manual_pose(0,node,inverse*(p-base),inverse.normalized())
func attach_to(target: Node3D,flags: int=0,inherit_scale: bool=false) -> bool:
	if not installed or retired or not is_instance_valid(target) or flags not in [0,3]: return false
	anchor_node=target; anchor_flags=flags; anchor_scale=scale; anchor_inherit_scale=inherit_scale
	set_meta("native_light_anchor",weakref(target))
	global_transform=Transform3D(Basis(target.global_basis.orthonormalized().get_rotation_quaternion()).scaled(anchor_scale*(target.global_basis.get_scale() if anchor_inherit_scale else Vector3.ONE)),target.global_position)
	return true
func detach() -> void:
	anchor_node=null
	if has_meta("native_light_anchor"): remove_meta("native_light_anchor")
func _process(_delta: float) -> void:
	if not is_instance_valid(anchor_node): return
	var rotation: Quaternion=(global_basis if anchor_flags==3 else anchor_node.global_basis).orthonormalized().get_rotation_quaternion()
	global_transform=Transform3D(Basis(rotation).scaled(anchor_scale*(anchor_node.global_basis.get_scale() if anchor_inherit_scale else Vector3.ONE)),anchor_node.global_position)
func retire() -> void:
	detach(); visible=false; set_process(false); super.retire()
