extends SceneTree
const Metadata=preload("res://systems/native_data/level_up_class_metadata.gd")
const Base=preload("res://systems/native_data/creation_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Snapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
const Capacity=preload("res://systems/native_data/level_up_feat_capacity.gd")
const State=preload("res://systems/native_data/level_up_feat_state.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
class Text extends RefCounted:
	var revision:=0
	func raw(value: Dictionary) -> String:return "Active "+str(int(value.strRef))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func _initialize() -> void:run.call_deferred()
func mode1_tables() -> Dictionary:
	return {"classes":{"orderedRows":[{"Label":"Other","SpellCaster":"0","ArcSpellLvlMod":"****","DivSpellLvlMod":"****","FeatsTable":"otherfeats","SkillsTable":"otherskills","AttackBonusTable":"otherbab"},{"Label":"Active caster","SpellCaster":"1","MemorizesSpells":"1","SpellbookRestricted":"1","LearnScroll":"0","SpellcastingAbil":"INT","SpellGainTable":"caster_gain","SpellKnownTable":"caster_known","PickSchool":"0","Arcane":"1","FeatsTable":"casterfeats","SkillsTable":"casterskills","AttackBonusTable":"casterbab"}]},"racialtypes":{"orderedRows":[{"NormalFeatEveryNthLevel":"1","NumberNormalFeatsEveryNthLevel":"1"}]},"ruleset":{"orderedRows":[]},"skills":{"orderedRows":[{"Untrained":"0","AllClassesCanUse":"1"}]},"feat":{"orderedRows":[{"Feat":"100","AllClassesCanUse":"1","MinSpellLvl":"2"}]},"otherfeats":{"orderedRows":[]},"casterfeats":{"orderedRows":[]},"otherskills":{"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]},"casterskills":{"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]},"otherbab":{"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"3"},{"BAB":"4"}]},"casterbab":{"orderedRows":[{"BAB":"0"}]},"caster_gain":{"orderedRows":[{"NumSpellLevels":"3","SpellLevel0":"2","SpellLevel1":"1","SpellLevel2":"1"}]},"caster_known":{"orderedRows":[{"SpellLevel0":"2","SpellLevel1":"1","SpellLevel2":"1"}]}}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed class resources mount read-only")
	var raw:=Parser.new().parse(catalog.get_resource("classes",2017).get_string_from_utf8());var before:=raw.duplicate(true);var base:=Base.compile(raw);var compiled:=Metadata.compile(raw)
	check(compiled.ready and raw.orderedRows.size()==43,"Mode1 extra-field projection covers all43 actual installed physical rows")
	if compiled.ready:
		for id in raw.orderedRows.size():
			for field in Metadata.EXTRA_FIELDS:
				var read:=Tables.integer(raw,id,field);var expected: int=(int(read.value)&255) if read.ok else 0;var actual:=Tables.integer(compiled.table,id,field)
				check(read.ready and actual.ready and actual.ok and actual.value==expected,"Installed constructor/conditional BYTE "+str(id)+"/"+field,{"actual":actual,"expected":expected})
		var unchanged:=true
		for id in raw.orderedRows.size():
			for field in Base.NUMERIC+["SpellcastingAbil","SpellTableColumn","CLMultiplier"]:
				unchanged=unchanged and Tables.cell(compiled.table,id,field)==Tables.cell(base.table,id,field)
		check(unchanged and raw==before and compiled.table.rowLabels==raw.rowLabels,"All existing projected fields, raw graph and physical IDs remain exact")
	for value in [-2147483648,-257,-1,0,1,255,256,257,2147483647]:
		var table:={"orderedRows":[{"ArcSpellLvlMod":str(value),"DivSpellLvlMod":str(value)}]};var answer:=Metadata.compile(table)
		for field in Metadata.EXTRA_FIELDS:check(Tables.integer(answer.table,0,field).value==(value&255),"Active successful INT writes its low BYTE "+field+"/"+str(value))
	var parser:=Parser.new()
	for headers in ["arcspelllvlmod ArcSpellLvlMod divspelllvlmod DivSpellLvlMod","ArcSpellLvlMod arcspelllvlmod DivSpellLvlMod divspelllvlmod"]:
		var custom:=parser.parse_reference("2DA V2.0\n"+headers+"\n92 257 0 -1 0\n");var original:=custom.duplicate(true);var answer:=Metadata.compile(custom)
		check(Tables.integer(answer.table,0,"ArcSpellLvlMod").value==1 and Tables.integer(answer.table,0,"DivSpellLvlMod").value==255 and Game.cell(answer.table.orderedRows[0],"ArcSpellLvlMod")=="1" and Game.cell(answer.table.orderedRows[0],"DivSpellLvlMod")=="255","First physical column and exact-key aliases use the same native BYTE")
		check(answer.table.orderedCells[0][1]=="0" and answer.table.orderedCells[0][3]=="0" and custom==original and answer.table.rowLabels==["92"],"Later physical cells/raw graph and nonnumeric row labels remain provenance")
	var absent:={"orderedRows":[{"Label":"Missing columns"}],"defaultValue":"99"};var missing:=Metadata.compile(absent)
	check(Tables.integer(missing.table,0,"ArcSpellLvlMod").value==0 and Tables.integer(missing.table,0,"DivSpellLvlMod").value==0,"Failed lookup retains constructor0 rather than failed GetINT output/default99")
	var malformed:=parser.parse_reference("2DA V2.0\nArcSpellLvlMod DivSpellLvlMod\n0 0xGG 0x123456789\n");var invalid:=Metadata.compile(malformed)
	check(invalid.ready and invalid.unknown[0].has("ArcSpellLvlMod") and invalid.unknown[0].has("DivSpellLvlMod") and not Tables.integer(invalid.table,0,"ArcSpellLvlMod").ready and not Tables.integer(invalid.table,0,"DivSpellLvlMod").ready,"Malformed reached conversions remain explicit unknown, not constructor0")
	check(not Metadata.compile({}).ready and not Base.compile({"orderedRows":[{"ArcSpellLvlMod":"****"}]}).unknown.has(0),"Malformed table stays unavailable and shared first-level compiler is unchanged")
	var active:=mode1_tables();var active_before:=active.duplicate(true);var received:={"race":0,"classes":[{"id":0,"level":3},{"id":1,"level":1,"school":0}],"baseAbilities":[12,12,14,14,12,12],"feats":[],"skills":[0]};var received_before:=received.duplicate(true);var ranks: Array=[0];var context:={"baseFortitude":3}
	var private:=Snapshot.compose(received,0,-1,ranks,active,context);check(private.ready,"Actual mode1 private snapshot advances current class without first-level state")
	var baseline:=Capacity.evaluate(private,2,active);check(not baseline.ready and str(baseline.reason).contains("ArcSpellLvlMod"),"Current raw/default-only mode1 memorizing prerequisite exposes the missing BYTE field")
	var fixed:=active.duplicate();fixed.classes=Metadata.compile(active.classes).table;var advanced:=Snapshot.compose(received,0,-1,ranks,fixed,context);var verdict:=Capacity.evaluate(advanced,2,fixed)
	check(verdict.ready and verdict.allowed,"Constructor-backed no-advancement BYTEs resolve the actual mode1 memorizing prerequisite",verdict)
	var state:=State.new();var text:=Text.new();state.configure(received,0,-1,ranks,context);var model:=state.model(fixed,text)
	check(model.ready and model.available.map(func(row):return int(row.id))==[0],"Actual mode1 feat adapter publishes its active physical spell-prerequisite choice")
	state.act("add",0,fixed,text);check(state.selected==[0] and state.validate(fixed,text).valid,"Mode1 choice remains subject to current native legality and completeness")
	var changed:=active.duplicate(true);changed.classes.orderedRows[0].ArcSpellLvlMod="1";changed.classes=Metadata.compile(changed.classes).table;advanced=Snapshot.compose(received,0,-1,ranks,changed,context);verdict=Capacity.evaluate(advanced,2,changed)
	check(verdict.ready and not verdict.allowed,"Explicit active advancement override changes the real getter result instead of reusing ctor0",verdict)
	changed=active.duplicate(true);changed.classes.orderedRows[0].DivSpellLvlMod="0xGG";changed.classes=Metadata.compile(changed.classes).table;advanced=Snapshot.compose(received,0,-1,ranks,changed,context)
	check(not Capacity.evaluate(advanced,2,changed).ready,"Malformed demanded mode1 advancement metadata cannot silently deny/allow")
	check(active==active_before and received==received_before and ranks==[0],"Mode1 predicate/selection leave active raw tables and received/private callers unchanged")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"runtimeIntegrated":false,"scope":"NEW unimported mode1-only constructor/conditional BYTE projection, all43 installed classes, lowBYTE/aliases/malformed/raw preservation and actual mode1 memorizing feat prerequisite/list/selection. No imported publication hook, game/server/pixel acceptance or new original execution."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
