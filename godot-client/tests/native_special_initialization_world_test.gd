extends "res://tests/native_parry_world_test.gd"
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Init=preload("res://systems/native_data/special_initialization.gd")
const LiveProbe=preload("res://tests/native_live_actions_probe.gd") # Compile queued real-server acceptance; never run it here.
class ControlledEffects extends Effects:
	var hold:=false
	func ensure_models(resources: Dictionary) -> bool:
		return false if hold else super.ensure_models(resources)
func models_ready(specials) -> bool:
	specials.advance()
	return not specials.handles.is_empty() and specials.handles.values().all(func(h):return is_instance_valid(h.model))
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original initialization resources mount read-only")
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world)
	var visibility:=preload("res://systems/native_render/particle_visibility.gd").new(); world.add_child(visibility); visibility.set_enabled(false)
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var owner:=ControlledEffects.new(); world.add_child(owner); owner.configure(world)
	check(await wait_for(func():return owner.tables.size()==3 and owner.ensure_models({"c_ydrowiz":true})),"Native active tables and original physical actor prepare")
	owner.set_process(false) # Explicitly advance the owner; no GPU or live server.
	var actor:=Actor.new(); world.add_child(actor)
	check(actor.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{},0,{"fieldDD":1}),"Original actor admits the unarmed animation context")
	world.instances[world.controlled_id]=actor
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":6,"gender":1,"phenotype":2,"equipment":[]},"replicated":{"position":[0,0,0],"stats":{"fieldDE4":25,"classes":[{"id":5,"level":20}]}},"playerState":{"feats":[213]}}
	world.desired[world.controlled_id]={"key":"one","object":object}; world.installed[world.controlled_id]="one"
	var specials=owner.special_attacks; var canonical:=JSON.stringify(object)
	var scale_before: Variant=owner.tables.appearance.orderedRows[6].get("HELMET_SCALE_F")
	owner.tables.appearance.orderedRows[6].HELMET_SCALE_F="0.75" # Active custom-rule fixture; no catalog file is changed.
	specials.observe(object)
	check(specials.stats.initializations==1 and specials.handles.size()==3,"Initialization reserves original paired ki slots and persistent eye model before any swing")
	check(await wait_for(func():return models_ready(specials)),"Actual original ki and eye models prepare asynchronously through native workers")
	var r: Dictionary=specials.records[world.controlled_id]; var eye_handle: Dictionary=r.eye.model; var eye_model=eye_handle.model
	check(eye_handle.resource=="vfx_monkeyesf" and eye_model.anchor_node==actor.physical_part("head_g"),"Original evil female-human eye model follows the actual head_g Part")
	check(eye_model.bundle_data.value.rig_asset.clips.is_empty() and eye_model.rigs.entities[0].models[0].native_owner.gob.runsE0.is_empty() and eye_model.find_children("*","Node",true,false).any(func(node):return node.has_method("detonate")),"Original eye emitters have their physical model with no invented impact clip/run")
	check(JSON.stringify(object)==canonical,"Initialization changes no canonical gameplay or replicated server fields")
	check(eye_model.scale.is_equal_approx(Vector3.ONE*Init.M.f(0.75+Init.M.f(0.13))),"Active custom appearance scale and original phenotype2 addition apply")
	actor.position=Vector3(4,2,-3); actor.rotation.y=0.7; await process_frame; await process_frame
	check(eye_model.global_position.distance_to(actor.physical_part("head_g").global_position)<0.0001 and eye_model.scale.is_equal_approx(eye_model.anchor_scale),"Eye effect consumes the current moving head pose and retains the explicit scale")
	var created: int=specials.stats.created; specials.observe(object); var initialized: int=specials.stats.initializations
	specials.advance(5.999)
	check(specials.stats.initializations==initialized and specials.stats.created==created,"Unchanged metadata and a partial six-second interval do not initialize again")
	specials.advance(0.002)
	check(specials.stats.initializations==initialized+1 and specials.stats.created==created and is_same(r.eye.model,eye_handle),"Original six-second trigger rechecks without duplicate cached eye/ki instances")
	for alignment in [50,80]:
		var old_ref: WeakRef=weakref(eye_model); eye_model=null; object.replicated.stats.fieldDE4=alignment; specials.observe(object)
		check(await wait_for(func():return models_ready(specials)),"Alignment change prepares original eye variant "+str(alignment))
		await settle_retirement(); r=specials.records[world.controlled_id]; eye_handle=r.eye.model; eye_model=eye_handle.model
		check(old_ref.get_ref()==null and eye_handle.resource==("vfx_monkeyesf02" if alignment==50 else "vfx_monkeyesf01") and specials.handles.size()==3,"Alignment category replaces and releases only the old persistent eye model")
	actor.rigs.entities[world.controlled_id].context.fieldDD=3; specials.observe(object)
	check(r.state.slots.slice(0,2).all(func(h):return h.model.rigs.entities[0].models[0].clip=="cessation") and r.eye.model.model==eye_model,"Armed weapon class plays cessation in both existing ki slots while retaining the eye owner")
	check(specials.stats.failed==0 and visibility.snapshot().registered>0 and not visibility.enabled,"Real original models/Parts/clips succeed while particle simulation remains disabled")
	object.replicated.stats.fieldDE4=25; object.replicated.stats.classes[0].level=19; specials.observe(object)
	check(r.eye.model.model==eye_model,"Level below20 does not invent eye destruction absent from the original initializer")
	var references: Array=specials.handles.values().map(func(h):return weakref(h.model)); eye_model=null
	world.desired[world.controlled_id].key="pending-replacement"; specials.advance(); await settle_retirement()
	check(specials.records.is_empty() and specials.handles.is_empty() and references.all(func(ref):return ref.get_ref()==null),"Pending appearance replacement retires original persistent and lazy models")
	specials.observe(object)
	check(specials.records.is_empty(),"Mismatched installed appearance cannot create effects under an old physical model")
	world.desired[world.controlled_id].key="one"; actor.rigs.entities[world.controlled_id].context.fieldDD=1
	object.replicated.stats.classes[0].level=20; owner.hold=true; specials.observe(object)
	check(specials.handles.size()==3 and specials.handles.values().all(func(h):return h.model==null and not h.commands.is_empty() if h.name=="monkeyes" else h.model==null),"Deferred eye attachment/scale/play remain ordered under a cold native resource boundary")
	object.nativeLifetime=2; specials.advance(); owner.hold=false; await process_frame; specials.advance()
	check(specials.records.is_empty() and specials.handles.is_empty() and owner.models.is_empty(),"Canonical reuse cancels every cold request before late resources can resurrect an eye effect")
	object.replicated.stats.erase("fieldDE4"); specials.observe(object)
	check(specials.handles.size()==2 and specials.records[world.controlled_id].eye.model==null and specials.records[world.controlled_id].eye_deferred,"Missing authoritative alignment defers only the eye model while independent paired ki initialization proceeds")
	object.replicated.stats.fieldDE4=80; specials.observe(object); check(await wait_for(func():return models_ready(specials)),"Receiving authoritative alignment completes the deferred native initialization")
	references=specials.handles.values().map(func(h):return weakref(h.model)); var snapshot: Dictionary=specials.snapshot(); var eye_assets: Array=[]
	for resource in ["vfx_monkeyesf","vfx_monkeyesf01","vfx_monkeyesf02"]:
		var bundle: Dictionary=owner.bundles[resource]; eye_assets.append({"resource":resource,"sha256":bundle.sha256,"clips":bundle.value.rig_asset.clips.map(func(clip):return clip.name),"parts":bundle.value.nodes.map(func(node):return {"name":node.name,"features":node.features})})
	check(snapshot.stats.missing_clip_requests==4 and snapshot.events.filter(func(event):return event.kind=="play" and str(event.resource).begins_with("vfx_monkeyes")).all(func(event):return not event.played and not event.available),"Original static eye models preserve the ignored missing-impact return, separately from actual provider failures")
	owner.tables.appearance.orderedRows[6].HELMET_SCALE_F=scale_before
	owner.close(); await settle_retirement()
	check(specials.records.is_empty() and specials.handles.is_empty() and specials.manager==null and references.all(func(ref):return ref.get_ref()==null),"World close releases persistent/paired models, references and pending ownership")
	world.combat.close(); world.instances.clear(); world.desired.clear(); actor.retire(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"special_attacks":snapshot,"eyeAssets":eye_assets,"initialCanonicalState":canonical,"scope":"Actual original actor, paired ki and three eye models, physical head_g/current transforms, active custom scale/phenotype, initialization cadence, stance changes and appearance/canonical/world retirement. Headless component acceptance only; no pixels, server or performance claim."},"\t")); file.close()
	print("NATIVE_SPECIAL_INITIALIZATION_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
