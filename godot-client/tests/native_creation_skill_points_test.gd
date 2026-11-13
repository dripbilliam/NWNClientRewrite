extends SceneTree
const Rules=preload("res://systems/native_data/creation_rules.gd")
const SkillRules=preload("res://systems/native_data/creation_skill_rules.gd")
const PackageRules=preload("res://systems/native_data/creation_package_rules.gd")
const Summary=preload("res://systems/native_data/creation_skill_summary.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"details":details})
static func compare(rule,expected: Dictionary,adjustment: int,assertion: Callable) -> void:
	var ranks: Array=[]
	for id in 8:ranks.append(int(rule.draft.skills.get(id,0)))
	assertion.call(ranks==expected.ranks.map(func(value):return int(value)) and rule.skill_balance()==int(expected.points),"Native draft skill ranks and remaining WORD match original instructions",{"actual":ranks,"points":rule.skill_balance(),"expected":expected})
	var source: Dictionary=Summary.source(rule);source.dexterityAdjustment=adjustment;var values:=Summary.calculate(source,rule.tables)
	assertion.call(values.get("ready",false) and values.get("values",[])==expected["values"].map(func(value):return int(value)),"Native skill-value projection matches original rank/cache writes",{"actual":values,"expected":expected})
static func verify_oracle(path: String,assertion: Callable) -> void:
	assertion.call(FileAccess.get_sha256(path)=="5c608eb2b37493295b6f3be7706f64a267d2ef68f0a0dd42ceca3db2969b0aca","Original skill allocation corpus is immutable",null)
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));assertion.call(corpus.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.rows.size()==144,"Original144 skill allocation fixtures identify the corpus",null)
	for row in corpus.rows:
		var c: Dictionary=row.case;var rule:=Rules.new();rule.tables=c.vital.tables.duplicate(true);rule.tables.classes.orderedRows[0].SkillPointBase=str(int(c.classPoints));rule.tables.classes.orderedRows[0].SkillsTable="test_skill_rules"
		rule.tables.test_skill_rules={"orderedRows":c.classSkills.duplicate(true)};rule.tables.skills={"orderedRows":[]};rule.tables.pref={"orderedRows":c.preferences.map(func(id):return {"SkillIndex":str(int(id))})}
		for data in c.skills:rule.tables.skills.orderedRows.append({"KeyAbility":SkillRules.KEYS[int(data.ability)].to_upper(),"Untrained":str(int(data.Untrained)),"AllClassesCanUse":str(int(data.AllClassesCanUse))})
		var race: Dictionary=rule.tables.racialtypes.orderedRows[0];race.SkillPointModifierAbility=SkillRules.KEYS[int(c.ability)] if int(c.ability)<6 else "None";race.ExtraSkillPointsPerLevel=str(int(c.extra));race.FirstLevelSkillPointsMultiplier=str(int(c.multiplier))
		rule.draft={"classId":0,"raceId":0,"abilities":c.vital.source.abilities.duplicate(),"skills":{},"feats":[],"domains":[]}
		var adjustment:=int(c.vital.source.dexterityAdjustment)
		assertion.call(SkillRules.budget(rule.tables,0,0,row.scores,adjustment)==int(row.budget) and rule.source_skill_budget(adjustment)==int(row.budget),"Active-table BYTE/WORD initial skill budget matches original instructions",{"case":c,"expected":row.budget,"actual":rule.source_skill_budget(adjustment)})
		for id in 8:rule.draft.skills[id]=int(row.initial.ranks[id])
		rule.record_skill_points(int(row.initial.points));compare(rule,row.initial,adjustment,assertion)
		for step in row.results:
			if step.operation.kind=="recommend":PackageRules.recommend_skills(rule,{"SkillPref2DA":"pref"})
			else:rule.change_skill(int(step.operation.id),1 if step.operation.kind=="up" else -1,int(step.operation.get("baseline",0)))
			compare(rule,step.state,adjustment,assertion)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	verify_oracle(args.oracle,check)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"144 original skill budget/rank/cache/preference cases, actual native draft allocation and cached point WORD. Original full GUI and separate level-up state ownership remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
