extends SceneTree
const Publication=preload("res://systems/native_data/level_up_rule_publication.gd")
const Metadata=preload("res://systems/native_data/creation_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Navigation=preload("res://systems/native_data/level_up_navigation.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Post=preload("res://systems/native_data/creation_post_feats.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func branches(received: Dictionary,class_id: int,active: Dictionary) -> Dictionary:
	var advanced:=Vitals.next_classes(received,class_id);var nav:=Navigation.new();nav.begin([8,19,42,61]);var transition:=nav.after_class(nav.ticket,advanced)
	if not transition.ready:return transition
	var source:=nav.post_source(active);var post:=Post.new();var children: Array=[]
	for at in 5:
		var value:=post.advance(source,0x8010)
		if not value.ready:return value
		if not value.activated:return {"ready":true,"children":children,"source":source,"code":value.code}
		children.append(value.child)
	return {"ready":false,"reason":"Mode1 post cursor did not terminate."}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle));var native: Dictionary={}
	check(oracle.get("success",false) and oracle.get("rows",[]).size()==512 and oracle.get("entry")=="0x1402a4350" and oracle.get("binarySha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original512 execution/default oracle is identified independently")
	for row in oracle.get("rows",[]):native[int(row.classId)]=row.fields
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed catalog mounts read-only")
	var raw:=Parser.new().parse(catalog.get_resource("classes",2017).get_string_from_utf8());var source:={"classes":raw,"ruleset":{"orderedRows":[]},"custom_spells":{"orderedRows":[{"Name":"16777217"}]}};var before: Dictionary=source.duplicate(true)
	var owner:=Publication.new();var scope: Array=[8,19,42,61];check(not owner.view(scope).ready,"No private view exists before a transaction begins")
	var value:=owner.begin(source,scope);check(value.ready and raw.orderedRows.size()==43,"Private mode1 owner publishes all actual43 installed physical class rows")
	if value.ready:
		check(not is_same(value.tables,source) and not is_same(value.tables.classes,raw) and is_same(value.rawClasses,raw) and source==before,"Raw active classes/map remain exact; only mode1 class projection detaches")
		check(is_same(value.tables.ruleset,source.ruleset) and is_same(value.tables.custom_spells,source.custom_spells),"Other active resource tables remain immutable shallow publication references")
		check(value.tables.classes.rowLabels==raw.rowLabels and value.tables.classes.orderedRows.size()==raw.orderedRows.size() and value.tables.classes.nativeClassProjection.scope=="mode1_private","Physical IDs/labels are preserved and private ownership is mode1")
		for id in raw.orderedRows.size():
			for field in Metadata.NUMERIC:
				var read:=Tables.integer(raw,id,field);var expected: Variant=native[id][field]
				if read.ready and read.ok:expected=int(int(read.value)!=0) if field in Metadata.BOOLEANS else int(read.value)&255 if field=="MinAssociateLevel" else int(read.value)
				var actual:=Tables.integer(value.tables.classes,id,field)
				check(actual.ready and actual.ok and actual.value==expected,"Actual mode1 private native/default/active field "+str(id)+"/"+field,{"actual":actual,"expected":expected})
		var ids: Dictionary={}
		for id in raw.orderedRows.size():ids[str(Tables.cell(raw,id,"Label").text).to_lower()]=id
		var received:={"classes":[{"id":int(ids.fighter),"level":1}]};var retained:=received.duplicate(true)
		var baseline:=branches(received,int(ids.fighter),source);check(not baseline.ready and baseline.get("field")=="SpellbookRestricted","Actual raw stock mode1 existing-class path exposes its missing compiled metadata")
		var fixed:=branches(received,int(ids.fighter),value.tables);check(fixed.ready and fixed.children.is_empty() and fixed.code==0x8016,"Actual compiled stock Fighter current-class2 mode1 post path terminates without invented flags",fixed)
		for sample in [{"label":"wizard","children":["school","spells","associate"]},{"label":"cleric","children":["domains"]},{"label":"druid","children":["associate"]}]:
			var answer:=branches(received,int(ids[sample.label]),value.tables);check(answer.ready and answer.children==sample.children,"Original new-class mode1 routing follows active/default "+sample.label,answer)
		check(received==retained and source==before,"Mode1 routing leaves canonical received snapshot and raw active tables unchanged")
		var version: int=value.publication;var compiles:=owner.class_compiles;var warm:=owner.publish(source,scope)
		check(warm.publication==version and owner.class_compiles==compiles and is_same(warm.tables,value.tables),"Unchanged publication reuses private classes/map without recompiling")
		var arrived:=source.duplicate();arrived.late_preferences={"orderedRows":[{"SpellIndex":"17"}]};var next:=owner.publish(arrived,scope)
		check(next.ready and next.publication!=version and owner.class_compiles==compiles and is_same(next.tables.classes,value.tables.classes) and not value.tables.has("late_preferences"),"Late dependency publication does not mutate a captured draft map or recompile unchanged classes")
		check(not owner.current(arrived,scope,version) and owner.current(arrived,scope,next.publication),"Publication version guards distinguish the captured draft from changed active data")
		check(not owner.publish({},[8,19,42,60]).ready and owner.current(arrived,scope,next.publication),"A retired transaction cannot overwrite or retire the current view")
		var old_view: Dictionary=next.tables;var reopened:=owner.begin(source,[8,19,42,62]);check(reopened.ready and not owner.view(scope).ready and not is_same(old_view.classes,reopened.tables.classes),"Reopen retires prior scope and allocates a new private class graph even for the same raw table")
		old_view.classes.orderedRows[ids.fighter].Arcane="1";check(Tables.integer(reopened.tables.classes,int(ids.fighter),"Arcane").value==0 and source==before,"A retained retired private class view cannot change a new draft or canonical tables")
	var parser:=Parser.new();var custom:=parser.parse_reference("2DA V2.0\narcane Arcane minassociatelevel MinAssociateLevel playerclass PlayerClass ArcSpellLvlMod DivSpellLvlMod\n92 2 0 257 0 1 0 **** ****\n");var custom_before:=custom.duplicate(true);var custom_source:={"classes":custom};var custom_scope: Array=[8,19,42,63]
	value=owner.begin(custom_source,custom_scope)
	check(value.ready and Tables.integer(value.tables.classes,0,"Arcane").value==1 and value.tables.classes.orderedRows[0].Arcane=="1" and value.tables.classes.orderedCells[0][1]=="0","Active nonzero BOOL and reversed case aliases preserve native first-column and later physical provenance")
	check(Tables.integer(value.tables.classes,0,"MinAssociateLevel").value==1 and value.tables.classes.rowLabels==["92"] and custom==custom_before,"Active BYTE override and arbitrary row labels preserve physical0/raw graph")
	check(Tables.integer(value.tables.classes,0,"ArcSpellLvlMod").value==0 and Tables.integer(value.tables.classes,0,"DivSpellLvlMod").value==0 and value.compiledFields.has("ArcSpellLvlMod") and value.compiledFields.has("DivSpellLvlMod") and not Tables.integer(custom,0,"ArcSpellLvlMod").ok,"Source-proven mode1 constructor BYTEs resolve failed active lookups while raw classes stay unavailable")
	var broken:=parser.parse_reference("2DA V2.0\nPickSchool Arcane\n0 0xGG 0xGG\n");value=owner.publish({"classes":broken},custom_scope)
	check(value.ready and value.unknown[0].has("PickSchool") and not Tables.integer(value.tables.classes,0,"PickSchool").ready and not Tables.integer(value.tables.classes,0,"Arcane").ready,"Malformed reached native fields remain explicit rather than using guessed compatibility values")
	var old_version: int=value.publication;value=owner.publish({"classes":{}},custom_scope)
	check(not value.ready and not owner.view(custom_scope,old_version).ready and not value.tables.has("classes"),"Invalid current class publication cannot reuse a preceding valid class cache")
	owner.retire();check(not owner.view(custom_scope).ready and not owner.begin(source,[8,19,42,-1]).ready,"Teardown and malformed transaction scope cannot retain private rules")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Private mode1 native-class publication owner, all43 actual installed raw/default/active numeric rows against original oracle fields, actual mode1 data routing, BOOL/BYTE/physical aliases, raw/received isolation, immutable publication/draft scopes and explicit uncovered/malformed metadata. No first-level character snapshot, actual runtime controls, packet or original-server acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
