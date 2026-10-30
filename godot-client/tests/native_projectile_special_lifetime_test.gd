extends "res://tests/native_projectile_lifetime_test.gd"
func special_packet(base: int,path: int,result: int) -> Dictionary:
	return {"kind":"projectile","id":0x80000002,"lifetime":1,"sourceLifetime":1,"message":{"kind":"safe-projectile","header":{"sourceId":0x80000001,"targetId":0x80000002,"from":[0,0,0],"to":[3,0,0],"duration":200,"appearance":0,"spellId":0,"path":path,"baseItem":base,"result":result}}}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original special ammunition mounts read-only")
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var projectiles=owner.projectiles
	check(await wait_for(func():return projectiles.ranged_tables.size()==2 and owner.tables.has("appearance") and owner.ensure_models({"c_dummy":true,"wamar_001":true,"wambu_001":true})),"Active native tables and original projectile bundles prepare")
	for id in [0x80000001,0x80000002]:
		var model=owner.create_model(id,"c_dummy"); world.instances[id]=model; model.position=Vector3(0 if id==world.controlled_id else 3,0,0)
		world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":201},"replicated":{"position":[model.position.x,0,0]}}}; world.installed[id]="one"
	var refs: Array=[]
	for scenario in [[61,0,1,11,2],[61,0,4,12,2],[8,13,2,13,1]]:
		var spawned: int=projectiles.stats.spawned; projectiles.receive(special_packet(scenario[0],scenario[1],scenario[2]))
		check(await wait_for(func():return projectiles.stats.spawned>spawned),"Special original model admits path "+str(scenario[3]))
		var s: Dictionary=projectiles.active.values().back(); refs.append(weakref(s.model)); var landing: Array=s.nodes.back().point.duplicate()
		check(int(s.path)==scenario[3] and s.nodes.size()==scenario[4] and s.nodes.all(func(n):return int(n.kind)==2 and int(n.targetId)==0x7f000000),"Actual path owns original finite ballistic tail nodes "+str(scenario[3]))
		check(await wait_for(func():return int(s.phase)==1),"Actual original special model completes multiframe flight "+str(scenario[3]))
		check(s.position==landing and s.model.anchor_node==null and s.node==null and s.nodes.is_empty(),"Ground tail terminates exactly without embedding "+str(scenario[3]))
	check(int(projectiles.stats.failed)==0 and int(projectiles.stats.scene_queries)==5,"Special paths run all five explicit scene queries without unsupported-path drops")
	owner.close(); await settle_retirement()
	check(projectiles.active.is_empty() and projectiles.queue.is_empty() and projectiles.tracking.is_empty() and projectiles.p.is_empty() and projectiles.impact_providers.is_empty() and owner.models.is_empty() and owner.client_dummies.entries.is_empty() and refs.all(func(ref):return ref.get_ref()==null),"World close releases every special projectile/model/provider")
	world.instances.clear(); world.desired.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual original arrow/bullet native owners under authored path 11/12/13 headers, multiframe flight, empty-scene landing and teardown; real scene/server outcomes have separate live evidence"},"\t")); file.close()
	print("NATIVE_SPECIAL_PROJECTILE_LIFETIME ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
