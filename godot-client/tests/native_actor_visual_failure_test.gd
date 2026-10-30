extends "res://tests/native_visual_failure_test.gd"
const Creatures=preload("res://systems/native_render/creature_stream.gd")
func creature(id: int,appearance: int) -> Dictionary:
	var value:=row(id,appearance,5); value.appearance={"appearance":appearance,"equipment":[]}; return value
func actor_batch(world,catalog,rows: Array) -> Dictionary:
	var owner:=Creatures.new(); world.add_child(owner); owner.admission_parent=world; owner.configure(catalog,world.pool,rows,1,"",world.controlled_id)
	var keys: Dictionary={}
	for object in rows: keys[int(object.id)]=world.signature(object)
	world.batches.append({"owner":owner,"actors":true,"keys":keys})
	var deadline:=Time.get_ticks_msec()+30000
	while not owner.done and Time.get_ticks_msec()<deadline: await process_frame
	check(owner.done,"Actual actor worker/preparation/publication batch completes")
	check(owner.assets.pending.is_empty() and owner.assets.running.is_empty(),"Actor batch drains every owned asset job including failed shared models")
	var sample: Dictionary=owner.stats.duplicate(true); streams.append(sample)
	for frame in 8:
		world._process(0.0)
		if not world.batches.any(func(batch):return batch.owner==owner): break
	return sample
func write_tables(folder: String,bad: bool=false) -> void:
	for name in ["appearance","racialtypes","gender","phenotype","capart","parts_robe","tailmodel","wingmodel","cloakmodel","baseitems","parts_chest"]:
		write(folder.path_join(name+".2da"),"2DA V2.0\n\nRACE MODELTYPE\n0 authored S\n1 absent S\n2 corrupt S\n" if name=="appearance" else "2DA V2.0\n\nValue\n0 0\n")
	if bad: write(folder.path_join("appearance.2da"),"not a table")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-actor-admission-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("authored.mdl"),model()); write(folder.path_join("corrupt.mdl"),"invalid authored model"); write_tables(folder)
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored actor fixtures mount without game assets or network")
	var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1
	var rows: Array=[creature(1,0),creature(2,1),creature(3,0),creature(4,2),creature(5,99),row(6,0,6),creature(7,0),creature(8,2)]
	rows[5].item={"baseItem":999}; rows[6].appearance.equipment=[{"slot":16,"item":{"baseItem":999}}]
	world.receive(rows,1)
	var sample:=await actor_batch(world,catalog,rows)
	check(sample.scope_errors.is_empty() and sample.object_failures.size()==6,"Planning, absent model, malformed shared model, ground item and equipment failures are object-specific")
	check(sample.object_failures.keys().all(func(id):return id in [2,4,5,6,7,8]),"Every failed visual is attributed to its actual registry owner")
	check(sample.jobs.filter(func(job):return job.model=="corrupt").size()==1 and sample.object_failures.has(4) and sample.object_failures.has(8),"One shared decode failure reaches both dependent actors without duplicated model work")
	check(world.instances.has(1) and world.instances.has(3) and world.instances[1].meshes.size()==1 and world.instances[3].meshes.size()==1,"Valid player and neighboring creature publish complete authored meshes")
	check(world.stats.errors.is_empty() and world.ready_for_control(),"Remote actor/item/equipment failures cannot revoke admitted player control")
	check(world.failed_objects.size()==6 and not world.snapshot().object_visuals_complete,"Strict full-world completeness stays false; failed objects remain explicitly reported")
	for frame in 5: world.receive(rows,1); world._process(0.0)
	check(world.pending_plan({}).actors.is_empty() and world.stats.failed_admissions==6,"Unchanged failed appearances do not start repeated preparation jobs")
	rows[1].appearance.appearance=0; world.receive(rows,1)
	check(not world.failed_objects.has(2) and world.pending_plan({}).actors.any(func(object):return object.id==2),"New appearance invalidates only its own failed binding")
	await actor_batch(world,catalog,[rows[1]])
	check(world.instances.has(2) and world.installed[2]==world.signature(rows[1]),"Corrected creature recovers through real native worker and publication flow")
	var stale:=Creatures.new(); world.add_child(stale); stale.set_process(false); stale.done=true; stale.object_failed(2,"Authored stale failure"); world.batches.append({"owner":stale,"actors":true,"keys":{2:"old-key"}})
	var before:=int(world.stats.stale_results); world._process(0.0)
	check(not world.failed_objects.has(2) and world.stats.stale_results==before+1 and world.ready_for_control(),"Stale actor failure cannot poison a newer appearance or player control")
	var previous=world.instances[3]; var previous_key: String=world.installed[3]
	rows[2].appearance.appearance=2; world.receive(rows,1); await actor_batch(world,catalog,[rows[2]])
	check(world.instances[3]==previous and world.installed[3]==previous_key and world.failed_objects.has(3) and world.ready_for_control(),"Failed remote replacement retains the old body while explicitly incomplete")
	rows=rows.filter(func(object):return object.id in [1,2]); world.receive(rows,1)
	check(world.failed_objects.is_empty() and world.snapshot().object_visuals_complete,"Server removal clears failed actor bindings without treating them as installed")
	rows[0].appearance.appearance=2; world.receive(rows,1); await actor_batch(world,catalog,[rows[0]])
	check(world.failed_objects.has(1) and not world.stats.errors.is_empty() and not world.ready_for_control() and world.pending_plan({}).actors.is_empty(),"Current controlled-character failure remains blocking, explicit and non-retrying")
	world.close(); world.queue_free(); await process_frame; await process_frame
	var bad_folder:=folder.path_join("bad"); write_tables(bad_folder,true)
	var bad_catalog:=Catalog.new(); check(bad_catalog.mount_directory(bad_folder),"Malformed authored required-table scope mounts for failure exercise")
	world=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1; rows=[creature(1,0)]; world.receive(rows,1)
	sample=await actor_batch(world,bad_catalog,rows)
	check(sample.scope_errors.size()==1 and sample.model_jobs==0 and sample.object_failures.is_empty(),"A broken shared appearance table fails the scope before guessing actor plans")
	check(not world.stats.errors.is_empty() and not world.ready_for_control(),"Required shared rules still stop player admission")
	world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"streams":streams,"publicConnections":0,"originalCreatureFailureParity":"unproven; explicit independent-object streaming policy","scope":"Actual authored raw-table/model worker jobs, shared failures, actor publication, appearance replacement and world admission; not full-world corpus or FPS acceptance"},"\t")); file.close()
	print("NATIVE_ACTOR_VISUAL_FAILURE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
