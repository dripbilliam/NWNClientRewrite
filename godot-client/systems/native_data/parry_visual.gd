extends RefCounted
# Original SpawnHitVisuals14080bb10 mode0. The current facing target is distinct
# from the attack record target. Original type11 visual118 owns its own lifetime.
const M=preload("res://systems/native_render/particle_math.gd")
static func place(actor: Dictionary,p: Dictionary) -> int:
	var target: Variant=p.object.call(p.targetId.call(actor))
	if target==null: return 0
	var space:=M.f(p.creatureSpace.call(target)); var impact: Variant=p.impactPose.call(actor)
	if impact==null: p.warning.call("missing-impact"); return 0
	var target_position: Array=p.position.call(target); var source_position: Array=p.position.call(actor); var facing: Array=p.orientation.call(actor)
	var height:=M.f(M.f(impact[2])-M.f(target_position[2]))
	if absf(height)>5: p.warning.call("impact-height")
	if space<=M.f(0.5): space=M.f(space*2)
	var position: Array=[M.f(M.f(target_position[0])-M.f(M.f(facing[0])*space)),M.f(M.f(target_position[1])-M.f(M.f(facing[1])*space)),M.f(M.f(source_position[2])+absf(height))]
	return int(p.areaVisual.call(actor,118,position))
