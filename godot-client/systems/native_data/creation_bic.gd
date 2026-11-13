extends RefCounted
const W=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Tail=preload("res://systems/native_data/creation_tail_bic.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const ClassTables=preload("res://systems/native_data/creation_feat_tables.gd")
var failure:=""
var writer:=W.new()
static func source_hp_fields(rules) -> Dictionary:
	# Original807950 serializes the already committed first-level caches.
	# Getter7f5e20 returns +8a; selected feat insertion9c8a90 does not recalculate it.
	var d: Dictionary=rules.draft;var base: Variant=rules.creation_base_hp
	if not base is int:return Tail.unavailable("The committed first-level hit-die cache is unavailable.")
	var cache:=Vitals.project({"classId":int(d.classId),"race":int(d.raceId),"abilities":d.abilities,"dexterityAdjustment":0},rules.tables,base)
	if not cache.ready:return Tail.unavailable("The committed first-level vital caches are unavailable.")
	var current: int=int(cache.fields.currentHP);var maximum: int=int(cache.fields.maximumHP)
	var values: Dictionary={"HitPoints":base,"MaxHitPoints":maximum,"PregameCurrent":current,"CurrentHitPoints":int(base)+current-maximum}
	var fields: Dictionary={}
	for key in values:
		if int(values[key])< -32768 or int(values[key])>32767:return Tail.unavailable("The committed first-level hit-point field cannot be serialized.")
		fields[key]=W.field(3,int(values[key]))
	return {"ready":true,"fields":fields}
static func source_pet_fields(rules) -> Dictionary:
	var d: Dictionary=rules.draft;var table: Dictionary=rules.tables.get("classes",{})
	var minimum:=ClassTables.integer(table,int(d.get("classId",-1)),"MinAssociateLevel")
	if not minimum.ready or not minimum.ok:return Tail.unavailable("The compiled class associate minimum is unavailable.")
	if (int(minimum.value)&255)!=1:return {"ready":true,"fields":{}}
	var arcane:=ClassTables.integer(table,int(d.classId),"Arcane")
	if not arcane.ready or not arcane.ok:return Tail.unavailable("The compiled class associate kind is unavailable.")
	var kind: String="familiar" if int(arcane.value)!=0 else "companion"
	var value: Variant=d.get(kind);var name: Variant=d.get(kind+"Name")
	if not value is int or value< -2147483648 or value>2147483647 or not name is String:return Tail.unavailable("The owned associate type/name cannot be serialized.")
	# Original807950 calls WriteFieldINT, conditionally on compiled class
	# metadata; absence of the unused pair is part of the native file shape.
	var prefix: String=kind.capitalize()
	return {"ready":true,"fields":{prefix+"Type":W.field(5,int(value)),prefix+"Name":W.field(10,str(name))}}
static func tail_patch(d: Dictionary) -> Dictionary:
	var appearance: Variant=d.get("sourceTailAppearance");var info: Variant=d.get("sourceTailInformation")
	if not appearance is Dictionary or not info is Dictionary:return Tail.unavailable("The accepted source tail is unavailable.")
	if not Tail.exact(appearance.get("mode"),0):return Tail.unavailable("Existing-character customization cannot use the first-level writer.")
	if not appearance.get("signature") is Array or appearance.signature!=[d.raceId,d.gender,d.classId,d.lawChaos,d.goodEvil,d.packageId]:return Tail.unavailable("The accepted source tail belongs to another creation context.")
	if not appearance.get("value") is Dictionary or not appearance.get("choice") is Dictionary:return Tail.unavailable("The accepted native appearance fields are unavailable.")
	var value: Dictionary=appearance.get("value",{})
	for field in ["head","phenotype","clothes","skin","hair","tattoo1","tattoo2"]:
		if value.get(field)!=d.get(field):return Tail.unavailable("The accepted native appearance was replaced: "+field)
	for field in ["firstName","lastName","age","deity","soundset"]:
		if info.get(field)!=d.get(field):return Tail.unavailable("The accepted native information was replaced: "+field)
	if info.get("description")!=d.get("biography"):return Tail.unavailable("The accepted native biography was replaced.")
	var result:=Tail.first_level(appearance.get("appearanceId"),value,appearance.get("choice",{}));var information:=Tail.information(info)
	if not result.ready:return result
	if not information.ready:return information
	result.fields.merge(information.fields,true);return result
static func validation_errors(rules) -> Array:
	var errors: Array=rules.errors()
	if not rules.draft.get("sourceTailChoices",false):return errors
	var patch:=tail_patch(rules.draft)
	if not patch.ready:errors.append(patch.reason);return errors
	# These exact fields have passed the source views' different native limits
	# and active provider admission. Keep all unrelated class/draft validation.
	var replaced: Array=["Enter a first name.","Enter a valid age.","Choose an available voice.","Choose an available head and body type.","Choose available clothing."]
	for field in ["firstName","lastName","deity","biography"]:replaced.append("Invalid or overlong "+field+".")
	for field in ["skin","hair","tattoo1","tattoo2"]:replaced.append("Invalid "+field+" colour.")
	return errors.filter(func(error):return not replaced.has(error))
func list(entries: Array,type: int) -> Dictionary:
	var result: Array=[]
	for values in entries: result.append(W.record(values,type))
	return W.field(15,result)
func item(catalog,name: String,type: int) -> Dictionary:
	var bytes: PackedByteArray=catalog.get_resource(name,2025)
	if not catalog.failure.is_empty(): failure=catalog.failure; return {}
	var parser:=Gff.new(); var document:=parser.parse(bytes,"UTI ")
	if not parser.failure.is_empty(): failure=parser.failure; return {}
	var result:=writer.typed(document,document.root,type)
	if not writer.failure.is_empty(): failure=writer.failure; return {}
	result.fields.erase("ObjectId"); result.fields.Identified=W.field(0,1); return result
func build(rules) -> PackedByteArray:
	failure=""; var errors: Array=validation_errors(rules)
	if not errors.is_empty(): failure="\n".join(errors); return PackedByteArray()
	var d: Dictionary=rules.draft; var cls: Dictionary=rules.cls(); var race: Dictionary=rules.race(); var package: Dictionary=rules.row("packages",int(d.packageId)); var hp: int=rules.num(cls,"HitDie")
	var skill_rows: Array=[]; var feat_rows: Array=[]; var feats: Array=rules.granted_feats()
	for choice in d.feats: feats.append(int(choice.id))
	for id in rules.rows("skills").size(): skill_rows.append({"Rank":W.field(0,int(d.skills.get(id,0)))})
	for id in feats: feat_rows.append({"Feat":W.field(2,int(id))})
	# Original first-level client writer140807950 uses active PickSchool /
	# PickDomains flags and a ClassList element of type0. Other classes omit
	# these optional fields; internal unset domains are not ordinary domain0.
	var classes:={"Class":W.field(5,int(d.classId)),"ClassLevel":W.field(3,1)}
	if rules.num(cls,"PickSchool")!=0: classes.School=W.field(0,int(d.school))
	if rules.num(cls,"PickDomains")!=0:
		classes.Domain1=W.field(0,int(d.domains[0])); classes.Domain2=W.field(0,int(d.domains[1]))
	var history:={"LvlStatHitDie":W.field(0,hp),"LvlStatClass":W.field(0,int(d.classId)),"EpicLevel":W.field(0,0),"SkillPoints":W.field(2,rules.skill_balance()),"SkillList":list(skill_rows,0),"FeatList":list(feat_rows,0)}
	for level in 10:
		if d.get("sourceTailChoices",false) and d.known.get(level,[]).size()>255:failure="The original first-level known-spell loop cannot terminate above255 entries.";return PackedByteArray()
		var known: Array=[]
		for id in d.known.get(level,[]): known.append({"Spell":W.field(2,int(id))})
		if not known.is_empty(): classes["KnownList"+str(level)]=list(known,0 if d.get("sourceTailChoices",false) else 3); history["KnownList"+str(level)]=list(known,0)
		var count: int=rules.spell_slots(level)
		if d.get("sourceTailChoices",false) and (count<0 or count>255):failure="The original first-level memorized slot count is outside its BYTE range.";return PackedByteArray()
		if rules.num(cls,"MemorizesSpells")!=0 and count>0:
			var prepared: Array=[]; var source: Array=d.memorized.get(level,[])
			for slot in count:
				var id: Variant=source[slot] if slot<source.size() else null
				var values:={"Spell":W.field(2,65535 if id==null else int(id))}
				#807950 AddListElement0 writes only WORD Spell; richer saved-game
				# flags belong to the unrelated generic serialization path.
				if not d.get("sourceTailChoices",false):
					values.Ready=W.field(0,0 if id==null else 1);values.SpellMetaMagic=W.field(0,0)
					if rules.num(cls,"PickDomains")!=0 and level>0 and slot==count-1:values.DomainSpell=W.field(0,1)
				prepared.append(values)
			classes["MemorizedList"+str(level)]=list(prepared,0 if d.get("sourceTailChoices",false) else 3)
	# The original first-level807950 writer emits known/memorized lists here,
	# and lets the authoritative server derive spontaneous daily uses. Retain
	# the older generic path only for drafts outside the verified source flow.
	if not d.get("sourceTailChoices",false) and not d.get("sourceSpellChoices",false) and rules.num(cls,"SpellCaster")!=0 and rules.num(cls,"MemorizesSpells")==0:
		var uses: Array=[]
		for level in 10: uses.append({"NumSpellsLeft":W.field(0,rules.spell_slots(level))})
		classes.SpellsPerDayList=list(uses,0x4567)
	var fields: Dictionary={}
	for pair in [["FirstName",str(d.firstName).strip_edges()],["LastName",str(d.lastName).strip_edges()],["Description",d.biography]]: fields[pair[0]]=W.field(12,pair[1])
	for pair in [["IsPC",1],["IsDM",0],["Gender",d.gender],["Race",d.raceId],["StartingPackage",int(d.packageId) if int(d.packageId)<256 else 0],["Interruptable",1],["Disarmable",1],["IsCommandable",1],["IsDestroyable",1],["IsRaiseable",1],["NaturalAC",0],["GoodEvil",d.goodEvil],["LawfulChaotic",d.lawChaos],["Appearance_Head",d.head],["Color_Skin",d.skin],["Color_Hair",d.hair],["Color_Tattoo1",d.tattoo1],["Color_Tattoo2",d.tattoo2],["MovementRate",0]]: fields[pair[0]]=W.field(0,int(pair[1]))
	for pair in [["Age",d.age],["Phenotype",d.phenotype]]: fields[pair[0]]=W.field(5,int(pair[1]))
	for pair in [["Subrace",d.subrace],["Deity",d.deity],["Tag",""]]: fields[pair[0]]=W.field(10,pair[1])
	if d.get("sourceTailChoices",false):
		var pets:=source_pet_fields(rules)
		if not pets.ready:failure=pets.reason;return PackedByteArray()
		fields.merge(pets.fields,true)
	else:
		for pair in [["FamiliarType",d.familiar],["CompanionType",d.companion]]:fields[pair[0]]=W.field(5,int(pair[1]))
		for pair in [["FamiliarName",d.familiarName],["CompanionName",d.companionName]]:fields[pair[0]]=W.field(10,pair[1])
	for pair in [["Conversation",""],["Portrait",d.portrait]]: fields[pair[0]]=W.field(11,pair[1])
	for pair in [["xStartingPackage",d.packageId],["Experience",0],["Gold",int(d.get("packageGold",0)) if d.get("packageSource",false) else rules.num(package,"Gold")]]: fields[pair[0]]=W.field(4,int(pair[1]))
	if d.get("sourceTailChoices",false):
		var hitpoints:=source_hp_fields(rules)
		if not hitpoints.ready:failure=hitpoints.reason;return PackedByteArray()
		fields.merge(hitpoints.fields,true)
	else:
		for key in ["HitPoints","CurrentHitPoints","MaxHitPoints"]: fields[key]=W.field(3,hp)
	for pair in [["FactionID",0],["Appearance_Type",rules.num(race,"Appearance")],["SoundSetFile",d.soundset],["SkillPoints",rules.skill_balance()]]: fields[pair[0]]=W.field(2,int(pair[1]))
	for pair in [["XPosition",0],["YPosition",0],["ZPosition",0],["XOrientation",0],["YOrientation",1]]: fields[pair[0]]=W.field(8,float(pair[1]))
	for key in rules.ABILITIES: fields[key]=W.field(0,int(d.abilities[key]))
	for part in ["Neck","Torso","Pelvis","LBicep","LFArm","LHand","LThigh","LShin","LFoot","RBicep","RFArm","RHand","RThigh","RShin"]: fields["BodyPart_"+part]=W.field(0,1)
	fields.ArmorPart_RFoot=W.field(0,1); fields.SkillList=list(skill_rows,0); fields.FeatList=list(feat_rows,1); fields.ClassList=W.field(15,[W.record(classes,0)]); fields.LvlStatList=W.field(15,[W.record(history,0)])
	var items: Array=[]; var catalog=rules.catalog.fork()
	var equipment: Array=d.get("packageEquipment",[]) if d.get("packageSource",false) else rules.rows(str(rules.cell(package,"Equip2DA",""))).map(func(data):return str(rules.cell(data,"Label","")))
	for entry in equipment:
		var name:=str(entry)
		if not rules.present(name):continue
		var value:=item(catalog,name,0)
		if not failure.is_empty(): return PackedByteArray()
		items.append(value)
	fields.ItemList=W.field(15,items)
	if d.get("sourceTailChoices",false):
		var patch:=tail_patch(d)
		if not patch.ready:failure=patch.reason;return PackedByteArray()
		fields.merge(patch.fields,true)
	else:
		var clothing:=item(catalog,str(rules.cell(rules.row("chargenclothes",int(d.clothes)),"ItemResRef","")),2)
		if not failure.is_empty(): return PackedByteArray()
		fields.Equip_ItemList=W.field(15,[clothing])
	var bytes:=writer.write("BIC ",W.record(fields)); failure=writer.failure
	if failure.is_empty():
		var parser:=Gff.new(); parser.parse(bytes,"BIC "); failure=parser.failure
	return bytes if failure.is_empty() else PackedByteArray()
