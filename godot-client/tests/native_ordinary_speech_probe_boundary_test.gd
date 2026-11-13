extends SceneTree
const Composed=preload("res://tests/native_live_composed_text_probe.gd")
const Ordinary=preload("res://tests/native_live_ordinary_speech_probe.gd")
const Entry=preload("res://tests/native_script_floating_world.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Chat=preload("res://systems/server_chat.gd")
const NameState=preload("res://systems/native_data/actor_name_state.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(Entry!=null and Ordinary!=null,"Actual SessionWorld/ordinary composed probe graph compiles without session/world instantiation")
	var probe:=Composed.new();root.add_child(probe)
	probe.scope={"connection":3,"generation":2,"areaId":7};probe.source={"id":4294967295,"objectType":5,"areaId":7,"nativeLifetime":1,"knownLifetime":2}
	probe.checks=16
	var raw:="<c"+String.chr(255)+String.chr(255)+String.chr(1)+">Native boundary text</c>"
	probe.observed_log({"type":94,"flags":128,"chat_mask":128,"text":"Native boundary text","raw":raw})
	var clock:={"delegated":true,"sharedRecord":true,"registryTracked":true,"registered":true};var defaults:={"mode":2,"largeFont":true}
	probe.ordinary_result={"success":true,"checks":15,"failures":[],"freshPopupPreferences":{"stored":defaults.duplicate(),"gameplay":defaults.duplicate(),"owner":defaults.duplicate(),"registry":defaults.duplicate()},"scope":probe.scope.duplicate(),"source":probe.source.duplicate(),"first":{"serial":6,"viewInstance":100,"mode":2,"font":"ttf fnt_default_hr 16","clock":clock.duplicate(),"captionUtf8":Array(Ordinary.FIRST.to_utf8_buffer()),"samples":[{"frame":1,"remaining":3.9,"position":[640.0,380.0],"visibleInTree":true}]},"replacement":{"serial":7,"viewInstance":100,"mode":2,"font":"ttf fnt_default_hr 16","clock":clock.duplicate(),"captionUtf8":Array(Ordinary.REPLACEMENT.to_utf8_buffer())},"expiry":[{"frame":250,"witness":[4294967295,1,2]}]}
	# This authored boundary calls the real payload reader/owner. It adds no
	# live pass criteria and does not claim these constructor facts were received.
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false)
	ui.generation=2;ui.area_id=7;ui.actor_name_history_complete=true
	ui.native_connection_query=func():return 3
	var metadata:={"source":NameState.SOURCE,"version":1,"id":4294967295,"revision":1,"presence":"present","construction":{"kind":"new","source":"A/type5","sequence":1},"override":{"known":true,"text":""},"publication":null,"diagnosticMustNotCopy":{"CUSTOM":"Forbidden full token snapshot"}}
	var current_row:={"id":4294967295,"objectType":5,"areaId":7,"nativeLifetime":1,"clientKnownLifetime":2,"nativeActorNameState":metadata}
	ui.text.objects[int(current_row.id)]=current_row;ui.actor_names.observe(current_row,metadata,ui.text,ui.actor_name_context())
	ui.chat=Chat.new();ui.add_child(ui.chat);ui.chat.setup()
	for body in [Ordinary.FIRST,Ordinary.REPLACEMENT]:ui.chat.append_message({"objectId":4294967295,"name":{"text":""},"nativeNameResolved":true,"text":body})
	var names_probe:=Ordinary.new();root.add_child(names_probe);names_probe.ui=ui;names_probe.source=probe.source.duplicate()
	var observed: Dictionary=names_probe.payload()
	check(observed.checks==0 and observed.success and names_probe.checks==0,"Read-only name diagnostics do not run, add or fabricate any live probe pass criteria")
	check(observed.actorNames.headerHistoryComplete and observed.actorNames.metadata.construction.kind=="new" and observed.actorNames.metadata.publication==null and observed.actorNames.resolved.ready and observed.actorNames.resolved.name=="","Actual payload observes the current header, thin constructor metadata and actual ActorNameState result")
	check(observed.actorNames.chatRows.size()==2 and observed.actorNames.chatRows[0].name=="" and observed.actorNames.chatRows[0].nativeNameResolved and observed.actorNames.chatRows[1].body==Ordinary.REPLACEMENT,"Actual Chat.rows diagnostics preserve empty native names, explicit row flags and both actual marker bodies")
	check(not JSON.stringify(observed.actorNames).contains("Forbidden full token snapshot"),"Name metadata diagnostics omit full CUSTOM/unrequested mutable graph fields")
	probe.ordinary_result.actorNames=observed.actorNames.duplicate(true)
	var payload:=probe.completion_payload();var encoded:=JSON.stringify(payload);var roundtrip: Variant=JSON.parse_string(encoded)
	check(roundtrip is Dictionary and encoded.find(String.chr(1))<0,"Actual Godot JSON roundtrip has no literal native RGB control")
	check(payload.success and payload.checks==16 and payload.ordinarySpeech.checks==15 and payload.ordinarySpeech.freshPopupPreferences.stored=={"mode":2,"largeFont":true} and payload.ordinarySpeech.first.clock.sharedRecord,"Composed completion preserves inherited16 and separate ordinary15 with explicit native defaults/shared clock facts")
	check(PackedByteArray(roundtrip.logs[0].rawUtf8).get_string_from_utf8()==raw and PackedByteArray(roundtrip.ordinarySpeech.first.captionUtf8).get_string_from_utf8()==Ordinary.FIRST,"Control-bearing old logs and new caption arrays remain lossless at the Node boundary")
	check(roundtrip.ordinarySpeech.actorNames.resolved.name=="" and roundtrip.ordinarySpeech.actorNames.chatRows[0].nativeNameResolved and roundtrip.ordinarySpeech.actorNames.headerHistoryComplete,"Actual new name diagnostics survive composed Godot JSON encode/decode without replacing empty success or boolean facts")
	observed.actorNames.resolved.first.text="Caller mutation";observed.actorNames.metadata.construction.kind="Caller mutation";observed.actorNames.chatRows[0].name="Caller mutation"
	check(ui.actor_names.name(current_row,ui.actor_name_context()).name=="" and metadata.construction.kind=="new" and ui.chat.rows[0].name.text=="","Payload mutation cannot alter current actor state, received metadata or actual Chat.rows")
	ui.actor_name_history_complete=false;var uncertain: Dictionary=names_probe.payload()
	check(uncertain.actorNames.headerHistoryComplete==false and not uncertain.actorNames.resolved.ready and uncertain.checks==0,"Unknown current history remains an unavailable observation, never new success criteria or invented constructor state")
	payload.ordinarySpeech.first.samples[0].position[0]=-1;payload.ordinarySpeech.source.nativeLifetime=999
	check(probe.ordinary_result.first.samples[0].position[0]==640.0 and probe.ordinary_result.source.nativeLifetime==1,"Detached completion mutation cannot change ordinary observations or source")
	probe.ordinary_result.success=false;check(not probe.completion_payload().success,"Ordinary rejection cannot be masked by inherited success")
	probe.ordinary_result.success=true;probe.failures.append("Authored inherited failure");check(not probe.completion_payload().success,"Inherited ScriptFloating rejection cannot be masked by ordinary success")
	check(encoded.to_utf8_buffer().size()<65536,"Representative bounded composed completion remains below existing64KiB Host guard")
	names_probe.queue_free();ui.close();ui.queue_free();probe.queue_free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"completion":roundtrip,"scope":"Actual composed probe/current SessionWorld graph compile and Godot JSON readback parsed by Node. All observation values are authored boundary tests only, not live projection/server authority. No session/world/key/GPU."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
