extends RefCounted
# Script floaties follow the native client object's pose, not head height,
# bounds, mesh readiness or ordinary popup lift. Presentation input stays with
# the existing movement owner; this adapter stores no object/pose registry.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const SpeechAnchor=preload("res://systems/native_data/overhead_speech_anchor.gd")
const F=preload("res://systems/native_render/particle_math.gd")
static func current(row: Dictionary,identity: Array,scope: Array,context: Dictionary) -> bool:
	return Scope.current_context(context) and scope==[int(context.connection),int(context.generation),int(context.areaId)] and not identity.is_empty() and identity==SpeechAnchor.witness(row) and int(row.get("areaId",-1))==int(context.areaId) and int(row.get("objectType",-1))==5
static func project(row: Dictionary,identity: Array,scope: Array,context: Dictionary,position: Variant,height: Variant,camera: Camera3D) -> Dictionary:
	if not Scope.current_context(context) or scope!=[int(context.connection),int(context.generation),int(context.areaId)]:return {"ready":false,"retired":true}
	# Missing or reused object IDs must not move an already active orphan to a
	# new creature. The independent widget can retain its last display/timer.
	if not current(row,identity,scope,context) or not position is Vector3 or not position.is_finite() or not is_instance_valid(camera) or not camera.is_inside_tree():return {"ready":false}
	if not (height is int or height is float) or not is_finite(float(height)):return {"ready":false}
	var point: Vector3=position
	point.y=F.f(F.f(point.y)+F.f(float(height)))
	var screen:=camera.unproject_position(point)
	var viewport_height:=camera.get_viewport().get_visible_rect().size.y
	if not point.is_finite() or not screen.is_finite() or not is_finite(viewport_height) or viewport_height<=0:return {"ready":false}
	return {"ready":true,"point":point,"screen":screen,"viewportHeight":float(viewport_height)}
