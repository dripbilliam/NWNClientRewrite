extends "res://tests/native_script_floating_core_test.gd"
const Receipt=preload("res://systems/native_data/script_floating_text_receipt.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionRoot=preload("res://native_session_world.gd")
const Chat=preload("res://systems/server_chat.gd")
const Categories=preload("res://systems/native_data/chat_categories.gd")
class CountingTalk extends Talk:
	var calls:=0
	var options_seen: Array=[]
	var native_fetches: Array=[]
	func fetch_native_reference(ref: Variant,gender: Variant=0) -> Dictionary:
		native_fetches.append({"ref":ref,"gender":gender});return super.fetch_native_reference(ref,gender)
	func parse_native_bytes(raw_bytes: PackedByteArray,options: Dictionary={}) -> Dictionary:
		var value: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(options.get("language",base.language)),true).get("text","")
		calls+=1;options_seen.append(options.duplicate(true));return super.parse_native_bytes(raw_bytes,options)
func make_owner(surface: Control,talk) -> ControlledOwner:
	var floating:=ControlledOwner.new();root.add_child(floating);floating.configure_processing(false)
	floating.configure(surface,talk,null,null,EmptyCatalog.new(),context,source,anchor)
	floating.log_message.connect(func(row):logs.append(row))
	return floating
func receive_explicit(floating,message: Dictionary) -> Dictionary:return floating.receive(message,3,7)
func echo_checks(surface: Control) -> void:
	current={"connection":3,"generation":7,"areaId":91,"enabled":true};rows={42:creature()};logs=[]
	var talk:=CountingTalk.new();var floating:=make_owner(surface,talk)
	var value:=packet(1,94,"Literal before area");value.nativeTextEvent.areaId=null;value.nativeTextEvent.source=null
	var accepted:=receive_explicit(floating,value)
	check(accepted.get("accepted_transport",false) and logs.size()==1 and logs[0].text=="Literal before area" and floating.entries.is_empty() and floating.queues.is_empty(),"Captured unknown area echoes immediately without widget identity or global table readiness")
	floating.receive(value,3,7);floating.data_changed();check(logs.size()==1,"Captured serial dedup and repeated publication emit one echo")
	var absent:=packet(2,94,"Accepted transport only");absent.erase("nativeTextEvent");var original:=absent.duplicate(true)
	accepted=receive_explicit(floating,absent)
	check(accepted.get("accepted_transport",false) and logs.size()==2 and absent==original and floating.entries.is_empty(),"Explicit admitted transport recovers absent metadata without modifying packet or inventing widget serial")
	floating.receive(absent);check(logs.size()==2,"One-argument legacy caller gains no absent-metadata recovery authority")
	var old:=packet(3,94,"Old area echo");old.nativeTextEvent.generation=6
	floating.receive(old,3,6)
	check(logs.size()==3 and logs[-1].text=="Old area echo" and floating.entries.is_empty(),"Current accepted connection preserves older-area echo but rejects its widget")
	current={"connection":3,"generation":null,"areaId":null,"enabled":true}
	floating.receive(packet(4,94,"Before first raw world"),3,7)
	check(logs.size()==4 and logs[-1].text=="Before first raw world" and floating.active_entries.is_empty(),"Known-area text echoes before first raw-world publication without selecting current area")
	current={"connection":3,"generation":7,"areaId":91,"enabled":true}
	var future:=packet(5,94,"Future area echo");future.nativeTextEvent.generation=8;future.nativeTextEvent.areaId=92;future.nativeTextEvent.source.areaId=92
	floating.receive(future,3,8);floating.frame_advance(0,0)
	check(logs.size()==5 and logs[-1].text=="Future area echo" and floating.entries[5].status=="pending" and not floating.active_entries.has(5) and not floating.views.has(5),"Future-area echo does not wait for raw scope and cannot activate its widget early")
	var at:=logs.size()
	for malformed in [null,{},1]:
		var rejected:=packet(10+at,94,"Malformed");rejected.nativeTextEvent=malformed;floating.receive(rejected,3,7)
	var contradictory:=packet(20,94,"Contradiction");contradictory.nativeTextEvent.source.id=43;floating.receive(contradictory,3,7)
	var wrong_envelope:=packet(21,94,"Wrong envelope");floating.receive(wrong_envelope,3,6)
	floating.receive(packet(22,94,"Wrong connection"),4,7);floating.receive(packet(23,94,"No generation"),3)
	check(logs.size()==at,"Malformed explicit metadata, target contradiction, envelope mismatch and invalid transport never fall through to recovery")
	var hidden:=packet(24,94,"No echo",0);floating.receive(hidden,3,7)
	floating.receive(packet(25,94,"",1),3,7)
	check(logs.size()==at,"Exact show flag and nonempty body govern independent echo")
	floating.reset();logs=[];talk.overrides[7000]="One parse <CUSTOM12>";talk.custom_tokens={12:"receipt"}
	floating.receive(packet(30,93,"",1),3,7);floating.frame_advance(0,0);floating.data_changed()
	check(logs.size()==1 and talk.calls==1 and talk.native_fetches==[{"ref":7000,"gender":0}] and floating.entries[30].body=="One parse receipt" and floating.views[30].model.raw==floating.entries[30].body,"Echo and widget share one native top fetch, one resolved type93 receipt body and one parse")
	check(talk.options_seen[0].context.is_empty() and talk.options_seen[0].nativeB8==0 and talk.options_seen[0].nativeBC==0 and talk.options_seen[0].localCustomTokensComplete,"Receipt uses explicit native NULL context and complete custom-token snapshot")
	floating.reset();logs=[];talk.calls=0;talk.named_ready=false;talk.custom_tokens={12:"before"};talk.overrides[7000]="<FirstName> <CUSTOM12> <CUSTOM13>";talk.overrides[7100]="Native name default"
	floating.receive(packet(31,93,"",1),3,7)
	current={"connection":3,"generation":8,"areaId":92,"enabled":true};rows={};floating.observe_sources()
	talk.custom_tokens[12]="after";talk.custom_tokens[13]="new later";talk.overrides[7000]="Changed later"
	talk.publish_table("stringtokens",{"columns":["TOKEN","ACTION","DEFAULT","R0","R1","R2","R3"],"orderedRows":[{"TOKEN":"FirstName","ACTION":"3","DEFAULT":"7100","R0":"-1","R1":"-1","R2":"-1","R3":"-1"}]});talk.import_tokens();floating.data_changed()
	check(logs.size()==1 and logs[0].text=="Native name default before <UNRECOGNIZED TOKEN>" and floating.entries.is_empty() and talk.calls==1,"Area retirement preserves unresolved connection receipt and its receipt token/raw snapshots, without reviving widget")
	floating.data_changed();check(logs.size()==1 and not floating.is_processing(),"Resolved connection-only echo is one-shot and has no idle callback")
	talk.named_ready=false;talk.overrides[7000]="<FirstName>";var cancelled:=packet(32,93);cancelled.nativeTextEvent.generation=8;cancelled.nativeTextEvent.areaId=92;cancelled.nativeTextEvent.source=null
	floating.receive(cancelled,3,8);current.connection=4;floating.observe_sources();talk.named_ready=true;floating.data_changed()
	check(logs.size()==1 and floating.pending_echo.is_empty(),"Retired connection cannot emit delayed text publication")
	current={"connection":3,"generation":7,"areaId":91,"enabled":true};floating.close();floating.data_changed();check(floating.pending_echo.is_empty() and not floating.is_processing(),"Close clears independent pending receipt and callbacks")
	floating.queue_free();talk.close();await process_frame
func shared_checks(surface: Control,fixture: Dictionary) -> void:
	check(SessionRoot!=null,"Current full SessionWorld and native entry graph compile")
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false)
	ui.generation=2;ui.area_id=7;ui.native_connection_query=func():return 3
	ui.chat=Chat.new();surface.add_child(ui.chat);ui.chat.setup()
	var floating:=ControlledOwner.new();ui.add_child(floating);ui.script_floating=floating;floating.configure_processing(false)
	floating.configure(surface,ui.text,null,null,null,ui.overhead_context,ui.overhead_source,ui.script_floating_anchor)
	floating.log_message.connect(ui.chat.append_message)
	ui.table_jobs[101]="unrelated-class-table";ui.tlk_jobs[102]=false
	var originals: Array=fixture.unknownAreaFixture.messages
	var selected: Dictionary={}
	for frame in originals:
		if int(frame.message.type)==94 and int(frame.message.data.integers["0"])==1:selected=frame;break
	check(not selected.is_empty() and selected.message.nativeTextEvent.areaId==null,"Actual Host fixture supplies captured unknown-area metadata on a receiver-trace-coded literal94")
	var input: Dictionary=selected.message;var before:=input.duplicate(true)
	ui.receive(input,int(selected.generation),3)
	check(input==before and ui.chat.rows.size()==1 and ui.queue.is_empty() and ui.table_jobs.size()==1 and ui.tlk_jobs.size()==1,"Actual Gameplay early transport path echoes before unrelated rules without mutating packet or pending jobs")
	check(floating.entries.is_empty() and ui.floating_rows.is_empty() and ui.feedback.floating.is_empty(),"Actual shared unknown-area route allocates no witnessed or legacy widget")
	check(ui.chat.rows[0].flags==128 and Categories.bits(ui.chat.rows[0])==128,"Native echo stays in the existing chat mask128 admission path")
	var recovered:=input.duplicate(true);recovered.erase("nativeTextEvent");ui.receive(recovered,int(selected.generation),3)
	check(ui.chat.rows.size()==2 and ui.queue.is_empty() and floating.entries.is_empty(),"Actual admitted missing-provenance fallback echoes once and never enters global feedback queue")
	ui.receive(input,int(selected.generation))
	check(ui.queue.size()==1 and ui.chat.rows.size()==2,"Existing no-transport unknown-area caller retains its narrow legacy queue behavior")
	var invalid:=input.duplicate(true);invalid.nativeTextEvent.version=2
	ui.receive(invalid,int(selected.generation),3);ui.receive(recovered,int(selected.generation),3.5)
	check(ui.queue.size()==1 and ui.chat.rows.size()==2 and ui.stats.stale_messages==2,"Explicit malformed metadata and invalid transport do not escape into legacy recovery")
	ui.native_connection_query=func():return null;ui.receive(recovered,int(selected.generation),3)
	check(ui.chat.rows.size()==2 and ui.queue.size()==1,"Retired actual connection cannot borrow current Gameplay to authorize recovery")
	ui.close();ui.queue_free();await process_frame
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","fixture"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var surface:=Control.new();root.add_child(surface);await echo_checks(surface);await shared_checks(surface,fixture);surface.queue_free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Connection-admitted script93/94 echo independent of widget area and rule readiness, strict transport/metadata/payload boundary, one shared body snapshot/parse, area-versus-connection retirement, no pixels/server.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("SCRIPT_FLOATING_ECHO ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
