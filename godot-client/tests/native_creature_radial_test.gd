extends SceneTree
const Policy=preload("res://systems/native_data/creature_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return str(int(value.strRef))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or oracle.get("success")!=true:quit(2);return
	var policy:=Policy.new();var rules:=Rules.new();rules.text=Text.new();policy.rules=rules
	var snapshot:={"id":99,"replicated":{"field8D4":128,"field8D6":0,"field8E0":0}}
	for observed in oracle.rows:
		if int(observed.input.polymorph)!=0:continue # Role4 is explicitly outside this first native base slice.
		var input: Dictionary=observed.input
		snapshot.replicated={"field8D4":int(input.flags),"field8D6":int(input.mode),"field8D8":int(input.related),"field8E0":0}
		var model:=policy.normal_self(snapshot);var expected: Array=observed.entries
		check(model.entries.size()==expected.size(),"Original self entry count "+str(input))
		for at in expected.size():
			var actual: Dictionary=model.entries[at];var source: Dictionary=expected[at]
			check(int(actual.slot)==int(source.slot) and str(actual.icon)==str(source.icon) and str(actual.label)==str(int(source.tooltip)),"Unchanged original self slot/icon/TLK "+str(input)+" #"+str(at))
	for observed in oracle.emotes:
		snapshot.replicated.field8E0=int(observed.field8E0)
		var result:=policy.emotes(0,int(observed.firstClass),snapshot)
		var original_disabled: Array=observed.disabled.map(func(slot):return int(slot))
		for at in observed.entries.size():
			var actual: Dictionary=result[at];var source: Dictionary=observed.entries[at]
			check(int(actual.slot)==int(source.slot) and str(actual.icon)==str(source.icon) and str(actual.label)==str(int(source.tooltip)) and bool(actual.disabled)==original_disabled.has(int(source.slot)),"Original world emote class/flags/slot "+str(observed.firstClass)+"/"+str(observed.field8E0)+" #"+str(at))
			if at<7:check(str(actual.action)=="world-emote" and int(actual.binding.type)==8 and int(actual.binding.intParam)==int(source.argument),"World emote invokes immediate source callback, not targeting")
	check(not Policy.combat_action({},{}).available,"Unknown identity/mode/flags are unavailable")
	snapshot.replicated={"field8D6":2,"field8D8":99}
	check(Policy.combat_action(snapshot,snapshot).action=="world-disengage","Known disengage does not invent missing attack flags")
	snapshot.replicated.field8D6=0
	check(not Policy.combat_action(snapshot,snapshot).available,"Retained related target cannot supply missing attack flag")
	snapshot.replicated.field8D4=128
	check(Policy.combat_action(snapshot,snapshot).action=="world-attack","Mode-changing delta ignores stale related target")
	snapshot.replicated={"field8D4":0,"field8D6":0,"field8E0":0}
	check(Policy.combat_action(snapshot,snapshot).action.is_empty(),"Received clear attack bit omits Attack")
	var before:=snapshot.duplicate(true);var detached:=policy.normal_self(snapshot);detached.entries[0].label="changed";detached.pending.clear()
	check(snapshot==before and policy.normal_self(snapshot).entries[0].label!="changed","Returned rows cannot mutate received state or later menu models")
	for page in [1,2]:
		snapshot.replicated.field8E0=16
		var rows:=policy.emotes(page,4,snapshot)
		check(rows.all(func(row):return row.disabled),"Later emote pages include original disabled More behavior "+str(page))
		snapshot.replicated.erase("field8E0")
		check(policy.emotes(page,4,snapshot).all(func(row):return row.disabled),"Missing emote availability remains unavailable "+str(page))
	var commands:=policy.commands()
	check(commands.map(func(row):return [int(row.slot),str(row.icon),int(row.binding.intParam)])==[[5,"IR_GUARD",9],[4,"IR_STANDGROUND",10],[3,"IR_FOLLOW",22],[2,"IR_ATTACKNEAREST",0],[6,"IR_HEALME",4]],"Original five common commands keep physical sectors and quickchat IDs")
	snapshot.replicated={"field8D4":128,"field8D6":0,"field8E0":0};var times: Array=[]
	for sample in 1000:
		var start:=Time.get_ticks_usec();policy.normal_self(snapshot);times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timing_ms":{"samples":times.size(),"p50":times[500],"p95":times[950],"maximum":times[-1]},"scope":"Native normal-self base and first world-emote page compared with unchanged original913-case oracle; role4 and live-server outcomes not accepted."},"  "));file.close();quit(0 if failures.is_empty() else 1)
