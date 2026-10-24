extends RefCounted
# Original14096ba80 /96a110 Type7 /96fa90 Type7. Providers retain handle
# lookup order and reload B8 after callbacks, including replacement models.
static func attach(e: Dictionary,p: Dictionary) -> void:
	var target = p.clientObject.call(e.target54)
	var target_render = p.renderObject.call(target) if target != null else null
	var source = p.clientObject.call(e.source58)
	var source_render = p.renderObject.call(source) if source != null else null
	if target_render == null or source_render == null or e.proceduralB8 == null:return
	var model = e.proceduralB8;var source_model = p.modelHandle.call(source_render,255,1)
	p.setParent.call(model,source_model,"" if e.sourceAnchor28 == null else str(e.sourceAnchor28),0)
	var current = e.proceduralB8;var target_model = p.modelHandle.call(target_render,255,1)
	p.reattachReferences.call(current,target_model,"" if e.targetAnchor38 == null else str(e.targetAnchor38))
static func start(e: Dictionary,id: int,p: Dictionary) -> void:
	if not e.updateProgramD8:return
	attach(e,p)
	var animation := str(p.programString.call(id&65535,"param6").value)
	p.playAnimation.call(e.proceduralB8,animation,1,0,0)
static func stop(e: Dictionary,p: Dictionary) -> void:
	if not e.updateProgramD8 or e.proceduralB8 == null:return
	p.setParent.call(e.proceduralB8,null,"",0);p.setScene.call(e.proceduralB8,0)
