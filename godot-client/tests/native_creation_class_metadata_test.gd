extends SceneTree
const Metadata=preload("res://systems/native_data/creation_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Post=preload("res://systems/native_data/creation_post_feats.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.success and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==512 and oracle.entry=="0x1402a4350","Complete unchanged original defaults oracle identifies512 executions/all256BYTE IDs")
	var native: Dictionary={}
	for row in oracle.rows:
		var actual:=Metadata.legacy(int(row.classId));var expected: Dictionary=row.fields
		for field in expected:check(actual.get(field)==expected[field],"Native default "+str(row.classId)+" fill"+str(row.fill)+" "+str(field),{"actual":actual.get(field),"expected":expected[field]})
		native[int(row.classId)]=expected
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Read-only original catalog mounts")
	var raw:=Parser.new().parse(catalog.get_resource("classes",2017).get_string_from_utf8());var before:=JSON.stringify(raw);var compiled:=Metadata.compile(raw)
	check(compiled.ready and raw.orderedRows.size()==43,"All43 actual installed physical class rows compile")
	if compiled.ready:
		check(is_same(compiled.raw,raw) and not is_same(compiled.table,raw) and JSON.stringify(raw)==before,"Private projection retains exact raw active table without mutating catalog/text data")
		check(compiled.table.rowLabels==raw.rowLabels and compiled.table.columns.slice(0,raw.columns.size())==raw.columns and compiled.table.orderedRows.size()==raw.orderedRows.size(),"Physical IDs, labels and source header order/case remain intact")
		for id in raw.orderedRows.size():
			for field in Metadata.NUMERIC:
				var read:=Tables.integer(raw,id,field);var expected: Variant=native[id][field]
				if read.ready and read.ok:expected=int(int(read.value)!=0) if field in Metadata.BOOLEANS else int(read.value)&255 if field=="MinAssociateLevel" else int(read.value)
				var actual:=Tables.integer(compiled.table,id,field)
				check(read.ready and actual.ready and actual.ok and actual.value==expected,"Installed raw/default/active numeric composition "+str(id)+"/"+str(field),{"raw":read,"actual":actual,"expected":expected})
		var rules:=Rules.new();rules.tables={"classes":compiled.table};rules.draft={"classId":4}
		var fighter:=Post.creation_source(rules);var finish:=Post.new().advance(fighter,0x800e)
		check(fighter.PickDomains==0 and fighter.PickSchool==0 and fighter.SpellbookRestricted==0 and fighter.MinAssociateLevel==255 and finish.ready and finish.child.is_empty(),"Actual stock Fighter failed optional cells preserve initialized defaults and finish the source post chain")
		check(Tables.integer(compiled.table,10,"PickSchool").value==1 and Tables.cell(compiled.table,10,"SpellcastingAbil").text=="INT" and Tables.cell(compiled.table,10,"SpellTableColumn").text=="Wiz_Sorc" and Tables.integer(compiled.table,10,"MinAssociateLevel").value==1,"Actual stock Wizard retains original school/primary/column/familiar defaults")
		check(Tables.integer(compiled.table,2,"PickDomains").value==1 and Tables.integer(compiled.table,3,"MinAssociateLevel").value==1 and Tables.integer(compiled.table,7,"MinAssociateLevel").value==6,"Actual Cleric/Druid/Ranger defaults preserve distinct class-dependent branches")
	var parser:=Parser.new();var custom:=parser.parse_reference("2DA V2.0\nArcane arcane MinAssociateLevel PickSchool SpellcastingAbil SpellTableColumn MinCastingLevel CLMultiplier\n77 2 0 257 0 CHA CUSTOM_SERVER -2 1.5\n")
	var custom_before:=JSON.stringify(custom);var answer:=Metadata.compile(custom)
	check(answer.ready and Tables.integer(answer.table,0,"Arcane").value==1 and answer.table.orderedCells[0][1]=="0","Active nonzero Arcane normalizes to native1, first duplicate physical column wins and later source cell remains untouched")
	check(Tables.integer(answer.table,0,"MinAssociateLevel").value==1 and Tables.integer(answer.table,0,"MinCastingLevel").value== -2 and Tables.integer(answer.table,0,"PickSchool").value==0,"Valid active fields override compatibility defaults with exact BYTE/signedINT/boolean widths")
	check(Tables.cell(answer.table,0,"SpellcastingAbil").text=="CHA" and Tables.cell(answer.table,0,"SpellTableColumn").text=="CUSTOM_SERVER" and float(Tables.cell(answer.table,0,"CLMultiplier").text)==1.5,"Explicit active ability/column/finiteFLOAT fields override original defaults without stock choices")
	check(JSON.stringify(custom)==custom_before and answer.table.rowLabels==["77"] and answer.table.orderedRows.size()==1,"Custom row label77 remains physical class0 and raw bytes/data stay unchanged")
	var reverse:=parser.parse_reference("2DA V2.0\narcane Arcane playerclass PlayerClass\n0 2 0 0 1\n");var reverse_before:=JSON.stringify(reverse);var reversed:=Metadata.compile(reverse)
	var getter:=Rules.new();getter.tables={"classes":reversed.table};getter.draft={"classId":0}
	check(reversed.ready and Tables.integer(reversed.table,0,"Arcane").value==1 and getter.num(getter.cls(),"Arcane")==1,"Reversed case headers preserve the first native column through both physical and exact-key rule getters")
	check(reversed.table.orderedCells[0][1]=="0" and reversed.table.orderedCells[0][3]=="1" and getter.num(getter.cls(),"PlayerClass")==0 and JSON.stringify(reverse)==reverse_before,"Private aliases also preserve unrelated first-column semantics while later physical cells and raw graph remain unchanged")
	var authored:={"orderedRows":[{"Arcane":"-2","FeatsTable":"server_feats","PlayerClass":"1","SpellCaster":"1","SpellcastingAbil":"BAD"}]};answer=Metadata.compile(authored)
	check(answer.ready and Tables.integer(answer.table,0,"Arcane").value==1 and Tables.cell(answer.table,0,"FeatsTable").text=="server_feats" and Tables.integer(answer.table,0,"SpellCaster").value==1,"Header-free authored active tables retain every unrelated field and native nonzero normalization")
	check(Tables.cell(answer.table,0,"SpellcastingAbil").text=="****","Unrecognized primary string preserves original default invalid ability byte instead of choosing an ability")
	var broken:=parser.parse_reference("2DA V2.0\nPickDomains Arcane CLMultiplier\n0 0xGG 0xGG bad-float\n");answer=Metadata.compile(broken)
	check(answer.ready and answer.unknown[0].has("PickDomains") and not Tables.integer(answer.table,0,"PickDomains").ready and Tables.cell(answer.table,0,"PickDomains").text=="0xGG","Malformed successful native hex conversion remains unresolved, never a legacy/default zero")
	check(answer.unknown[0].has("Arcane") and answer.unknown[0].has("CLMultiplier"),"Unknown integer/FLOAT writes retain explicit private diagnostics")
	check(not Metadata.compile({}).ready,"Missing physical table is explicit rather than a stock class list")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"originalExecutions":512,"installedRows":raw.orderedRows.size(),"gpu":false,"serverConnections":0,"scope":"Private first-level metadata compiler defaults against complete original2a4350 execution for256physicalBYTE IDs/two dirty seeds, all43 real installed rows, conditional active override widths/case/physical IDs, malformed inputs and raw isolation. Source data only; no actual source controller/controls/BIC/server admission or world/level-up migration."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
