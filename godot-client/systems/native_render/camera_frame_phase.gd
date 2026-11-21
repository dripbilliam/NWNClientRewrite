extends Node
# The normal frame follows the camera after world/visual/particle updates but
# before light admission. Entry anchoring remains on the world pose callback.
var world: Node3D
var closed:=false
func configure(owner: Node3D) -> void:
	world=owner
	process_priority=80
func _process(delta: float) -> void:
	if closed or not is_instance_valid(world) or world.closed or world.retiring:return
	if world.camera_post_motion.is_valid():world.camera_post_motion.call(delta)
func close() -> void:
	closed=true;set_process(false)
func _exit_tree() -> void:close()
