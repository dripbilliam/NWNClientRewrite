extends SceneTree
const Runtime=preload("res://systems/native_render/native_scene_visibility_runtime.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const ActorAlpha=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
class Text extends RefCounted:
	var objects: Dictionary={}
class Ui extends Node:
	var text:=Text.new()
class Settings extends Node:
	var creature_shadow_detail:=2
class Clock extends RefCounted:
	var queries:=0
	func reveal_timing() -> Dictionary:
		queries+=1
		return {"available":true,"snapshot_us":200000,"source":"authored-native-snapshot-input"}
class Client extends Node:
	var world
	var gameplay_ui
	var render_settings
	var native_clock_runtime:=Clock.new()
	var session_connection:=7
	var epoch:=3
	var closing:=false
	func native_text_connection() -> Variant:return session_connection if not closing else null
var checks:=0
var failures: Array=[]
var report:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func birth(id: int,physical: String,ownership: String="new",certified: bool=true) -> Dictionary:
	return {"version":2,"objectId":id,"objectType":5,"operation":"create","ownership":ownership,"physicalToken":physical,"lifecycleEpoch":4,"constructionCertified":certified,"aiRegistrationCertified":certified,"constructionHistoryComplete":certified}
func source(id: int,physical: String,life: int=1,area: int=9) -> Dictionary:
	return {"id":id,"objectType":5,"areaId":area,"nativeLifetime":life,"replicated":{"position":[5.0,5.0,0.0]},"playerState":{"visibility":{}},"nativeClockOwner":{"version":1,"source":"native-client-clock-owner-v1","epoch":4,"connection":7,"physicalCurrent":true,"physicalToken":physical}}
func admit(client: Client,row: Dictionary) -> void:
	client.gameplay_ui.text.objects[row.id]=row;client.world.desired[row.id]={"object":row,"key":"model/"+str(row.id)+"/"+str(row.nativeLifetime)}
func world(client: Client,area: int=9,generation: int=3) -> Node3D:
	var value:=World.new();value.set_process(false);root.add_child(value);value.generation=generation;value.area_id=area;value.controlled_id=1
	value.terrain=Terrain.new();value.terrain.set_process(false);value.add_child(value.terrain)
	value.effects=Effects.new();value.effects.set_process(false);value.add_child(value.effects);value.effects.world=value;value.effects.client=value.effects
	client.world=value;client.epoch=generation;return value
func data(client: Client,objects: Array,removed: Array=[]) -> Dictionary:
	return {"area":{"id":client.world.area_id,"width":2,"height":2,"fields":{"8":1}},"controlledId":1,"objects":objects,"removedObjectIds":removed,"bridgeMode":"delta"}
func actor(client: Client,id: int) -> Node3D:
	var value:=Actor.new();value.set_process(false);client.world.add_child(value);value.actor_alpha_enabled=true;value.actor_alpha=ActorAlpha.new();value.renderer_alpha_primary_models.assign([0]);value.object_id=id
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.set_meta("native_source_model_index",0);var material:=StandardMaterial3D.new();material.albedo_color=Color(1,1,1,.8);mesh.material_override=material;value.add_child(mesh);value.meshes.append(mesh);value.actor_alpha.enroll(mesh,0)
	client.world.instances[id]=value;client.world.installed[id]=client.world.desired[id].key;return value
func tile(serial: int,actor_row: Dictionary,generation: int=3,area: int=9,state: int=1) -> Dictionary:
	return {"kind":"raw-tile-visibility","connection":7,"generation":generation,"areaId":area,"actorId":1,"lifetime":Lifetime.token(actor_row),"serial":serial,"change":{"mode":[0,0],"points":[{"x":0,"y":0,"state":state}]}}
func member(snapshot: Dictionary,id: int) -> Dictionary:
	for row in snapshot.bridge.get("owner",{}).get("members",[]):
		if row.id==id:return row
	return {}
func release_world(value: Node3D) -> void:
	value.closed=true;value.terrain.closed=true;value.effects.closed=true
	for instance in value.instances.values():instance.retire()
	value.instances.clear();value.desired.clear();value.installed.clear();value.motion.objects.clear();value.pool.clear();value.motion.facing_target_query=Callable();value.free()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var client:=Client.new();root.add_child(client)
	var runtime:=Runtime.new();check(runtime.configure(client).available and runtime.snapshot().scope.is_empty(),"Startup configures lazily before world/UI/settings exist")
	var initializer: Dictionary=JSON.parse_string(JSON.stringify({"ui":{"gameMasterPermission":{"source":"native_connection_start_16","permission":0,"field114":null,"parameter":null}}}))
	check(not runtime.accepted_world(initializer).available and runtime.snapshot().fields.permission==false,"Real JSON connection16 initialization precedes unavailable area/UI/world and never waits for map history")
	client.gameplay_ui=Ui.new();client.add_child(client.gameplay_ui);client.render_settings=Settings.new();client.add_child(client.render_settings)
	var first:=world(client);var controlled:=source(1,"controlled");var remote:=source(2,"remote")
	check(runtime.lifecycle(birth(1,"controlled")).constructed and runtime.lifecycle(birth(2,"remote")).constructed,"Admitted native lifecycle births work independently of clock runtime readiness")
	admit(client,controlled);admit(client,remote);runtime.receive_connection_permission(false)
	check(runtime.receive(tile(1,controlled)) and runtime.snapshot().pending==1 and runtime.snapshot().tile_count==0,"Fresh tile event waits for accepted-world-end rather than old registry positions")
	var existing:=actor(client,2);var clock=client.native_clock_runtime;client.native_clock_runtime=null
	for malformed in [{"id":9,"height":2,"fields":{"8":1}},{"id":9,"width":2,"height":2,"fields":null},{"id":9,"width":2,"height":2,"fields":[]},{"id":9,"width":2,"height":2,"fields":{}},{"id":9,"width":2,"height":2,"fields":{"8":0.5}},{"id":9,"width":65536,"height":65536,"fields":{"8":0}}]:
		var invalid:=data(client,[controlled,remote]);invalid.area=JSON.parse_string(JSON.stringify(malformed))
		check(not runtime.accepted_world(invalid).available and runtime.snapshot().pending==1 and runtime.snapshot().tile_count==0 and existing.meshes[0].visible,"Unavailable native area header/fields retain fresh map queue and real Actor "+JSON.stringify(malformed))
	check(not runtime.accepted_world(data(client,[controlled,remote])).available and runtime.snapshot().pending==1 and runtime.snapshot().bridge.is_empty() and existing.meshes[0].visible and is_equal_approx(existing.meshes[0].material_override.albedo_color.a,.8),"Raw replay/missing native clock retains fresh queue and cannot blank existing real Actor")
	client.native_clock_runtime=clock;first.instances.erase(2);first.installed.erase(2);existing.retire()
	var raw_only:=Runtime.new();raw_only.configure(client)
	check(not raw_only.accepted_world(data(client,[controlled,remote])).available and raw_only.snapshot().bridge.is_empty() and raw_only.snapshot().issues.has("fresh-native-map-history-unavailable/reveal-not-applied"),"Raw-only capture without fresh map history never guesses reveal state from sticky automap")
	raw_only.close()
	check(runtime.accepted_world(data(client,[controlled,remote])).available,"Actual World/AreaStream/EffectWorld boundary binds the scene visibility runtime")
	var initial:=runtime.snapshot()
	check(initial.tiles==[1,0,0,0] and initial.pending==0 and initial.stats.accepted_events==1,"Ordered native tile setter runs only after canonical world publication")
	check(member(initial,1).id==1 and member(initial,2).id==2 and not member(initial,2).instance_present,"Server-known unloaded actors participate before visual preparation finishes")
	check(not initial.fog_available and initial.issues.has("native-draw-collected-tile-owner-unavailable/fog-kept-at-default1"),"Missing draw collector is explicit and cannot turn world tiles permanently black")
	check(first.instance_ready.is_connected(runtime._ready_signal) and first.terrain.tile_published.is_connected(runtime._tile_signal),"Runtime binds actual existing World and AreaStream publication signals")
	var physical:=actor(client,2);first.instance_ready.emit(2,remote,physical)
	check(member(runtime.snapshot(),2).instance_present and runtime.snapshot().stats.model_publications==1,"Actual ActorInstance adopts retained native opacity at its existing ready signal")
	var scans: int=runtime.snapshot().stats.world_scans
	var queries: int=client.native_clock_runtime.queries
	check(runtime.advance().available and client.native_clock_runtime.queries==queries+1 and runtime.snapshot().stats.world_scans==scans,"Frame advance reads supplied existing clock only and never scans world entities")
	check(not runtime.receive(tile(1,controlled)),"Duplicated sticky serial is never reapplied")
	var moved:=remote.duplicate(true);moved.replicated.position=[15.0,5.0,0.0];admit(client,moved)
	first.motion.objects[2]={"position":Vector3(15,5,0),"render":Vector3(15,5,99)}
	check(runtime.receive_movement({"kind":"movement","connection":7,"generation":3,"areaId":9,"records":[{"id":2,"changes":{"position":[15,5,0]}}]}).observed==1,"Admitted movement observes native local motion position at explicit changed-record boundary")
	check(member(runtime.snapshot(),2).position_native==[15.0,5.0,0.0],"LOS query position is separate from interpolated/predicted display render height99")
	first.instances.erase(2);first.instance_removed.emit(2)
	check(not member(runtime.snapshot(),2).is_empty(),"Pure renderer eviction does not destroy canonical entity/fade lifetime")
	first.instances[2]=physical
	var fresh:=source(2,"remote-reused",2);runtime.lifecycle(birth(2,"remote-reused"));admit(client,fresh)
	check(runtime.accepted_world(data(client,[fresh])).available and member(runtime.snapshot(),2).lifetime==Lifetime.token(fresh),"Same-ID fresh physical/lifetime replaces old presentation reference")
	check(not runtime.receive_movement({"kind":"movement","connection":6,"generation":3,"areaId":9,"records":[]}).available,"Stale connection movement cannot query current entity presentation")
	var permission:={"kind":"raw-creature-visibility-permission","connection":7,"generation":3,"areaId":9,"actorId":1,"lifetime":Lifetime.token(controlled),"serial":1,"permission":false,"field114":true,"recipientOwner":controlled.nativeClockOwner}
	check(runtime.receive(permission) and runtime.snapshot().pending==0,"Fresh connection permission applies independently of coalesced world/map queue")
	check(runtime._creature_fields(1,Lifetime.token(controlled)).creature114==1,"Native permission applies to exact captured physical controlled cache")
	var next:=world(client,10,4);var transferred:=source(1,"controlled",3,10);runtime.lifecycle(birth(1,"controlled","retained",false));admit(client,transferred)
	check(runtime.receive(tile(2,transferred,4,10)) and runtime.accepted_world(data(client,[transferred])).available,"Area transition rebinds scope before draining future-generation events")
	check(not first.instance_ready.is_connected(runtime._ready_signal) and next.instance_ready.is_connected(runtime._ready_signal),"Old world signals are disconnected and cannot publish into successor scope")
	check(runtime._creature_fields(1,Lifetime.token(transferred)).creature114==1,"Certified retained physical local fields survive transitions without constructor resets")
	permission.serial=2;permission.field114=false
	check(runtime.receive(permission) and runtime._creature_fields(1,Lifetime.token(transferred)).creature114==0,"Prior-area permission still updates global state and only its retained original physical recipient")
	check(runtime.receive(tile(3,controlled,3,9)) and runtime.accepted_world(data(client,[])).available and runtime.snapshot().pending==0 and runtime.snapshot().stats.retired_events==1,"Late old-area raw tile event retires without touching new native map")
	var cold:=runtime.snapshot();cold.tiles[0]=99;cold.scope.area_id=99
	check(runtime.snapshot().tiles[0]==1 and runtime.snapshot().scope.area_id==10,"Diagnostics cannot mutate native tile states or active scope")
	runtime.cleanup_connection();client.session_connection=8
	check(runtime.snapshot().references==0 and runtime.snapshot().tile_count==0 and not runtime.receive(tile(4,transferred,4,10)),"Reconnect clears references/maps/queues and fences previous connection events")
	check(not runtime._creature_fields(1,Lifetime.token(transferred)).available,"Reconnect never transfers prior account's local physical fields")
	runtime.close();check(runtime.snapshot().closed and not next.instance_ready.is_connected(runtime._ready_signal),"Close disconnects borrowed owners and releases runtime callback cycles")
	var prearea:=Runtime.new();prearea.configure(client)
	check(prearea.receive({"kind":"raw-creature-visibility-permission","connection":8,"generation":0,"areaId":0x7f000000,"actorId":null,"lifetime":null,"serial":1,"permission":true,"field114":false,"recipientOwner":null}) and prearea.snapshot().fields.permission==true and prearea.snapshot().pending==0,"Null-recipient pre-area permission does not wait for a renderer/bridge to exist")
	prearea.close()
	physical.retire();release_world(first);release_world(next);client.world=null;client.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual World/AreaStream/EffectWorld/Actor owners with authored admitted lifecycle/transport, passive client/UI holders and explicit fixture clock callback. Ordered raw-world-end, unloaded entities, native position versus render height, scoped retirement/reconnect and no-frame-scan checks. No live server, actual transport SessionWorld, missing shadowblob/drawcollector or native-clock acceptance claim."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_SCENE_VISIBILITY_RUNTIME ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
