extends SceneTree
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const Summary=preload("res://systems/native_data/creation_summary_values.gd")
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const SHA="0650c6924fe381bf544872f596a1905238964f2a0b6a2b901a1600fa6f803601"
var checks:=0
var failures: Array=[]
func _init() -> void: run.call_deferred()
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value: failures.append({"label":label,"details":details})
func source(rules,adjustment: int=0) -> Dictionary: return {"classId":int(rules.draft.classId),"race":int(rules.draft.raceId),"abilities":rules.draft.abilities,"dexterityAdjustment":adjustment}
func compare(rules,expected: Dictionary,adjustment: int) -> void:
	var actual: Array=[]; var scores: Dictionary=rules.abilities()
	for key in Rules.ABILITIES: actual.append(int(scores[key]))
	var expected_scores: Array=expected.scores.map(func(value):return int(value)); var actual_raw: Dictionary={};var expected_raw: Dictionary={}
	for key in Rules.ABILITIES: actual_raw[key]=int(rules.draft.abilities[key]);expected_raw[key]=int(expected.abilities[key])
	check(actual==expected_scores and actual_raw==expected_raw and rules.draft.abilities.size()==6,"Actual native draft raw/effective abilities match original setters and Class OK",{"actual":actual,"raw":actual_raw,"expected":expected})
	var result:=Vitals.project(source(rules,adjustment),rules.tables,rules.creation_base_hp)
	check(result.ready and int(rules.creation_base_hp)==int(expected.baseHP) and result.fields.currentHP==int(expected.currentHP) and result.fields.maximumHP==int(expected.maximumHP) and result.fields.armorBase==int(expected.armorBase) and result.fields.armorModeBonus==int(expected.armorModeBonus),"Committed class cache and visible HP/AC match the original instruction sequence",{"actual":result,"baseHP":rules.creation_base_hp,"expected":expected})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	check(FileAccess.get_sha256(args.oracle)==SHA,"Original Class OK/vital corpus remains pinned")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(data.target==ORIGINAL and data.rows.size()==48 and data.procedures[0]=="0x1408e36d0","Original corpus executes the complete creation branch of Class OK")
	for row in data.rows:
		var before:=JSON.stringify(row); var rules:=Rules.new(); rules.tables=row.case.tables.duplicate(true); rules.creation_base_hp=int(row.case.source.baseHP)
		rules.draft={"classId":int(row.case.source.classId),"raceId":0,"abilities":row.case.source.abilities.duplicate(),"skills":{},"feats":[],"known":{},"memorized":{},"domains":[],"packageId":-1,"goodEvil":50,"lawChaos":50}
		for id in row.case.source.primaryFeats+row.case.source.bonusFeats: rules.draft.feats.append({"id":int(id),"kind":"normal"})
		var adjustment:=int(row.case.source.dexterityAdjustment)
		compare(rules,row.initial,adjustment)
		for step in row.results:
			if step.operation.kind=="class": rules.select_class(int(step.operation.id))
			else: rules.draft.abilities[str(step.operation.key)]=int(step.operation.value); rules.reset_choices()
			compare(rules,step.state,adjustment)
		var projected:=Vitals.project(source(rules,adjustment),rules.tables,rules.creation_base_hp)
		var view:=Summary.compose(projected.fields,8,rules.tables)
		check(view.pending.is_empty() or not view.pending.has("hitpoints") and not view.pending.has("armorclass"),"Verified draft vitals populate the original summary without a BIC import")
		check(JSON.stringify(row)==before,"Native lifecycle projection does not mutate original instruction evidence")
	var fixture: Dictionary=data.rows[0].case.tables.duplicate(true)
	check(not Vitals.project({"classId":0,"race":0,"abilities":{}},fixture,null).ready,"An uncommitted hit-die cache stays unavailable")
	fixture.erase("gain0");check(not Vitals.effective({"classId":0,"race":0,"abilities":{}},fixture).ready,"Missing active class gains do not become guessed vitals")
	fixture=data.rows[0].case.tables.duplicate(true);fixture.ruleset.orderedRows=[{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":"0"}]
	check(not Vitals.project({"classId":0,"race":0,"abilities":{}},fixture,8).ready,"Invalid modifier rules cannot publish a fabricated HP/AC value")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"48 executed original class/ability configurations,240 transitions compared with actual CreationRules class/reset inputs, committed hit-die cache and native summary values. Unbuffed first-level draft only; corpus temporary-HP fixture is not imported, and source child/pixels/server acceptance remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
