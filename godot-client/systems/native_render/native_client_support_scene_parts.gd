extends "res://systems/native_render/native_client_support_scene.gd"
# Separate opt-in successor; accepted v3 ordinary adapter and projectiles are
# unchanged. Uses an explicit unsupported result for absent Part provenance.
const PartTrace=preload("res://systems/native_render/native_support_part_trace.gd")
var _part_trace:=PartTrace.new()

func _trace(start: Vector3,end: Vector3) -> Dictionary:
	var owner:=_checked_world(_query_revision)
	if owner==null:return _unavailable()
	_stats.rays+=1
	var hit: Dictionary=_part_trace.trace(owner,[start.x,start.y,start.z],[end.x,end.y,end.z])
	if _checked_world(_query_revision)==null:return _unavailable()
	if not hit.available:return hit
	if not hit.hit:return {"available":true,"hit":false}
	var position: Variant=vector_value(hit.position);var normal: Variant=vector_value(hit.normal)
	if position==null or normal==null:
		_reason="Malformed support Part-policy geometry";return _unavailable()
	return {"available":true,"hit":true,"position":position,"normal":normal}

func snapshot() -> Dictionary:
	if not main_thread():return super.snapshot()
	var result:=super.snapshot()
	result.part_policy="ordinary-trimesh-unmasked/aabb-maskBFFFFFFF"
	result.part_trace=_part_trace.snapshot()
	return result
