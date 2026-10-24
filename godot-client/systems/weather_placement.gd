extends RefCounted
const F = preload("res://systems/area_environment_state.gd")
static func unit(v: Array) -> Array:
	var length := F.f(F.f(F.f(v[0]*v[0])+F.f(v[1]*v[1]))+F.f(v[2]*v[2]))
	if length >= F.f(.99999) and length <= F.f(1.00001): return v.duplicate()
	if length == 0: return [1.0,0.0,0.0]
	var scale := F.f(sqrt(F.f(1.0/length)))
	return [F.f(v[0]*scale),F.f(v[1]*scale),F.f(v[2]*scale)]

# Native coordinates and w,x,y,z quaternion. Assembly1407e7f05..81f2;
# CRT trig rounding is separately bounded, not a native CRT implementation.
static func layout(position: Array,q: Array) -> Array:
	var x := F.f(F.f(q[0]*q[2])+F.f(q[1]*q[3]))
	var y := F.f(F.f(q[2]*q[3])-F.f(q[0]*q[1]))
	var direction := unit([F.f(x+x),F.f(y+y),0.0])
	var perpendicular := unit([direction[1],-direction[0],0.0])
	var cross := [F.f(perpendicular[0]*10.0),F.f(perpendicular[1]*10.0),0.0]
	var forward := [F.f(direction[0]*10.0),F.f(direction[1]*10.0),0.0]
	var base := [F.f(F.f(position[0])-cross[0]),F.f(F.f(position[1])-cross[1]),F.f(F.f(position[2])+15.0)]
	var yaw := F.f(F.f(atan2(-direction[0],direction[1]))*F.f(57.295776))
	var half := F.f(F.f(yaw*F.f(.017453292))*.5)
	var rotation := [F.f(cos(half)),0.0,0.0,F.f(sin(half))]
	var result: Array = []
	for row in 2:
		for column in 3:
			result.append({"position":[F.f(F.f(F.f(cross[0]*column)+base[0])+F.f(forward[0]*row)),F.f(F.f(F.f(cross[1]*column)+base[1])+F.f(forward[1]*row)),base[2] if row == 0 and column == 1 else F.f(base[2]-5.0)],"quaternion":rotation.duplicate()})
	return result

static func from_camera(position: Vector3,camera: Camera3D) -> Array:
	# Camera local axes are view axes, while model local axes were converted
	# from Z-up to Y-up. Convert world frame only for the camera getter.
	var q := Quaternion(Vector3.RIGHT,PI/2)*camera.global_basis.orthonormalized().get_rotation_quaternion()
	return layout([F.f(position.x),F.f(-position.z),F.f(position.y)],[F.f(q.w),F.f(q.x),F.f(q.y),F.f(q.z)])
