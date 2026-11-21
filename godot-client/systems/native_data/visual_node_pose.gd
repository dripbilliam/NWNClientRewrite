extends RefCounted
# visual_node_pose.js: native [w,x,y,z] and [x,y,z] values. The scene graph is
# read/written only at this boundary; arithmetic retains the old f32 grouping.
const Math = preload("res://systems/native_render/particle_math.gd")

static func _orientation(node: Node3D) -> Array:
	var q: Quaternion=node.global_basis.orthonormalized().get_rotation_quaternion()
	return [Math.f(q.w),Math.f(q.x),Math.f(-q.z),Math.f(q.y)]

static func _position(node: Node3D) -> Array:
	var p: Vector3=node.global_position
	return [Math.f(p.x),Math.f(-p.z),Math.f(p.y)]

static func local_pose(node: Node3D, position: Array, quaternion: Array) -> void:
	if not is_instance_valid(node):return
	var p: Vector3=node.position
	var q: Quaternion=node.quaternion
	position.assign([Math.f(p.x),Math.f(-p.z),Math.f(p.y)])
	quaternion.assign([Math.f(q.w),Math.f(q.x),Math.f(-q.z),Math.f(q.y)])

static func world_pose(node: Node3D, position: Array, quaternion: Array) -> void:
	if not is_instance_valid(node):return
	position.assign(_position(node))
	quaternion.assign(_orientation(node))

static func normalize_visual(q: Array) -> Array:
	var w:=Math.f(q[0]);var x:=Math.f(q[1]);var y:=Math.f(q[2]);var z:=Math.f(q[3])
	var squared:=Math.f(Math.f(Math.f(Math.f(x*x)+Math.f(w*w))+Math.f(y*y))+Math.f(z*z))
	if squared==1:return [w,x,y,z]
	if not (squared>0):
		q.assign([1.0,0.0,0.0,0.0])
		return [1.0,0.0,0.0,0.0]
	var scale:=Math.f(sqrt(Math.f(1/squared)))
	return [Math.f(w*scale),Math.f(x*scale),Math.f(y*scale),Math.f(z*scale)]

static func local_to_godot_position(p: Array) -> Vector3:
	return Vector3(Math.f(p[0]),Math.f(p[2]),-Math.f(p[1]))

static func local_to_godot_quaternion(q: Array) -> Quaternion:
	return Quaternion(Math.f(q[1]),Math.f(q[3]),-Math.f(q[2]),Math.f(q[0]))

static func set_world_pose(rigs, node: Node3D, position: Array, quaternion: Array) -> bool:
	if not is_instance_valid(node):return false
	# Gob::SetPartPosition clears local P/Q before querying the parent pose.
	node.position=Vector3.ZERO
	node.quaternion=Quaternion.IDENTITY
	var base_position: Array=[];var base_quaternion: Array=[]
	world_pose(node,base_position,base_quaternion)
	base_quaternion[0]=Math.f(-base_quaternion[0])
	var displacement:=Math.subtract(position,base_position)
	var local_position:=Math.rotate(base_quaternion,displacement)
	var local_quaternion:=normalize_visual(Math.multiply(base_quaternion,quaternion))
	return rigs.set_manual_pose(0,node,local_to_godot_position(local_position),local_to_godot_quaternion(local_quaternion))

static func reset_world_orientation(rigs, node: Node3D) -> bool:
	if not is_instance_valid(node):return false
	var position: Array=[];var quaternion: Array=[]
	world_pose(node,position,quaternion)
	return set_world_pose(rigs,node,position,[1.0,0.0,0.0,0.0])
