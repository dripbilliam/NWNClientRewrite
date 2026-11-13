extends SceneTree
const Flags=preload("res://systems/native_data/level_up_module_context.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","fixture"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture));check(fixture.success and fixture.cases.size()==8,"Actual Node module packets cover both incoming build layouts and all BOOL combinations")
	for at in fixture.cases.size():
		var row: Dictionary=fixture.cases[at];var before: Dictionary=row.module.duplicate(true);var value:=Flags.compose(row.module)
		check(value==row.expected and value.forceMaximum is bool and value.hideHitPointGain is bool,"Actual decoded numeric module BOOLs survive JSON and become exact native flags "+str(at))
		check(row.module==before and row.module.serverFlags.field158 is float and row.module.serverFlags.field164 is float,"Native adaptation preserves canonical received numeric module fields "+str(at))
	for force in [false,true]:
		for hide in [false,true]:check(Flags.compose({"serverFlags":{"field158":force,"field164":hide}})=={"forceMaximum":force,"hideHitPointGain":hide},"Existing explicit BOOL input remains compatible")
	for invalid in [null,2,-1,.5,NAN,INF,"0","1",[],{}]:
		var value:=Flags.compose({"serverFlags":{"field158":invalid,"field164":invalid}})
		check(value.forceMaximum==null and value.hideHitPointGain==null,"Missing/malformed values never become an invented Boolean: "+str(invalid))
	check(Flags.compose({}).forceMaximum==null and Flags.compose(null).hideHitPointGain==null,"Absent module/flag map remains explicitly unknown")
	check(Flags.compose({"serverFlags":{"field158":0,"field164":1.0}})=={"forceMaximum":false,"hideHitPointGain":true},"Exact integer/float0/1 forms share the native bit meaning")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"serverConnections":0,"gpu":false,"scope":"Actual Node module packet decode→JSON→Godot strict BOOL adapter, both incoming versions/all bit combinations, bool compatibility and missing/malformed rejection. No UI/server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
