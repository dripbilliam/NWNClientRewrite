extends SceneTree
const ActionProbe=preload("res://tests/native_live_actions_probe.gd")
const NpcProbe=preload("res://tests/native_live_npc_combat_probe.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var npc=NpcProbe.new();var action=ActionProbe.new()
	check(npc.has_method("exercise") and npc.has_method("pose"),"Owned NPC probe compiles with its real private model/clock path")
	check(action.has_method("run"),"Existing actions owner compiles with isolated NPC delegate")
	npc.probe={"session":{"world":null}}
	check(not npc.scope_valid(),"Retired world cannot retain NPC scope")
	check(npc.state().is_empty() and npc.metadata().is_empty(),"Retired world supplies no private actor or cue")
	check(npc.clocks().is_empty(),"Retired world does not index prior model clocks")
	check(npc.facing()==-2.0,"Retired world does not invent facing")
	check(not await npc.pose(),"Retired pose observes failure without dereferencing old rigs")
	check(npc.status_action("NATIVE_NPC_STOP:65535","NATIVE_NPC_STOP:")==65535,"Original status parser preserves installed action constant")
	check(npc.status_action("unrelated","NATIVE_NPC_STOP:")==-1,"Missing original query is not an idle acknowledgment")
	action.free();npc=null;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual source NPC probe/dispatcher compilation and retired-owner guards only; no server/model presentation outcome from this test."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
