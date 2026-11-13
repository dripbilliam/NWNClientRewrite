extends SceneTree
# Actual shared early ingress/owner/log/anchor; canonical fixture publication
# and passive drawing only are controlled. No server/actor outcome is authored.
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const SessionRoot=preload("res://native_session_world.gd")
const LiveEntry=preload("res://tests/native_script_floating_world.gd")
const Anchor=preload("res://systems/native_data/script_floating_anchor.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Chat=preload("res://systems/server_chat.gd")
class TrackingText extends "res://systems/native_data/talk_text.gd":
	var resolves: Array=[]
	var native_fetches: Array=[]
	func fetch_native_reference(ref: Variant,gender: Variant=0) -> Dictionary:
		native_fetches.append({"ref":ref,"gender":gender});return super.fetch_native_reference(ref,gender)
	func parse_native_bytes(raw_bytes: PackedByteArray,options: Dictionary={}) -> Dictionary:
		var value: String=preload("res://systems/native_data/native_text_encoding.gd").decode(raw_bytes,int(options.get("language",base.language)),true).get("text","")
		resolves.append({"id":null,"value":{"text":value},"options":options.duplicate(true)})
		return super.parse_native_bytes(raw_bytes,options)
	func resolve(value: Variant,id: int,options: Dictionary={})->String:
		resolves.append({"id":id,"value":value.duplicate(true) if value is Dictionary else value,"options":options.duplicate(true)})
		return super.resolve(value,id,options)
class PassiveView extends Control:
	var layout_ready:=false
	var model: Dictionary={}
	var placements: Array=[]
	func configure(_art,_fonts,_resources)->void:hide()
	func set_content(value: Dictionary)->void:model=value.duplicate(true);layout_ready=true
	func apply_frame(point: Vector2,alpha: float)->void:placements.append({"point":point,"alpha":alpha});position=point;show()
	func prepare_colors()->void:pass
	func release()->void:hide();layout_ready=false;model={}
	func close()->void:release()
class ReceivedOwner extends "res://systems/native_script_floating.gd":
	var received: Array=[]
	func receive(message: Dictionary,transport_connection: Variant=null,transport_generation: Variant=null)->Dictionary:
		received.append(message.duplicate(true));return super.receive(message,transport_connection,transport_generation)
	func _make_view()->Control:return PassiveView.new()
var checks:=0
var failures: Array=[]
var connection: Variant=3
var clock_ms: Variant=0
var echoed: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func configured(fixture: Dictionary,install: String)->Dictionary:
	var overlay:=Control.new();root.add_child(overlay)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,10,20);camera.look_at(Vector3(0,2,0))
	var ui:=Gameplay.new();root.add_child(ui);ui.set_process(false)
	ui.text.close();ui.text=TrackingText.new();ui.feedback.text=ui.text
	check(ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Actual installed TLK supplies93 lookup without an authored text provider")
	ui.chat=Chat.new();overlay.add_child(ui.chat);ui.chat.setup()
	ui.generation=2;ui.area_id=7;ui.controlled_id=-1
	ui.native_connection_query=func():return connection
	ui.script_floating_anchor_query=func(id,witness,scope,height):return Anchor.project(ui.overhead_source(id),witness,scope,ui.overhead_context(),Vector3(1,2,-3),height,camera)
	ui.script_floating_object_delta_query=func(_id,_witness,_scope):return clock_ms
	if fixture.get("target") is Dictionary:ui.text.objects[int(fixture.target.id)]=fixture.target.duplicate(true)
	var owner:=ReceivedOwner.new();ui.add_child(owner);ui.script_floating=owner
	owner.configure(overlay,ui.text,null,null,null,ui.overhead_context,ui.overhead_source,ui.script_floating_anchor)
	owner.object_delta_ms_reader=ui.script_floating_object_delta;owner.configure_processing(false)
	owner.log_message.connect(ui.chat.append_message);owner.log_message.connect(func(row):echoed.append(row.duplicate(true)))
	# Genuine unrelated readiness blockers stay pending throughout this test.
	ui.table_jobs[101]="unrelated-class-table";ui.tlk_jobs[102]=false
	return {"ui":ui,"owner":owner,"overlay":overlay,"camera":camera}
func release(value: Dictionary)->void:
	value.ui.close();value.ui.queue_free();value.overlay.queue_free();value.camera.queue_free()
func ingest(value: Dictionary,fixture: Dictionary)->void:
	for frame in fixture.messages:
		var before: Dictionary=frame.message.duplicate(true);value.ui.receive(frame.message,int(frame.generation))
		check(frame.message==before,"Actual shared early dispatch leaves every decoded packet and metadata unchanged")
	check(value.owner.received.size()==16,"All16 original receiver-trace codec packets reach the actual dedicated Owner")
	check(value.ui.queue.is_empty() and value.ui.table_jobs.size()==1 and value.ui.tlk_jobs.size()==1,"Script93/94 bypass the original global menu queue without changing its pending work")
	check(echoed.size()==12 and value.ui.chat.rows.size()==12,"Only exact showChat1 echoes once through the actual native Chat append path")
	check(value.ui.floating_rows.is_empty() and value.ui.feedback.floating.is_empty(),"Shared ingress creates no legacy4.5second duplicate")
func run()->void:
	var output:="";var fixture_path:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
	if output.is_empty() or fixture_path.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path));root.size=Vector2i(800,600)
	check(SessionRoot!=null and LiveEntry!=null,"Actual current SessionWorld and isolated source live entry graph compile without instantiation")
	check(fixture.messages.size()==16 and fixture.provenance.nativeWriterCapture==false,"Fixture provenance remains original receiver traces plus authored codec bytes, not retained writer packets")
	echoed.clear();connection=3;clock_ms=0
	var live:=configured(fixture,install);ingest(live,fixture)
	check(live.owner.entries.size()==16,"Current canonical creature allocates independent queued widgets before any model/mesh exists")
	check(live.ui.text.resolves.size()==8 and live.ui.text.native_fetches.size()>=8,"Only93 performs actual native reference fetch and one top-level TLK parse;94 stays literal")
	for row in live.ui.text.resolves:
		check(row.options.has("context") and row.options.context.is_empty() and row.options.get("nativeB8",0)==0 and row.options.get("nativeBC",0)==0,"Type93 supplies explicit native NULL context and B8/BCzero without borrowing target/controlled fields")
	live.owner.frame_advance(0.0,0)
	check(live.owner.views.size()==1,"Per-object FIFO activates only one native widget in its first manager frame")
	var first:=int(fixture.messages[0].message.nativeTextEvent.serial)
	live.owner.frame_advance(0.125,399)
	check(live.owner.views.size()==1,"399 object milliseconds cannot release the next queued widget")
	live.owner.frame_advance(0.125,1)
	check(live.owner.views.size()==1,"The decrement-to-zero manager frame does not also activate a second widget")
	check(live.owner.entries[first].remaining==1.25,"GUI lifetime uses its own delta independently of the object cooldown")
	live.owner.frame_advance(0.0,0)
	check(live.owner.views.size()==2,"Next eligible manager frame activates the oldest pending widget before GUI tick")
	var id:=int(fixture.target.id);live.ui.text.objects.erase(id);live.owner.observe_sources([],[id])
	var active_before: int=live.owner.views.size();live.owner.frame_advance(0.125,0)
	check(live.owner.entries.size()==active_before and live.owner.views.size()==active_before,"Removal clears pending FIFO only; active widgets retain independent lifetime")
	var reused: Dictionary=fixture.target.duplicate(true);reused.clientKnownLifetime=int(reused.clientKnownLifetime)+1;live.ui.text.objects[id]=reused
	live.owner.observe_sources([id]);var placed_before:=0
	for view in live.owner.views.values():placed_before+=view.placements.size()
	live.owner.frame_advance(0.125,0);var placed_after:=0
	for view in live.owner.views.values():placed_after+=view.placements.size()
	check(placed_after==placed_before,"Reused ID cannot retarget an active orphan to another disclosure")
	connection=4;live.owner.frame_advance(0.0,0)
	check(live.owner.entries.is_empty() and live.owner.views.is_empty(),"Connection retirement clears all pending and active ScriptFloating widgets")
	var echoes_before:=echoed.size();live.ui.receive(fixture.messages[0].message,2)
	check(echoed.size()==echoes_before and live.owner.entries.is_empty(),"Old connection packet cannot reopen or echo under the next accepted connection")
	release(live);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var delayed:=configured(fixture,install);delayed.ui.text.objects.erase(id);ingest(delayed,fixture)
	check(delayed.owner.views.is_empty(),"Known received target awaiting raw publication cannot invent an anchor or view")
	delayed.ui.text.objects[id]=fixture.target.duplicate(true);delayed.owner.observe_sources([id]);delayed.owner.frame_advance(0.0,0)
	check(delayed.owner.entries.size()==16 and delayed.owner.views.size()==1,"Exact delayed canonical disclosure releases retained known-target FIFO without mesh readiness")
	check(echoed.size()==12,"Delayed target publication never duplicates its already resolved log echoes")
	release(delayed);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var redisclosed: Dictionary=fixture.redisclosedFixture;var older:=configured(redisclosed,install)
	older.ui.text.objects[id]=redisclosed.previousTarget.duplicate(true);ingest(older,redisclosed);older.owner.frame_advance(0.0,0)
	check(older.owner.views.is_empty() and older.owner.entries.size()==16,"Expected newer Host witness waits while raw bridge still publishes the older disclosed row")
	older.ui.text.objects[id]=redisclosed.target.duplicate(true);older.owner.observe_sources([id]);older.owner.frame_advance(0.0,0)
	check(older.owner.views.size()==1 and older.owner.entries.size()==16,"Matching newer publication releases the retained valid future disclosure FIFO")
	release(older);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var stale:=configured(redisclosed,install);var previous: Dictionary=redisclosed.previousMessages[0]
	stale.ui.receive(previous.message,int(previous.generation));stale.owner.frame_advance(0.0,0);stale.owner.configure_processing(true)
	check(stale.owner.views.is_empty() and not stale.owner.is_processing(),"Proven newer current row cannot retarget or indefinitely poll an old unbound event")
	check(stale.ui.chat.rows.size()==1,"Stale target lifetime does not discard the original packet's independently eligible log echo")
	stale.owner.configure_processing(false);release(stale);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var fallback:=configured(fixture,install)
	var selected: Array=[]
	for frame in fixture.messages:
		var message: Dictionary=frame.message
		var type:=int(message.type);var echo:=int(message.data.integers.get("1" if type==93 else "0"))
		if not selected.has([type,echo]):
			selected.append([type,echo]);var without: Dictionary=message.duplicate(true);without.erase("nativeTextEvent");fallback.ui.receive(without,2)
	check(fallback.owner.received.is_empty() and fallback.ui.queue.size()==4,"Capture-failure packet without metadata preserves the normal log-only queue and invents no dedicated source")
	while not fallback.ui.queue.is_empty():
		var queued: Dictionary=fallback.ui.queue.pop_front();fallback.ui.present(queued.message)
	check(fallback.ui.chat.rows.size()==2 and fallback.owner.entries.is_empty(),"Normal queued fallback retains only exact echo1 without creating dedicated widgets")
	check(fallback.ui.feedback.floating.is_empty() and fallback.ui.floating_rows.is_empty(),"Normal formatter fallback cannot create or retain legacy floating duplicates")
	check(fallback.ui.table_jobs.size()==1 and fallback.ui.tlk_jobs.size()==1,"Manual fallback presentation check never forces unrelated menu readiness")
	var invalid: Dictionary=fixture.messages[1].message.duplicate(true);invalid.nativeTextEvent=null;var rows_before: int=fallback.ui.chat.rows.size();fallback.ui.receive(invalid,2)
	check(fallback.ui.queue.is_empty() and fallback.ui.chat.rows.size()==rows_before,"Explicit invalid metadata remains rejected, distinct from absent capture metadata")
	release(fallback);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var unknown:=configured(fixture.unknownAreaFixture,install);var unplaced: Dictionary=fixture.unknownAreaFixture.messages[0]
	unknown.ui.receive(unplaced.message,int(unplaced.generation))
	check(unplaced.message.nativeTextEvent.areaId==null and unknown.owner.received.is_empty() and unknown.ui.queue.size()==1,"Actual Host unknown-area metadata retains its accepted-generation log-only queue without borrowing target area")
	var queued_unknown: Dictionary=unknown.ui.queue.pop_front();unknown.ui.present(queued_unknown.message)
	check(unknown.ui.chat.rows.size()==1 and unknown.owner.entries.is_empty() and unknown.ui.floating_rows.is_empty() and unknown.ui.feedback.floating.is_empty(),"Unknown-area fallback preserves exact eligible log echo without either widget path")
	var other_connection: Dictionary=unplaced.message.duplicate(true);other_connection.nativeTextEvent.connection=4;unknown.ui.receive(other_connection,2)
	check(unknown.ui.queue.is_empty() and unknown.ui.chat.rows.size()==1,"Unknown-area fallback cannot echo from a retired connection")
	for bad_header in [{"version":0},{"serial":0},{"source":"Malformed authored guard case"}]:
		var malformed: Dictionary=unplaced.message.duplicate(true);malformed.nativeTextEvent.merge(bad_header,true);unknown.ui.receive(malformed,2)
		check(unknown.ui.queue.is_empty() and unknown.ui.chat.rows.size()==1,"Unknown-area fallback rejects explicit malformed provenance header: "+str(bad_header.keys()[0]))
	var absent_source: Dictionary=unplaced.message.duplicate(true);absent_source.nativeTextEvent.erase("source");unknown.ui.receive(absent_source,2)
	check(unknown.ui.queue.is_empty() and unknown.ui.chat.rows.size()==1,"Unknown-area fallback rejects absent source identity rather than treating it as explicit source:null")
	release(unknown);await process_frame;await process_frame
	echoed.clear();connection=3;clock_ms=0
	var outer:=configured(fixture,install);outer.ui.receive(fixture.messages[0].message,3)
	check(outer.owner.received.is_empty() and outer.ui.queue.is_empty() and outer.ui.chat.rows.is_empty(),"Mismatching outer generation is rejected before dedicated ingress even when metadata looks current")
	release(outer);await process_frame;await process_frame
	for state in ["missing","removed","other-area","noncreature"]:
		echoed.clear();connection=3;clock_ms=0
		var variant: Dictionary=fixture.targetVariants[state];var context:=configured(variant,install);ingest(context,variant)
		check(context.owner.entries.is_empty(),"Unavailable/noncreature target has no invented widget: "+state)
		release(context);await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual current SessionWorld/live-entry graph, Gameplay early93/94 dispatch, real installed TLK with NULL parser context, actual dedicated Owner FIFO/lifetimes/echo and actual Chat append. Passive view and controlled canonical source/camera/clock only. Receiver-trace codec fixture is explicitly not original-server writer capture. No GPU, key, server or user-process action."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
