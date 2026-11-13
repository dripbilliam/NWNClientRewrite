extends SceneTree
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Snapshot=preload("res://systems/native_data/creation_feat_snapshot.gd")
const State=preload("res://systems/native_data/creation_feat_state.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
class Text extends RefCounted:
	var revision:=1
	var names: Dictionary={}
	func raw(value: Dictionary) -> String:return str(names.get(int(value.strRef),"text"+str(int(value.strRef))))
var checks:=0
var failures: Array=[]
var performance: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
static func table(rows: Array) -> Dictionary:return {"orderedRows":rows}
static func fixture() -> RefCounted:
	var rules:=Rules.new()
	rules.tables={"feat":table([]),"classes":table([{"FeatsTable":"classfeats","SkillsTable":"classskills","AttackBonusTable":"attack","SavingThrowTable":"saves","BonusFeatsTable":"bonus","SpellCaster":"0"}]),"racialtypes":table([{"FeatsTable":"racefeats","ExtraFeatsAtFirstLevel":"0","NumberNormalFeatsEveryNthLevel":"2"}]),"skills":table([{"Untrained":"0","AllClassesCanUse":"1"}]),"ruleset":table([]),"classfeats":table([{"FeatIndex":"4","List":"3","GrantedOnLevel":"1"},{"FeatIndex":"5","List":"0","GrantedOnLevel":"2"}]),"classskills":table([]),"attack":table([{"BAB":"0"}]),"saves":table([{"FortSave":"99"}]),"bonus":table([{"Bonus":"0"}]),"racefeats":table([]),"masterfeats":table([{"STRREF":"100","DESCRIPTION":"101","ICON":"group"}])}
	for id in 11:rules.tables.feat.orderedRows.append({"FEAT":str(id),"Description":str(id+1000),"AllClassesCanUse":"1","Icon":"feat"+str(id)})
	rules.tables.feat.orderedRows[1].MINSTR="13";rules.tables.feat.orderedRows[2].PREREQFEAT1="0";rules.tables.feat.orderedRows[3].REQSKILL="0";rules.tables.feat.orderedRows[3].ReqSkillMinRanks="1"
	rules.tables.feat.orderedRows[6].MinFortSave="1";rules.tables.feat.orderedRows[7].PreReqEpic="1";rules.tables.feat.orderedRows[8].MASTERFEAT="0";rules.tables.feat.orderedRows[9].MASTERFEAT="0";rules.tables.feat.orderedRows[9].PREREQFEAT1="0";rules.tables.feat.orderedRows[10].MinSpellLvl="1"
	rules.draft={"raceId":0,"classId":0,"abilities":{"Str":10,"Dex":10,"Con":10,"Int":10,"Wis":11,"Cha":10},"skills":{},"domains":[],"school":0,"feats":[],"packageId":0}
	return rules
func ids(model: Dictionary,field: String) -> Array:return model.get(field,[]).filter(func(entry):return not entry.has("children")).map(func(entry):return int(entry.id))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var parser:=Parser.new()
	var parsed:=parser.parse_reference("2DA V2.0\nDEFAULT: 17\nFeat PreReqFeat1 MinSTR MinFortSave ReqAction GainMultiple MASTERFEAT\n99 7 **** **** **** **** 2 ****\n")
	var decoded:=Tables.decode(parsed)
	check(decoded.ready and decoded.definitions.size()==1,"Physical row index is distinct from 2DA row label")
	var feat: Dictionary=decoded.definitions[0]
	check(feat.valid and feat.id==0 and feat.FEAT==7,"Physical feat identity uses the valid FEAT strref")
	check(feat.PreReqFeat1==65535 and feat.MinSTR==0 and feat.MinFortSave==0 and feat.ReqAction==1 and feat.MinLevelClass==255,"Constructor sentinels survive conditional failed writes, explicit empty unconditional fields become0",feat)
	check(feat.MinDEX==17 and feat.Description==17 and feat.GainMultiple==0 and feat.MASTERFEAT==255,"Missing columns consume DEFAULT only for unconditional writes",feat)
	check(Tables.integer(parsed,0,"PreReqFeat1")=={"ready":true,"ok":false,"value":0},"Present empty cell differs from missing column/default")
	check(Tables.integer(parsed,-1,"Feat").value==17,"Out-of-range row consumes decimal DEFAULT with failed lookup")
	var raw:=table([{"FEAT":"0xFFFFFFFF","PreReqFeat1":"65537","MinSTR":"-1","GainMultiple":"1","MASTERFEAT":"256","ReqAction":"0","OrReqFeat0":"-2"}])
	feat=Tables.definition(raw,0)
	check(feat.FEAT==-1 and feat.PreReqFeat1==1 and feat.MinSTR==255 and feat.MASTERFEAT==0 and feat.ReqAction==0 and feat.OrReqFeats[0]==65534,"Raw active integer conversions preserve native signed/WORD/BYTE semantics",feat)
	check(not Tables.definition(table([{"FEAT":"0xZZ"}]),0).ready,"Undefined failed hex conversion never invents a strref/stat")
	check(not Tables.definition(table([{"FEAT":"****"}]),0).valid,"An empty physical definition stays invalid")
	var duplicate:=parser.parse_reference("2DA V2.0\nFeat feat MinSTR minstr\n0 3 8 12 19\n")
	feat=Tables.definition(duplicate,0)
	check(feat.FEAT==3 and feat.MinSTR==12,"Original case-insensitive first physical column wins over duplicate dictionary spellings")
	check(FileAccess.get_sha256(args.oracle)=="1d19d1b1f16106583689b28e44f2fbff01043ca4adaa715ebf69d126c42111b6","Original instruction corpus digest is pinned independently of its labels")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(evidence.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and evidence.rows.size()==480,"Immutable original complete CanChooseFeat corpus loaded")
	for index in evidence.rows.size():
		var observed: Dictionary=evidence.rows[index];var source: Dictionary=observed.case.duplicate(true);var rows: Array=[]
		for definition in source.definitions:rows.append({"FEAT":str(int(definition.id)),"AllClassesCanUse":str(int(definition.AllClassesCanUse))})
		var original_feat: Dictionary=source.feat
		for key in original_feat:
			if key=="OrReqFeats":
				for at in original_feat[key].size():rows[int(source.featId)]["OrReqFeat"+str(at)]=str(int(original_feat[key][at]))
			else:rows[int(source.featId)][key]=str(int(original_feat[key]))
		var load_result:=Tables.decode(table(rows));source.definitions=load_result.definitions;source.feat=source.definitions[int(source.featId)]
		var actual:=Choice.evaluate(source)
		check(load_result.ready and actual.ready and actual.allowed==observed.accepted,"Raw active feat rows compose with original full choice/prerequisite outcome "+str(index),actual)
	var rules:=fixture();var text:=Text.new();text.names={0:"Alpha",2:"Dependent",4:"Granted",8:"Child A",9:"Child B",100:"Family"};var state:=State.new()
	var draft_before:=JSON.stringify(rules.draft);var model:=state.compose(rules,text)
	check(model.ready and model.remaining==2 and not model.canAccept,"Real first-level draft has original two remaining selections",model)
	check(ids(model,"available")==[0] and ids(model,"known")==[4] and not model.known[0].enabled,"Ability/grant-level/Fort/skill/epic/spell prerequisites exclude invalid choices while grants remain",model)
	check(model.available.size()==2 and model.available[1].name=="Family" and model.available[1].children.size()==1 and model.available[1].children[0].id==8,"Original grouped available rows expose physical children",model)
	model.available.clear();model.known[0].name="mutated consumer";model=state.compose(rules,text)
	check(model.available.size()==2 and model.known[0].name=="Granted" and state.model_builds==1,"Cached menu views are detached and unchanged draft reads do not rescan physical definitions")
	model=state.apply("add",0,rules,text);check(model.ready and model.remaining==1 and ids(model,"available").has(2),"Selecting a prerequisite enables its dependent from the active draft")
	model=state.apply("add",2,rules,text);check(model.ready and model.remaining==0 and model.canAccept and state.selected==[0,2],"Two accepted choices fill normal reservations")
	var validation:=Snapshot.validate_choices(rules,[0,2]);check(validation.ready and validation.valid,"Committed original source choices pass the active first-level validator")
	validation=Snapshot.validate_choices(rules,[2]);check(validation.ready and not validation.valid,"Removing a committed prerequisite invalidates the source choice set")
	model=state.apply("remove",0,rules,text);check(model.ready and model.remaining==2 and state.selected.is_empty(),"Removing a prerequisite cascades through dependent choices")
	model=state.apply("add",4,rules,text);check(state.selected.is_empty(),"A granted feat cannot be selected again")
	rules.tables.preferences=table([{"FeatIndex":"2"},{"FeatIndex":"0"},{"FeatIndex":"2"}]);model=state.apply("recommend",-1,rules,text,"preferences")
	check(state.selected==[0,2] and model.canAccept,"Recommended follows physical active preferences in order with native prerequisites")
	model=state.apply("reset",-1,rules,text);check(state.selected.is_empty() and ids(model,"known")==[4],"Reset clears selectable choices and retains granted rows")
	check(JSON.stringify(rules.draft)==draft_before,"Selection/reset/recommend projections never mutate the live actor draft before OK")
	check(state.builds==1,"Warm detail/choice operations decode active feat definitions once")
	rules.draft.skills[0]=1;model=state.compose(rules,text);check(ids(model,"available").has(3),"Raw rank changes are read without rebuilding static feat resources")
	var cls: Dictionary=rules.tables.classes.orderedRows[0];cls.SpellCaster="1";cls.MemorizesSpells="1";cls.SpellcastingAbil="WIS";cls.SpellGainTable="spellgain"
	check(not state.compose(rules,text).ready,"Missing declared spell-gain resource is pending, not a zero stat")
	rules.tables.spellgain=table([{"NumSpellLevels":"2","SpellLevel0":"3","SpellLevel1":"1"}]);model=state.compose(rules,text)
	check(model.ready and ids(model,"available").has(10),"Original-backed memorizing capacity enables a positive MINSPELL feat")
	cls.MemorizesSpells="0";cls.SpellbookRestricted="1";cls.SpellKnownTable="spellknown";rules.tables.spellknown=table([{"SpellLevel0":"3","SpellLevel1":"1"}]);model=state.compose(rules,text)
	check(model.ready and ids(model,"available").has(10),"Non-memorizing known-spell table participates in the same active adapter")
	var next_table: Dictionary=rules.tables.feat.duplicate(true);next_table.orderedRows[1].MINSTR="0";rules.tables.feat=next_table;model=state.compose(rules,text)
	check(model.ready and ids(model,"available").has(1) and state.builds==2,"Replacing the active server feat table invalidates the local decoder")
	text.names[0]="Renamed";text.revision+=1;model=state.compose(rules,text);check(model.ready and model.available.any(func(entry):return entry.name=="Renamed") and state.builds==2,"TLK revision refreshes labels without reparsing static feat definitions")
	var missing: Variant=rules.tables.attack;rules.tables.erase("attack");check(not state.compose(rules,text).ready,"Unavailable BAB dependency stays pending")
	rules.tables.attack=missing
	# Active asset publication replaces the table object. Consumers never edit
	# the decoder's borrowed immutable table in place.
	var malformed: Dictionary=rules.tables.classfeats.duplicate(true);malformed.orderedRows.insert(0,{"FeatIndex":"65535","List":"0","GrantedOnLevel":"1"});rules.tables.classfeats=malformed
	check(not state.compose(rules,text).ready,"Publishing malformed native class-table storage invalidates the cache and stays explicit")
	var crowded:=fixture();var large:=State.new();var warm: Array=[]
	for id in range(11,1024):crowded.tables.feat.orderedRows.append({"FEAT":str(id),"Description":"1000","AllClassesCanUse":"1","MinSTR":"255"})
	var began:=Time.get_ticks_usec();var large_model:=large.compose(crowded,text);var cold_ms:=(Time.get_ticks_usec()-began)/1000.0
	for at in 24:
		began=Time.get_ticks_usec();large_model=large.compose(crowded,text);warm.append((Time.get_ticks_usec()-began)/1000.0)
	warm.sort();performance={"physicalDefinitions":1024,"coldModelMs":cold_ms,"warmSamples":warm.size(),"warmP95Ms":warm[ceili(warm.size()*.95)-1],"warmMaxMs":warm[-1],"staticBuilds":large.builds,"modelBuilds":large.model_builds}
	check(large_model.ready and large.builds==1 and large.model_builds==1 and float(performance.warmP95Ms)<3,"A1024-definition active ruleset avoids repeated prerequisite scans/static decoding and an obnoxious steady menu stall",performance)
	var output:=FileAccess.open(args.report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_cases":480,"static_builds":state.builds,"performance":performance,"serverConnections":0,"gpu":false,"scope":"Raw active feat table conversion, complete original choice corpus composition and real first-level draft state/actions. No graphical/server acceptance or level-up adapter."},"\t"));output.close();quit(0 if failures.is_empty() else 1)
