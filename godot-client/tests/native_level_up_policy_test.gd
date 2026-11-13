extends SceneTree
const Choice=preload("res://systems/native_data/level_up_attributes_state.gd")
const Classes=preload("res://systems/native_data/level_up_class_state.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Skills=preload("res://systems/native_data/level_up_skill_state.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return "Active "+str(int(value.strRef))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not parsed is Dictionary or parsed.get("binarySha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or parsed.get("rows",[]).size()!=56:quit(2);return
	var operations:=0
	for row in parsed.rows:
		var state:=Choice.new();state.selected=int(row.initial.selected)
		for observed in row.results:
			var before:=state.selected;var direction:=int(observed.operation.direction);var index:=int(observed.operation.index)
			var changed: bool=state.move(index,direction) if observed.operation.get("present",true) else false
			check(state.selected==int(observed.state.selected) and state.points()==int(observed.state.points),"Original attribute selected/point transition"+str(operations))
			check(observed.before.raw.all(func(value):return Classes.integer(value,0,255)) and observed.state.raw.all(func(value):return Classes.integer(value,0,255)),"Original JSON raw values are exact native BYTEs"+str(operations))
			var expected:=PackedByteArray(observed.before.raw.map(func(value):return int(value)))
			if changed:expected[index]=(int(expected[index])+direction)&255
			check(expected==PackedByteArray(observed.state.raw.map(func(value):return int(value))),"Original BYTE setter transition"+str(operations))
			check(changed==observed.calls.any(func(call):return call.get("kind")=="gui-boundary" and call.get("procedure")=="0x1408ef340"),"Original no-op retains help versus successful-arrow help delivery"+str(operations))
			check(changed==(before!=state.selected),"Private choice changes only on an admitted original arrow"+str(operations));operations+=1
		check(row.cancelAndEscape.size()==2 and row.cancelAndEscape.all(func(value):return Classes.integer(value,2,2)),"Original nonmodal Cancel/Escape return code2")
	var recommended:=Choice.new()
	for pair in [["DEX",1],["INT",3],["CHA",5],["CON",2],["WIS",4],["STR",0],["dex",0],["DEXmore",0],["",0]]:
		recommended.selected=5;recommended.recommend(pair[0]);check(recommended.selected==pair[1] and recommended.points()==0,"Original exact four-byte Attribute comparison: "+str(pair[0]))
	recommended.selected=4;recommended.recommend("DEX",false);check(recommended.selected==-1 and recommended.points()==1,"Recommendation refunds the previous choice before failed package load")
	var tables:={"classes":{"orderedRows":[{"Name":"10","PlayerClass":"1","StatGainTable":"gains","SkillsTable":"skillclass","SkillPointBase":"2"},{"Name":"11","PlayerClass":"1","StatGainTable":"","SkillsTable":"skillclass","SkillPointBase":"3"}]},"racialtypes":{"orderedRows":[{"StrAdjust":"20","ExtraSkillPointsPerLevel":"1"}]},"ruleset":{"orderedRows":[]},"gains":{"orderedRows":[{"Str":"1"},{"Str":"2"}]},"skills":{"orderedRows":[{"Name":"100","Description":"200","AllClassesCanUse":"1","KeyAbility":"STR","Untrained":"1"},{"Name":"101","Description":"201","AllClassesCanUse":"1","KeyAbility":"INT","Untrained":"1"},{"Name":"102","Description":"202","AllClassesCanUse":"0","HideFromLevelUp":"1"}]},"skillclass":{"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]}}
	var snapshot:={"classes":[{"id":0,"level":1}],"race":0,"baseAbilities":[255,12,14,18,8,10],"skills":[1,0,0],"fieldDC6":5}
	var original:=snapshot.duplicate(true);var values:=Vitals.project(snapshot,0,0,tables)
	check(values.ready and values.raw==[0,12,14,18,8,10] and values.scores==[23,12,14,18,8,10] and values.classes==[{"id":0,"level":2}],"Private raw BYTE increase and active next-level class/racial gains, without live effect caches")
	check(snapshot==original,"Private ability/class projection never changes received snapshot")
	for change in [{"baseAbilities":[null,12,14,18,8,10]},{"race":null},{"classes":[{"id":0,"level":1},{"id":0,"level":1}]}]:
		var bad:=snapshot.duplicate(true);bad.merge(change,true);check(not Vitals.project(bad,0,0,tables).ready,"Missing/malformed received draft source remains unavailable")
	var skills:=Skills.new();check(skills.configure(snapshot,0,0,tables) and skills.points==12,"Mode1 skill points add the carried WORD once to next-level class/race/modifier budget")
	var text:=Text.new();var model:=skills.compose(tables,text)
	check(model.ready and model.entries.size()==2 and model.details[0].rank==1 and model.details[0].modifier==6 and model.details[0].value==7,"Active physical skill rows and private effective-score details are source driven")
	check(not skills.move(0,-1,tables) and skills.move(0,1,tables) and skills.points==11 and skills.changes()==[1,0,0],"Original stored-entry baseline prevents refunding received ranks")
	check(skills.move(0,-1,tables) and skills.points==12 and skills.changes()==[0,0,0],"Refund only the private rank increase")
	check(skills.move(1,1,tables) and skills.points==10 and skills.changes()==[0,1,0],"Cross-class increment spends exactly two private points")
	var replaced:=tables.duplicate();replaced.skillclass={"orderedRows":[]};check(not skills.move(0,1,replaced) and not skills.compose(replaced,text).ready,"Changed active class-skill publication retires input/model instead of using stale rules")
	check(snapshot==original,"Skill choices leave received ranks/points/classes unchanged")
	var invalid:=snapshot.duplicate(true);invalid.skills=[1,0];check(not skills.configure(invalid,0,0,tables) and not skills.compose(tables,text).ready and skills.ranks.is_empty(),"Incomplete received skill storage clears old actionable rows")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":parsed.rows.size(),"originalOperations":operations,"scope":"Differential original attribute callbacks plus private mode1 class/ability/skill state boundaries under controlled active tables; no integrated controller or original-server/pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
