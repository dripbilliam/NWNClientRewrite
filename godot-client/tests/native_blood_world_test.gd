extends "res://tests/native_projectile_lifetime_test.gd"
const Query=preload("res://systems/native_data/visual_definition.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original blood resources mount read-only")
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	# Explicit no-geometry scene boundary in this component test. The real
	# localhost acceptance uses live_world's original static-face scene trace.
	world.set_meta("native_particle_collision",func(_start,_end,_out,_hit):return false)
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world)
	check(await wait_for(func():return owner.tables.has("appearance") and owner.tables.has("visualeffects") and owner.projectiles.ranged_tables.has("baseitems") and owner.blood.prepare_hp_defaults() and owner.ensure_models({"c_ydrowiz":true})),"Active original tables, private client constructor and actual native actor prepare")
	var model=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(model)
	check(model.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Actual actor installs with canonical ID and physical body Parts")
	world.instances[world.controlled_id]=model
	var appearance:=1
	check(str(Query.query(owner.tables.appearance,appearance,"BLOODCOLR","string").value)=="R","Original selected appearance has red blood")
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":appearance},"replicated":{"position":[0,0,0],"orientation":[1,0,0],"animation":0,"hitPoints":{"maximum":100}}}
	world.desired[world.controlled_id]={"key":"one","object":object}; world.installed[world.controlled_id]="one"
	var blood=owner.blood; var record:={"result":1,"damage":1,"attackType":0,"killingBlow":0,"weaponAttackType":1}
	for i in 4: blood.receive(world.controlled_id,record,[1,0,0],"impact")
	blood.advance()
	check(blood.owners.size()==1 and blood.owners[world.controlled_id].slots.all(func(entry):return entry!=null) and blood.stats.full_slots==1,"Four concurrent hits reserve exactly three physical slots")
	check(await wait_for(func():return blood.stats.started==3),"All three actual original blood models prepare through native workers")
	var slots: Array=blood.owners[world.controlled_id].slots
	check(blood.stats.failed==0 and slots.all(func(entry):return entry.model.anchor_node==model.physical_part("impact") and entry.model.anchor_flags==3 and entry.model.rigs.entities[0].models[0].clip=="impact"),"Original impact clips attach to non-null physical body with independent orientation")
	check(slots.all(func(entry):return entry.model.find_children("*","Node",true,false).filter(func(node):return node.has_method("detonate")).all(func(node):return node.failure.is_empty())),"Original blood emitters accept their explicit scene collision service")
	var refs: Array=slots.map(func(entry):return weakref(entry.model)); var rotations: Array=slots.map(func(entry):return entry.model.global_basis.orthonormalized().get_rotation_quaternion())
	model.position=Vector3(3,0,2); model.rotation.y=0.7
	await process_frame; await process_frame
	check(slots.all(func(entry):return entry.model.global_position.distance_to(model.physical_part("impact").global_position)<0.0001) and slots.all(func(entry):return entry.model.global_basis.orthonormalized().get_rotation_quaternion().is_equal_approx(rotations[entry.index])),"Blood follows moving bones while retaining the original world orientation")
	check(await wait_for(func():return slots.all(func(entry):return blood.play_info(entry)==-1.0)),"Real original impact animation runs finish and disappear")
	check(blood.owners.size()==1 and refs.all(func(ref):return ref.get_ref()!=null) and blood.stats.destroyed==0,"Finished blood models remain retained until reuse or creature removal")
	for i in 2: blood.receive(world.controlled_id,record,[0,1,0],"impact")
	blood.advance(); await settle_retirement()
	check(blood.stats.reused==2 and blood.stats.started==5 and refs[0].get_ref()==null and refs[1].get_ref()==null and refs[2].get_ref()!=null,"Later hits destroy and reuse the first two finished physical slots in order")
	check(await wait_for(func():return slots.all(func(entry):return blood.play_info(entry)==-1.0)),"Prior hits finish before the undisclosed-HP unarmed case")
	object.replicated.erase("hitPoints"); var private_before:=object.duplicate(true)
	var unarmed:=record.duplicate(); unarmed.weaponAttackType=7
	blood.receive(world.controlled_id,unarmed,[1,0,0],"impact"); blood.advance()
	check(await wait_for(func():return blood.stats.started==6),"Unarmed hit on an NPC without disclosed HP prepares a real original blood model")
	var low:=int(Query.query(owner.tables.visualeffects,112,"LowViolence","integer").value)
	var expected:=str(Query.query(owner.tables.visualeffects,low,"Imp_Impact_Node","string").value).to_lower()
	check(blood.hp_defaults.maximum==1 and slots[0].resource==expected and blood.stats.failed==0,"Original private constructor selects the low-violence medium effect")
	check(object==private_before and not object.replicated.has("hitPoints"),"Undisclosed NPC HP stays absent from authoritative data")
	world.set_meta("native_gore",2); check(blood.gore()==2,"World inherits full blood selection from native Graphics preference")
	object.nativeLifetime=2; await settle_retirement()
	check(blood.owners.is_empty() and refs[2].get_ref()==null,"Canonical creature reuse destroys the old three-slot model owner")
	blood.receive(world.controlled_id,record,[1,0,0],"impact"); object.nativeLifetime=3; blood.advance()
	check(blood.owners.is_empty() and blood.queue.is_empty() and blood.stats.stale>=2,"Deferred hit cannot bind to a replacement creature lifetime")
	object.nativeField28=1; blood.receive(world.controlled_id,record,[1,0,0],"impact"); blood.advance()
	check(blood.owners.is_empty() and blood.stats.suppressed==1,"Original mode1 kind gate suppresses blood before resource allocation")
	object.nativeField28=0; blood.receive(world.controlled_id,record,[1,0,0],"impact"); blood.advance()
	check(not blood.owners.is_empty(),"Later valid hit creates a fresh private owner")
	var replacement=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(replacement)
	check(replacement.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Replacement creature installs as a new actual rig owner")
	blood.receive(world.controlled_id,record,[1,0,0],"impact"); world.instances[world.controlled_id]=replacement; blood.advance(); await settle_retirement()
	check(blood.owners.is_empty() and blood.queue.is_empty(),"Source model replacement retires existing slots and rejects a pending hit bound to the old model")
	blood.receive(world.controlled_id,record,[1,0,0],"impact"); blood.advance()
	var snapshot: Dictionary=blood.snapshot(); owner.close(); await settle_retirement()
	check(blood.manager==null and blood.queue.is_empty() and blood.owners.is_empty() and owner.models.is_empty(),"World close cancels pending blood preparation and releases every model")
	blood.receive(world.controlled_id,record,[1,0,0],"impact"); check(blood.queue.is_empty(),"Retired blood owner cannot resurrect after world closure")
	world.instances.clear(); world.desired.clear(); model.retire(); replacement.retire(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"blood":snapshot,"scope":"Actual original impact clips and physical anchors under authored hit fields: three-slot admission, follow-position/independent orientation, native animation completion, retained finished models, ordered reuse, canonical reuse and cleanup. No real server or pixel outcome here."},"\t")); file.close()
	print("NATIVE_BLOOD_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
