extends SceneTree
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const SHA="c1d83c3a2a1bbfd6dffc607dec6ab86bc09052c7908eff069497669f8b45285c"
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"details":details})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==SHA,"Original prerequisite corpus remains immutable")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(evidence.target==ORIGINAL and evidence.rows.size()==360 and evidence.procedures.size()==11 and evidence.procedures[0]=="0x1407ee690","Original full prerequisite entry and all reached helpers identify the corpus")
	for observed in evidence.rows:
		var before:=JSON.stringify(observed);var source: Dictionary=observed.case;var result:=Requirements.evaluate(source,source.feat)
		check(result.ready and result.allowed==observed.accepted,"Native decoded prerequisite state matches original machine execution",{"source":source,"actual":result,"expected":observed.accepted})
		check(JSON.stringify(observed)==before,"Native prerequisite projection leaves original instruction fixtures unchanged")
	var source: Dictionary=evidence.rows[0].case.duplicate(true);source.classes[source.current].feats=[];source.feat={"MINSPELLLVL":1}
	check(not Requirements.evaluate(source,source.feat).ready,"Unported spell-capacity ownership is explicit rather than a guessed prerequisite result")
	source.spellLevels={1:false};check(Requirements.evaluate(source,source.feat).ready and not Requirements.evaluate(source,source.feat).allowed,"A published negative original spell-capacity result is respected")
	source.spellLevels={1:true};check(Requirements.evaluate(source,source.feat).ready and Requirements.evaluate(source,source.feat).allowed,"A published positive spell-capacity result reaches the remaining prerequisite rules")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"360 complete original prerequisite executions and reached owned/selected/class/skill/level helpers; decoded snapshots with MINSPELLLVL0 and cached BAB. Active-table/cached-save adapter, spell capacity, source draft binding, full creator/level-up and pixels remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
