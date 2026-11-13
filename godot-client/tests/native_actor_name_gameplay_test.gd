extends SceneTree
# Actual Gameplay publication and queued chat; passive service owners only.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionRoot=preload("res://native_session_world.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const ServerChat=preload("res://systems/server_chat.gd")
const NativeChat=preload("res://systems/native_chat_hud.gd")
const Text=preload("res://systems/server_text.gd")
class PassiveOwner extends Node:
	var state: Dictionary={"players":[]}
	var worlds:=0
	func set_world(_epoch: int,_area: int,_controlled: int,_objects: Variant,_extra: Dictionary={}) -> void:worlds+=1
	func update_world(_epoch: int,_area: int,_controlled: int,_objects: Array,_removed: Array,_extra: Dictionary={}) -> void:worlds+=1
	func reset() -> void:pass
	func sync() -> void:pass
	func refresh() -> void:pass
	func close() -> void:pass
	func close_modal_owner() -> void:pass
class TracingTalk extends Talk:
	var selected_fetches: Array=[]
	var parses: Array=[]
	func fetch_native_reference_snapshot(ref: Variant,gender: Variant,selected: Dictionary) -> Dictionary:
		selected_fetches.append({"ref":ref,"gender":gender,"selected":selected.duplicate(true)})
		return super.fetch_native_reference_snapshot(ref,gender,selected)
	func parse_native(input: String,state: Dictionary={}) -> Dictionary:
		parses.append({"input":input,"state":state.duplicate(true)})
		return super.parse_native(input,state)
var checks:=0
var failures: Array=[]
var fixture: Dictionary={}
var connection: Variant=null
var instances: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
static func tlk(rows: Dictionary) -> PackedByteArray:
	var count:=1
	for key in rows:count=maxi(count,int(key)+1)
	var bytes:=PackedByteArray();bytes.resize(20+count*40);var magic:="TLK V3.0".to_ascii_buffer()
	for at in magic.size():bytes[at]=magic[at]
	bytes.encode_u32(12,count);bytes.encode_u32(16,bytes.size());var offset:=0
	for key in rows:
		var raw:=str(rows[key]).to_ascii_buffer();var at:=20+int(key)*40
		bytes.encode_u32(at,1);bytes.encode_u32(at+28,offset);bytes.encode_u32(at+32,raw.size());bytes.append_array(raw);offset+=raw.size()
	return bytes
func make_ui():
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false);instances.append(ui)
	ui.text.close();ui.text=TracingTalk.new()
	ui.native_connection_query=func():return connection
	ui.inventory=PassiveOwner.new();ui.add_child(ui.inventory)
	ui.desktop=PassiveOwner.new();ui.add_child(ui.desktop)
	ui.barter=PassiveOwner.new();ui.add_child(ui.barter)
	ui.conversation=PassiveOwner.new();ui.add_child(ui.conversation)
	ui.examine=PassiveOwner.new();ui.add_child(ui.examine)
	ui.examine_skin=PassiveOwner.new();ui.add_child(ui.examine_skin)
	ui.chat=ServerChat.new();ui.add_child(ui.chat);ui.chat.setup()
	ui.bindings_installed=true;ui.hud_ready=true;ui.tables_ready=true
	ui.text.named_ready=true
	return ui
func open_base(ui,rows: Dictionary) -> void:
	check(ui.text.base.open_bytes(tlk(rows)) and ui.text.publish_native_family(false,true),"Actual native TLK pair opens controlled test bytes")
	ui.text.mark_changed();ui.floating_text_data_changed()
func drain(ui) -> void:
	var bound: int=ui.queue.size()+1
	for _at in bound:
		if ui.queue.is_empty():break
		ui._profile_process(0.0)
	check(ui.queue.is_empty(),"Actual Gameplay queue drains without an authored presentation bypass")
func snapshot(ui,stage: Dictionary) -> void:
	connection=stage.scope.connection
	ui.set_world(int(stage.scope.generation),int(stage.scope.areaId),int(stage.get("controlledId",fixture.id)),stage.objects.duplicate(true),{},stage.header.duplicate(true))
func delta(ui,stage: Dictionary) -> void:
	connection=stage.scope.connection
	ui.update_world(int(stage.scope.generation),int(stage.scope.areaId),int(stage.get("controlledId",fixture.id)),stage.objects.duplicate(true),stage.get("removed",[]).duplicate(),{},stage.header.duplicate(true))
func ingress(ui,frame: Dictionary) -> void:
	ui.receive(frame.message.duplicate(true),int(frame.scope.generation),frame.scope.connection)
func last_name(ui) -> String:
	return str(ui.chat.rows[-1].get("name",{}).get("text","")) if not ui.chat.rows.is_empty() else "<NO ROW>"
func last_native(ui) -> bool:
	return not ui.chat.rows.is_empty() and ui.chat.rows[-1].get("nativeNameResolved",false)==true
func assert_last(ui,name: String,body: String,label: String) -> void:
	check(not ui.chat.rows.is_empty() and last_name(ui)==name and ui.chat.rows[-1].text==body and last_native(ui),label)
func native_empty_painter(row: Dictionary) -> void:
	# Execute native history painter with real text/scroll nodes. No art/font
	# service or mesh is necessary for this exact punctuation boundary.
	var skin:=NativeChat.new();root.add_child(skin);skin.panel=ServerChat.new();skin.add_child(skin.panel);skin.panel.setup()
	var painted:=row.duplicate(true);painted.erase("reply") # Portrait attachments have a separate actual-control suite.
	skin.panel.rows.clear();skin.panel.rows.append(painted);skin.layout_ready=true;skin.preferences.timestamps=false;skin.preferences.autoscroll=false
	for at in 2:
		var scroll:=ScrollContainer.new();skin.add_child(scroll);var body:=VBoxContainer.new();scroll.add_child(body);var label:=Text.label({});body.add_child(label)
		skin.panes.append({"scroll":scroll,"body":body,"label":label,"replies":{},"wanted_replies":{}})
	skin.admitted=[{int(row.chat_sequence):true},{}];skin.render_history()
	check(skin.panes[0].label.get_parsed_text()==": "+str(row.text)+"\n","Actual NativeChatHud painter preserves colon for a ready empty native name")
	if process_frame.is_connected(skin.restore_scroll):process_frame.disconnect(skin.restore_scroll)
	skin.closed=true;skin.queue_free()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:="";var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
	if report.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(SessionRoot!=null,"Current actual SessionWorld/root graph parses without starting a Session")
	cases()
	for ui in instances:ui.close();ui.queue_free()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual NetworkWorld/RawCombatEvents/disclosures/TextEventScope metadata -> JSON -> actual Gameplay set_world/update_world/receive/queue/speech/present with real TalkText/selected native TLK/parser and both actual Chat painters. Passive unrelated inventory/desktop/examine/barter owners. No server/GPU/key/profile/build/user-process or native glyph-pixel acceptance."})+"\n");file.close()
	print("NATIVE_ACTOR_NAME_GAMEPLAY ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func cases() -> void:
	check(fixture.version==1 and fixture.provenance.authoredDecodedRecords and not fixture.provenance.jsTextResolution and not fixture.provenance.scenePreparation and fixture.protocolChecks==73 and fixture.cases.size()==11,"All11 real NetworkWorld fixture scenarios/73 protocol assertions cross JSON without JS text resolution or scene preparation")
	var expected_names:={"actor-after-party-u":"Actor First Actor Last","captured-before-rename":"Name at event","new-event-after-newer-raw":"Name in newer raw","new-p-event-before-raw":"New event name","ctor-empty-chat":"","chat-keeps-p-snapshot":"Café at P Last at P","base-selection-chat":"Base First Base Last","current-after-pending-replaced":"Replacement before base ready","chat-after-current-p":"Current P after redisclosure","captured-before-history-taint":"Before history taint","new-connection-chat":"Reconnect current actor"}
	var delayed_labels:=["pending-base-chat","chat-after-ambiguous-redisclosure","old-connection-event","base-selection-chat"]
	var legacy_labels:=["unknown-constructor-chat","chat-after-incomplete-prefix","chat-after-rejected-transaction"]
	for case_name in fixture.cases:
		var ui=make_ui();var scenario: Dictionary=fixture.cases[case_name];var saved:=scenario.duplicate(true);connection=fixture.connection
		var cold: bool=case_name in ["baseBeforeLateOverride","pendingThenReplaceRemoveReuse","reconnectScope"]
		if not cold:open_base(ui,{100:"Base First",101:"Base Last",999:"Pending first",5189:"Explicit legacy unknown"})
		for step in scenario.steps:
			match str(step.kind):
				"snapshot":snapshot(ui,step)
				"delta":delta(ui,step)
				"data":ui.receive(step.message.duplicate(true),int(step.scope.generation),step.scope.connection)
				"speech":
					var before: int=ui.chat.rows.size();var pending_before: int=ui.pending_speech_logs.size()
					var supplied: Dictionary=step.message.duplicate(true);var preserved:=supplied.duplicate(true)
					ui.receive(supplied,int(step.scope.generation),step.scope.connection)
					if supplied.nativeTextEvent.get("actorName") is Dictionary and supplied.nativeTextEvent.actorName.get("state") is Dictionary:
						supplied.nativeTextEvent.actorName.state.override.text="Caller mutation after actual receive"
						supplied.nativeTextEvent.actorName.state.override.known=true
					drain(ui)
					check(step.message==preserved,"Actual receive retained detached input, never rewrites NetworkWorld fixture: "+str(step.label))
					if step.label=="replay-old-event-in-new-scope":
						check(ui.chat.rows.size()==before and ui.pending_speech_logs.size()==pending_before,"Old embedded connection/generation envelope cannot publish or pend a native name in current outer scope")
					elif step.label in delayed_labels:
						check(ui.chat.rows.size()==before and ui.pending_speech_logs.size()==pending_before+1,"Native captured name stays explicitly pending without borrowing newer/live providers: "+str(step.label))
					elif step.label in legacy_labels:
						check(ui.chat.rows.size()==before+1 and not last_native(ui),"Unknown imported/tainted controlled-name provenance remains an explicit unproven adapter: "+str(step.label))
						check(last_name(ui)!="Must roll back","Rejected staged P never leaks into any displayed adapter")
					else:
						check(expected_names.has(step.label),"Every ready native fixture name has an independent literal expectation: "+str(step.label))
						if expected_names.has(step.label):assert_last(ui,str(expected_names[step.label]),str(step.message.text.text),"Actual queued native name/body matches accepted P snapshot: "+str(step.label))
					if step.label=="ctor-empty-chat" and ui.chat.rows.size()>before:
						check(ui.chat.messages.get_parsed_text()==": Ctor empty body\n","Actual ServerChat painter preserves colon for ready native constructor-empty name")
						native_empty_painter(ui.chat.rows[-1])
					if step.label=="new-connection-chat":check(ui.pending_speech_logs.is_empty(),"Fresh accepted scope retires old pending name receipt before current chat")
		if case_name=="baseBeforeLateOverride":
			check(ui.text.overrides.get(100)=="Not the stored base selection","Actual custom-data receive updates live override before cold name TLK completion")
			open_base(ui,{100:"Base First",101:"Base Last",999:"Pending first",5189:"Explicit legacy unknown"});ui.drain_speech_logs()
			assert_last(ui,"Base First Base Last","Base ref body","Cold P-time absent override uses actual base even after later live override")
			check(ui.pending_speech_logs.is_empty(),"Actual data publication resolves captured base name exactly once")
		if case_name=="pendingThenReplaceRemoveReuse":
			var before: int=ui.chat.rows.size();open_base(ui,{100:"Base First",101:"Base Last",999:"Pending first",5189:"Explicit legacy unknown"});ui.drain_speech_logs()
			check(ui.chat.rows.size()==before+1,"Only the captured old pending name finishes; ambiguous redisclosure never borrows the later P")
			assert_last(ui,"Pending first Pending last","Pending base body","Historical name completes after newer P, D and same-ID redisclosure without retargeting")
			check(ui.pending_speech_logs.size()==1 and ui.pending_speech_logs[0].message.text.text=="Ambiguous body","Uncertified D+A name remains pending despite current later P publication")
		if case_name=="reconnectScope":
			var before: int=ui.chat.rows.size();open_base(ui,{999:"Wrong old resource after reconnect",5189:"Explicit legacy unknown"});ui.drain_speech_logs()
			check(ui.chat.rows.size()==before and ui.pending_speech_logs.is_empty(),"Late old reference publication cannot resurrect a retired connection receipt")
		check(scenario==saved,"Every scope/row/metadata/data step remains detached and unchanged: "+str(case_name))
		var count: int=ui.chat.rows.size();ui.drain_speech_logs();ui.drain_speech_logs();check(ui.chat.rows.size()==count,"Repeated data wake cannot duplicate delivered logs: "+str(case_name))
		ui.close()
	negative_boundaries()
func negative_boundaries() -> void:
	var ui=make_ui();connection=fixture.connection;open_base(ui,{5189:"Explicit legacy unknown"})
	snapshot(ui,fixture.cases.constructorEmpty.steps[0])
	var original: Dictionary=fixture.cases.constructorEmpty.steps[1].message
	for variant in ["absent-source","wrong-packet-id","missing-packet-state","malformed-history"]:
		var message:=original.duplicate(true)
		match variant:
			"absent-source":message.nativeTextEvent.source=null
			"wrong-packet-id":message.nativeTextEvent.actorName.state.id=int(fixture.id)+1
			"missing-packet-state":message.nativeTextEvent.actorName.erase("state")
			"malformed-history":message.nativeTextEvent.actorName.historyComplete="true"
		var before: int=ui.chat.rows.size();ui.receive(message,int(fixture.generation),fixture.connection);drain(ui)
		check(ui.chat.rows.size()==before,"Malformed explicit actor-name/source provenance cannot invent stored stats or fall through to a native claim: "+variant)
	check(ui.text.objects.size()==1 and ui.text.objects[int(fixture.id)].get("replicated",{}).get("stats",{}).is_empty(),"Name integration never invents stats/provider context for an otherwise name-only received actor")
	ui.close()

