extends SceneTree
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
const SHA="1d19d1b1f16106583689b28e44f2fbff01043ca4adaa715ebf69d126c42111b6"
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
	check(FileAccess.get_sha256(args.oracle)==SHA,"Original complete feat-choice corpus remains immutable")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(evidence.target==ORIGINAL and evidence.rows.size()==480 and evidence.procedures.has("0x1407ed040") and evidence.procedures.has("0x1407ee690") and evidence.boundaries.map(func(entry):return entry.service)==["malloc","memset","free"],"Original choice/prerequisite/classification helpers execute with only three explicit memory ABI boundaries")
	var accepted:=0
	for observed in evidence.rows:
		var before:=JSON.stringify(observed);var result:=Choice.evaluate(observed.case)
		check(result.ready and result.allowed==observed.accepted,"Native feasibility/duplicate/class flags and prerequisites match the complete original CanChooseFeat execution",{"source":observed.case,"actual":result,"expected":observed.accepted})
		if result.allowed:accepted+=1
		check(JSON.stringify(observed)==before,"Native feat-choice projection does not mutate original instruction evidence")
	check(accepted==178,"Original accepted/rejected population remains178/302")
	var pending: Dictionary=evidence.rows[1].case.duplicate(true);pending.erase("classes");check(not Choice.evaluate(pending).ready,"Unpublished decoded class ownership stays pending")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"480 complete original CanChooseFeat executions, including original reached prerequisite/classification helpers and BYTE normal/bonus reservations; only malloc/memset/free ABI boundaries. Decoded valid feats, MINSPELL0 and cached BAB. Active-table/snapshot adapter, source draft/server/pixels remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
