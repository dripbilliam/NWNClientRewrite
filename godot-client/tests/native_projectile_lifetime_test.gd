extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
class World extends Node3D:
	var catalog
	var generation:=1
	var area_id:=1
	var cache_path:=""
	var controlled_id:=0x80000001
	var minutes_per_hour:=5
	var instances: Dictionary={}
	var desired: Dictionary={}
	var installed: Dictionary={}
	var pool:=Pool.new()
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func packet(target: int=0x80000002,target_lifetime: int=1) -> Dictionary:
	return {"kind":"projectile","id":target,"lifetime":target_lifetime,"sourceLifetime":1,"message":{"kind":"safe-projectile","header":{"sourceId":0x80000001,"targetId":target,"from":[0,0,0],"to":[3,0,0],"duration":3000,"appearance":6,"spellId":58,"path":null,"baseItem":255,"result":0}}}
func wait_for(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func settle_retirement() -> void:
	await process_frame
	await process_frame
	# Dummy rendering has no draw signal. Node/model retirement is still
	# observable headlessly; graphical runs also wait for GPU submission.
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original resources mount read-only")
	var world:=World.new(); world.catalog=catalog; world.pool.picking=false; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var projectiles=owner.projectiles
	check(await wait_for(func():return not projectiles.table.is_empty() and owner.ensure_models({"c_dummy":true,"vpr_fireball":true})),"Original native projectile/dummy resources and active spell table prepare")
	if owner.bundles.has("c_dummy"):
		for id in [0x80000001,0x80000002]:
			var model=owner.create_model(id,"c_dummy"); world.instances[id]=model; model.position=Vector3(0 if id==world.controlled_id else 3,0,0)
			world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":201},"replicated":{"position":[model.position.x,0,0]}}}; world.installed[id]="one"
		projectiles.receive(packet()); check(await wait_for(func():return not projectiles.active.is_empty()),"Authored delivery creates an actual native projectile owner")
		if not projectiles.active.is_empty():
			var s: Dictionary=projectiles.active.values()[0]; var id:=int(s.id); var weak: WeakRef=weakref(s.model)
			world.desired[0x80000002].object.nativeLifetime=2; await process_frame; await process_frame
			check(projectiles.active.is_empty() and projectiles.stats.stale==1 and not owner.client_dummies.entries.has(id) and weak.get_ref()==null,"Reused canonical target retires the projectile/model instead of attaching to its replacement")
		var spawned: int=projectiles.stats.spawned; projectiles.receive(packet()); await process_frame
		check(projectiles.stats.spawned==spawned and projectiles.stats.stale==2,"Deferred stale header cannot start against a replacement target")
		world.desired[0x80000002].object.nativeLifetime=1
		var retired: int=projectiles.stats.retired; projectiles.receive(packet()); projectiles.queue[-1].received-=4000
		check(await wait_for(func():return projectiles.stats.retired>retired),"Deferred preparation consumes original travel time instead of restarting its clock")
		check(projectiles.history.any(func(row):return row.kind=="ready" and int(row.get("preparationMs",0))>=4000) and projectiles.active.is_empty(),"Already-expired travel reaches impact and retires without a fresh full flight")
		projectiles.receive(packet(0x80000003,0))
		world.desired[0x80000003]={"key":"late","object":{"id":0x80000003,"objectType":5,"nativeLifetime":2,"replicated":{"position":[9,0,0]}}}
		check(await wait_for(func():return not projectiles.active.is_empty()),"Missing-target delivery creates the original native c_dummy and projectile")
		if not projectiles.active.is_empty():
			var s: Dictionary=projectiles.active.values()[0]; var target_id:=int(s.targetId)
			check(target_id<0x7f000000 and target_id!=0x80000003 and int(owner.client_dummies.entries[target_id].state.duration)==3500 and not world.desired.has(target_id),"Late canonical target cannot replace the private host, which expires at travel plus 500ms")
		var active_refs: Array=projectiles.active.values().map(func(s):return weakref(s.model)); owner.close(); await process_frame; await process_frame
		check(projectiles.active.is_empty() and projectiles.queue.is_empty() and projectiles.p.is_empty() and owner.client_dummies.entries.is_empty() and owner.models.is_empty() and active_refs.all(func(ref):return ref.get_ref()==null),"World close releases native projectiles, targets, models and provider cycles")
		projectiles.receive(packet()); check(projectiles.queue.is_empty(),"Retired world cannot queue another projectile")
	else: owner.close()
	world.instances.clear(); world.desired.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native asset/effect/projectile/dummy owners under authored headers: reused target, deferred stale event, missing-target allocation and teardown; no server outcome is synthesized"},"\t")); file.close()
	print("NATIVE_PROJECTILE_LIFETIME ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
