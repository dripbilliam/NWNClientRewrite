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
var presentation_failed:=false
var active_message: Dictionary={}
var floating_enabled:=true
var total_damage_only:=false
func report_failure(message: Dictionary,reason: String) -> void:
	diagnostics.append({"code":"network.feedback-presentation-failed","reason":reason,"kind":message.get("kind"),"type":message.get("type"),"sourceId":message.get("sourceId"),"spellId":message.get("spellId")})
func contains_base_item(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("baseItem"):return true
		for child in value.values():
			if contains_base_item(child):return true
	elif value is Array:
		for child in value:
			if contains_base_item(child):return true
	return false
func actor_name_uses_base_item(id: int) -> bool:
	var object: Dictionary=text.objects.get(id,{})
	for family in ["replicated","appearance","item","staticState"]:
		var section: Variant=object.get(family,{})
		if section is Dictionary and section.get("name")!=null:return contains_base_item(section.name)
	for player in text.players.values():
		if not player is Dictionary:continue
		var character: Variant=player.get("character")
		if int(player.get("objectId",-1))!=id and (not character is Dictionary or int(character.get("id",-1))!=id):continue
		if character is Dictionary:return contains_base_item(character.get("firstName")) or contains_base_item(character.get("lastName"))
		return false
	return false
func required_tables(message: Dictionary) -> Array[String]:
	var required: Array[String]=[]
	match str(message.get("kind","")):
		"attack-feedback":
			if int(message.get("minor",0))==6:required.append("feat")
		"damage-feedback":required.append("damagetypes");required.append("damagetypegroups")
		"spell-feedback":
			required.append("spells")
			if bool(message.get("hasItem",false)) and not bool(message.get("identified",false)):required.append("baseitems")
	if (contains_base_item(message.get("itemName")) or contains_base_item(message.get("data"))) and not required.has("baseitems"):required.append("baseitems")
	if not required.has("baseitems"):
		var ids: Array=[]
		for field in ["sourceId","targetId"]:
			if message.has(field):ids.append(int(message[field]))
		var data: Variant=message.get("data")
		if data is Dictionary:
			var objects: Variant=data.get("objects")
			if objects is Array:ids.append_array(objects)
			elif objects is Dictionary:ids.append_array(objects.values())
		for id in ids:
			if actor_name_uses_base_item(int(id)):required.append("baseitems");break
	return required
func color(rgb: Array) -> String: return "<c"+String.chr(maxi(1,int(rgb[0])&255))+String.chr(maxi(1,int(rgb[1])&255))+String.chr(maxi(1,int(rgb[2])&255))+">"
func raw(ref: int) -> String:
	var reference:={"strRef":ref&0xffffffff}
	return text.resolve(reference,2130706432) if text.overrides.has(ref&0xffffffff) else text.raw(reference)
func parse(ref: int,options: Dictionary={}) -> String:
	for id in tokens:
		var published:Dictionary=text.network_token(int(id),tokens[id])
		if published.has("error"):
			presentation_failed=true
			report_failure(active_message,str(published.error))
			return ""
	var resolved: String=text.resolve({"strRef":ref&0xffffffff},2130706432,options)
	if not text.network_last_error.is_empty():
		presentation_failed=true;report_failure(active_message,text.network_last_error)
	return resolved
func parse_feedback(ref: int) -> String: return parse(ref,{"nativeB8":0,"nativeBC":0})
func controlled_creature() -> bool:
	var actor: Dictionary=text.objects.get(controlled,{})
	return not actor.is_empty() and int(actor.get("objectType",0))==5
func name(id: int,colored: bool=false) -> String:
	var object: Dictionary=text.objects.get(id,{})
	var value: Variant=object.get("replicated",{}).get("name")
	if value==null:value=object.get("appearance",{}).get("name")
	if value==null:value=object.get("item",{}).get("name")
	if value==null:value=object.get("staticState",{}).get("name")
	if value==null:
		for player in text.players.values():
			if not player is Dictionary:continue
			var character: Variant=player.get("character")
			if int(player.get("objectId",-1))!=id and (not character is Dictionary or int(character.get("id",-1))!=id):continue
			if character is Dictionary:value={"firstName":character.get("firstName",{"text":""}),"lastName":character.get("lastName",{"text":""})}
			break
	if value==null:return raw(8349)
	var result: String
	if value is Dictionary and (value.get("firstName")!=null or value.get("lastName")!=null):
		var parts: Array[String]=[]
		for part in [value.get("firstName",{"text":""}),value.get("lastName",{"text":""})]:
			var resolved:=string(part)
			if not resolved.is_empty():parts.append(resolved)
		result=" ".join(parts)
	else:result=string(value)
	return color([153,255,255] if id==controlled else [204,153,204])+result+"</c>" if colored else result
func row(table: String,id: int) -> Dictionary:
	var rows: Array=text.tables.get(table,{}).get("orderedRows",[]); return rows[id] if id>=0 and id<rows.size() else {}
func num(table: String,id: int,key: String,fallback: int=0) -> int: return Rules.number(Rules.cell(row(table,id),key),fallback)
func string(value: Variant) -> String:
	if value is Dictionary and value.has("baseItem"):
		var entry: Variant=Rules.cell(row("baseitems",int(value.baseItem)),"Name")
		if entry==null or str(entry) in ["","****"]:
			report_failure(active_message,"Native feedback base-item name is unavailable")
			presentation_failed=true
			return ""
		return raw(Rules.number(entry,-1)&0xffffffff)
	return text.raw(value)
func slot(data: Dictionary,family: String,index: int,fallback: Variant=null) -> Variant:
	var entries: Variant=data.get(family,{})
	return entries[index] if entries is Array and index>=0 and index<entries.size() else entries.get(str(index),entries.get(index,fallback)) if entries is Dictionary else fallback
func float_text(id: int,content: String,font: String="") -> void:
	if text.objects.has(id) and not content.is_empty(): floating.append({"objectId":id,"raw":content,"rgb":[1,1,1],"font":font,"flags":0,"rich":Rich.parse(content)})
func format(message: Dictionary) -> Array:
	tokens.clear(); floating.clear(); sounds.clear(); presentation_failed=false; active_message=message; var output: Array=[]; var content:=""; var tint:=color([255,255,1]); var kind:=str(message.kind); var details: Dictionary={}
	match kind:
		"spell-feedback":
			details={"category":"spell-feedback","sourceId":message.get("sourceId"),"spellId":message.get("spellId"),"casting":message.get("casting"),"identified":message.get("identified"),"hasItem":message.get("hasItem")}
			var item_name: String=string(message.get("itemName","")) if Rules.flag(message.get("hasItem",false)) and Rules.flag(message.get("identified",false)) else ""
			var id:=int(message.spellId); var spell:=row("spells",id)
			if spell.is_empty():return []
			var alt:=num("spells",id,"AltMessage")
			if alt!=0: tokens[0]=name(int(message.sourceId),controlled_creature()); content=parse_feedback(alt)
			else:
				var has_item:=Rules.flag(message.hasItem); var identified:=Rules.flag(message.identified)
				var verb:=raw(8127 if Rules.flag(message.casting) and not has_item else 1501 if not has_item else 63264)
				var spell_name:=item_name if has_item and identified else raw(num("spells",id,"Name",-1)) if identified else raw(1502)
				if has_item and not identified: tokens[0]=string({"baseItem":int(message.get("baseItem",-1))}); spell_name=parse_feedback(63265)
				tokens[0]=name(int(message.sourceId),controlled_creature()); tokens[1]=verb; tokens[2]=spell_name; content=parse_feedback(10482)
			tint=color([204,119,255])
		"initiative-feedback":
			details={"category":"initiative-feedback","sourceId":message.get("sourceId"),"roll":message.get("roll"),"modifier":message.get("modifier")}
			var roll:=int(message.roll); var modifier:=int(message.modifier); var total:=roll+modifier
			for pair in [[0,name(int(message.sourceId),controlled_creature())],[1,str(total)],[2,str(roll)],[3,"-" if modifier<0 else "+"],[4,str(absi(modifier))],[5,str(total)]]: tokens[pair[0]]=pair[1]
			content=parse_feedback(53174); tint=color([255,102,1])
		"attack-feedback":
			details={"category":"attack-feedback","sourceId":message.get("sourceId"),"targetId":message.get("targetId"),"result":message.get("result"),"attackType":message.get("attackType")}
			content=attack(message); tint=color([255,102,1])
		"damage-feedback":
			details={"category":"damage-feedback","sourceId":message.get("sourceId"),"targetId":message.get("targetId"),"damage":message.get("damage")}
			content=damage(message); tint=color([255,102,1])
		"combat-feedback":
			var type:=int(message.type); var data: Dictionary=message.get("data",{})
			details={"category":"script-feedback" if type in [93,94] else "combat-feedback","type":type,"data":data}
			if Scroll.handles(type):
				var plan:=Scroll.plan(type,int(slot(data,"integers",0,0)),text)
				tokens.merge(plan.tokens,true); content=parse(int(plan.ref)) if plan.parse else raw(int(plan.ref)); sounds.append(plan.sound)
			elif type in [93,94]:
				content=parse(int(slot(data,"integers",0,0))) if type==93 else string(slot(data,"strings",0,{})); float_text(int(slot(data,"objects",0,-1)),content)
				if int(slot(data,"integers",1 if type==93 else 0,0))!=1: return []
			else:
				var descriptor: Dictionary=descriptors.get(str(type),{})
				if descriptor.is_empty():
					diagnostics.append({"code":"network.feedback-format-unhandled","reason":"Native feedback formatting branch is not implemented","type":type,"data":data})
					return []
				for recipe in descriptor.tokens:
					match str(recipe.kind):
						"integer": tokens[int(recipe.id)]=str(int(slot(data,"integers",int(recipe.slot),0)))
						"string": tokens[int(recipe.id)]=string(slot(data,"strings",int(recipe.slot),{}))
						"tlk": tokens[int(recipe.id)]=raw(int(recipe.ref))
						_: tokens[int(recipe.id)]=name(int(slot(data,"objects",int(recipe.slot),-1)))
				content=parse(int(descriptor.ref),descriptor.get("parseOptions",{})) if descriptor.kind=="parse" else raw(int(descriptor.ref)) if descriptor.kind=="tlk" else string(slot(data,"strings",int(descriptor.slot),{}))
			if not str(message.get("color","")).is_empty(): tint=str(message.color)
	if presentation_failed:floating.clear();sounds.clear();return []
	if not content.is_empty():
		var rendered: String=tint+content+"</c>"
		var rich: Dictionary=Rich.parse(rendered)
		output.append({"system":true,"category":details.get("category",kind),"raw":rendered,"rich":rich,"richText":rich.spans,"text":rich.text,"flags":128}.merged(details,true))
	if message.get("debug") is String and not str(message.debug).is_empty():
		var debug_raw: String=str(message.debug)
		var debug_rich: Dictionary=Rich.parse(debug_raw)
		var debug_details: Dictionary=details.duplicate()
		debug_details.category="attack-debug" if kind=="attack-feedback" else "damage-debug" if kind=="damage-feedback" else kind+"-debug"
		output.append({"system":true,"raw":debug_raw,"rich":debug_rich,"richText":debug_rich.spans,"text":debug_rich.text,"flags":128}.merged(debug_details,true))
	return output
func attack(m: Dictionary) -> String:
	var special:=int(m.minor)==6; var modifier:=int(m.modifier); var sign:="-" if modifier<0 else "+"; var absolute:=str(absi(modifier)); var total:=int(m.roll)+modifier; var confirmation:=""; var attack_name:=""
	if Rules.flag(m.threatened): tokens[0]=str(m.confirmation); confirmation=parse_feedback(61953)+" "+sign+" "+absolute+" = "+str(int(m.confirmation)+modifier)
	if special and int(m.attackType)!=0:
		var builtin: Variant={65001:517,65000:518,65003:5606}.get(int(m.attackType))
		if builtin!=null:attack_name=raw(int(builtin))
		else:
			var feat_rows: Array=text.tables.get("feat",{}).get("orderedRows",[])
			var feat_row:=row("feat",int(m.attackType)) if int(m.attackType)<(feat_rows.size()&65535) else {}
			var feat_cell: Variant=Rules.cell(feat_row,"Feat")
			if feat_cell!=null and str(feat_cell) not in ["","****"]:
				var feat_ref:=Rules.number(feat_cell,-2147483648)
				if feat_ref!=-2147483648:attack_name=raw(feat_ref&0xffffffff)
	var ref:=int({1:511,2:1463,3:5224,4:514,10:1769}.get(int(m.result),{5:53241,6:53300}.get(int(m.result),-1) if special else {7:61628}.get(int(m.result),-1)))
	var result:=raw(ref) if ref>=0 else ""
	if int(m.result) in [8,9]: tokens[0]=str(m.concealmentChance); result=parse_feedback(62337 if int(m.result)==8 else 62336)
	var player: Dictionary=text.objects.get(controlled,{})
	tokens[0]=name(int(m.sourceId),not player.is_empty() and int(player.get("objectType",0))==5)
	if special: tokens[1]=attack_name; tokens[2]=name(int(m.targetId))
	else: tokens[1]=name(int(m.targetId))
	for pair in [[2,result],[3,str(m.roll)],[4,sign],[5,absolute],[6,str(total)],[7,confirmation]]: tokens[int(pair[0])+(1 if special else 0)]=pair[1]
	var content:=parse_feedback(10471 if special else 10470); var mode_buffer:=content
	if not special and Rules.flag(m.coupDeGrace): mode_buffer=raw(61629); content=mode_buffer+" : "+content
	if Rules.flag(m.sneakAttack) or Rules.flag(m.deathAttack): content=(raw(5225) if Rules.flag(m.sneakAttack) else "")+(" + " if Rules.flag(m.sneakAttack) and Rules.flag(m.deathAttack) else "")+(raw(3952) if Rules.flag(m.deathAttack) else "")+" : "+content
	var mode:=int(m.combatMode)
	if mode>=2 if special else mode not in [0,9]:
		var mode_ref:=int({2:417,3:403,5:1060,6:419,7:2773,8:2777,11:76423}.get(mode,{4:53239,10:2803}.get(mode,-1) if not special else -1))
		if mode_ref>=0: mode_buffer=raw(mode_ref)
		else:
			diagnostics.append({"code":"network.attack-feedback-warning","reason":"Error! Unrecognized attack mode!","combatMode":mode,"minor":int(m.minor)})
		content=mode_buffer+" : "+content
	if not special and Rules.flag(m.specialMinus534): content=raw(6626)+" : "+content
	if Rules.flag(m.offhand): content=raw(1559)+" : "+content
	var source: Dictionary=text.objects.get(int(m.sourceId),{})
	if not floating_enabled or source.is_empty() or int(source.get("objectType",0))!=5 or bool(source.get("replicationRemoved",false)):return content
	if special and int(m.attackType) not in [867,868]: float_text(int(m.sourceId),attack_name+": *"+result+"*")
	elif not special:
		if Rules.flag(m.sneakAttack):float_text(int(m.sourceId),"*"+raw(53237)+"*")
		elif Rules.flag(m.deathAttack):float_text(int(m.sourceId),"*"+raw(3952)+"*")
		if Rules.flag(m.coupDeGrace):float_text(int(m.sourceId),"*"+raw(61630)+"*")
		if Rules.flag(m.specialMinus534):float_text(int(m.sourceId),"*"+raw(67595)+"*")
		if int(m.result) in [3,10]: float_text(int(m.sourceId),"*"+raw(67510 if int(m.result)==3 else 1770)+"*")
	return content
func damage(m: Dictionary) -> String:
	var count: int=m.damage.size()
	var type_rows: Array=text.tables.get("damagetypes",{}).get("orderedRows",[])
	if type_rows.size()>count:
		presentation_failed=true;report_failure(active_message,"Native damage table exceeds the available server damage slots")
		return ""
	var groups: Array=[]
	for row_index in range(count):
		var group_color:=""
		var group_row:=row("damagetypegroups",row_index)
		var rgb: Array=[]
		for column in ["ColorR","ColorG","ColorB"]:
			var cell_value: Variant=Rules.cell(group_row,column)
			if cell_value==null or str(cell_value) in ["","****"]:break
			var number:=Rules.number(cell_value,-2147483648)
			if number==-2147483648:break
			rgb.append(number)
		if rgb.size()==3:
			var raw:=""
			for value in rgb:raw+=String.chr(1 if int(value)<1 else int(value)&255)
			group_color="<c"+raw.split(String.chr(0))[0]+">"
		groups.append({"amount":-1,"color":group_color})
	var total:=0
	for value in m.damage:
		if int(value)==-1:continue
		total=(total+int(value))&0xffffffff
		if total>=0x80000000:total-=0x100000000
	for index in range(mini(type_rows.size(),32)):
		var amount:=int(m.damage[index])
		if amount==-1:continue
		var group_value: Variant=Rules.cell(type_rows[index],"DamageTypeGroup")
		if group_value==null or str(group_value) in ["","****"]:continue
		var group_index:=Rules.number(group_value,-1)
		if group_index<0 or group_index>=count:
			presentation_failed=true;report_failure(active_message,"Native damage group index is outside the available display groups")
			return ""
		var group: Dictionary=groups[group_index]
		if int(group.amount)==-1:group.amount=0
		group.amount=(int(group.amount)+amount)&0xffffffff
		if int(group.amount)>=0x80000000:group.amount=int(group.amount)-0x100000000
	var player: Dictionary=text.objects.get(controlled,{})
	tokens[0]=name(int(m.sourceId),not player.is_empty() and int(player.get("objectType",0))==5)
	tokens[1]=name(int(m.targetId))
	tokens[2]=str(total)
	var header:=parse_feedback(10466)
	var parts: Array[String]=[]
	for row_index in range(count):
		var group: Dictionary=groups[row_index]
		if int(group.amount)==-1:continue
		var ref_value: Variant=Rules.cell(row("damagetypegroups",row_index),"FeedbackStrref")
		var ref:=Rules.number(ref_value,-1) if ref_value!=null else -1
		tokens[0]=str(group.amount)
		var part:=parse_feedback(ref&0xffffffff)
		if not str(group.color).is_empty():part=str(group.color)+part+"</c>"
		parts.append(part)
	var target: Dictionary=text.objects.get(int(m.targetId),{})
	if floating_enabled and not target.is_empty() and not bool(target.get("replicationRemoved",false)):
		if total_damage_only:float_text(int(m.targetId),color([153,153,255])+str(total&0xffffffff)+"</c>","fnt_floaty_smal")
		else:
			for group in groups:
				if int(group.amount)==-1:continue
				float_text(int(m.targetId),(str(group.color)+str(int(group.amount)&0xffffffff)+"</c>") if not str(group.color).is_empty() else str(int(group.amount)&0xffffffff),"fnt_floaty_smal")
	return header+" ("+" ".join(parts)+")"
