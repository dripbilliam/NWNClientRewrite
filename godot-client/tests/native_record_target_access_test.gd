extends SceneTree
# Real canonical adapter policy with authored target-sheet accessors. Actual
# Desktop/installed source sheet input is owned by the companion record suite.
const Base=preload("res://tests/native_gui_panel_policy_test.gd")
const Adapter=preload("res://systems/native_gui_panel_access.gd")
class RecordDesktop extends Base.Desktop:
	var closed:=false
	var displayed: Variant=null
	var forced:=0
	var ui_owner
	func current_sheet_target() -> Variant:return displayed if sheet.wanted else null
	func force_self_character_record() -> bool:
		if sheet.wanted and displayed==actor_id:return true
		if not ui_owner.dependencies_ready:return false
		displayed=actor_id;forced+=1;sheet.open();return true
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func event(sequence: int,kind: String="disabled",change: Dictionary={}) -> Dictionary:
	var value:={"sequence":sequence,"panelId":8,"kind":kind,"retiredThrough":0}
	if kind=="disabled":value.merge({"disabled":true,"targetId":2130706432,"targetSource":"received"})
	else:value.scope={"actorId":42,"areaId":55,"areaGeneration":1,"controlLifetime":1,"source":"client_receive_context"}
	value.merge(change,true);return value
func header(revision: int) -> Dictionary:
	return {"revision":revision,"retiredThrough":0,"disabled":[],"events":[],"control":{"actorId":42,"areaId":55,"areaGeneration":1,"controlLifetime":1,"source":"client_receive_context"}}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var ui:=Base.Ui.new()
	for node in [ui.desktop.players,ui.desktop.journal,ui.desktop.book,ui.desktop.sheet]:node.free()
	ui.desktop.free();ui.desktop=RecordDesktop.new();root.add_child(ui);ui.add_child(ui.desktop)
	var d=ui.desktop;d.ui_owner=ui
	for node in [d.players,d.journal,d.book,d.sheet]:ui.add_child(node)
	d.objects[42].merge({"areaId":55,"clientKnownLifetime":7});d.objects[84]={"id":84,"areaId":55,"objectType":5,"clientKnownLifetime":9}
	var access:=Adapter.new();ui.add_child(access);access.configure(ui);access.observe_header(header(0))
	check(access.character_target(84) and d.sent.is_empty(),"Available target Record uses canonical gate without invented notification")
	access.receive_event(event(1,"disabled",{"targetId":84}))
	for repeat in 2:check(not access.character_target(84),"Each physical blocked target attempt remains blocked")
	check(d.sent.size()==2 and d.sent[0].targetId==84 and d.sent[0].recordActorLifetime==7 and d.sent[0].recordTargetLifetime==9 and d.sent[1].attemptSerial==d.sent[0].attemptSerial+1,"Blocked GUI14 intent retains requested target and exact disclosure counters")
	d.displayed=84;d.sheet.open();check(not access.character_target(84) and d.sent.size()==3,"Requested-target gate runs even when the shared sheet is already open")
	access.receive_event(event(2,"disabled",{"targetId":42}));check(d.sheet.wanted and d.sheet.closes==0,"A self-only disable does not close the different displayed target")
	access.receive_event(event(3,"disabled",{"targetId":84}));check(not d.sheet.wanted and d.sheet.closes==1,"Exact displayed-target disable invokes original sheet close once")
	d.sheet.open();d.displayed=null
	access.receive_event(event(4,"disabled",{"targetId":42}));check(d.sheet.wanted and d.sheet.closes==1,"Unavailable displayed identity never falls back to actor for exact receive-close")
	access.receive_event(event(5));check(not d.sheet.wanted and d.sheet.closes==2,"Global disable closes the current sheet regardless of unavailable exact identity")
	var before: int=d.sent.size()
	for mutation in [{"objectType":6},{"areaId":56},{"replicationRemoved":true},{"destroyed":true},{"clientKnownLifetime":null},{"clientKnownLifetime":0},{"clientKnownLifetime":"9"}]:
		var original: Dictionary=d.objects[84].duplicate(true);d.objects[84].merge(mutation,true);check(not access.character_target(84),"Unavailable/retired target cannot emit a blocked attempt");d.objects[84]=original
	check(d.sent.size()==before and not access.character_target(2130706432),"Malformed target identity never emits a packet intent")
	var actor: Dictionary=d.objects[42].duplicate(true);d.objects[42].erase("clientKnownLifetime");check(not access.character_target(84) and d.sent.size()==before,"Missing actor disclosure lifetime is unavailable");d.objects[42]=actor
	# Disable->popup->enable remains ordered while a wanted foreign sheet needs
	# actual self retarget readiness. Completion is explicit, without a header.
	d.displayed=84;d.sheet.open();ui.dependencies_ready=false
	access.receive_event(event(6,"popup"));access.receive_event(event(7,"disabled",{"disabled":false}))
	check(access.effects_seen==5 and access.pending.size()==2 and d.displayed==84 and d.forced==0,"Forced8 waits for self-retarget readiness despite another wanted sheet")
	ui.dependencies_ready=true;access.drain()
	check(access.effects_seen==7 and access.pending.is_empty() and d.displayed==42 and d.forced==1 and d.sheet.wanted,"Selected readiness completion retargets to self once then drains queued enable")
	var opens: int=d.sheet.opens;ui.dependencies_ready=false;access.receive_event(event(8,"popup"))
	check(access.effects_seen==8 and access.pending.is_empty() and d.sheet.opens==opens and d.forced==1,"Already-current wanted self is idempotent during resource refresh")
	access.observe_header(header(8));check(d.forced==1,"Repeated canonical header never replays an accepted forced command")
	access.close();check(not access.character_target(84) and access.pending.is_empty(),"Connection close rejects new target gates and retires queued commands")
	ui.free();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Canonical native access adapter with authored Desktop displayed-target/readiness methods; physical native sheet and original-server UI acceptance are separate.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("RECORD_TARGET_ACCESS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
