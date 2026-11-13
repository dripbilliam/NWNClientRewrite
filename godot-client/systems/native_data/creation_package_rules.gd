extends RefCounted
# Creation package callbacks8e4620/1ec0. Existing native prerequisite/rule
# providers remain separate; this module never invents fallback preferences.
const State=preload("res://systems/native_data/creation_package_state.gd")
static func scalar(rules,data: Dictionary,key: String) -> Variant:return rules.num(data,key) if State.present(rules.cell(data,key)) else null
static func resource(rules,data: Dictionary,key: String) -> String:
	var value: Variant=rules.cell(data,key);return str(value).to_lower() if State.present(value) else ""
static func equipment(rules,data: Dictionary) -> Array:
	var result: Array=[]
	for row in rules.rows(resource(rules,data,"Equip2DA")):
		var label: Variant=rules.cell(row,"Label")
		if State.present(label):result.append(str(label).to_lower().left(16))
	return result
static func assign_feats(rules,ids: Array) -> Array:
	var slots: Dictionary=rules.feat_slots();var normal:=0;var bonus:=0;var both: Array=[];var result: Array=[]
	for id in ids:
		var n: bool=rules.feat_allowed(int(id),"normal");var b: bool=rules.feat_allowed(int(id),"bonus")
		if not n and not b:return []
		if n and b:both.append(result.size());result.append({"id":int(id),"kind":""})
		elif n:normal+=1;result.append({"id":int(id),"kind":"normal"})
		else:bonus+=1;result.append({"id":int(id),"kind":"bonus"})
	if normal>int(slots.normal) or bonus>int(slots.bonus) or ids.size()>int(slots.normal)+int(slots.bonus):return []
	for index in both:
		if normal<int(slots.normal):result[index].kind="normal";normal+=1
		else:result[index].kind="bonus";bonus+=1
	return result
static func recommend_feats(rules,data: Dictionary) -> Dictionary:
	if rules.draft.get("packageSource",false):
		var result:=preload("res://systems/native_data/creation_feat_automatic.gd").recommendation(rules)
		if not result.ready:return result
		var choices:=assign_feats(rules,result.selected)
		if not result.selected.is_empty() and choices.is_empty():return {"ready":false,"reason":"The native automatic feat slot assignment is unavailable."}
		rules.draft.feats=choices
		return {"ready":true}
	var ids: Array=[];var owned: Array=rules.granted_feats();var slots: Dictionary=rules.feat_slots()
	for entry in rules.rows(resource(rules,data,"FeatPref2DA")):
		if ids.size()>=int(slots.normal)+int(slots.bonus):break
		var value: Variant=scalar(rules,entry,"FeatIndex")
		if value==null:continue
		var id:=int(value)&65535
		if ids.has(id) or owned.has(id) or not rules.feat_requirement(id,owned+ids).is_empty():continue
		var candidate: Array=ids+[id];var assignment:=assign_feats(rules,candidate)
		if not assignment.is_empty():ids=candidate;rules.draft.feats=assignment
	return {"ready":true}
static func recommend_skills(rules,data: Dictionary) -> void:
	# Original fills each preference to its cap before advancing, with no
	# automatic scan of unlisted skills and no HideFromLevelUp filter here.
	for entry in rules.rows(resource(rules,data,"SkillPref2DA")):
		var value: Variant=scalar(rules,entry,"SkillIndex")
		if value==null:continue
		var id:=int(value)&65535
		while rules.change_skill(id,1):pass
static func spell_level(rules,id: int) -> int:
	if rules.row("spells",id).is_empty():return 255
	return rules.num(rules.row("spells",id),str(rules.cell(rules.cls(),"SpellTableColumn","")),255)&255
static func recommend_spells(rules,data: Dictionary) -> void:
	if rules.num(rules.cls(),"SpellbookRestricted")==0:return
	var memorizes: bool=rules.num(rules.cls(),"MemorizesSpells")!=0
	var remaining:=3+maxi(0,rules.modifier(int(rules.abilities().Int)))
	if memorizes and rules.draft.known.get(0,[]).is_empty():
		for id in rules.rows("spells").size():
			if spell_level(rules,id)==0:rules.draft.known.get_or_add(0,[]).append(id)
	for entry in rules.rows(resource(rules,data,"SpellPref2DA")):
		if memorizes and remaining==0:break
		var value: Variant=scalar(rules,entry,"SpellIndex")
		if value==null:continue
		var id:=int(value);var level:=spell_level(rules,id)
		if level>=10:continue
		var primary: String=rules.primary()
		if primary.is_empty() or int(rules.abilities()[primary])<level-1+rules.cfg("BASE_ABILITY_MIN_PRIMARY",11):continue
		var known: Array=rules.draft.known.get_or_add(level,[])
		if known.has(id):continue
		if memorizes:
			if level!=0 and rules.spell_slots(level)==0:continue
			var opposition: int=rules.num(rules.row("spellschools",int(rules.draft.school)),"Opposition",-1);var letter: Variant=rules.cell(rules.row("spellschools",opposition),"Letter")
			if int(rules.draft.school)!=0 and State.present(letter) and rules.cell(rules.row("spells",id),"School")==letter:continue
		else:
			var maximum: int=rules.num(rules.first("SpellKnownTable"),"SpellLevel"+str(level))
			if known.size()>=maximum:continue
		known.append(id)
		if memorizes and level!=0:remaining-=1
	if memorizes:
		for level in 10:rules.draft.memorized[level]=rules.draft.known.get(level,[]).slice(0,rules.spell_slots(level))
static func apply(rules,id: int,automatic: bool) -> Dictionary:
	var data: Dictionary=rules.row("packages",id)
	if data.is_empty():return {"accepted":false,"error":"The selected package has no active rule row."}
	rules.draft.packageId=id;rules.draft.packageSource=true
	var gold: Variant=scalar(rules,data,"Gold")
	if gold!=null:rules.draft.packageGold=int(gold)&0xffffffff
	rules.draft.get_or_add("packageEquipment",[]).append_array(equipment(rules,data))
	if not automatic:return {"accepted":true,"configure":true,"packageId":id}
	if rules.num(rules.cls(),"PickSchool")!=0:
		var school: Variant=scalar(rules,data,"School")
		if school!=null:rules.draft.school=int(school)&255
	if rules.num(rules.cls(),"PickDomains")!=0:
		if rules.draft.domains.size()!=2:rules.draft.domains=[255,255]
		for index in 2:
			var domain: Variant=scalar(rules,data,"Domain"+str(index+1))
			if domain!=null:rules.draft.domains[index]=int(domain)&255
	if (rules.num(rules.cls(),"MinAssociateLevel")&255)==1:
		var associate: Variant=scalar(rules,data,"Associate")
		if associate!=null:
			rules.draft["familiar" if rules.num(rules.cls(),"Arcane")!=0 else "companion"]=int(associate)
			# The original generates a new name through CNWNameGen. Preserve the
			# existing draft name until that data-driven name owner is ported.
			rules.draft.packageAssociateNamePending=true
	if not resource(rules,data,"SpellPref2DA").is_empty():recommend_spells(rules,data)
	if not resource(rules,data,"FeatPref2DA").is_empty():
		var feats:=recommend_feats(rules,data)
		if not feats.ready:return {"accepted":false,"error":str(feats.get("reason","The automatic feat preferences are unavailable."))}
	if not resource(rules,data,"SkillPref2DA").is_empty():recommend_skills(rules,data)
	rules.commit_skill_summary()
	return {"accepted":true,"code":0x8008,"packageId":id}
