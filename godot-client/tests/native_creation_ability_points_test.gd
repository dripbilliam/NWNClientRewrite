extends SceneTree
const Rules=preload("res://systems/native_data/creation_rules.gd")
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"details":details})
static func verify_oracle(path: String,assertion: Callable) -> void:
	assertion.call(FileAccess.get_sha256(path)=="040e68746f5c6831b78845292a5bb1c5ab1a9da0b64aeedb3910f7548aa6ec48","Immutable original Abilities point-transition corpus",null)
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));assertion.call(corpus.binarySha256==ORIGINAL and corpus.rows.size()==96,"96 original configurations and1344 attribute actions",null)
	for row in corpus.rows:
		var rules:=Rules.new();rules.tables=row.case.tables.duplicate(true);rules.creation_base_hp=int(row.initial.baseHP)
		rules.draft={"classId":int(row.initial.classId),"raceId":0,"abilities":{},"skills":{},"feats":[],"known":{},"memorized":{},"domains":[1,2],"packageId":123}
		for key in rules.ABILITIES:rules.draft.abilities[key]=int(row.initial.abilities[key])
		rules.record_ability_points(int(row.initial.points))
		for step in row.results:
			if step.operation.kind=="step":rules.change_ability(int(step.operation.index),int(step.operation.direction))
			elif step.operation.kind=="recommend":rules.recommend_abilities()
			var state: Dictionary=step.state;var scores:=rules.abilities()
			var raw_match: bool=rules.ABILITIES.all(func(key):return int(rules.draft.abilities[key])==int(state.abilities[key]));var actual: Array=rules.ABILITIES.map(func(key):return int(scores[key]));var expected: Array=state.scores.map(func(value):return int(value))
			assertion.call(raw_match and actual==expected and rules.point_balance()==int(state.points),"Actual draft raw/effective/remaining BYTE matches original button or recommendation",{"operation":step.operation,"actual":rules.draft.abilities,"points":rules.point_balance(),"expected":state,"settings":row.case.settings})
			assertion.call(rules.draft.domains==[1,2] and int(rules.draft.packageId)==123,"Original attribute edits/recommendation/Cancel retain derived choices until parent acceptance",step.operation)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	verify_oracle(args.oracle,check)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"Original twelve Abilities callbacks, cost/min/max and recommendation/Cancel across96 configurations/1344 actions compared with actual CreationRules raw/effective/remaining-cache changes. GUI text/help/timing, source frame, complete creator and server acceptance are separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
