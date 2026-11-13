extends SceneTree
const Received=preload("res://systems/native_data/level_up_received_context.gd")
const Wait=preload("res://systems/native_data/level_up_context_wait.gd")
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
	if not args.has_all(["fixture","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	for row in fixture.rows:
		var before: Dictionary=row.actor.duplicate(true);var value:=Received.snapshot(row.actor)
		check(typeof(row.actor.playerState.combat.canLevelUp)==TYPE_FLOAT,"Actual decoded one-bit BOOL crosses JSON as a numeric value: "+str(row.name))
		check(value.ready==row.ready and (not value.ready or value.value==row.snapshot),"Real I-mask1 decode matches actual network snapshot shape: "+str(row.name))
		if value.ready:
			value.value.classes[0].level=99;check(row.actor==before,"Native read view stays detached from actual decoded actor data")
	var row: Dictionary=fixture.rows[0];var source: Dictionary=row.actor.duplicate(true);var scope: Array=[1,7,42]
	var begin:={"token":11,"snapshot":row.snapshot,"available":[false,false,false,true],"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":null}}
	var original:=begin.duplicate(true);var wait:=Wait.new();var captured:=wait.capture(begin,scope,3,source)
	check(wait.armed and captured.waiting and not captured.ready and wait.matched,"Real numeric canLevelUp=1 establishes an exact pending comparison")
	var late:=source.duplicate(true);late.inventoryStats.field9c=0
	var value:=wait.consume(scope,11,3,late)
	check(value.ready and value.result.draftContext.baseFortitude==0 and value.result.snapshot==begin.snapshot and value.sends==0 and not value.serverAcknowledged,"Late received signed zero resumes actual numeric-wire context without packet or invented acceptance")
	check(begin==original and source.inventoryStats.is_empty(),"Wire context enrichment does not mutate the actor or original begin")
	for flag in [true,false,0,1,2,-1,0.5,"1",null]:
		var actor:=source.duplicate(true);actor.playerState.combat.canLevelUp=flag
		var accepted: bool=flag if flag is bool else (flag is int or flag is float) and flag==1
		check(Received.snapshot(actor).ready==accepted,"Only authored true or native bit1 is levelable: "+str(flag))
	wait.capture(begin,scope,4,source)
	var disabled: Dictionary=fixture.rows[1].actor.duplicate(true);disabled.inventoryStats.field9c=0
	check(not wait.consume(scope,11,4,disabled).ready and not wait.armed,"Actual numeric canLevelUp=0 retires a previously matched context when S9c arrives")
	wait.close()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"wireCases":fixture.rows.size(),"scope":"Actual NativeMessageWriter/Reader and readPlayerState I-mask1 output through JSON into native snapshot/wait owners, including numeric BOOL, strict malformed rejection, detached exact comparison and signed-zero resume. No server, UI pixels or end-to-end acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
