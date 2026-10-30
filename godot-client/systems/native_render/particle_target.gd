extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
# Original first DIRECT physical reference child, including observable provider
# call order. Runtime binding must supply a real referenced model, not a guessed
# named node or nearest world object.
static func set_target(e: Dictionary,p: Dictionary) -> void:
	var children: Array=Schedule.invoke(p,"children",[e])
	for child in children:
		if Schedule.invoke(p,"referenceView",[child])==null: continue
		e.target1c0=Schedule.invoke(p,"referenceView",[child]).model68
		var position: Array=Schedule.invoke(p,"globalPosition",[e]); var target: Array=Schedule.invoke(p,"targetPosition",[e.target1c0]); var difference:=M.subtract(target,position)
		var x:=float(difference[0]); var y:=float(difference[1]); var z:=float(difference[2]); e.targetDistance20c=M.f(sqrt(M.f(M.f(M.f(x*x)+M.f(y*y))+M.f(z*z))))
		if Schedule.invoke(p,"lightningView",[e])==null: return
		var direction:=M.subtract(Schedule.invoke(p,"targetPosition",[e.target1c0]),e.position1e0)
		Schedule.invoke(p,"lightningView",[e]).lightningPreviousDirection=direction
		Schedule.invoke(p,"lightningView",[e]).lightningPreviousPosition=M.values(e.position1e0); return
	Schedule.invoke(p,"removeListener",[e.source50,e.targetListener128])
static func initialize_lightning(e: Dictionary,p: Dictionary) -> void:
	Schedule.invoke(p,"baseInitialize",[e]); e.lifeExp=1.0
	e.targetListener128=Schedule.invoke(p,"listen",[e.source50,set_target,"_EmitterTarget",e]); e.ageMode1cc=0
