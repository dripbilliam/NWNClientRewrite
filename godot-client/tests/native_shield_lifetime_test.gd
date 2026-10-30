extends "res://tests/native_ranged_lifetime_test.gd"
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
func block_packet() -> Dictionary:
	var value:=ranged_packet(); value.message.header.result=2; value.message.header.duration=40; return value
func embedded(projectiles) -> bool:
	return projectiles.active.values().any(func(s):return int(s.phase)==1 and int(s.result)==2 and is_instance_valid(s.model.anchor_node))
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original shield assets mount read-only")
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var projectiles=owner.projectiles
	check(await wait_for(func():return projectiles.ranged_tables.size()==2 and owner.tables.has("appearance") and owner.ensure_models({"c_ydrowiz":true,"ashsw_011":true,"wamar_001":true})),"Active ranged tables, original actor/shield/arrow prepare through native workers")
	var table: Dictionary=projectiles.ranged_tables.baseitems
	check(int(Query.query(table,14,"WeaponType","integer").value)==0 and int(Query.query(table,14,"WeaponWield","integer").value)==7,"Original shield has different damage-type and wield fields; byte8 selector must use WeaponWield")
	var actors: Array=[]
	for id in [0x80000001,0x80000002]:
		var model:=Actor.new(); world.add_child(model); var pieces: Array=[{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}]
		if id==0x80000002: pieces.append({"bundle":owner.bundles.ashsw_011,"anchor":"lhand","attachment":"pq","equipmentSlot":32,"follow":true})
		check(model.install(pieces,world.pool,id,{}),"Actual original actor and held shield install "+str(id)+" "+model.failure); actors.append(model); world.instances[id]=model; model.position=Vector3(0 if id==world.controlled_id else 3,0,0)
		var equipment: Array=[] if id==world.controlled_id else [{"slot":32,"id":0x80000077,"item":{"baseItem":14}}]
		world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":1,"equipment":equipment},"replicated":{"position":[model.position.x,0,0]}}}; world.installed[id]="one"
	var target=world.instances[0x80000002]; var parts: Array=[target.equipment_part(32,"imp_shield_1"),target.equipment_part(32,"imp_shield_2")]
	check(parts.all(func(part):return is_instance_valid(part)),"Both original physical shield impact Parts exist on the equipped item")
	projectiles.receive(block_packet()); check(await wait_for(func():return embedded(projectiles)),"Native block receiver attaches an actual original arrow")
	if embedded(projectiles):
		var s: Dictionary=projectiles.active.values()[0]; var arrow=s.model; var weak: WeakRef=weakref(arrow)
		check(parts.has(arrow.anchor_node) and arrow.anchor_flags==0 and int(s.rangedEffect)==0 and projectiles.tracking.is_empty() and int(s.impactDuration)==8000,"Shield Part attachment uses original flags/duration and avoids body-hit blood/tracking")
		target.position+=Vector3(1,0.25,2); target.rotation.y=0.7; await process_frame; await process_frame
		check(arrow.global_position.distance_to(arrow.anchor_node.global_position)<0.0001 and arrow.global_basis.orthonormalized().get_rotation_quaternion().is_equal_approx(arrow.anchor_node.global_basis.orthonormalized().get_rotation_quaternion()),"Original shield embedding follows the actual item's position and orientation")
		s.lastTime.time-=8001; projectiles.advance(0); arrow=null; await settle_retirement()
		check(projectiles.active.is_empty() and weak.get_ref()==null and owner.models.is_empty(),"Original impact countdown releases the real arrow and private owner")
	var before: int=projectiles.stats.spawned; var stale: int=projectiles.stats.stale
	projectiles.receive(block_packet()); world.desired[0x80000002].object.nativeLifetime=2
	check(await wait_for(func():return projectiles.queue.is_empty()),"Deferred shield header is consumed")
	check(projectiles.stats.spawned==before and projectiles.stats.stale==stale+1,"Deferred block cannot bind to a replaced canonical shield owner")
	world.desired[0x80000002].object.nativeLifetime=1; projectiles.receive(block_packet())
	check(await wait_for(func():return embedded(projectiles)),"A new valid block owns another actual arrow")
	var live_refs: Array=projectiles.active.values().map(func(s):return weakref(s.model)); world.desired[0x80000002].object.nativeLifetime=2; await settle_retirement()
	check(projectiles.active.is_empty() and live_refs.all(func(ref):return ref.get_ref()==null),"Live canonical owner reuse retires shield arrows without rebinding")
	world.desired[0x80000002].object.nativeLifetime=1; projectiles.receive(block_packet()); owner.close(); await settle_retirement()
	check(projectiles.queue.is_empty() and projectiles.active.is_empty() and projectiles.impact_providers.is_empty() and owner.models.is_empty() and owner.client_dummies.entries.is_empty(),"World closure discards pending shield work and releases native ownership")
	var stats: Dictionary=projectiles.stats.duplicate(); world.instances.clear(); world.desired.clear()
	for actor in actors: actor.retire()
	await settle_retirement(); actors.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"projectiles":stats,"scope":"Actual original actor/shield/arrow and active original tables under authored block fields: correct WeaponWield, held-item Parts, pose following, original expiry, deferred/live canonical reuse and world cleanup. Real server outcomes/pixels are separate; unequip/physical-host removal native attachment semantics remain open."},"\t")); file.close()
	print("NATIVE_SHIELD_LIFETIME ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
