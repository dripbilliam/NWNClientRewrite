extends RefCounted
# Original CanChooseFeat7ed040 over decoded active rules/stat storage. Separate
# normal-only/bonus-only reservations precede flexible choices; duplicate owned
# or newly selected physical IDs are rejected even for GainMultiple feats.
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Context=preload("res://systems/native_data/creation_feat_context.gd")
static func num(data: Dictionary,key: String,fallback: int=0) -> int:return Game.number(Game.cell(data,key),fallback)
static func answer(allowed: bool) -> Dictionary:return {"ready":true,"allowed":allowed}
static func flags(source: Dictionary,id: int) -> Dictionary:
	var definitions: Array=source.get("definitions",[]);var physical:=id&65535
	if physical>=(definitions.size()&65535) or not definitions[physical].get("valid",true):return {"valid":false,"normal":false,"bonus":false,"all":false}
	var all_classes: bool=num(definitions[physical],"AllClassesCanUse")!=0;var normal:=all_classes;var bonus:=false
	var classes: Array=source.get("classes",[]);var current:=int(source.get("current",0))
	if source.get(Context.KEY) is Dictionary:
		var entry: Dictionary=source[Context.KEY].get(physical,{})
		if not entry.is_empty():
			var list:=int(entry.List);normal=list in [0,1];bonus=list in [1,2]
	elif current>=0 and current<mini(8,classes.size()):
		for entry in classes[current].get("feats",[]):
			if (num(entry,"id")&65535)!=physical:continue
			var list:=num(entry,"List")&255;normal=list in [0,1];bonus=list in [1,2];break
	return {"valid":true,"normal":normal or all_classes and not bonus,"bonus":bonus,"all":all_classes}
static func evaluate(source: Dictionary) -> Dictionary:
	if not source.has_all(["featId","feat","current","classes","normal","bonus","definitions","selected","owned"]):return {"ready":false,"allowed":false,"reason":"Decoded native feat choice snapshot is incomplete."}
	var id:=int(source.featId)&65535;var candidate:=flags(source,id)
	if not candidate.valid:return answer(false)
	var normal:=int(source.normal)&255;var bonus:=int(source.bonus)&255
	if normal==0 and bonus==0:return answer(false)
	var owned: Array=source.owned;var chosen: Array=source.selected
	if Requirements.owns(owned.slice(0,owned.size()&65535),id) or Requirements.owns(chosen,id):return answer(false)
	var prerequisites:=Requirements.evaluate(source,source.feat)
	if not prerequisites.ready:return prerequisites
	if not prerequisites.allowed or not candidate.normal and not candidate.bonus:return answer(false)
	var deferred:=0
	for selected in chosen:
		var available:=flags(source,int(selected))
		if available.normal and not available.bonus:
			if normal==0:return answer(false)
			normal-=1
		elif available.bonus and not available.normal and bonus!=0:bonus-=1
		else:deferred+=1
	# Existing bonus-only selections with no bonus slots are deferred by the
	# original chosen-loop. The candidate bonus-only branch instead fails.
	# Preserve this asymmetry rather than applying a generic bipartite count.
	var reserved:=false
	if candidate.normal and not candidate.bonus:
		if normal==0:return answer(false)
		normal-=1;reserved=true
	elif candidate.bonus and not candidate.normal:
		if bonus==0:return answer(false)
		bonus-=1;reserved=true
	for index in deferred:
		if normal!=0:normal-=1
		elif bonus!=0:bonus-=1
		else:return answer(false)
	return answer(reserved or normal!=0 or bonus!=0)
