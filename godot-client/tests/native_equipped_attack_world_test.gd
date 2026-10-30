extends "res://tests/native_parry_world_test.gd"
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Stream=preload("res://systems/native_render/creature_stream.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Equipped=preload("res://systems/native_data/equipped_attack_visual.gd")
class ControlledEffects extends Effects:
	var hold:=false
	func ensure_models(resources: Dictionary) -> bool:
		return false if hold else super.ensure_models(resources)
func materials(actor,slot: int) -> Array:
	var result: Array=[]
	for index in actor.equipment_models.get(slot,[]):
		for part in actor.rigs.entities[actor.object_id].model_parts[index]:
			for child in actor.rigs.node_at(actor.object_id,int(part)).get_children():
				if child is MeshInstance3D and child.material_override is StandardMaterial3D: result.append(child.material_override)
	return result
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original weapon resources mount read-only")
	var bytes:=catalog.get_resource("baseitems",2017); var table:=Table.new(); var baseitems:=table.parse(Binary.new(bytes).text(0,bytes.size()))
	var base:=-1
	for i in baseitems.orderedRows.size():
		var row: Dictionary=baseitems.orderedRows[i]
		if str(row.get("ModelType",""))=="2" and catalog.has_resource(Equipped.resource(str(row.get("ItemClass",""))),2002): base=i; break
	check(base>=0,"Active original base-item row provides an original _mb model")
	if base<0: quit(1); return
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world)
	var visibility:=preload("res://systems/native_render/particle_visibility.gd").new(); world.add_child(visibility) # Keep particle simulation off during feature work.
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var owner:=ControlledEffects.new(); world.add_child(owner); owner.configure(world)
	var stream:=Stream.new(); stream.catalog=catalog; stream.tables={"baseitems":baseitems}
	var item:={"baseItem":base,"parts":[1,1,1]}; var descriptors:=stream.item_descriptors(item,"rhand",1.4,16)
	var resource:=Equipped.resource(str(baseitems.orderedRows[base].ItemClass)); var resources:={"c_ydrowiz":true}; resources[resource]=true
	for piece in descriptors: resources[str(piece.model)]=true
	check(await wait_for(func():return owner.tables.size()==3 and owner.ensure_models(resources)),"Original actor, held weapon pieces and blur model prepare natively")
	var pieces: Array=[{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}]
	for piece in descriptors:
		var value: Dictionary=piece.duplicate(true); value.bundle=owner.bundles[str(piece.model)]; pieces.append(value)
	var actors: Array=[]
	for id in [world.controlled_id,0x80000002]:
		var actor:=Actor.new(); world.add_child(actor); actor.position=Vector3(2,1,-3)
		check(actor.install(pieces,world.pool,id,{}),"Real original actor/weapon hierarchy installs "+str(id))
		actors.append(actor); world.instances[id]=actor; world.installed[id]="one"
		world.desired[id]={"key":"one","object":{"id":id,"objectType":5,"nativeLifetime":1,"appearance":{"equipment":[{"id":100,"slot":16,"item":item}]},"replicated":{"position":[2,3,1]}}}
	var id: int=world.controlled_id; var actor=actors[0]; var weapons=owner.equipped_attacks; var untouched:=materials(actors[1],16).map(func(mat):return [mat.albedo_color,mat.emission])
	check(actor.equipment_visuals[16].baseItem==base and actor.equipment_visuals[16].itemClass==baseitems.orderedRows[base].ItemClass,"Original active base-item metadata reaches native held owner")
	var canonical:=JSON.stringify(world.desired)
	actor.rigs._update(0.25)
	var model_index: int=actor.equipment_models[16][0]; var clock: Dictionary=actor.rigs.playback_state(id,model_index)
	var serial: int=clock.serial
	world.combat.engine.event("weapon-start",id,{"attackType":6,"modelEvent":"blur_start"})
	check(weapons.records.has(id) and is_instance_valid(weapons.records[id].model) and int(weapons.records[id].state.enabled)==1,"Original event synchronously admits warmed equipped slotFB model")
	var record: Dictionary=weapons.records[id]; var model=record.model
	check(model.bundle_data.resource_name==resource and model.anchor_node==actor.equipment_part(16,"root") and model.get_meta("native_weapon_slot_configuration")==[251,0,0],"Actual original model attaches to held root with original slot/configuration")
	check(actor.rigs.playback_state(id,model_index).serial==serial and absf(float(actor.rigs.playback_state(id,model_index).time)-float(clock.time))<0.00001,"Admitting colour owner preserves held animation clock and serial")
	check(not materials(actor,16).is_empty() and materials(actor,16).all(func(mat):return mat.albedo_color.r==1 and mat.albedo_color.g==0 and mat.albedo_color.b==0),"Attack colour applies to private held model materials")
	check(materials(actors[1],16).map(func(mat):return [mat.albedo_color,mat.emission])==untouched,"Shared original resources and another actor remain untinted")
	var count: int=weapons.stats.created; world.combat.engine.event("weapon-start",id,{"attackType":6})
	check(weapons.stats.created==count,"Repeated blur start cannot duplicate slotFB")
	actor.equipment_colour_scope(16,0,[0.0,0.0,1.0])
	check(materials(actor,16).all(func(mat):return mat.albedo_color.b==1 and mat.albedo_color.r==0) and model.rigs.entities[0].models[0].native_owner.pose.colour_scopes.active[0],"Higher-priority colour propagates to held pieces and attached blur")
	actor.equipment_colour_scope(16,0,null)
	check(materials(actor,16).all(func(mat):return mat.albedo_color.r==1 and mat.albedo_color.b==0),"Clearing higher-priority scope restores still-active attack colour")
	actor.position+=Vector3(1,0.25,-2); actor.scale=Vector3.ONE*1.2; model._process(0)
	check(model.global_position.distance_to(model.anchor_node.global_position)<0.00001 and model.global_basis.get_scale().distance_to(model.anchor_node.global_basis.get_scale())<0.00001,"Blur follows current held position, rotation and scale")
	var weak: WeakRef=weakref(model); world.combat.engine.event("weapon-end",id,{"modelEvent":"blur_end"}); await settle_retirement()
	check(weak.get_ref()==null and record.state.enabled==0 and record.state.attackType==0 and not actor.equipment_colour_state(16).active[4],"Blur end releases actual model and clears original colour/attack state")
	check(JSON.stringify(world.desired)==canonical,"Weapon presentation does not mutate canonical server state")
	owner.hold=true; world.combat.engine.event("weapon-start",id,{"attackType":9})
	check(record.pending and record.state.enabled==0 and not is_instance_valid(record.model),"Delayed native data leaves original enable state uncommitted")
	world.combat.engine.event("weapon-end",id,{}); owner.hold=false; weapons.advance()
	check(not record.pending and not is_instance_valid(record.model) and weapons.stats.created==count,"Late completion cannot display an expired attack window")
	world.combat.engine.event("weapon-start",id,{"attackType":9}); world.desired[id].object.appearance.equipment[0].id=101; weapons.advance(); await settle_retirement()
	check(not weapons.records.has(id) and not actor.equipment_colour_state(16).active[4],"Canonical equipment replacement releases old blur and colour listener")
	world.combat.engine.event("weapon-start",id,{"attackType":31}); world.desired[id].object.nativeLifetime=2; weapons.advance(); await settle_retirement()
	check(weapons.records.is_empty() and weapons.stats.failed==0,"Reused actor lifetime retires equipped visuals without failures")
	var snapshot: Dictionary=weapons.snapshot(); owner.close(); world.combat.close()
	check(weapons.records.is_empty() and weapons.manager==null and owner.models.is_empty(),"World closure releases equipped models/resources/callbacks")
	world.instances.clear(); world.desired.clear()
	for node in actors: node.retire()
	stream.free(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"equipped":snapshot,"baseItem":base,"resource":resource,"publicConnections":0,"scope":"Headless actual original actor/weapon/blur models, native metadata, private materials/colour priority, preserved clock, live attachment transform, delayed completion/expiry/equipment/lifetime/closure. Live server and GPU visual acceptance queued."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
