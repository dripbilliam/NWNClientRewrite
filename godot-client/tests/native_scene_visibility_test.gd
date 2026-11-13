extends SceneTree
const SceneVisibility = preload("res://systems/native_render/native_scene_visibility.gd")
const Query = preload("res://systems/native_data/native_tile_query.gd")
const Alpha = preload("res://tools/native_parity/visibility/alpha_program.gd")
const Lifetime = preload("res://systems/native_data/entity_presentation_lifetime.gd")
class TestWorld extends Node:
	var desired: Dictionary = {}
class TestActor extends Node3D:
	var retired := false
var checks := 0
var failures: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 24: failures.append(label)
func _initialize() -> void: call_deferred("run")
func source(id: int, kind: int, life: int = 1) -> Dictionary:
	return {"id":id,"objectType":kind,"nativeLifetime":life,"disclosureLifetime":1,"areaId":7,"replicated":{}}
func entry(snapshot: Dictionary, id: int) -> Dictionary:
	for row in snapshot.members:
		if row.id == id: return row
	return {}
func run() -> void:
	var report_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
	var bypass := Query.read(0,null,null,null,null)
	check(bypass.available and bypass.revealed, "known area flags bypass unused missing grid/position")
	check(not Query.read(null,2,2,[0,0,0,0],[5,5,0]).available, "unknown area flag unavailable")
	check(not Query.read(1,2,2,[0,null,0,0],[15,5,0]).available, "missing current tile not fabricated0")
	check(Query.read(1,2,2,[0,null,0,0],[5,5,0]).available, "unread unrelated tile can remain unknown")
	check(Query.read(1,2,2,[0,1,0,0],[10,10,0]).revealed == false, "X seam priority over visible Y neighbor")
	check(Query.read(1,2,2,[0,0,1,0],[10,10,0]).revealed, "selected X seam neighbor reveals")
	check(not Query.read(1,2,2,[0,0,0,0],[-0.1,5,0]).revealed, "native truncation toward0, not floor")
	check(Query.read(1,2,2,[0,0,0,0],[-11,5,0]).revealed, "invalid current tile native bypass")
	check(not Query.read(1,2,2,[0,0,0,0],[NAN,5,0]).available, "nonfinite XY unavailable")
	check(Query.read(1,2,2,[1,null,0,0],[9.99995,5,0]).revealed, "known revealed current does not read unknown neighbor")
	var world := TestWorld.new()
	root.add_child(world)
	var actor := TestActor.new()
	world.add_child(actor)
	var states: Array = [1,0,0,0]
	var scope := {"connection_epoch":1,"area_generation":3,"area_id":7,"controlled_id":99,"controlled_lifetime":[["nativeLifetime",true,2],["disclosureLifetime",false,null]]}
	var wire := {"kind":"raw-tile-visibility","connection":1.0,"generation":3.0,"areaId":7.0,"actorId":99.0,"lifetime":[["nativeLifetime",true,2.0],["disclosureLifetime",false,null]],"serial":1.0,"change":{"mode":[true,false],"points":[{"x":0.0,"y":0.0}]}}
	check(SceneVisibility.wire_scope(wire) == scope,"exact host frame scope normalizes JSON finite integer fields and full lifetime")
	var normalized := SceneVisibility.wire_scope(wire)
	normalized.controlled_lifetime[0][2] = 999
	check(wire.lifetime[0][2] == 2,"wire lifetime is detached")
	var missing_wire := wire.duplicate(true)
	missing_wire.lifetime[0] = ["nativeLifetime",false,null]
	check(SceneVisibility.wire_scope(missing_wire).is_empty(),"missing native lifetime explicit unavailable, not lifetime0")
	missing_wire = wire.duplicate(true)
	missing_wire.lifetime[1] = ["disclosureLifetime",false,0]
	check(SceneVisibility.wire_scope(missing_wire).is_empty(),"absent lifetime must carry null, not invented0")
	missing_wire = wire.duplicate(true)
	missing_wire.connection = "1"
	check(SceneVisibility.wire_scope(missing_wire).is_empty(),"wire numeric connection never coerces strings")
	var live := {"current":true,"target_ready":true,"target_queries":0}
	var publications: Array = []
	var fogs: Array = []
	var owner := SceneVisibility.new()
	var callbacks := {
		"scope_current":func(_scope: Dictionary) -> bool:return live.current,
		"tile_center":func(_index: int,x: int,y: int) -> Array:return [float(x * 10 + 5),float(y * 10 + 5)],
		"target_alpha":func(_id: int,_lifetime: Array,revealed: int) -> Dictionary:
			live.target_queries += 1
			return {"available":true,"alpha_word":Alpha.ONE_WORD if revealed != 0 else 0} if live.target_ready else {"available":false},
		"publish":func(id: int,lifetime: Array,command: Dictionary) -> bool:
			publications.append({"id":id,"lifetime":lifetime,"command":command,"tiles":states.duplicate(),"fade_at_callback":entry(owner.snapshot(),id).get("fade")})
			return true,
		"tile_fog":func(event: Dictionary) -> bool:fogs.append({"event":event,"tiles":states.duplicate()});return true,
	}
	check(owner.configure(world,scope,{"width":2,"height":2,"flags":1,"states":states},callbacks).available, "configure exact scope/canonical array/callbacks")
	var object := source(11,9)
	world.desired[11] = {"object":object}
	check(owner.observe_object(object,[5,5,2],actor,"create").available, "noncreature original area assignment")
	var row := entry(owner.snapshot(),11)
	check(row.fade.status == 0 and row.fade.desired == 1 and row.fade.opacity_word == 0, "visible placeable immediate0 then target1 native entry")
	check(publications.size() == 3 and publications[0].command.setter == "immediate765c80" and publications[2].command.setter == "target765920", "entry hook and alpha order")
	check(publications[0].fade_at_callback.status == 0 and publications[0].fade_at_callback.desired == 1,"native immediate status store before hooks, desired store afterward")
	owner.advance({"snapshot_us":200000})
	row = entry(owner.snapshot(),11)
	check(row.fade.status == 2 and row.fade.opacity_word == Alpha.word(0.1), "existing clock drives native fade step")
	var before_notifications: int = owner.stats.object_notifications
	var raw := {"scope":scope,"serial":1,"change":{"mode":[1,0],"points":[{"x":0,"y":0}]}}
	check(owner.receive_wire(wire).accepted, "exact fresh host wire full replacement accepted")
	check(states == [1,0,0,0] and owner.stats.object_notifications == before_notifications + 1, "full hide/list reveal not lost to final-map equality")
	check(publications[-1].tiles[0] == 0 and fogs[-1].tiles[0] == 0, "object/fog callbacks both before canonical tile store")
	check(not owner.receive(raw).accepted and owner.stats.stale_events == 1, "same raw serial not replayed")
	check(wire.change == {"mode":[true,false],"points":[{"x":0.0,"y":0.0}]} and wire.lifetime[0][2] == 2,"raw transport payload and lifetime remain unmodified")
	var changed_control := wire.duplicate(true)
	changed_control.lifetime[1] = ["disclosureLifetime",true,0]
	changed_control.serial = 2
	check(not owner.receive_wire(changed_control).accepted and owner.snapshot().last_serial == 1,"controlled disclosure lifetime acquisition retires prior scope without consuming event")
	var wrong_scope := scope.duplicate()
	wrong_scope.area_generation = 4
	check(not owner.receive({"scope":wrong_scope,"serial":2,"change":{"mode":[1,0],"points":[]}}).accepted and owner.snapshot().last_serial == 1, "future area event not consumed")
	check(not owner.receive({"scope":scope,"serial":2,"change":{"mode":[0,0],"points":[{"x":0,"y":0}]}}).available and owner.snapshot().last_serial == 1, "malformed event not consumed")
	var creature := source(12,5)
	world.desired[12] = {"object":creature}
	check(owner.observe_object(creature,[15,5,0],null,"create").available, "client-known actor participates before visual install")
	row = entry(owner.snapshot(),12)
	check(row.prior_query230 == 0 and row.fade.status == 0 and row.fade.opacity_word == 0 and not row.instance_present, "creature prior230=1 change uses immediate0 then stores query0")
	check(owner.receive({"scope":scope,"serial":2,"change":{"mode":[0,0],"points":[{"state":1,"x":1,"y":0}]}}).accepted, "raw tile reveal for unloaded actor")
	row = entry(owner.snapshot(),12)
	check(row.fade.desired == 1 and row.fade.status == 0, "tile notifications use target setter only")
	check(owner.observe_object(creature,[15,5,0],null,"position").available, "existing creature position boundary")
	row = entry(owner.snapshot(),12)
	check(row.prior_query230 == 1 and row.fade.status == 1 and row.fade.opacity_word == Alpha.ONE_WORD, "movement transition dispatches from prior230 then stores new value")
	var known_before: int = owner.snapshot().members.size()
	var static_object := source(13,9)
	static_object.staticState = {"appearance":1}
	world.desired[13] = {"object":static_object}
	check(not owner.observe_object(static_object,[5,5,0],null,"create").accepted and owner.snapshot().members.size() == known_before, "ClientArea static geometry is not ordinary CNWC object")
	var item := source(14,6)
	world.desired[14] = {"object":item}
	owner.observe_object(item,[5,5,1],null,"area-entry")
	row = entry(owner.snapshot(),14)
	check(row.fade.status == 1 and row.fade.desired == 1 and row.fade.opacity_word == Alpha.ONE_WORD, "visible native item entry immediate1")
	var deferred := source(15,9)
	world.desired[15] = {"object":deferred}
	live.target_ready = false
	owner.observe_object(deferred,[5,5,1],null,"create")
	check(entry(owner.snapshot(),15).fade.opacity_word == null, "missing target is explicit null, not invented alpha0")
	live.target_ready = true
	owner.advance({"snapshot_us":200000})
	check(entry(owner.snapshot(),15).fade.opacity_word == Alpha.word(0.1), "deferred immediate target resolves before existing fade clock")
	var gated := source(16,9)
	world.desired[16] = {"object":gated}
	owner.observe_object(gated,[5,5,1],null,"create")
	var gated_before: Dictionary = entry(owner.snapshot(),16).fade
	check(owner.set_native_gates(16,Lifetime.token(gated),1,0).available,"native setter gate admitted with exact lifetime")
	var count_before := publications.size()
	owner.observe_object(gated,[5,5,1],null,"mode")
	check(publications.size() == count_before and entry(owner.snapshot(),16).fade == gated_before,"native104==1 skips immediate and target setters")
	check(not owner.set_native_gates(16,Lifetime.token(gated),"0",0).available,"native gate fields never coerce strings")
	owner.remove(16,Lifetime.token(gated))
	var replacement := source(11,9,2)
	world.desired[11] = {"object":replacement}
	owner.observe_object(replacement,[5,5,2],actor,"create")
	check(not owner.remove(11,Lifetime.token(object)).accepted and entry(owner.snapshot(),11).lifetime == Lifetime.token(replacement), "stale removal cannot retire reused ID")
	check(not owner.observe_object(object,[15,5,2],null,"position").available and entry(owner.snapshot(),11).lifetime == Lifetime.token(replacement) and entry(owner.snapshot(),11).position_native == [5.0,5.0,2.0],"stale observation cannot retire or move reused full-ID member")
	check(owner.bind_instance(12,Lifetime.token(creature),actor).available, "late visual receives retained actor alpha")
	var detached := owner.snapshot()
	detached.members[0].fade.opacity_word = 123
	detached.members[0].position_native[0] = 999
	check(entry(owner.snapshot(),11).fade.opacity_word == 0 and entry(owner.snapshot(),11).position_native[0] == 5, "cold snapshot detached from state/index")
	actor.free()
	check(not entry(owner.snapshot(),11).instance_present and not entry(owner.snapshot(),12).instance_present, "freed weak visuals not retained/replaced")
	live.current = false
	check(not owner.receive({"scope":scope,"serial":3,"change":{"mode":[1,0],"points":[]}}).available, "retired connection cannot publish")
	owner.close()
	check(states == [1,1,0,0] and owner.snapshot().members.is_empty(), "close clears only private state, not canonical tiles")
	live.current = true
	check(owner.configure(world,scope,{"width":2,"height":2,"flags":1,"states":states},callbacks).available and owner.snapshot().last_serial == -1,"closed owner can configure fresh lifecycle with reset delivery serial")
	var close_callbacks := callbacks.duplicate()
	close_callbacks.target_alpha = func(_id: int,_lifetime: Array,_revealed: int) -> Dictionary:
		owner.close()
		return {"available":true,"alpha_word":Alpha.ONE_WORD}
	owner.close()
	owner.configure(world,scope,{"width":2,"height":2,"flags":1,"states":states},close_callbacks)
	check(not owner.observe_object(replacement,[5,5,2],null,"create").available and owner.snapshot().members.is_empty(),"target callback closing scope cannot republish or resurrect old member")
	world.free()
	var report := {"checks":checks,"failures":failures,"scope":"Boundary-driven Godot scene visibility integration with fake canonical owner/publication callbacks; pure native query, no game assets/server/GPU or actual renderer lifecycle claim"}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
