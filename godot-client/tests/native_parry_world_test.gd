extends "res://tests/native_projectile_lifetime_test.gd"
const Parry=preload("res://systems/native_data/parry_visual.gd")
const Motion=preload("res://systems/network_motion.gd")
class ParryWorld extends World:
	var combat
	var motion:=Motion.new()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original parry resources mount read-only")
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	world.set_meta("native_particle_collision",func(_start,_end,_out,_hit):return false) # Explicit no-geometry component boundary.
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world)
	check(await wait_for(func():return owner.tables.size()==3 and owner.ensure_models({"c_ydrowiz":true})),"Active native effect tables and original actor prepare")
	var actors: Array=[]
	for id in [world.controlled_id,0x80000002]:
		var model=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(model)
		check(model.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,id,{}),"Original actor physical model installs "+str(id))
		world.instances[id]=model; actors.append(model); model.position=Vector3(1,3,-2) if id==world.controlled_id else Vector3(5,2,-8)
		world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":1},"replicated":{"position":[model.position.x,-model.position.z,model.position.y],"facingTarget":0x80000002,"orientation":[0.6,0.8,0.0]}}}; world.installed[id]="one"
		world.motion.objects[id]={"orientation":Vector3(0.6,0.8,0.0)}
	var canonical:=JSON.stringify(world.desired); var parries=owner.parries
	world.combat.engine.event("parry",world.controlled_id,{"targetId":123,"record":{"targetId":123}}) # Deliberately different from facingTarget.
	check(parries.queue.size()==1,"Actual combat presentation signal reaches the native parry owner")
	parries.advance(); check(parries.stats.spawned==1 and parries.stats.failed==0,"Native original placement reserves one independent area effect")
	var event: Dictionary=parries.history.back(); var effect:=int(event.effect); var descriptor: Dictionary=owner.records[effect]
	check(descriptor.area and int(owner.entries[effect].visual)==118 and int(owner.client_dummies.entries[descriptor.actor].object.objectType)==11 and not world.desired.has(int(descriptor.actor)),"Parry visual has a private type11 owner and original row118")
	check(JSON.stringify(world.desired)==canonical and parries.history[0].target==0x80000002,"Facing target and canonical gameplay remain unchanged")
	check(await wait_for(func():return owner.entries.has(effect) and owner.entries[effect].runtime!=null),"Actual original spark resource prepares through native workers")
	var runtime=owner.entries[effect].runtime; var model=runtime.state.model
	check(is_instance_valid(model) and model.rigs.entities[0].models[0].clip=="impact" and model.anchor_node==null,"Original spark impact clip runs as a location effect rather than a creature attachment")
	check(model.find_children("*","Node",true,false).filter(func(node):return node.has_method("detonate")).all(func(node):return node.failure.is_empty()),"Original spark emitters accept the explicit component scene service")
	check(model.global_position.distance_to(Vector3(event.position[0],event.position[2],-event.position[1]))<0.0001,"Original spark model draws at computed native placement")
	var source_entry: Dictionary=world.desired[world.controlled_id]; world.desired.erase(world.controlled_id); world.instances.erase(world.controlled_id)
	owner.advance(0.001)
	check(owner.entries.has(effect) and is_instance_valid(model) and model.anchor_node==null,"Already-created area spark survives source removal independently")
	world.desired[world.controlled_id]=source_entry; world.instances[world.controlled_id]=actors[0]
	var held: WeakRef=weakref(model)
	check(await wait_for(func():return not owner.entries.has(effect)),"Original area animation/retirement timer finishes the spark")
	model=null; runtime=null; await settle_retirement()
	check(held.get_ref()==null and not owner.client_dummies.entries.has(int(descriptor.actor)),"Spark retirement releases real model, area owner and callbacks")
	world.desired[world.controlled_id].object.replicated.facingTarget=0x7f000000
	check(parries.receive(world.controlled_id)==0 and parries.queue.is_empty() and parries.stats.suppressed==1,"Missing facing target does not substitute the last combat target")
	world.desired[world.controlled_id].object.replicated.facingTarget=0x80000002
	parries.receive(world.controlled_id); world.desired[world.controlled_id].object.nativeLifetime=2; parries.advance()
	check(parries.stats.stale==1 and parries.queue.is_empty() and parries.stats.spawned==1,"Deferred spark rejects a replaced canonical actor")
	parries.receive(world.controlled_id); world.desired[0x80000002].object.nativeLifetime=2; parries.advance()
	check(parries.stats.stale==2 and parries.stats.spawned==1,"Deferred spark rejects a replaced facing target")
	var replacement=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(replacement); actors.append(replacement)
	check(replacement.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Actual replacement source rig installs under the same canonical ID")
	parries.receive(world.controlled_id); world.instances[world.controlled_id]=replacement; parries.advance()
	check(parries.stats.stale==3 and parries.stats.spawned==1,"Deferred spark rejects physical source model replacement")
	parries.receive(world.controlled_id); var before: int=owner.entries.size(); owner.close(); parries.advance(); await settle_retirement()
	check(parries.queue.is_empty() and parries.manager==null and owner.entries.is_empty() and owner.client_dummies.entries.is_empty() and before==0,"World close cancels pending local spark preparation without resurrection")
	var snapshot: Dictionary=parries.snapshot(); world.combat.close(); world.instances.clear(); world.desired.clear()
	for actor in actors: actor.retire()
	await settle_retirement(); actors.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"parries":snapshot,"scope":"Actual original actors/physical impact, combat signal, private type11 row118 original spark clip/placement/retirement and stale actor/target/world rejection under authored state; real server/pixel acceptance is separate."},"\t")); file.close()
	print("NATIVE_PARRY_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
