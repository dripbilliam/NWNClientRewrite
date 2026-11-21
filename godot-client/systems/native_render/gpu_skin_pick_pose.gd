extends RefCounted

const SkinDeformation = preload("res://systems/native_data/skin_deformation.gd")

# The CPU extracts a float32 quaternion from each relative pose. Certify its
# length at query time. Keep extra space above that tested squared length.
const POSE_NORM_SQUARED_LIMIT := 1.0001
const POSE_NORM_BOUND := 1.0001
const MAX_CERTIFIED_RADIUS := 1000000.0

var _skin: Dictionary
var _rigid: Array[Transform3D] = []
var _revision := 0
var _bounds_revision := -1
var _prepared_revision := -1
var _prepared: Dictionary = {}
var _pose: Dictionary = {}
var _bind_bounds: AABB
var _bind_valid := true
var _source_extent := Vector3.ZERO
var _weight_ceiling := 0.0
var _bone_indices := PackedInt32Array()
var _bone_radii := PackedFloat64Array()
var _certified := false
var exact_preparations := 0

func _init(skin: Dictionary) -> void:
	_skin = skin
	var positions: PackedVector3Array = skin.positions
	var weights: Variant = skin.weights
	var indices: Variant = skin.indices
	var slot_radii := PackedFloat64Array()
	slot_radii.resize(mini(skin.source.slots.size(),64))
	slot_radii.fill(-1.0)
	var valid := true
	_bind_bounds = AABB(positions[0], Vector3.ZERO)
	for index in positions.size():
		var point := positions[index]
		_bind_valid = _bind_valid and point.is_finite()
		_bind_bounds = _bind_bounds.expand(point)
		_source_extent = _source_extent.max(point.abs())
		var radius := float(point.length())
		valid = valid and is_finite(radius) and radius <= MAX_CERTIFIED_RADIUS
		var weight := 0.0
		for component in 4:
			var at := 4 * index + component
			var influence := float(weights[at])
			if not is_finite(influence):
				valid = false
				continue
			if influence <= 0.0:
				continue
			var slot := int(indices[at])
			if slot < 0 or slot >= slot_radii.size():
				valid = false
				continue
			weight += influence
			slot_radii[slot] = maxf(slot_radii[slot], radius)
		_weight_ceiling = maxf(_weight_ceiling, weight)
	_certified = _bind_valid and valid and _weight_ceiling <= 16.0 and _bind_radii(slot_radii)

func commit(rigid: Array[Transform3D]) -> void:
	_rigid = rigid
	_revision += 1

func pose() -> Dictionary:
	if _bounds_revision == _revision:
		return _pose
	_bounds_revision = _revision
	if _revision == 0:
		_pose = {"revision": _revision, "bounds": _bind_bounds if _bind_valid else null}
		return _pose
	_pose = {"revision": _revision, "bounds": _conservative_bounds()}
	return _pose

func faces(revision: int) -> PackedVector3Array:
	if not _bind_valid or revision != _revision or revision != _bounds_revision:
		return PackedVector3Array()
	if revision == 0:
		return _skin.positions
	var part := int(_skin.part)
	if part < 0 or part >= _rigid.size() or not _rigid[part].is_finite():
		return PackedVector3Array()
	var determinant := _rigid[part].basis.determinant()
	if not is_finite(determinant) or determinant == 0.0:
		return PackedVector3Array()
	if _prepared_revision != revision:
		_prepared_revision = revision
		exact_preparations += 1
		_prepared = SkinDeformation.prepare_pose(_skin, _rigid)
	if _prepared.has("error"):
		return PackedVector3Array()
	var vertices: Variant = SkinDeformation.deform(_skin, _prepared)
	if vertices is PackedVector3Array:
		if _pose.bounds == null:
			for vertex in vertices:
				if not vertex.is_finite():
					return PackedVector3Array()
		return vertices
	return PackedVector3Array()

func _bind_radii(slot_radii: PackedFloat64Array) -> bool:
	var source: Dictionary = _skin.source
	var bone_steps: Dictionary = {}
	var first_bones: Dictionary = {}
	var envelopes: Dictionary = {}
	var root_seen := false
	var certified_slots := 0
	for slot in slot_radii.size():
		var physical := int(source.slots[slot])
		if physical < 0 or physical >= int(_skin.physical_count):
			continue
		if physical == 0:
			if root_seen:
				break
			root_seen = true
		if physical >= source.inversePositions.size() or physical >= source.inverseQuaternions.size():
			return false
		var position: Variant = source.inversePositions[physical]
		var quaternion: Variant = source.inverseQuaternions[physical]
		if not position is Array or position.size() < 3 or not quaternion is Array or quaternion.size() < 4:
			return false
		# Match the float32 conversion in the original reader's pose math.
		var position_radius := float(Vector3(position[0], position[1], position[2]).length())
		var inverse_norm := float(Vector4(quaternion[0], quaternion[1], quaternion[2], quaternion[3]).length())
		var bone := int(_skin.bones[slot]) if slot < _skin.bones.size() else -1
		if bone < 0 or not is_finite(position_radius) or position_radius > MAX_CERTIFIED_RADIUS or not is_finite(inverse_norm) or inverse_norm > 4.0:
			return false
		if int(first_bones.get(physical, bone)) != bone:
			return false
		first_bones[physical] = bone
		var previous: Vector2 = bone_steps.get(physical, Vector2(POSE_NORM_BOUND, 0.0))
		var translation := float(previous.y) + _rotation_norm(previous.x) * position_radius
		# An authored physical bone may occur in several slots. The native
		# reader applies another inverse step at each occurrence to the same
		# physical pose. Round each upper bound outward before storing it.
		var norm := (float(previous.x) * inverse_norm + 0.00000001) * 1.00001
		if not is_finite(norm) or norm > 256.0 or not is_finite(translation) or translation > MAX_CERTIFIED_RADIUS:
			return false
		bone_steps[physical] = Vector2(norm, translation)
		if slot_radii[slot] < 0.0:
			continue
		certified_slots += 1
		var radius := translation + _rotation_norm(norm) * slot_radii[slot]
		if not is_finite(radius) or radius > MAX_CERTIFIED_RADIUS:
			return false
		envelopes[bone] = maxf(float(envelopes.get(bone, 0.0)), radius)
	for radius in slot_radii:
		if radius >= 0.0:
			certified_slots -= 1
	if certified_slots != 0:
		return false
	for bone in envelopes:
		_bone_indices.append(bone)
		_bone_radii.append(envelopes[bone])
	return true

static func _rotation_norm(quaternion_norm: float) -> float:
	# The raw quaternion basis equals n² R(unit) + (1 - n²) I.
	# Its operator norm is bounded by n² + abs(1 - n²), plus allowance
	# for the native float32 products and sums. Identity shortcuts fit too.
	var squared := quaternion_norm * quaternion_norm
	return maxf(1.0, 2.0 * squared - 1.0) + (1.0 + squared) * 0.00002

func _conservative_bounds() -> Variant:
	var part := int(_skin.part)
	if not _certified or part < 0 or part >= _rigid.size():
		return null
	var mesh_pose := _rigid[part]
	if not mesh_pose.is_finite() or absf(mesh_pose.basis.determinant()) < 0.00001:
		return null
	var inverse := mesh_pose.affine_inverse()
	var weighted_extent := Vector3.ZERO
	for index in _bone_indices.size():
		var bone := _bone_indices[index]
		if bone >= _rigid.size():
			return null
		var relative := inverse * _rigid[bone]
		if not relative.is_finite() or relative.origin.length_squared() > MAX_CERTIFIED_RADIUS * MAX_CERTIFIED_RADIUS:
			return null
		# Use the CPU's exact column normalization to certify its initial
		# relative quaternion without constructing the packed bind matrices.
		var basis := relative.basis
		var sx := basis.x.length()
		var sy := basis.y.length()
		var sz := basis.z.length()
		if not is_finite(sx) or not is_finite(sy) or not is_finite(sz) or minf(minf(sx, sy), sz) < 0.00001:
			return null
		if basis.determinant() < 0.0:
			sx = -sx
		basis = Basis(basis.x / sx, basis.y / sy, basis.z / sz)
		var norm := basis.get_rotation_quaternion().length_squared()
		if not is_finite(norm) or norm > POSE_NORM_SQUARED_LIMIT:
			return null
		weighted_extent = weighted_extent.max(relative.origin.abs() + Vector3.ONE * _bone_radii[index])
	# Positive weights may sum to more than one. Keep unweighted bind
	# corners and allow cumulative float32 position rounding at all 64 slots.
	var extent := _source_extent.max(weighted_extent * (_weight_ceiling * 1.0002))
	if not extent.is_finite() or extent.length_squared() > 1.0e20:
		return null
	# Round out past the float32 conversion of both the faces and the box.
	var margin := maxf(0.0001, extent.length() * 0.00001)
	return AABB(-extent, extent * 2.0).grow(margin)
