extends "res://native_session_world.gd"
# Real session/bootstrap/receive/reset hooks; source owners below are authored.
const TestMotion=preload("res://systems/network_motion.gd")
const ClientAPI=preload("res://systems/client_api/access.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var updates: Array=[]
var fixture_serial:=0
var reset_observations: Array=[]
class RawText extends RefCounted:
	var objects: Dictionary={}
class RawUi extends Node:
	signal options_requested
	var text:=RawText.new()
	var generation:=1
	var area_id:=7
	var controlled_id:=1
	func set_world(gen: int,area: int,controlled: int,rows: Array,_inventory: Dictionary={},_header: Dictionary={}) -> void:
		generation=gen; area_id=area; controlled_id=controlled; text.objects.clear()
		for row in rows: text.objects[int(row.id)]=row
	func update_world(gen: int,area: int,controlled: int,rows: Array,removed: Array,_inventory: Dictionary={},_header: Dictionary={}) -> void:
		if gen!=generation or area!=area_id: return
		controlled_id=controlled
		for id in removed: text.objects.erase(int(id))
		for row in rows: text.objects[int(row.id)]=row
	func set_radial_preferences(_value: Dictionary) -> void: pass
	func close() -> void: pass
class RawWorld extends Node3D:
	var area_id:=7
	var generation:=1
	var controlled_id:=1
	var minutes_per_hour:=5
	var placeable_lights: Node
	var point_wind: Node
	var effects: Node
	var closed:=false
	var retiring:=false
	var motion:=TestMotion.new()
	var motion_revisions: Dictionary={}
	func receive(rows: Array,controlled: int) -> void:
		controlled_id=controlled
		for row in rows:
			if int(row.get("objectType",0))==5 and not motion.objects.has(int(row.id)): motion.observe(int(row.id),row.get("replicated",{}),true,row.get("replicated",{}))
	func receive_delta(rows: Array,removed: Array,controlled: int) -> void:
		for id in removed: motion.objects.erase(int(id)); motion_revisions.erase(int(id))
		receive(rows,controlled)
	func observe_movement(records: Array) -> void:
		if closed or retiring: return
		for row in records:
			if int(row.revision)<=int(motion_revisions.get(int(row.id),-1)): continue
			motion_revisions[int(row.id)]=int(row.revision)
			motion.observe(int(row.id),row.changes,bool(row.get("created",false)),row.initial)
	func begin_retirement() -> void: retiring=true
	func worker_tasks() -> Array: return []
	func close() -> void: closed=true
class Transitions extends RefCounted:
	func receive(_rows: Array,_removed: Array,_delta: bool) -> bool: return false
class Settings extends Node:
	var radial_preferences: Dictionary={}
	var compact_scenery_enabled:=false
	func hide() -> void: pass
class Menu extends Node:
	var scope: Array=[]
	func set_native_scope(value: Array) -> void: scope=value.duplicate()
	func dismiss() -> void: pass
	func detach_native() -> void: pass
class RejectingBinding extends RefCounted:
	var delegate: RefCounted
	var rejected:=0
	func _init(value: RefCounted) -> void: delegate=value
	func commit(_connection: int,_generation: int,_area: int,_data: Dictionary) -> bool:
		rejected+=1; return false
	func reset(reason: String) -> bool: return delegate.reset(reason)
func _initialize() -> void: call_deferred("run")
func check(value: bool,label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text); push_error(label_text)
func source_row(id: int=1,life: int=10,area: int=7,type: int=5) -> Dictionary:
	return {"id":id,"nativeLifetime":life,"areaId":area,"objectType":type,"replicated":{"position":[1,2,0],"orientation":[1,0,0],"animation":0,"walkRate":2,"runRate":4},"clientAbilityCache":{"base":null,"bonuses":[0,0,0,0,0,0],"dex":0}}
func feed(rows: Array,mode: String="full",removed: Array=[],gen: int=1,area: int=7,controlled: int=1) -> void:
	fixture_serial+=1
	var header:={"bridgeMode":mode,"bridgeBaseSerial":accepted_raw_serial,"area":{"id":area},"module":{},"controlledId":controlled,"removedObjectIds":removed}
	receive({"kind":"raw-world-begin","connection":session_connection,"serial":fixture_serial,"generation":gen,"count":rows.size(),"data":header})
	if not rows.is_empty(): receive({"kind":"raw-world-chunk","connection":session_connection,"serial":fixture_serial,"generation":gen,"objects":rows})
	receive({"kind":"raw-world-end","connection":session_connection,"serial":fixture_serial,"generation":gen})
func movement(revision: int,gen: int=1,area: int=7,connection: int=1) -> void:
	receive({"kind":"movement","connection":connection,"generation":gen,"areaId":area,"records":[{"id":1,"revision":revision,"changes":{"position":[3,2,0],"animation":0},"initial":{"position":[1,2,0]}}]})
func prepare_owners(gen: int=1,area: int=7) -> void:
	transition_targets=Transitions.new()
	world=RawWorld.new(); world.generation=gen; world.area_id=area; host.add_child(world)
	gameplay_ui=RawUi.new(); gameplay_ui.generation=gen; gameplay_ui.area_id=area; host.add_child(gameplay_ui)
	gameplay_ui.options_requested.connect(open_game_options)
	epoch=gen; initialized=true
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
	host=Node3D.new(); root.add_child(host); render_settings=Settings.new(); host.add_child(render_settings)
	render_menu=Menu.new(); host.add_child(render_menu)
	world_retirement=WorldRetirement.new(); host.add_child(world_retirement)
	transition_targets=Transitions.new(); session_connection=1
	install_entity_api()
	var provider: RefCounted=ClientAPI.entities
	check(provider!=null and entity_api_binding!=null,"Actual session bootstrap installs and binds ClientAPI.entities")
	var initial_provider:=provider; install_entity_api()
	check(ClientAPI.entities==initial_provider,"Actual session bootstrap is idempotent")
	provider.entity_updated.connect(func(event):updates.append(event))
	prepare_owners(); initialized=false
	feed([source_row()])
	check(provider.list_references().is_empty() and report.entity_api_observer.ignored==1,"Uninitialized base snapshot rejection cannot publish API data")
	check(not closing and accepted_raw_serial==fixture_serial and requests.back().kind=="raw-world-accepted" and requests.back().serial==fixture_serial,"Uninitialized snapshot retains the pre-API core acknowledgment behavior")
	initialized=true; feed([source_row(),source_row(2,11,7,7)])
	check(not closing and accepted_raw_serial==fixture_serial and provider.list_references().size()==2,"Real begin/chunk/end receiver publishes accepted raw snapshot before acknowledgment")
	check(provider.get_by_id(2)!=null and not provider.get_by_id(2).presentation.available,"Real native hooks include previsual/non-renderable raw entities")
	check(provider.get_controlled().object_id==1 and not provider.get_player_character().available,"Real session control has no fabricated player-character identity")
	var reference: Dictionary=provider.get_reference(1)
	var entity: Dictionary=provider.resolve(reference)
	check(entity.received.source=="client_received_read_model" and entity.client_data.ability_cache.source=="client_initialized_ability_cache" and not entity.received.value.has("clientAbilityCache"),"Actual binding classifies merged read-model and initialized cache provenance")
	var boundary_count: int=provider.diagnostics().boundaries; var ack_count:=requests.size()
	feed([source_row(1,999)],"full",[],0)
	check(provider.diagnostics().boundaries==boundary_count and provider.resolve(reference)!=null,"Old generation ignored by the base cannot publish API data")
	check(not closing and accepted_raw_serial==fixture_serial and requests.size()==ack_count+1 and requests.back().serial==fixture_serial,"Ignored old-generation snapshot retains original core application/ACK flow")
	ack_count=requests.size()
	feed([source_row(1,999,8)],"full",[],1,8)
	check(provider.diagnostics().boundaries==boundary_count and not provider.get_scope().active and provider.resolve(reference)==null,"Base-accepted inconsistent area invalidates only API scope without publishing")
	check(not closing and accepted_raw_serial==fixture_serial and requests.size()==ack_count+1 and gameplay_ui.text.objects[1].nativeLifetime==999,"Inconsistent observer scope preserves original canonical application and ACK")
	check(report.entity_api_observer.invalidated==1 and report.entity_api_observer.last_reason=="owner_scope_mismatch" and report.entity_api_observer.size()==3,"Observer diagnostics retain only fixed counters and the last finite reason")
	feed([source_row(),source_row(2,11,7,7)])
	reference=provider.get_reference(1)
	check(provider.get_scope().active and provider.resolve(reference)!=null,"A consistent full publication restores the invalidated observer")
	updates.clear(); FrameProfile.enabled=false; movement(1)
	check(updates.size()==1 and updates[0].source=="presentation_input" and provider.resolve(reference).presentation.value.position==Vector3(3,2,0),"Actual unprofiled receive path publishes after the movement owner applies input")
	check(provider.resolve(reference).replicated.value.position==[1,2,0],"Fast movement input does not rewrite the last raw received read model")
	movement(1); movement(0); movement(2,0); movement(2,1,8); movement(2,1,7,0)
	check(updates.size()==1,"Duplicate/stale revision, generation, area and connection movement do not publish")
	FrameProfile.enabled=true; movement(2); FrameProfile.enabled=false
	check(updates.size()==2 and updates[-1].input_revision==2,"Actual profiled receive path publishes accepted movement too")
	world.retiring=true; movement(3); world.retiring=false
	check(updates.size()==2,"Retiring world cannot publish movement rejected by its owner")
	var changed:=source_row(); changed.replicated.position=[4,2,0]
	feed([changed],"delta",[2])
	check(provider.get_reference(1)==reference and provider.get_by_id(2)==null and provider.resolve(reference).replicated.value.position==[4,2,0],"Actual delta hook reads canonical upserts/removals and preserves entity lifetime")
	feed([source_row(1,12)],"delta")
	check(provider.resolve(reference)==null,"Actual same-ID transport identity replacement invalidates old refs")
	reference=provider.get_reference(1)
	world.area_id=8; world.generation=2; gameplay_ui.generation=2; gameplay_ui.area_id=8; epoch=2
	feed([source_row(1,12,8)],"full",[],2,8)
	check(provider.resolve(reference)==null and provider.get_scope().area_generation==2,"Hook publication follows fixture-owned area generation without renderer admission")
	var real_binding: RefCounted=entity_api_binding; var rejecting:=RejectingBinding.new(real_binding)
	reference=provider.get_reference(1); entity_api_binding=rejecting; ack_count=requests.size()
	feed([source_row(1,12,8)],"full",[],2,8)
	check(rejecting.rejected==1 and not closing and accepted_raw_serial==fixture_serial and requests.size()==ack_count+1 and requests.back().kind=="raw-world-accepted","Binding rejection cannot fail/disconnect or suppress the core ACK")
	check(not provider.get_scope().active and provider.resolve(reference)==null and report.entity_api_observer.last_reason=="binding_rejected","Binding rejection invalidates only API state and records bounded diagnostics")
	entity_api_binding=real_binding; feed([source_row(1,12,8)],"full",[],2,8)
	check(provider.get_scope().active,"Observer can recover after a nonfatal binding rejection")
	reference=provider.get_reference(1); cancelled_connection=session_connection
	movement(9,2,8); check(provider.get_scope().active,"Rejected canceled-connection movement cannot alter active query scope")
	reset_session()
	check(provider.resolve(reference)==null and not provider.get_scope().active and reset_observations[-1],"Actual reset invalidates API scope before owner diagnostics and teardown")
	check(world==null and gameplay_ui==null,"Actual reset tears down authored source owners")
	session_connection=2; cancelled_connection=-1; prepare_owners(0,8)
	feed([source_row(1,12,8)],"full",[],0,8)
	check(provider.get_scope().connection==2 and provider.get_scope().area_generation==0 and provider.resolve(reference)==null,"Reconnection hook accepts fresh lower generation without resurrecting old refs")
	var api_node: Node=root.get_node("ClientAPI"); var blocker:=TCPServer.new()
	check(blocker.listen(0,"127.0.0.1")==OK,"REST bind-error fixture owns an isolated loopback port")
	var rest_discovery:=output+".rest-discovery.json"
	var rest_failure: Dictionary=api_node.start_rest_from_arguments(["--entity-api-rest=true","--entity-api-rest-port="+str(blocker.get_local_port()),"--entity-api-rest-discovery="+rest_discovery])
	ack_count=requests.size(); feed([source_row(1,12,8)],"full",[],0,8)
	check(rest_failure.error=="bind_failed" and not closing and requests.size()==ack_count+1 and accepted_raw_serial==fixture_serial and provider.get_scope().active,"REST startup failure cannot fail the game, invalidate entity state or suppress core ACK")
	blocker.stop()
	var rest_started: Dictionary=api_node.start_rest_from_arguments(["--entity-api-rest=true","--entity-api-rest-port=0","--entity-api-rest-discovery="+rest_discovery])
	check(rest_started.listening,"Actual session shutdown fixture starts an owned REST listener")
	reference=provider.get_reference(1); closing=true; shutdown()
	check(not provider.get_scope().active and provider.resolve(reference)==null,"Actual shutdown entry invalidates scope even on an already-closing path")
	check(not api_node.rest_status().listening and not FileAccess.file_exists(rest_discovery),"Actual session shutdown hook closes REST and removes its credential discovery file")
	closing=false; world_retirement.close(); host.free(); host=null; world=null; gameplay_ui=null
	await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"nativeBuilds":0,"sessionOwnerSha256":FileAccess.get_sha256("res://native_session_world.gd"),"projectSha256":FileAccess.get_sha256("res://project.godot"),"scope":"Actual native_session_world bootstrap, raw framing/base receive, profiled/unprofiled movement hooks, reset and shutdown entry, plus owned REST bind failure/shutdown; raw/UI/world owners and area-ready state are authored fixtures. No live game client, game-server connection, renderer admission or native rebuild."}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print("ENTITY_API_SESSION_RESULT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
func retain_world_diagnostics(_reason: String,_connection: int=0) -> void:
	reset_observations.append(not ClientAPI.entities.get_scope().active)
func send(value: Dictionary) -> void: requests.append(value.duplicate(true))
func fail(reason: String) -> void: failures.append(reason); closing=true
