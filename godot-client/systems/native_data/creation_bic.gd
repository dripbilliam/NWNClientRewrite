extends RefCounted
const W=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
var failure:=""
var writer:=W.new()
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
	failure=""; var errors: Array=rules.errors()
	if not errors.is_empty(): failure="\n".join(errors); return PackedByteArray()
	var d: Dictionary=rules.draft; var cls: Dictionary=rules.cls(); var race: Dictionary=rules.race(); var package: Dictionary=rules.row("packages",int(d.packageId)); var hp: int=rules.num(cls,"HitDie")
	var skill_rows: Array=[]; var feat_rows: Array=[]; var feats: Array=rules.granted_feats()
	for choice in d.feats: feats.append(int(choice.id))
	for id in rules.rows("skills").size(): skill_rows.append({"Rank":W.field(0,int(d.skills.get(id,0)))})
	for id in feats: feat_rows.append({"Feat":W.field(2,int(id))})
	var classes:={"Class":W.field(5,int(d.classId)),"ClassLevel":W.field(3,1),"School":W.field(0,int(d.school)),"Domain1":W.field(0,int(d.domains[0]) if d.domains.size()>0 else 0),"Domain2":W.field(0,int(d.domains[1]) if d.domains.size()>1 else 0)}
	var history:={"LvlStatHitDie":W.field(0,hp),"LvlStatClass":W.field(0,int(d.classId)),"EpicLevel":W.field(0,0),"SkillPoints":W.field(2,rules.skill_balance()),"SkillList":list(skill_rows,0),"FeatList":list(feat_rows,0)}
	for level in 10:
		var known: Array=[]
		for id in d.known.get(level,[]): known.append({"Spell":W.field(2,int(id))})
		if not known.is_empty(): classes["KnownList"+str(level)]=list(known,3); history["KnownList"+str(level)]=list(known,0)
		var count: int=rules.spell_slots(level)
		if rules.num(cls,"MemorizesSpells")!=0 and count>0:
			var prepared: Array=[]; var source: Array=d.memorized.get(level,[])
			for slot in count:
				var id: Variant=source[slot] if slot<source.size() else null
				var values:={"Spell":W.field(2,65535 if id==null else int(id)),"Ready":W.field(0,0 if id==null else 1),"SpellMetaMagic":W.field(0,0)}
				if rules.num(cls,"PickDomains")!=0 and level>0 and slot==count-1: values.DomainSpell=W.field(0,1)
				prepared.append(values)
			classes["MemorizedList"+str(level)]=list(prepared,3)
	if rules.num(cls,"SpellCaster")!=0 and rules.num(cls,"MemorizesSpells")==0:
		var uses: Array=[]
		for level in 10: uses.append({"NumSpellsLeft":W.field(0,rules.spell_slots(level))})
		classes.SpellsPerDayList=list(uses,0x4567)
	var fields: Dictionary={}
	for pair in [["FirstName",str(d.firstName).strip_edges()],["LastName",str(d.lastName).strip_edges()],["Description",d.biography]]: fields[pair[0]]=W.field(12,pair[1])
	for pair in [["IsPC",1],["IsDM",0],["Gender",d.gender],["Race",d.raceId],["StartingPackage",int(d.packageId) if int(d.packageId)<256 else 0],["Interruptable",1],["Disarmable",1],["IsCommandable",1],["IsDestroyable",1],["IsRaiseable",1],["NaturalAC",0],["GoodEvil",d.goodEvil],["LawfulChaotic",d.lawChaos],["Appearance_Head",d.head],["Color_Skin",d.skin],["Color_Hair",d.hair],["Color_Tattoo1",d.tattoo1],["Color_Tattoo2",d.tattoo2],["MovementRate",0]]: fields[pair[0]]=W.field(0,int(pair[1]))
	for pair in [["Age",d.age],["Phenotype",d.phenotype],["FamiliarType",d.familiar],["CompanionType",d.companion]]: fields[pair[0]]=W.field(5,int(pair[1]))
	for pair in [["Subrace",d.subrace],["Deity",d.deity],["Tag",""],["FamiliarName",d.familiarName],["CompanionName",d.companionName]]: fields[pair[0]]=W.field(10,pair[1])
	for pair in [["Conversation",""],["Portrait",d.portrait]]: fields[pair[0]]=W.field(11,pair[1])
	for pair in [["xStartingPackage",d.packageId],["Experience",0],["Gold",rules.num(package,"Gold")]]: fields[pair[0]]=W.field(4,int(pair[1]))
	for key in ["HitPoints","CurrentHitPoints","MaxHitPoints"]: fields[key]=W.field(3,hp)
	for pair in [["FactionID",0],["Appearance_Type",rules.num(race,"Appearance")],["SoundSetFile",d.soundset],["SkillPoints",rules.skill_balance()]]: fields[pair[0]]=W.field(2,int(pair[1]))
	for pair in [["XPosition",0],["YPosition",0],["ZPosition",0],["XOrientation",0],["YOrientation",1]]: fields[pair[0]]=W.field(8,float(pair[1]))
	for key in rules.ABILITIES: fields[key]=W.field(0,int(d.abilities[key]))
	for part in ["Neck","Torso","Pelvis","LBicep","LFArm","LHand","LThigh","LShin","LFoot","RBicep","RFArm","RHand","RThigh","RShin"]: fields["BodyPart_"+part]=W.field(0,1)
	fields.ArmorPart_RFoot=W.field(0,1); fields.SkillList=list(skill_rows,0); fields.FeatList=list(feat_rows,1); fields.ClassList=W.field(15,[W.record(classes,2)]); fields.LvlStatList=W.field(15,[W.record(history,0)])
	var items: Array=[]; var catalog=rules.catalog.fork()
	for data in rules.rows(str(rules.cell(package,"Equip2DA",""))):
		var name:=str(rules.cell(data,"Label",""))
		if not rules.present(name): continue
		var value:=item(catalog,name,0)
		if not failure.is_empty(): return PackedByteArray()
		items.append(value)
	var clothing:=item(catalog,str(rules.cell(rules.row("chargenclothes",int(d.clothes)),"ItemResRef","")),2)
	if not failure.is_empty(): return PackedByteArray()
	fields.ItemList=W.field(15,items); fields.Equip_ItemList=W.field(15,[clothing])
	var bytes:=writer.write("BIC ",W.record(fields)); failure=writer.failure
	if failure.is_empty():
		var parser:=Gff.new(); parser.parse(bytes,"BIC "); failure=parser.failure
	return bytes if failure.is_empty() else PackedByteArray()
