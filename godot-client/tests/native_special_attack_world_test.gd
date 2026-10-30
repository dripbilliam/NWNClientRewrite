extends "res://tests/native_parry_world_test.gd"
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original special-attack assets mount read-only")
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new()); world.set_meta("native_particle_collision",func(_start,_end,_out,_hit):return false)
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var specials=owner.special_attacks
	check(await wait_for(func():return owner.tables.size()==3 and owner.ensure_models({"c_ydrowiz":true})),"Native tables and actual actor prepare")
	var actor=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(actor)
	check(actor.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Original actor's physical limb Parts install")
	world.instances[world.controlled_id]=actor; actor.position=Vector3(2,1,-3)
	world.desired[world.controlled_id]={"key":"one","object":{"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":1,"equipment":[]},"playerState":{"feats":[213]},"replicated":{"position":[2,3,1],"stats":{"classes":[{"id":5,"level":15}]}}}}; world.installed[world.controlled_id]="one"
	for type in [39,296,0]:
		world.combat.engine.event("weapon-start",world.controlled_id,{"animation":200,"attackType":type,"modelEvent":"blur_start"})
		var slot:=2 if type==39 else (3 if type==296 else 0)
		check(await wait_for(func():return specials.records.has(world.controlled_id) and specials.records[world.controlled_id].state.slots[slot]!=null and is_instance_valid(specials.records[world.controlled_id].state.slots[slot].model)),"Original special-attack model prepares for type"+str(type))
		var h: Dictionary=specials.records[world.controlled_id].state.slots[slot]
		if not is_instance_valid(h.model): continue
		check(h.model.anchor_node==actor.physical_part("rhand") and h.model.rigs.entities[0].models[0].clip=="impact","Actual special effect follows original rhand Part and plays impact")
		actor.position+=Vector3(0.2,0.1,-0.3); await process_frame; await process_frame
		check(h.model.global_position.distance_to(h.model.anchor_node.global_position)<0.0001,"Actual special effect consumes the current actor pose")
		var created: int=specials.stats.created
		world.combat.engine.event("weapon-start",world.controlled_id,{"animation":200,"attackType":type,"modelEvent":"blur_start"})
		check(specials.stats.created==created,"Repeated original blur_start does not allocate duplicate slots")
		world.combat.engine.event("weapon-end",world.controlled_id,{"modelEvent":"blur_end"})
		check(h.model.rigs.entities[0].models[0].clip=="cessation" and specials.handles.has(h.id),"Original cessation retains the lazy slot until owner release")
	check(specials.stats.created==4 and specials.stats.loaded==4 and specials.stats.failed==0,"All four original special-attack slots install without model/Part/clip failures")
	var references: Array=specials.handles.values().map(func(h):return weakref(h.model)); world.desired[world.controlled_id].object.nativeLifetime=2; specials.advance(); await settle_retirement()
	check(specials.records.is_empty() and specials.handles.is_empty() and references.all(func(ref):return ref.get_ref()==null),"Canonical actor reuse releases all real special models")
	world.combat.engine.event("weapon-start",world.controlled_id,{"animation":200,"attackType":39}); owner.close(); await settle_retirement()
	check(specials.records.is_empty() and specials.handles.is_empty() and specials.manager==null and owner.models.is_empty(),"World closure discards pending native special-attack resources and callbacks")
	var snapshot: Dictionary=specials.snapshot(); world.combat.close(); world.instances.clear(); world.desired.clear(); actor.retire(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"special_attacks":snapshot,"scope":"Actual original actor and four special models, combat presentation signal, physical Parts/current transforms, impact/cessation, lazy slot retention and canonical/world retirement under authored state. Real server outcomes and pixels are separate acceptance."},"\t")); file.close()
	print("NATIVE_SPECIAL_ATTACK_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
