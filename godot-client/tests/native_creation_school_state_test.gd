extends SceneTree
const Post=preload("res://systems/native_data/creation_post_feats.gd")
const School=preload("res://systems/native_data/creation_school_state.gd")
const Snapshot=preload("res://systems/native_data/creation_feat_snapshot.gd")
const Fixtures=preload("res://tests/native_creation_feat_adapter_test.gd")
const ROUTING_CORPUS_SHA256="5bbae4be1f87aa9129ceee15a41c850f5d2ff8eaba981bbe3dd6e841a069d886"
const SCHOOL_CORPUS_SHA256="c3acb48cb1db3c9222eb88a91e8cd4aaf5b4d8be68f5f3c9b63bf1d37385c2cf"
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
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==ROUTING_CORPUS_SHA256,"Immutable original routing corpus digest")
	check(FileAccess.get_sha256("res://school-oracle.json")==SCHOOL_CORPUS_SHA256,"Immutable original School corpus digest")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==3876,"Original routing corpus identifies complete coordinator/getter execution with explicit GUI boundaries")
	for at in oracle.rows.size():
		var row: Dictionary=oracle.rows[at];var input: Dictionary=row.input;var expected: Dictionary=row.output;var before:=JSON.stringify(input)
		var flow:=Post.new();flow.stage=int(input.stage);var actual:=flow.advance(input,int(input.code),bool(input.cancel));var child: String=str(expected.child) if expected.child!=null else ""
		check(actual.ready and flow.stage==int(expected.stage) and actual.child==child and actual.code==expected.code and actual.activated==expected.activated,"Original post-Feats stage/child/callback result "+str(at),{"expected":expected,"actual":actual,"stage":flow.stage})
		check(JSON.stringify(input)==before,"Coordinator leaves the borrowed native class snapshot unchanged "+str(at))
	var missing:=Post.new();missing.stage=1;var unresolved:=missing.advance({"present":true,"mode":0},0x800e)
	check(not unresolved.ready and missing.stage==1,"Unavailable conditional class metadata does not consume a stage or become false")
	unresolved=missing.advance({"present":true,"mode":0,"PickSchool":null},0x800e);check(not unresolved.ready and missing.stage==1,"Explicit missing class flags are not converted into zero")
	var school_oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://school-oracle.json"))
	check(school_oracle.target==oracle.target and school_oracle.rows.size()==84,"Original School84 callback observations include programmatic SelectTab and SetSchool")
	for at in school_oracle.rows.size():
		var row: Dictionary=school_oracle.rows[at];var input: Dictionary=row.input;var state:=School.new();var model:={"ready":true,"entries":[],"recommended":int(input.recommended)}
		for id in 9:model.entries.append({"title":1000+id,"description":2000+id})
		state.reset(model)
		check(state.selected==int(row.initial.selected) and state.help_title==int(row.initial.help["0x630"]) and state.help_description==int(row.initial.help["0x228"]),"Original School initial General highlight does not fire selection help "+str(at))
		if input.select!=null:state.select_index(int(input.select))
		if input.recommend and input.present and input.packagesLoaded:state.recommend()
		check(state.selected==int(row.selection.selected) and state.help_title==int(row.selection.help["0x630"]) and state.help_description==int(row.selection.help["0x228"]),"Original active-help/Recommended physical selection "+str(at))
		if input.finish=="ok" and input.present:
			check(int(row.output.school)==(state.selected&255),"Original SetSchool commits the selected physical byte "+str(at))
			var sequence: Array=row.output.calls.filter(func(call):return call[0] in ["clear-memorized","clear-known","recompute-slots","coordinator"])
			check(sequence.map(func(call):return call[0])==["clear-memorized","clear-known","recompute-slots","coordinator"] and sequence.slice(0,3).all(func(call):return int(call[1])==int(input.oldSchool)) and int(sequence[-1][1])==0x800f and int(sequence[-1][2])==state.selected,"Original clears/recomputes spells using the old school before its final write and800f handoff "+str(at),row.output.calls)
	var rules=Fixtures.fixture();rules.tables.spellschools={"orderedRows":[]};rules.tables.packages={"orderedRows":[{"School":"8"}]}
	for id in 12:rules.tables.spellschools.orderedRows.append({"StringRef":str(3000+id),"Description":str(4000+id)})
	var model:=School.choices(rules);check(model.ready and model.entries.size()==9 and model.entries[8].title==3008 and model.recommended==8,"School uses active physical help rows with the original fixed9 tab surface")
	rules.tables.classes.orderedRows[0].merge({"MemorizesSpells":"1","SpellCaster":"1","SpellcastingAbil":"INT","PickSchool":"1","SpellGainTable":"spellgain"},true)
	rules.draft.abilities.Int=14;rules.draft.school=0;rules.tables.spellgain={"orderedRows":[{"NumSpellLevels":"2","SpellLevel0":"3","SpellLevel1":"1"}]}
	var old_slots:=Snapshot.school_slot_reset(rules);check(old_slots.ready and old_slots.counts[1]==2,"Original-backed slot reset includes ability bonus with current General school",old_slots)
	rules.creation_spell_slots=old_slots.counts;rules.draft.sourceSpellSlots=true;rules.draft.school=8
	check(rules.spell_slots(1)==2 and Snapshot.school_slot_reset(rules).counts[1]==3,"A new specialization does not rewrite the already-reset slot cache until the next native reset")
	rules.reset_choices();check(rules.creation_spell_slots.is_empty() and not rules.draft.get("sourceSpellSlots",false),"Derived reset retires the source-owned slot cache")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRoutingCases":3876,"originalSchoolCases":84,"serverConnections":0,"gpu":false,"scope":"Original coordinator branch/getter execution and School callbacks with explicit GUI/table/cache-reset boundaries, active physical school metadata and existing original-backed slot getter ordering. No actual source-view/server/pixel or complete spell-cache acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
