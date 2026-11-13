extends "res://tests/native_creation_daily_uses_test.gd"
func record_id(document: Dictionary,value: Dictionary) -> int:
	for id in document.records:
		if is_same(document.records[id],value):return int(id)
	return -1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Unchanged installed UTI/catalog is used by actual Builder")
	var rules:=OwnedRules.new();rules.catalog=catalog
	rules.tables={"classes":{"orderedRows":[{"HitDie":"8","SpellCaster":"1","MemorizesSpells":"1","MinAssociateLevel":"255","PickDomains":"1"}]},"racialtypes":{"orderedRows":[{"Appearance":"0"}]},"ruleset":{"orderedRows":[]},"packages":{"orderedRows":[{"Gold":"3"}]},"chargenclothes":{"orderedRows":[{"ItemResRef":"nw_cloth002"}]}}
	rules.draft={"classId":0,"raceId":0,"packageId":0,"gender":0,"feats":[],"skills":{},"known":{0:[1,2],1:[3]},"memorized":{0:[1,null],1:[]},"domains":[0,1],"school":0,"firstName":"Native","lastName":"Spells","biography":"","subrace":"","deity":"","age":18,"phenotype":0,"head":1,"clothes":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"portrait":"po_hu_m_01","soundset":0,"familiar":-1,"familiarName":"","companion":-1,"companionName":"","goodEvil":50,"lawChaos":50,"abilities":{"Str":10,"Dex":10,"Con":10,"Int":10,"Wis":10,"Cha":10}}
	rules.creation_skill_points=0;rules.skill_points_snapshot={};rules.creation_base_hp=8
	var builder:=Builder.new();var parser:=Parser.new();var generic:=parser.parse(builder.build(rules),"BIC ")
	check(builder.failure.is_empty() and parser.failure.is_empty(),"Generic full BIC still builds")
	var generic_class: Dictionary=generic.root.ClassList[0]
	var gid:=record_id(generic,generic_class.KnownList0[0]);var mid:=record_id(generic,generic_class.MemorizedList1[0])
	check(generic.struct_types[gid]==3 and generic.struct_types[mid]==3 and generic_class.MemorizedList1[0].keys().size()==4 and generic_class.MemorizedList1[0].has_all(["Spell","Ready","SpellMetaMagic","DomainSpell"]),"Generic Known/Mem type3 and richer saved-game flags remain unchanged")
	var parts: Array=[];parts.resize(19);parts.fill(1)
	var appearance: Dictionary={"head":1,"phenotype":0,"clothes":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"skinParts":parts,"bodyParts":parts.duplicate(),"materialColors":[0,0,0,0,0,0],"clothingResRef":"nw_cloth002"}
	rules.draft.sourceTailChoices=true
	rules.draft.sourceTailAppearance={"mode":0,"signature":[0,0,0,50,50,0],"appearanceId":0,"value":appearance,"choice":{"id":0,"resRef":"nw_cloth002"}}
	rules.draft.sourceTailInformation={"firstName":"Native","lastName":"Spells","description":"","deity":"","age":18,"soundset":0}
	var parsed:=parser.parse(builder.build(rules),"BIC ")
	check(builder.failure.is_empty() and parser.failure.is_empty(),"Actual source-tail typed BIC writes and reparses")
	if not parsed.is_empty():
		var cls: Dictionary=parsed.root.ClassList[0]
		for key in ["KnownList0","KnownList1","MemorizedList0","MemorizedList1"]:
			for row in cls[key]:
				var id:=record_id(parsed,row)
				check(parsed.struct_types[id]==0 and row.keys()==["Spell"] and parsed.field_types[id]=={"Spell":2},"Original807950 source row type0 and ONLY WORD Spell: "+key)
		check(cls.MemorizedList0[0].Spell==1 and cls.MemorizedList0[1].Spell==65535 and cls.MemorizedList1[0].Spell==65535,"Original unset getter serializes WORDffff, without invented ready/meta/domain tags")
		check(cls.Domain1==0 and cls.Domain2==1 and cls.KnownList0.map(func(row):return int(row.Spell))==[1,2],"Source field-shape correction preserves domain IDs and known spell order")
	rules.draft.known[0]=range(256)
	check(builder.build(rules).is_empty() and builder.failure.contains("255"),"Nonterminating original known-count256 domain is rejected explicitly")
	rules.draft.sourceTailChoices=false
	check(not builder.build(rules).is_empty() and builder.failure.is_empty(),"Unrelated generic writer retains its existing wider known-list capability")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual complete Builder/GFF source-tail and generic outputs: original807950 struct0/WORD-only Known/Memorized rows, unsetFFFF, no copied Ready/Meta/Domain flags, independent domain/known order preserved and BYTE save-loop bound. Authored admission fixture with real catalog/UTI; no server claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
