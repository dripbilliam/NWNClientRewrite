extends RefCounted
# Complete bounded chunk owner flow; private model/scene operations are native
# presentation providers. Full original lower model and scene parity is separate.
const M=preload("res://systems/native_render/particle_math.gd")
const Trig=preload("res://systems/native_render/particle_trig.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const REQUIRED=["createChunkModel","chunkScene","chunkScale","chunkPlay","chunkPosition","chunkOrientation","destroyChunkModel"]
static func construct(e: Dictionary,delta: float,p: Dictionary) -> Dictionary:
	var part: Dictionary=Schedule.invoke(p,"baseCreate",[delta]); part.nativeChunky=true
	part.chunk78=Schedule.invoke(p,"createChunkModel",[str(e.chunkName)])
	if part.chunk78!=null: Schedule.invoke(p,"chunkScene",[part.chunk78,true])
	return part
static func initialize(part: Dictionary,delta: float,factor: float,p: Dictionary) -> void:
	# ChunkyParticle explicitly forces1 for base particle initialization; the
	# caller's factor scales the model, rather than its emission extent.
	Schedule.invoke(p,"baseInitialize",[part,delta,1.0])
	if part.get("chunk78")==null: return
	Schedule.invoke(p,"chunkScene",[part.chunk78,true])
	Schedule.invoke(p,"chunkScale",[part.chunk78,M.f(factor),0])
	Schedule.invoke(p,"chunkPlay",[part.chunk78,"impact",1.0,1,0.0])
static func destroy(part: Dictionary,p: Dictionary) -> void:
	if part.get("chunk78")==null: return
	Schedule.invoke(p,"destroyChunkModel",[part.chunk78,1]); part.chunk78=null
static func render(e: Dictionary,p: Dictionary) -> void:
	var source: Variant=e.get("source50")
	var source_instance: Variant=source.get("instance") if source is Dictionary else null
	var instance: Variant=e.get("instance100")
	# Original COMISS/JA: unordered fades do not take the less-than-one exit.
	if source_instance is Dictionary and M.f(source_instance.fade)<1: return
	if instance is Dictionary and M.f(instance.fade)<1: return
	var active: Array=e.active188.records
	if bool(p.get("renderEmitterSpheres",false)) and not active.is_empty(): Schedule.invoke(p,"renderBoundingSphere",[e])
	for part in active:
		var child: Variant=part.get("chunk78")
		if child==null: continue
		Schedule.invoke(p,"chunkPosition",[child,M.values(part.position10)])
		if M.f(e.particleRot)==0 or int(part.stopped70)!=0: continue
		var axis:=M.normalize(part.direction4c); var angle:=M.f(M.f(part.rotation1c)*M.f(0.5))
		var cosine: float=p.cosineFloat.call(angle) if p.has("cosineFloat") else Trig.cosine(angle)
		var sine: float=p.sineFloat.call(angle) if p.has("sineFloat") else Trig.sine(angle)
		Schedule.invoke(p,"chunkOrientation",[child,[M.f(cosine),M.f(axis[0]*sine),M.f(axis[1]*sine),M.f(axis[2]*sine)]])
