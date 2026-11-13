extends "res://native_session_world.gd"
# Real session wire/barrier/commit/API/reset paths. A held metadata owner makes
# ordering tests deterministic; the separate metadata test owns actual workers.
const Authored=preload("res://tests/native_entity_api_session_test.gd")
const API=preload("res://systems/client_api/access.gd")
const Decoder=preload("res://systems/bridge_frames.gd")
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
const Backlog=preload("res://systems/native_data/snapshot_protocol_backlog.gd")
const Preparation=preload("res://systems/native_data/world_snapshot_preparation.gd")
const ActualWorld=preload("res://systems/native_render/live_world.gd")
const WorldFixture=preload("res://tests/native_world_snapshot_sidecar_test.gd")
var checks:=0
var failures: Array=[]
var trace: Array=[]
var sent: Array=[]
var protocol_failures: Array=[]
var reentrant_reset:=false
class HeldPreparation extends RefCounted:
	var active:=false
	var running: Array=[]
	var retired: Array=[]
	var scope: Array=[]
	var rows: Array=[]
	var area_id:=-1
	var count:=0
	var sealed:=false
	var released:=false
	var closed:=false
	func begin(value: Array,area: int,total: int) -> bool:
		cancel();active=true;scope=value.duplicate();area_id=area;count=total;return true
	func submit(value: Array) -> bool:rows.append_array(value);return true
	func seal() -> bool:sealed=rows.size()==count;return sealed
	func poll() -> bool:return active and sealed and released
	func take(value: Array) -> Dictionary:
		if value!=scope or not poll():return {}
		var error:=""
		for source in rows:
			error=Metadata.validation_error(source)
			if not error.is_empty():break
		var result:={"version":1,"error":error,"scope":scope,"area_id":area_id,"count":count,"rows":Metadata.prepare(rows,area_id) if error.is_empty() else []}
		active=false;rows=[];return result
	func cancel() -> void:active=false;rows=[];scope=[];sealed=false;released=false
	func close() -> void:cancel();closed=true
	func snapshot() -> Dictionary:return {"active":active,"closed":closed,"current_tasks":0,"retired_tasks":0,"pending_rows":rows.size(),"stats":{"authored_held_owner":true}}
class World extends Authored.RawWorld:
	var events: Array=[]
	func set_show_blockers(_value: bool) -> void:pass
	func stage_received_metadata(_rows: Array,_metadata: Dictionary) -> bool:events.append("stage");return true
	func receive(rows: Array,controlled: int) -> void:events.append("world");super.receive(rows,controlled)
	func observe_movement(records: Array) -> void:events.append("movement");super.observe_movement(records)
class Ui extends Authored.RawUi:
	var events: Array=[]
	func set_world(gen: int,area: int,controlled: int,rows: Array,inventory: Dictionary={},header: Dictionary={}) -> void:events.append("ui");super.set_world(gen,area,controlled,rows,inventory,header)
class Settings extends Authored.Settings:
	var show_blockers_enabled:=false
class Menu extends Authored.Menu:
	var native_scope: Array=[]
	var callback: Callable
	func set_native_scope(value: Array) -> void:
		native_scope=value.duplicate();scope=value.duplicate()
		if callback.is_valid():
			var invoke:=callback;callback=Callable();invoke.call()
class Visibility extends RefCounted:
	var events: Array=[]
	var callback: Callable
	func accepted_world(_data: Dictionary) -> void:
		events.append("visibility")
		if callback.is_valid():
			var invoke:=callback;callback=Callable();invoke.call()
	func receive_movement(_message: Dictionary) -> void:pass
	func cleanup_connection() -> void:events.append("visibility-reset")
	func snapshot() -> Dictionary:return {}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_text: String) -> void:
	checks+=1
	if not value:failures.append(label_text);push_error(label_text)
func row(id: int=1) -> Dictionary:
	return {"id":id,"areaId":7,"objectType":5,"nativeLifetime":1,"clientKnownLifetime":1,"replicated":{"position":[1,2,0],"orientation":[1,0,0],"animation":0,"walkRate":2,"runRate":4}}
func frames_for(serial: int,rows: Array,generation: int=1) -> Array:
	return [{"kind":"raw-world-begin","connection":1,"serial":serial,"generation":generation,"count":rows.size(),"data":{"bridgeMode":"full","area":{"id":7},"module":{},"controlledId":1}}, {"kind":"raw-world-chunk","connection":1,"serial":serial,"generation":generation,"objects":rows}, {"kind":"raw-world-end","connection":1,"serial":serial,"generation":generation}]
func wire(messages: Array) -> void:
	var bytes:=PackedByteArray()
	for message in messages:bytes.append_array((JSON.stringify(message)+"\n").to_utf8_buffer())
	var decoder:=Decoder.new();var decoded:=decoder.feed(bytes)
	check(decoder.failure.is_empty() and decoded.size()==messages.size() and decoder.last_frame_sizes.size()==decoded.size(),"Actual JSON framing supplies private exact wire sizes")
	dispatch_protocol_messages(decoded,decoder.last_frame_sizes)
func motion_message(revision: int=1,connection: int=1) -> Dictionary:
	return {"kind":"movement","connection":connection,"generation":1,"areaId":7,"records":[{"id":1,"revision":revision,"changes":{"position":[3,2,0],"animation":0},"initial":{"position":[1,2,0]}}]}
func owners() -> void:
	world=World.new();world.events=trace;host.add_child(world)
	gameplay_ui=Ui.new();gameplay_ui.events=trace;host.add_child(gameplay_ui);gameplay_ui.options_requested.connect(open_game_options)
	transition_targets=Authored.Transitions.new();epoch=1;initialized=true
	native_visibility_runtime=Visibility.new();native_visibility_runtime.events=trace
	snapshot_preparation=HeldPreparation.new();snapshot_preparation_enabled=true;cancelled_connection=-1;session_connection=1
func release_metadata() -> void:snapshot_preparation.released=true;poll_snapshot_preparation()
func ack_count() -> int:return sent.filter(func(value):return value.kind=="raw-world-accepted").size()
func api_event(event: Dictionary) -> void:
	trace.append("api-movement" if event.get("source")=="presentation_input" else "api")
	if reentrant_reset:
		reentrant_reset=false;reset_session()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	host=Node3D.new();root.add_child(host);label=Label.new();host.add_child(label)
	render_settings=Settings.new();host.add_child(render_settings);render_menu=Menu.new();host.add_child(render_menu)
	world_retirement=WorldRetirement.new();host.add_child(world_retirement);install_entity_api()
	var provider: RefCounted=API.entities;provider.entity_added.connect(api_event);provider.entity_updated.connect(api_event)
	owners();var transaction:=frames_for(1,[row()]);transaction.append(motion_message())
	wire(transaction)
	check(received==0 and ack_count()==0 and snapshot_backlog.size()==1 and not pending_prepared_snapshot.is_empty(),"Pending raw end defers core, visibility, API and ACK while later movement queues")
	check(not snapshot_transition_waiting(),"Same-generation full snapshot keeps normal input policy")
	release_metadata()
	check(trace==["stage","world","ui","visibility","api","ack","movement","api-movement"],"Actual owner ordering: core/UI, visibility, API, ACK, queued movement")
	check(accepted_raw_serial==1 and snapshot_backlog.size()==0 and provider.get_by_id(1).presentation.value.position==Vector3(3,2,0),"Queued movement applies after accepted canonical full boundary")
	# Two queued raw transactions retain begin/chunk/end continuation ordering.
	trace.clear();wire(frames_for(2,[row()]));wire(frames_for(3,[row(2)]))
	check(snapshot_backlog.size()==3,"Next raw begin/chunk/end are queued as one ordered continuation")
	release_metadata()
	check(accepted_raw_serial==2 and snapshot_backlog.size()==0 and not pending_prepared_snapshot.is_empty() and pending_prepared_snapshot.serial==3,"Draining new begin preserves queued chunk/end via cancel(false)")
	release_metadata();check(accepted_raw_serial==3 and provider.get_by_id(2)!=null,"Queued continuation completes and ACKs its own serial")
	# Stale interrupts remain stale; current reset discards pending data/backlog.
	var before_ack:=ack_count();wire(frames_for(4,[row()]))
	wire([{"kind":"session-reset","connection":0}])
	check(not pending_prepared_snapshot.is_empty() and snapshot_backlog.size()==1,"Stale reset cannot cancel current preparation")
	wire([{"kind":"session-reset","connection":1}])
	check(pending_prepared_snapshot.is_empty() and snapshot_backlog.size()==0 and world==null and accepted_raw_serial==-1 and ack_count()==before_ack,"Current reset cancels pending admission and queued messages without ACK")
	owners();wire(frames_for(5,[row()],2))
	check(snapshot_transition_waiting() and keyboard_context().is_empty() and native_pointer_blocked(Vector2.ZERO),"Incoming generation gates old-world keyboard and pointer while pending")
	wire([{"kind":"session-reset","connection":1}]);check(not snapshot_transition_waiting(),"Reset clears the pending-generation presentation guard")
	# Authored/direct raw calls never activate asynchronous borrowed preparation.
	owners();before_ack=ack_count()
	for message in frames_for(6,[row()]):receive(message)
	check(not snapshot_preparation.active and pending_prepared_snapshot.is_empty() and ack_count()==before_ack+1,"Entirely direct/authored raw path remains synchronous")
	before_ack=ack_count();var received_before:=received
	wire(frames_for(7,[row()],0))
	check(ack_count()==before_ack+1 and accepted_raw_serial==7 and received==received_before,"Ignored old-generation full snapshot retains original ACK without worker activation")
	before_ack=ack_count();var inconsistent:=frames_for(8,[row()]);inconsistent[0].data.area.id=8;inconsistent[1].objects[0].areaId=8
	wire(inconsistent);release_metadata()
	check(ack_count()==before_ack+1 and accepted_raw_serial==8 and report.entity_api_observer.last_reason=="owner_scope_mismatch","Base-accepted area mismatch remains a nonfatal observer invalidation and retains original ACK")
	# A public entity event can synchronously reset during the final commit.
	reentrant_reset=true;before_ack=ack_count();wire(frames_for(9,[row(7)]));release_metadata()
	check(world==null and accepted_raw_serial==-1 and ack_count()==before_ack,"Reentrant API reset cannot overwrite reset serial or send stale ACK")
	owners();before_ack=ack_count();native_visibility_runtime.callback=func():reset_session()
	wire(frames_for(10,[row()]));release_metadata()
	check(world==null and accepted_raw_serial==-1 and ack_count()==before_ack,"Reentrant visibility reset cannot continue API publication or ACK")
	owners();before_ack=ack_count();render_menu.native_scope=[];render_menu.callback=func():reset_session()
	wire(frames_for(11,[row()]));release_metadata()
	check(world==null and accepted_raw_serial==-1 and ack_count()==before_ack,"Reentrant menu scope reset preserves reset serial and suppresses stale ACK")
	# Non-Dictionary shape errors finish the barrier and fail without core admission.
	owners();before_ack=ack_count();wire(frames_for(12,[["not-a-row"]]));release_metadata()
	check(closing and pending_prepared_snapshot.is_empty() and ack_count()==before_ack and protocol_failures.size()==1,"Malformed worker row terminates cleanly after readiness instead of a typed world loop error")
	closing=false;snapshot_preparation=HeldPreparation.new();owners();before_ack=ack_count()
	var mixed:=frames_for(13,[row()]);wire([mixed[0]]);receive(mixed[1])
	check(closing and ack_count()==before_ack and not snapshot_preparation.active,"Authored chunk cannot join a worker scope started by trusted wire")
	closing=false;owners();wire(frames_for(14,[row()]));wire([{"kind":"finish","connection":0}])
	check(not closing and not pending_prepared_snapshot.is_empty(),"Stale finish cannot stop a current scope")
	wire([{"kind":"finish","connection":1}]);check(closing and pending_prepared_snapshot.is_empty() and snapshot_preparation.closed,"Current finish immediately cancels and closes preparation")
	# Actual queue bounds use private frame byte counts, never message fields.
	var backlog:=Backlog.new()
	var accepted_all:=true
	for index in 1024:accepted_all=backlog.push({"kind":"notice","wire_bytes":0},1) and accepted_all
	check(accepted_all,"Backlog accepts exactly its bounded message capacity")
	check(not backlog.push({},1) and backlog.snapshot().messages==1024,"Message cap rejects 1025th retained message")
	backlog.detach();check(backlog.push({},16*1024*1024) and not backlog.push({},1),"Byte cap rejects above exact 16MiB independently of message count")
	var rolling:=Backlog.new();rolling.push({},1);rolling.push({},1)
	for index in 4096:rolling.pop();rolling.push({},1)
	check(rolling.size()==2 and rolling.bytes==2 and rolling.entries.size()<=Backlog.MAX_MESSAGES*2,"Continuously nonempty backlog compacts consumed slots within a fixed bound")
	var decoder:=Decoder.new();var utf8:=(JSON.stringify({"kind":"notice","text":"é·","wire_bytes":1})+"\n").to_utf8_buffer()
	check(decoder.feed(utf8.slice(0,3)).is_empty() and decoder.last_frame_sizes.is_empty(),"Fragmented partial JSON has no admitted size record")
	check(decoder.feed(utf8.slice(3)).size()==1 and decoder.last_frame_sizes[0]==utf8.size(),"UTF8 accounting includes exact bytes and newline rather than spoofed field")
	var metadata:=JSON.stringify({"kind":"particle-stream","connection":1,"areaId":7,"generation":1,"transferId":1,"epoch":1,"sequence":1,"emitters":[]}).to_utf8_buffer()
	var binary:=PackedByteArray([0x89,0x50,0x41,0x52,0,0,0,0]);binary.encode_u32(4,4+metadata.size())
	var length:=PackedByteArray([0,0,0,0]);length.encode_u32(0,metadata.size());binary.append_array(length);binary.append_array(metadata)
	check(decoder.feed(binary.slice(0,9)).is_empty() and decoder.last_frame_sizes.is_empty(),"Partial binary framing does not invent retained-message bytes")
	check(decoder.feed(binary.slice(9)).size()==1 and decoder.last_frame_sizes[0]==binary.size(),"Binary wire accounting includes header, metadata length and payload bytes")
	# Exercise the complete wire -> real worker -> actual World sidecar -> ACK
	# route. Keep asset loading and frame simulation disabled; this is a state
	# boundary test, without a renderer, server or timing/FPS assertion.
	closing=false;reset_session();owners();snapshot_preparation.close()
	snapshot_preparation=Preparation.new()
	world.free();world=ActualWorld.new();world.area_id=7;world.generation=1
	world.combat=WorldFixture.Combat.new();host.add_child(world);world.set_process(false)
	var actual_rows: Array=[]
	for index in 128:actual_rows.append(row(index+1))
	var actual_frames:=frames_for(15,actual_rows)
	actual_frames[1].objects=actual_rows.slice(0,64)
	actual_frames.insert(2,{"kind":"raw-world-chunk","connection":1,"serial":15,"generation":1,"objects":actual_rows.slice(64)})
	actual_frames.append(motion_message(20))
	before_ack=ack_count();wire(actual_frames)
	var deadline:=Time.get_ticks_msec()+10000
	while ack_count()==before_ack and Time.get_ticks_msec()<deadline:
		poll_snapshot_preparation();await process_frame
	var real_worker: Dictionary=snapshot_preparation.snapshot()
	check(ack_count()==before_ack+1 and accepted_raw_serial==15 and snapshot_backlog.size()==0,"Real worker completes the actual wire/session/World/ACK boundary and drains queued movement")
	check(world.received_metadata_stats.prepared_boundaries==1 and world.received_metadata_stats.prepared_rows==128 and world.received_metadata_stats.rejected==0,"Actual World consumes all real worker metadata exactly once")
	check(real_worker.stats.completed>0 and not real_worker.stats.threads.is_empty() and not real_worker.stats.threads.has(OS.get_main_thread_id()) and real_worker.stats.peak_tasks<=2,"Integrated preparation completes off-main with bounded tasks")
	check(world.desired.size()==128 and world.motion.objects[1].position==Vector3(3,2,0) and provider.get_by_id(1).presentation.value.position==Vector3(3,2,0),"Actual World and read-only API observe queued movement after prepared full admission")
	check(world._staged_received_metadata.is_empty() and world._boundary_received_metadata.is_empty(),"Integrated metadata expires without a second canonical store")
	# Cancel a real borrower scope before its raw end, then reap terminal tasks.
	var cancel_frames:=frames_for(16,actual_rows.slice(0,64))
	wire(cancel_frames.slice(0,2));before_ack=ack_count()
	wire([{"kind":"session-reset","connection":1}])
	deadline=Time.get_ticks_msec()+10000
	while not snapshot_preparation.retired.is_empty() and Time.get_ticks_msec()<deadline:
		poll_snapshot_preparation();await process_frame
	check(world==null and ack_count()==before_ack and not snapshot_preparation.active and snapshot_preparation.running.is_empty() and snapshot_preparation.retired.is_empty(),"Real worker reset releases borrowed rows without stale publication or ACK")
	closing=false;reset_session();world_retirement.close();snapshot_preparation.close();host.free();host=null;world=null;gameplay_ui=null
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"real_worker":real_worker,"scope":"Actual wire/session/worker/World metadata publication, API and ACK; deterministic held-worker ordering, resets, cancellation, reentrancy and exact bounded backlog accounting. UI, visibility and shutdown are authored boundaries; no asset admission, server, rendering or FPS acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if failures.is_empty() else 1)
func retain_world_diagnostics(_reason: String,_connection: int=0) -> void:pass
func send(value: Dictionary) -> void:
	var message:=value.duplicate(true);message.connection=session_connection;sent.append(message)
	if value.kind=="raw-world-accepted":trace.append("ack")
func shutdown() -> void:
	cancel_snapshot_preparation();snapshot_preparation.close();closing=true
	if report.has("failure"):protocol_failures.append(report.failure)
