extends RefCounted

const SkinPreparation = preload("res://systems/native_data/skin_preparation.gd")
const FrameProfile = preload("res://systems/native_render/frame_profile.gd")

static var compiled_available: bool = OS.get_cmdline_user_args().has("--cpu-skin-deform=compiled") and ClassDB.class_has_method(&"NwnParticleKernel", &"cpu_skin_deform")
static var compiled_bind_available: bool = compiled_available and ClassDB.class_has_method(&"NwnParticleKernel", &"cpu_skin_bind_matrices")
static var compiled_normals_available: bool = not OS.get_cmdline_user_args().has("--cpu-skin-normals=script") and ClassDB.class_has_method(&"NwnParticleKernel", &"cpu_skin_flat_normals")
static var compiled_calls := 0
static var compiled_rejections := 0
static var compiled_bind_calls := 0
static var compiled_bind_rejections := 0

static func compiled_status() -> Dictionary:
	return {"requested":OS.get_cmdline_user_args().has("--cpu-skin-deform=compiled"),
		"available":compiled_available,"calls":compiled_calls,"rejections":compiled_rejections,
		"bind_available":compiled_bind_available,"bind_calls":compiled_bind_calls,"bind_rejections":compiled_bind_rejections}

static func flat_normals(points: PackedVector3Array) -> PackedVector3Array:
	var count := points.size()
	if compiled_normals_available and count > 0:
		var began := FrameProfile.begin()
		var result: Variant = ClassDB.class_call_static(&"NwnParticleKernel", &"cpu_skin_flat_normals", points)
		FrameProfile.finish("actor_skin_native_normals_ms", began)
		if result is PackedVector3Array and result.size() == count:
			FrameProfile.count("count_cpu_skin_normals_compiled", 1)
			return result
		FrameProfile.count("count_cpu_skin_normals_compiled_rejections", 1)
	var normals := PackedVector3Array()
	normals.resize(count)
	for triangle in range(0, count, 3):
		var normal := (points[triangle + 2] - points[triangle + 1]).cross(points[triangle] - points[triangle + 1]).normalized()
		for corner in 3:
			normals[triangle + corner] = normal
	return normals

static func bind_compiled(skin: Dictionary) -> void:
	if not compiled_available:
		return
	var source: Dictionary = skin.source
	if source.inversePositions.is_empty() or source.inverseQuaternions.is_empty():
		return
	# Retain the typed, authored streams on the skin. Only pose matrices
	# change at publication time.
	var weights: Variant = skin.weights
	if not weights is PackedFloat64Array:
		weights = PackedFloat64Array(Array(weights))
	var bones: Variant = skin.indices
	if not bones is PackedInt32Array:
		bones = PackedInt32Array(bones)
	skin.compiled_input = {"positions": skin.positions, "weights": weights, "bones": bones, "aliases": skin.first_corners}

static func corner_leaders(source: Dictionary,count: int) -> PackedInt32Array:
	# ActorInstance expands each indexed face in [0, 2, 1] order. A
	# repeated source index carries the same position and four influences,
	# while the normals, UVs and picking still use the full corner stream.
	var first_corners:=PackedInt32Array()
	var source_indices: Variant=source.get("source_indices")
	if source_indices is PackedInt32Array and source_indices.size()==count:
		var first_by_source: Dictionary={}
		var expanded:=0
		first_corners.resize(count)
		for face in range(0,count,3):
			for corner in [0,2,1]:
				var source_index:=int(source_indices[face+corner])
				if not first_by_source.has(source_index):first_by_source[source_index]=expanded
				first_corners[expanded]=int(first_by_source[source_index])
				expanded+=1
		if first_by_source.size()==count:first_corners.clear()
	return first_corners

static func prepare_pose(skin: Dictionary,rigid: Array[Transform3D]) -> Dictionary:
	var transforms: Array[Transform3D]=[]
	var inverse: Transform3D=rigid[int(skin.part)].affine_inverse()
	var native_matrices: Array=[]
	var skin_source: Dictionary=skin.get("source",{})
	if not skin_source.is_empty() and not skin_source.inversePositions.is_empty() and not skin_source.inverseQuaternions.is_empty():
		var physical_count:=int(skin.get("physical_count",0));var positions: Array=[];var quaternions: Array=[]
		positions.resize(physical_count);quaternions.resize(physical_count)
		for slot in mini(skin_source.slots.size(),64):
			var physical:=int(skin_source.slots[slot]);var bone:=int(skin.bones[slot])
			if physical<0 or physical>=physical_count or bone<0 or bone>=rigid.size() or positions[physical]!=null:continue
			var pose: Transform3D=inverse*rigid[bone]
			# Three Matrix4.decompose removes each rigid column's accumulated
			# length before extracting the quaternion. These parts have unit
			# authored scale, but their composed basis can still drift slightly.
			var basis: Basis=pose.basis
			var sx:=basis.x.length();var sy:=basis.y.length();var sz:=basis.z.length()
			if basis.determinant()<0.0:sx=-sx
			if sx!=0.0 and sy!=0.0 and sz!=0.0:
				basis=Basis(basis.x/sx,basis.y/sy,basis.z/sz)
			var rotation: Quaternion=basis.get_rotation_quaternion()
			positions[physical]=[pose.origin.x,-pose.origin.z,pose.origin.y]
			quaternions[physical]=[rotation.w,rotation.x,-rotation.z,rotation.y]
		var result: Variant = null
		if compiled_bind_available and skin.has("compiled_input"):
			var began := FrameProfile.begin()
			result = ClassDB.class_call_static(&"NwnParticleKernel", &"cpu_skin_bind_matrices", {
				"slots":skin_source.slots, "positions":positions, "quaternions":quaternions,
				"inverse_positions":skin_source.inversePositions, "inverse_quaternions":skin_source.inverseQuaternions})
			FrameProfile.finish("actor_skin_native_bind_ms", began)
			if result is Dictionary and not result.has("error") and result.get("matrices") is Array and result.matrices.size() == mini(skin_source.slots.size(),64):
				compiled_bind_calls += 1
				FrameProfile.count("count_cpu_skin_bind_compiled", 1)
			else:
				compiled_bind_rejections += 1
				FrameProfile.count("count_cpu_skin_bind_compiled_rejections", 1)
				result = null
		if result == null:
			result = SkinPreparation.native_bone_matrices(skin_source.slots,positions,quaternions,skin_source.inversePositions,skin_source.inverseQuaternions)
		if result.has("error"):return result
		native_matrices=result.matrices
	else:
		# The old decoded-only Three input path lacked inverse bind arrays.
		for slot in skin.bones.size():
			var bone:=int(skin.bones[slot])
			transforms.append((inverse*rigid[bone]*skin.inverse[slot]).orthonormalized() if bone>=0 and bone<rigid.size() else Transform3D.IDENTITY)
	return {"native":native_matrices,"transforms":transforms}

static func deform(skin: Dictionary,prepared: Dictionary) -> Variant:
	var native_matrices: Array=prepared.native
	if not native_matrices.is_empty() and skin.has("compiled_input"):
		var input: Dictionary = skin.compiled_input.duplicate()
		input.matrices = native_matrices
		var began := FrameProfile.begin()
		var result: Variant = ClassDB.class_call_static(&"NwnParticleKernel", &"cpu_skin_deform", input)
		FrameProfile.finish("actor_skin_native_deform_ms", began)
		if result is Dictionary and result.get("positions") is PackedVector3Array and result.positions.size() == skin.positions.size():
			compiled_calls += 1
			FrameProfile.count("count_cpu_skin_compiled", 1)
			return result.positions
		# The script owns compatibility for sources rejected by the kernel.
		compiled_rejections += 1
		FrameProfile.count("count_cpu_skin_compiled_rejections", 1)
	var transforms: Array[Transform3D]=prepared.transforms
	var original: PackedVector3Array=skin.positions
	var weights: Variant=skin.weights
	var indices: Variant=skin.indices
	var first_corners: PackedInt32Array=skin.first_corners
	var has_reused_corners:=not first_corners.is_empty()
	var deformed:=PackedVector3Array()
	deformed.resize(original.size())
	for index in original.size():
		if has_reused_corners:
			var first_corner:=first_corners[index]
			if first_corner!=index:
				deformed[index]=deformed[first_corner]
				continue
		var base: Vector3=original[index]
		var x:=0.0;var y:=0.0;var z:=0.0;var weighted:=false
		for component in 4:
			var at:=index*4+component;var weight:=float(weights[at])
			if weight<=0:continue
			if native_matrices.is_empty():
				var point: Vector3=transforms[int(indices[at])]*base
				x+=point.x*weight;y+=point.y*weight;z+=point.z*weight
			else:
				var slot:=int(indices[at])
				if slot<0 or slot>=native_matrices.size() or not native_matrices[slot] is Array:return "Native weighted skin slot is unavailable"
				var matrix: Array=native_matrices[slot];var vx:=base.x;var vy:=-base.z;var vz:=base.y
				x+=(float(matrix[0])*vx+float(matrix[1])*vy+float(matrix[2])*vz+float(matrix[3]))*weight
				y+=(float(matrix[4])*vx+float(matrix[5])*vy+float(matrix[6])*vz+float(matrix[7]))*weight
				z+=(float(matrix[8])*vx+float(matrix[9])*vy+float(matrix[10])*vz+float(matrix[11]))*weight
			weighted=true
		deformed[index]=(Vector3(x,z,-y) if not native_matrices.is_empty() else Vector3(x,y,z)) if weighted else base
	return deformed
