extends "res://tests/nwn62_construction_test.gd"
const FrozenTemplate=preload("res://.cache/nwn62/before/systems/native_render/model_template.gd")
var observations: Array=[]
class EntryScope extends Node:
	var closed:=false
	var retiring:=false
func measurement_pool(staged: bool)->Dictionary:
	var pool:=Pool.new();pool.cooperative_templates=staged;pool.publication_budget_us=3000
	var context:=EntryScope.new();context.set_meta("native_entry_loading",OS.get_cmdline_user_args().has("--entry-loading-experiment"));pool.bind_publication_world(context)
	return {"pool":pool,"context":context}
func summarize(values: Array)->Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0.0
	for value in sorted:total+=float(value)
	return {"count":sorted.size(),"median_us":sorted[sorted.size()/2],"p95_us":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)],"max_us":sorted[-1],"mean_us":total/sorted.size(),"total_us":total}
func measure(input: Dictionary,staged: bool,placements: int,label: String)->Dictionary:
	await process_frame
	var configuration:=measurement_pool(staged);var pool=configuration.pool
	var template=Template.new() if staged else FrozenTemplate.new()
	var pending: Dictionary={};var ready:=false;var completed:=0;var callbacks: Array=[];var units: Array=[];var roots: Array=[]
	var began:=Time.get_ticks_usec();var first_us:=0;var frames:=0;var failed:=""
	var phase_cpu: Dictionary={};var phase_calls: Dictionary={};var phase_frames: Dictionary={};var active_us:=0;var first_cpu_us:=0;var first_frames:=0
	if staged:
		var unit_began:=Time.get_ticks_usec()
		if not template.begin_staged_build(input,pool):failed=template.failure
		pool.construction_finished(unit_began);var setup_us:=Time.get_ticks_usec()-unit_began;units.append(setup_us);active_us+=setup_us;phase_cpu.begin=setup_us
	while completed<placements and failed.is_empty() and frames<1200:
		var callback_began:=Time.get_ticks_usec();var attempts:=0
		while pool.can_publish() and completed<placements:
			if attempts>0 and Time.get_ticks_usec()-callback_began>=Template.callback_budget(pool):break
			var unit_began:=Time.get_ticks_usec();var status:="pending"
			var phase:="template:"+str(template._build_progress.get("phase","sync-build")) if not ready else "placement:"+str(pending.placement_job.phase) if pending.has("placement_job") else "clone-or-first"
			if not ready:
				if staged:
					var result: Dictionary=template.staged_build_step(8,Template.step_budget(pool));status=str(result.status)
					if status=="failed":failed=str(result.reason)
				else:
					ready=template.build(input,pool);status="ready" if ready else "failed"
					if not ready:failed=template.failure
				ready=status=="ready"
				pool.construction_finished(unit_began)
			else:
				var result: Dictionary=template.create_step(pending,8,Template.step_budget(pool)) if staged else {"status":"ready","instance":template.create()}
				status=str(result.status)
				if status=="failed":failed=str(result.get("reason","Placement failed"))
				elif status=="ready":
					if result.instance==null:failed="Placement returned null";break
					roots.append(result.instance);completed+=1
					if completed==1:first_us=Time.get_ticks_usec()-began
					pool.publication_finished(unit_began)
				else:pool.construction_finished(unit_began)
			var elapsed:=Time.get_ticks_usec()-unit_began;units.append(elapsed);active_us+=elapsed;phase_cpu[phase]=int(phase_cpu.get(phase,0))+elapsed;phase_calls[phase]=int(phase_calls.get(phase,0))+1
			if not phase_frames.has(phase):phase_frames[phase]=[]
			if not phase_frames[phase].has(frames):phase_frames[phase].append(frames)
			if completed==1 and first_cpu_us==0:first_cpu_us=active_us;first_frames=frames+1
			attempts+=1
		callbacks.append(Time.get_ticks_usec()-callback_began);frames+=1
		if completed<placements:await process_frame
	var full_us:=Time.get_ticks_usec()-began
	check(failed.is_empty() and completed==placements,label+": all complete original placements published")
	for phase in phase_frames:phase_frames[phase]=phase_frames[phase].size()
	var result:={"label":label,"staged":staged,"placements":completed,"source_nodes":input.value.nodes.size(),"source_meshes":input.value.nodes.filter(func(row):return not row.get("mesh",{}).is_empty()).size(),"frames":frames,"first_us":first_us,"first_active_us":first_cpu_us,"first_frames":first_frames,"first_pacing_us":maxi(0,first_us-first_cpu_us),"full_us":full_us,"callbacks":summarize(callbacks),"units":summarize(units),"phase_at_start_cpu_us":phase_cpu,"phase_at_start_calls":phase_calls,"phase_callback_frames":phase_frames,"mode":template.construction_snapshot().mode,"small_native_packed":template.small_native_packed if staged else false,"fallback":template.recipe_fallback_reason,"failure":failed}
	for instance in roots:instance.free()
	result.publication_budget_us=pool.publication_budget_limit_us();result.entry_allowance_configured_us=pool.entry_publication_budget_us
	Template.cancel_creation(pending);template=null;pool.clear();pool=null
	configuration.context.free()
	return result
func measure_actors(input: Dictionary,staged: bool,count: int,label: String)->Dictionary:
	await process_frame
	var configuration:=measurement_pool(staged);var pool=configuration.pool
	var pieces: Array=[{"bundle":input,"initial_clip":"","follow":true}]
	var began:=Time.get_ticks_usec();var first_us:=0;var roots: Array=[];var callbacks: Array=[];var units: Array=[];var actor;var failure:="";var frames:=0
	while roots.size()<count and failure.is_empty() and frames<1200:
		var callback_began:=Time.get_ticks_usec();var attempts:=0
		while pool.can_publish() and roots.size()<count:
			if attempts>0 and Time.get_ticks_usec()-callback_began>=Template.callback_budget(pool):break
			var unit_began:=Time.get_ticks_usec();var ready:=false
			if actor==null:
				actor=Actor.new() if staged else ActorBefore.new()
				if staged:
					if not actor.begin_install(pieces,pool,roots.size()+1,{}):failure=actor.failure
				else:
					ready=actor.install(pieces,pool,roots.size()+1,{})
					if not ready:failure=actor.failure
			if staged and failure.is_empty():
				var progress: Dictionary=actor.install_step(8,Template.step_budget(pool));ready=progress.status=="ready"
				if progress.status=="failed":failure=str(progress.reason)
			if ready:
				roots.append(actor);actor=null
				if roots.size()==1:first_us=Time.get_ticks_usec()-began
				pool.publication_finished(unit_began)
			else:pool.construction_finished(unit_began)
			units.append(Time.get_ticks_usec()-unit_began);attempts+=1
		callbacks.append(Time.get_ticks_usec()-callback_began);frames+=1
		if roots.size()<count:await process_frame
	var full_us:=Time.get_ticks_usec()-began
	check(failure.is_empty() and roots.size()==count,label+": every complete private actor publishes")
	var result:={"label":label,"staged":staged,"placements":roots.size(),"source_nodes":input.value.nodes.size(),"frames":frames,"first_us":first_us,"full_us":full_us,"callbacks":summarize(callbacks),"units":summarize(units),"failure":failure}
	if is_instance_valid(actor):actor.cancel_install();actor.free()
	for instance in roots:instance.free()
	result.publication_budget_us=pool.publication_budget_limit_us();result.entry_allowance_configured_us=pool.entry_publication_budget_us
	pool.clear();configuration.context.free();return result
func run()->void:
	Engine.max_fps=60
	var file:=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ)
	if file==null:print("Original tile fixture unavailable");quit(2);return
	var original: Dictionary=file.get_var(false);file.close()
	var inputs: Array=[{"name":"original-tile","bundle":original,"placements":24}]
	var preflight:=OS.get_cmdline_user_args().has("--preflight")
	# A larger authored graph proves per-node subdivision; it is labelled
	# separately from the unmodified installed tile and uses prepared uploads.
	var authored:=bundle("d");authored.value.nodes=authored.value.nodes.slice(0,2)
	for index in 256:
		var row: Dictionary=authored.value.nodes[1].duplicate(true);row.name="copy_"+str(index);row.parent=0;row.position=[index*0.001,0.0,0.0];authored.value.nodes.append(row)
	inputs.append({"name":"authored-257-mesh","bundle":authored,"placements":8})
	for item in inputs:
		for leg in ([false,true] if preflight else [false,true,true,false]):
			observations.append(await measure(item.bundle,leg,2 if preflight else int(item.placements),str(item.name)+"-"+str(observations.size())))
	authored.value.rig_asset=ActorData.new().rig_asset(authored.value)
	for leg in ([false,true] if preflight else [false,true,true,false]):
		observations.append(await measure_actors(authored,leg,2 if preflight else 8,"authored-257-mesh-actors-"+str(observations.size())))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Headless normal-engine ABBA component construction; identical per-leg configured shared ledger (ordinary3ms or PRIVATE entry experiment),60Hz engine-frame pacing, all placements retained until end. Original installed tile and separately labelled authored larger graph. First/full publication latency and actual callback/unit active CPU; no renderer/FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var output:=FileAccess.open(argument.substr(9),FileAccess.WRITE);output.store_string(JSON.stringify(result,"  "));output.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
