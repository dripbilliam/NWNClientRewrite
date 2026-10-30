extends "res://tests/native_projectile_lifetime_test.gd"
func ranged_packet(lifetime: int=1) -> Dictionary:
	return {"kind":"projectile","id":0x80000002,"lifetime":lifetime,"sourceLifetime":1,"message":{"kind":"safe-projectile","header":{"sourceId":0x80000001,"targetId":0x80000002,"from":[0,0,0],"to":[3,0,0],"duration":2000,"appearance":0,"spellId":0,"path":2,"baseItem":8,"result":1}}}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original resources mount read-only")
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var projectiles=owner.projectiles
	check(await wait_for(func():return projectiles.ranged_tables.size()==2 and owner.tables.has("appearance") and owner.ensure_models({"c_dummy":true,"wamar_001":true})),"Active ranged tables and original models prepare through native workers")
	for id in [0x80000001,0x80000002]:
		var model=owner.create_model(id,"c_dummy"); world.instances[id]=model; model.position=Vector3(0 if id==world.controlled_id else 3,0,0)
		world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":201},"replicated":{"position":[model.position.x,0,0]}}}; world.installed[id]="one"
	projectiles.receive(ranged_packet())
	check(await wait_for(func():return not projectiles.active.is_empty()),"Authored ranged header admits actual native original arrow")
	if not projectiles.active.is_empty():
		var s: Dictionary=projectiles.active.values()[0]; var id:=int(s.id); var weak: WeakRef=weakref(s.model)
		check(s.get("ranged",false) and projectiles.tracking.get(0x80000002,[]).has(id) and not world.desired.has(id),"Hit projectile tracking stays private to the native target")
		world.desired.erase(0x80000002); await settle_retirement()
		check(projectiles.active.is_empty() and projectiles.tracking.is_empty() and not owner.client_dummies.entries.has(id) and weak.get_ref()==null,"Removed target releases actual arrow, private allocation and tracking")
	world.desired[0x80000002]={"key":"two","object":{"id":0x80000002,"objectType":5,"nativeLifetime":2,"appearance":{"appearance":201},"replicated":{"position":[3,0,0]}}}
	var spawned: int=projectiles.stats.spawned; var stale: int=projectiles.stats.stale; projectiles.receive(ranged_packet())
	check(await wait_for(func():return projectiles.queue.is_empty() and projectiles.stats.spawned==spawned and projectiles.stats.stale==stale+1),"Deferred old header cannot attach to a reused canonical target")
	world.desired[0x80000002].object.nativeLifetime=1; projectiles.receive(ranged_packet())
	check(await wait_for(func():return not projectiles.active.is_empty()),"Fresh header admits after target identity restoration")
	if not projectiles.active.is_empty():
		var s: Dictionary=projectiles.active.values()[0]; var weak: WeakRef=weakref(s.model); world.desired[0x80000002].object.nativeLifetime=2
		await settle_retirement()
		check(projectiles.active.is_empty() and projectiles.tracking.is_empty() and weak.get_ref()==null,"Live target identity reuse retires the original ranged owner")
	world.desired[0x80000002].object.nativeLifetime=1; projectiles.receive(ranged_packet())
	check(await wait_for(func():return not projectiles.active.is_empty()),"Live ranged owner exists before world retirement")
	var refs: Array=projectiles.active.values().map(func(s):return weakref(s.model)); owner.close(); await settle_retirement()
	check(projectiles.active.is_empty() and projectiles.queue.is_empty() and projectiles.tracking.is_empty() and projectiles.p.is_empty() and projectiles.impact_providers.is_empty() and owner.client_dummies.entries.is_empty() and owner.models.is_empty() and refs.all(func(ref):return ref.get_ref()==null),"World close releases ranged models, trackers, allocations and provider cycles")
	projectiles.receive(ranged_packet()); check(projectiles.queue.is_empty(),"Retired ranged world cannot accept later headers")
	world.instances.clear(); world.desired.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual original arrow and native worker/projectile owners under authored ranged headers: target removal, deferred/live target reuse and world cleanup. Does not synthesize or accept server combat outcomes."},"\t")); file.close()
	print("NATIVE_RANGED_LIFETIME ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
