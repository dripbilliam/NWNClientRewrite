extends RefCounted
# Original client CC3/5/6/8/11/14 presentation, translated from the verified
# binary-derived reference. This owner never rolls, damages or changes actors.
const Rich=preload("res://systems/native_data/rich_text.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Scroll=preload("res://systems/native_data/scroll_feedback.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
var descriptors: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://systems/native_data/feedback_descriptors.json"))
var text
var controlled:=-1
var tokens: Dictionary={}
var floating: Array=[]
var sounds: Array=[]
var diagnostics: Array=[]
func color(rgb: Array) -> String: return "<c"+String.chr(maxi(1,int(rgb[0])&255))+String.chr(maxi(1,int(rgb[1])&255))+String.chr(maxi(1,int(rgb[2])&255))+">"
func raw(ref: int) -> String: return text.raw({"strRef":ref&0xffffffff})
func parse(ref: int) -> String:
	var previous: Dictionary=text.custom_tokens.duplicate(); text.custom_tokens.merge(tokens,true)
	var result: String=text.resolve({"strRef":ref&0xffffffff},2130706432)
	text.custom_tokens=previous; return result
func name(id: int,colored: bool=false) -> String:
	var result: String=text.name(null,id)
	if result.is_empty(): return raw(8349)
	return color([153,255,255] if id==controlled else [204,153,204])+result+"</c>" if colored else result
func row(table: String,id: int) -> Dictionary:
	var rows: Array=text.tables.get(table,{}).get("orderedRows",[]); return rows[id] if id>=0 and id<rows.size() else {}
func num(table: String,id: int,key: String,fallback: int=0) -> int: return Rules.number(Rules.cell(row(table,id),key),fallback)
func string(value: Variant) -> String:
	if value is Dictionary and value.has("baseItem"): return raw(num("baseitems",int(value.baseItem),"Name",-1))
	return text.raw(value)
func slot(data: Dictionary,family: String,index: int,fallback: Variant=null) -> Variant:
	var entries: Variant=data.get(family,{})
	return entries[index] if entries is Array and index>=0 and index<entries.size() else entries.get(str(index),entries.get(index,fallback)) if entries is Dictionary else fallback
func float_text(id: int,content: String) -> void:
	if text.objects.has(id) and not content.is_empty(): floating.append({"objectId":id,"rich":Rich.parse(content)})
func format(message: Dictionary) -> Array:
	tokens.clear(); floating.clear(); sounds.clear(); var output: Array=[]; var content:=""; var tint:=color([255,255,1]); var kind:=str(message.kind)
	match kind:
		"spell-feedback":
			var id:=int(message.spellId); var spell:=row("spells",id)
			if spell.is_empty(): diagnostics.append("Unavailable spell feedback row "+str(id)); return []
			var alt:=num("spells",id,"AltMessage")
			if alt!=0: tokens[0]=name(int(message.sourceId),true); content=parse(alt)
			else:
				var has_item:=Rules.flag(message.hasItem); var identified:=Rules.flag(message.identified)
				var verb:=raw(8127 if Rules.flag(message.casting) and not has_item else 1501 if not has_item else 63264)
				var spell_name:=string(message.itemName) if has_item and identified else raw(num("spells",id,"Name",-1)) if identified else raw(1502)
				if has_item and not identified: tokens[0]=raw(num("baseitems",int(message.get("baseItem",-1)),"Name",-1)); spell_name=parse(63265)
				tokens[0]=name(int(message.sourceId),true); tokens[1]=verb; tokens[2]=spell_name; content=parse(10482)
			tint=color([204,119,255])
		"initiative-feedback":
			var roll:=int(message.roll); var modifier:=int(message.modifier); var total:=roll+modifier
			for pair in [[0,name(int(message.sourceId),true)],[1,str(total)],[2,str(roll)],[3,"-" if modifier<0 else "+"],[4,str(absi(modifier))],[5,str(total)]]: tokens[pair[0]]=pair[1]
			content=parse(53174); tint=color([255,102,1])
		"attack-feedback":
			content=attack(message); tint=color([255,102,1])
		"damage-feedback":
			content=damage(message); tint=color([255,102,1])
		"combat-feedback":
			var type:=int(message.type); var data: Dictionary=message.get("data",{})
			if Scroll.handles(type):
				var plan:=Scroll.plan(type,int(slot(data,"integers",0,0)),text)
				tokens.merge(plan.tokens,true); content=parse(int(plan.ref)) if plan.parse else raw(int(plan.ref)); sounds.append(plan.sound)
			elif type in [93,94]:
				content=parse(int(slot(data,"integers",0,0))) if type==93 else string(slot(data,"strings",0,{})); float_text(int(slot(data,"objects",0,-1)),content)
				if int(slot(data,"integers",1 if type==93 else 0,0))!=1: return []
			else:
				var descriptor: Dictionary=descriptors.get(str(type),{})
				if descriptor.is_empty():
					if not diagnostics.has("Unsupported feedback branch "+str(type)): diagnostics.append("Unsupported feedback branch "+str(type))
					return []
				for recipe in descriptor.tokens:
					match str(recipe.kind):
						"integer": tokens[int(recipe.id)]=str(int(slot(data,"integers",int(recipe.slot),0)))
						"string": tokens[int(recipe.id)]=string(slot(data,"strings",int(recipe.slot),{}))
						"tlk": tokens[int(recipe.id)]=raw(int(recipe.ref))
						_: tokens[int(recipe.id)]=name(int(slot(data,"objects",int(recipe.slot),-1)))
				content=parse(int(descriptor.ref)) if descriptor.kind=="parse" else raw(int(descriptor.ref)) if descriptor.kind=="tlk" else string(slot(data,"strings",int(descriptor.slot),{}))
			if not str(message.get("color","")).is_empty(): tint=str(message.color)
	if not content.is_empty(): output.append({"system":true,"category":kind,"rich":Rich.parse(tint+content+"</c>"),"text":Rich.parse(content).text})
	if message.get("debug") is String and not str(message.debug).is_empty(): output.append({"system":true,"category":kind+"-debug","rich":Rich.parse(str(message.debug))})
	return output
func attack(m: Dictionary) -> String:
	var special:=int(m.minor)==6; var modifier:=int(m.modifier); var sign:="-" if modifier<0 else "+"; var absolute:=str(absi(modifier)); var total:=int(m.roll)+modifier; var confirmation:=""; var attack_name:=""
	if Rules.flag(m.threatened): tokens[0]=Numbers.text(m.confirmation); confirmation=parse(61953)+" "+sign+" "+absolute+" = "+str(int(m.confirmation)+modifier)
	if special and int(m.attackType)!=0: attack_name=raw(int({65001:517,65000:518,65003:5606}.get(int(m.attackType),num("feat",int(m.attackType),"FEAT",-1))))
	var ref:=int({1:511,2:1463,3:5224,4:514,10:1769}.get(int(m.result),{5:53241,6:53300}.get(int(m.result),-1) if special else {7:61628}.get(int(m.result),-1)))
	var result:=raw(ref) if ref>=0 else ""
	if int(m.result) in [8,9]: tokens[0]=Numbers.text(m.concealmentChance); result=parse(62337 if int(m.result)==8 else 62336)
	tokens[0]=name(int(m.sourceId),true)
	if special: tokens[1]=attack_name; tokens[2]=name(int(m.targetId))
	else: tokens[1]=name(int(m.targetId))
	for pair in [[2,result],[3,Numbers.text(m.roll)],[4,sign],[5,absolute],[6,str(total)],[7,confirmation]]: tokens[int(pair[0])+(1 if special else 0)]=pair[1]
	var content:=parse(10471 if special else 10470); var mode_buffer:=content
	if not special and Rules.flag(m.coupDeGrace): mode_buffer=raw(61629); content=mode_buffer+" : "+content
	if Rules.flag(m.sneakAttack) or Rules.flag(m.deathAttack): content=(raw(5225) if Rules.flag(m.sneakAttack) else "")+(" + " if Rules.flag(m.sneakAttack) and Rules.flag(m.deathAttack) else "")+(raw(3952) if Rules.flag(m.deathAttack) else "")+" : "+content
	var mode:=int(m.combatMode)
	if mode>=2 if special else mode not in [0,9]:
		var mode_ref:=int({2:417,3:403,5:1060,6:419,7:2773,8:2777,11:76423}.get(mode,{4:53239,10:2803}.get(mode,-1) if not special else -1))
		if mode_ref>=0: mode_buffer=raw(mode_ref)
		content=mode_buffer+" : "+content
	if not special and Rules.flag(m.specialMinus534): content=raw(6626)+" : "+content
	if Rules.flag(m.offhand): content=raw(1559)+" : "+content
	if special and int(m.attackType) not in [867,868]: float_text(int(m.sourceId),attack_name+": *"+result+"*")
	elif not special:
		for pair in [["sneakAttack",53237],["deathAttack",3952],["coupDeGrace",61630],["specialMinus534",67595]]:
			if Rules.flag(m.get(pair[0],false)): float_text(int(m.sourceId),"*"+raw(pair[1])+"*")
		if int(m.result) in [3,10]: float_text(int(m.sourceId),"*"+raw(67510 if int(m.result)==3 else 1770)+"*")
	return content
func damage(m: Dictionary) -> String:
	var total:=0; var groups: Dictionary={}; var parts: Array=[]
	for value in m.damage:
		if int(value)!=-1: total+=int(value)
	for index in mini(m.damage.size(),text.tables.get("damagetypes",{}).get("orderedRows",[]).size()):
		if int(m.damage[index])==-1: continue
		var group:=num("damagetypes",index,"DamageTypeGroup",-1)
		if group>=0 and group<m.damage.size(): groups[group]=int(groups.get(group,0))+int(m.damage[index])
	tokens[0]=name(int(m.sourceId),true); tokens[1]=name(int(m.targetId)); tokens[2]=str(total); var header:=parse(10466)
	for group in groups:
		tokens[0]=str(groups[group]); var group_color:=color([num("damagetypegroups",group,"ColorR",255),num("damagetypegroups",group,"ColorG",255),num("damagetypegroups",group,"ColorB",255)])
		parts.append(group_color+parse(num("damagetypegroups",group,"FeedbackStrref",-1))+"</c>"); float_text(int(m.targetId),group_color+str(groups[group])+"</c>")
	return header+" ("+" ".join(parts)+")"
