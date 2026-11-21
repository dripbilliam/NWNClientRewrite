extends RefCounted
# Literal src/main.js::hasStaticSkinMapping and recordModelLimitations.
static func has_static_skin_mapping(parsed: Dictionary) -> bool:
	var nodes: Array=parsed.get("nodes",[])
	for node in nodes:
		if not bool(node.get("skinned",false)):continue
		var skin: Variant=node.get("skinData")
		if not skin is Dictionary:continue
		for index in skin.get("boneConstantSlots",[]):
			if int(index)>=0 and int(index)<nodes.size():return true
	return false

static func entries(parsed: Dictionary,references: bool=false) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var name:=str(parsed.get("modelName",""))
	var nodes: Array=parsed.get("nodes",[])
	if nodes.any(func(node):return str(node.get("type",""))=="light"):
		rows.append({"code":"model.lighting-approximate","message":"Model lights use the native legacy quadratic falloff; gamma-corrected settings, native per-object light selection, vertical/shadow offsets and shadow/flare passes are not yet reconstructed","detail":{"model":name}})
	for message in parsed.get("unsupportedAnimations",[]):
		rows.append({"code":"animation.unsupported","message":str(message),"detail":{"model":name}})
	if bool(parsed.get("hasSkinnedMeshes",false)) and not has_static_skin_mapping(parsed):
		rows.append({"code":"model.skin-mapping-unavailable","message":"No skin bone slots map to model nodes; base vertices are displayed","detail":{"model":name}})
	for node in nodes:
		var node_name:=str(node.get("name",""))
		for feature in node.get("unsupportedFeatures",[]):
			var text:=str(feature)
			if text=="Emitter runtime simulation" or (references and text=="Referenced model attachment"):continue
			rows.append({"code":"model.feature-unimplemented","message":text+" is not implemented","detail":{"model":name,"node":node_name,"feature":text}})
		var kind:=str(node.get("type",""))
		if kind not in (["trimesh","dummy","light","emitter","reference"] if references else ["trimesh","dummy","light","emitter"]):
			rows.append({"code":"model.node-unimplemented","message":"Node type "+kind+" is not rendered","detail":{"model":name,"node":node_name,"nodeType":kind}})
	return rows
