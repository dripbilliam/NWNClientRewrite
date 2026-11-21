extends RefCounted
# Original14096ba80 /96a110 Type7 /96fa90 Type7. Providers retain handle
# lookup order and reload B8 after callbacks, including replacement models.
static func attach(e: Dictionary,p: Dictionary) -> bool:
	var target = p.clientObject.call(e.target54)
	var target_render = p.renderObject.call(target) if target != null else null
	var source = p.clientObject.call(e.source58)
	var source_render = p.renderObject.call(source) if source != null else null
	if target_render == null or source_render == null or e.proceduralB8 == null:return true
	var model = e.proceduralB8;var source_model = p.modelHandle.call(source_render,255,1)
	var attached: Variant=p.setParent.call(model,source_model,"" if e.sourceAnchor28 == null else str(e.sourceAnchor28),0)
	if attached is bool and not attached:return false
	var current = e.proceduralB8;var target_model = p.modelHandle.call(target_render,255,1)
	p.reattachReferences.call(current,target_model,"" if e.targetAnchor38 == null else str(e.targetAnchor38))
	return true
static func start(e: Dictionary,id: int,p: Dictionary) -> bool:
	if not e.updateProgramD8:return true
	if not attach(e,p):return false
	var animation := str(p.programString.call(id&65535,"param6").value)
	p.playAnimation.call(e.proceduralB8,animation,1,0,0)
	return true
static func stop(e: Dictionary,p: Dictionary) -> void:
	if not e.updateProgramD8 or e.proceduralB8 == null:return
	p.setParent.call(e.proceduralB8,null,"",0);p.setScene.call(e.proceduralB8,0)
