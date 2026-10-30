extends "res://tests/native_projectile_lifetime_test.gd"
const Spell=preload("res://systems/native_data/projectile_spell.gd")
const TEST_SPELL=107
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original casting resources mount read-only")
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world)
	check(await wait_for(func():return not owner.projectiles.table.is_empty() and owner.ensure_models({"c_ydrowiz":true})),"Original source and active spell table prepare")
	var model=preload("res://systems/native_render/actor_instance.gd").new(); world.add_child(model)
	check(model.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Original actor source installs under its actual canonical rig ID")
	world.instances[world.controlled_id]=model
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":201,"gender":1},"replicated":{"position":[0,0,0],"animation":15,"cast":{"spell":TEST_SPELL,"silent":0},"stats":{"racialType":6}}}
	world.desired[world.controlled_id]={"key":"one","object":object}; world.installed[world.controlled_id]="one"
	var casts=owner.casts; var definition: Dictionary=Spell.casting(owner.projectiles.table,TEST_SPELL); var release:=Spell.prepare(owner.projectiles.table,TEST_SPELL)
	var conjure_count: int=definition.conjure.filter(func(ref):return not str(ref).is_empty()).size()
	var release_refs: Array=[release.castHead,release.castHand,release.castGround]; var release_count: int=release_refs.filter(func(ref):return not str(ref).is_empty()).size()
	check(conjure_count>0 and release_count>0,"Installed spell exercises original conjure and release resources")
	casts.observe(object,15)
	check(await wait_for(func():return casts.stats.loaded>=conjure_count),"Actual original conjure models load through native workers")
	check(casts.stats.failed==0 and casts.handles.values().all(func(h):return h.category.begins_with("conjure") and is_instance_valid(h.model.anchor_node) and h.model.anchor_node==owner.anchor(world.controlled_id,0,str(h.part))),"Original conjure models bind to non-null source physical Parts")
	check(casts.handles.values().all(func(h):return h.model.rigs.entities[0].models[0].clip=="conjure01"),"Original conjure01 clips actually play")
	var expected_sounds: Array=[definition.conjureSoundFemale,definition.conjureSound].filter(func(ref):return not str(ref).is_empty())
	check(casts.history.filter(func(e):return e.kind=="sound").map(func(e):return e.resource)==expected_sounds,"Replicated racial type and created appearance gender select original female chant and generic VFX audio")
	var held: Array=casts.handles.values().map(func(h):return weakref(h.model))
	casts.release(object,release_refs,Time.get_ticks_msec())
	check(await wait_for(func():return casts.stats.loaded>=conjure_count+release_count),"Original release models load with the shared native controller")
	check(casts.history.any(func(e):return e.kind=="release") and int(casts.records[world.controlled_id].visuals.released)==1,"Projectile release arms original independent casting cleanup timers")
	check(casts.handles.values().filter(func(h):return h.category.begins_with("cast")).all(func(h):return is_instance_valid(h.model.anchor_node) and h.model.anchor_node==owner.anchor(world.controlled_id,0,str(h.part)) and h.model.rigs.entities[0].models[0].clip=="cast01"),"Actual original cast01 models stay attached to non-null source bones")
	var release_model=casts.handles.values().filter(func(h):return h.category=="castvisual")[0].model
	var explosions: Array=release_model.find_children("*","Node",true,false).filter(func(node):return node.has_method("detonate") and str(node.original_properties.get("update",""))=="Explosion")
	check(not explosions.is_empty() and release_model.emitter_listeners.size()==explosions.size(),"Only original Explosion parts register their Gob Detonate listener")
	check(await wait_for(func():return explosions.all(func(node):return node.queued_detonate or int(node._state.get("detonate108",0))!=0)),"Actual original cast01 Detonate event reaches the emitter BYTE command")
	for node in explosions: node.queued_detonate=false; node._state.detonate108=0
	release_model.rigs.model_event.emit(0,1,"detonate",1)
	check(explosions.all(func(node):return not node.queued_detonate and int(node._state.get("detonate108",0))==0),"Another physical model slot cannot detonate this model's Explosion parts")
	check(await wait_for(func():return casts.stats.callbacks>0),"Actual original fade clip emits native donefade callback")
	casts.observe(object,0)
	var r: Dictionary=casts.records[world.controlled_id]; r.last-=5001
	await process_frame; await process_frame
	check(int(r.visuals.conjureTime)==0 and int(r.visuals.castTime)>4000 and int(r.visuals.castTime)<=5000,"First cleanup interval expires conjure without exhausting the separate cast timer")
	held.append_array(casts.handles.values().map(func(h):return weakref(h.model))); r.last-=5001
	await settle_retirement()
	check(casts.handles.is_empty() and casts.records.is_empty() and held.all(func(ref):return ref.get_ref()==null),"Second cleanup interval releases real private models, rig callbacks and controllers")
	object.replicated.animation=0; object.replicated.cast={"spell":58,"silent":0}; var sound_before: int=casts.history.filter(func(e):return e.kind=="sound").size()
	casts.receive({"id":world.controlled_id,"lifetime":1,"animation":15,"cast":{"spell":TEST_SPELL,"silent":1}})
	casts.observe(object,0)
	check(int(casts.records[world.controlled_id].spellId)==TEST_SPELL and int(casts.records[world.controlled_id].animation)==15,"Immediate cast scalars win over an older world/motion snapshot")
	check(await wait_for(func():return not casts.handles.is_empty()),"Later cast creates a fresh source controller")
	check(casts.history.filter(func(e):return e.kind=="sound").size()==sound_before,"Server silent flag suppresses chant and generic conjure sounds")
	var stale: int=casts.stats.stale; object.nativeLifetime=2
	await settle_retirement()
	check(casts.handles.is_empty() and casts.records.is_empty() and casts.stats.stale==stale+1,"Canonical source reuse retires old cast models rather than rebinding them")
	casts.release(object,release_refs,Time.get_ticks_msec()); object.nativeLifetime=3
	await process_frame; await process_frame
	check(casts.releases.is_empty() and casts.handles.is_empty() and casts.stats.stale==stale+2,"Queued release rejects a replaced source before model preparation")
	object.replicated.animation=0; casts.observe(object,0)
	check(casts.records.is_empty(),"Idle creatures do not acquire per-frame casting controllers")
	# Original active-table Proj=0, under authored packet/animation fields.
	check(int(release.useProjectile)==0,"Original selected spell has no traveling projectile")
	object.replicated.animation=17; casts.observe(object,17)
	var before: int=casts.stats.releases; var spawned: int=owner.projectiles.stats.spawned
	owner.projectiles.receive({"kind":"projectile","id":0x7f000000,"lifetime":0,"sourceLifetime":3,"message":{"kind":"safe-projectile","header":{"sourceId":world.controlled_id,"targetId":0x7f000000,"from":[0,0,0],"to":[1,0,0],"duration":200,"appearance":6,"spellId":TEST_SPELL,"path":null,"baseItem":255,"result":0}}})
	check(await wait_for(func():return casts.stats.releases==before+1),"Native receiver releases casting visuals even when active table disables projectile")
	check(owner.projectiles.stats.spawned==spawned and owner.projectiles.queue.is_empty(),"Proj=0 creates no invented projectile")
	check(await wait_for(func():return not casts.handles.is_empty()),"Non-projectile release still owns real private models")
	var pending_refs: Array=casts.handles.values().filter(func(h):return is_instance_valid(h.model)).map(func(h):return weakref(h.model))
	var snapshot: Dictionary=casts.snapshot(); owner.close(); await settle_retirement()
	check(casts.records.is_empty() and casts.handles.is_empty() and casts.releases.is_empty() and casts.manager==null and pending_refs.all(func(ref):return ref.get_ref()==null),"World retirement cancels pending loads and releases model/callback/provider ownership")
	world.instances.clear(); world.desired.clear(); model.retire(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"casts":snapshot,"scope":"Actual original conjure/cast/fade clips, bone anchors, callbacks and native audio requests under authored replicated casting fields; source reuse, sequential timers, active-table Proj=0 and world cleanup. No real server outcome or pixel acceptance here."},"\t")); file.close()
	print("NATIVE_CAST_VISUAL_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
