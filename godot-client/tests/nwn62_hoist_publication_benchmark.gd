extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Current=preload("res://systems/native_render/model_template.gd")
const ControlTemplate=preload("res://.cache/nwn62/hoist-control-a/model_template.gd")
var completed: Dictionary={}

func _initialize() -> void:call_deferred("run")
func measure(bundle: Dictionary,kind: String) -> Dictionary:
	await process_frame
	var pool:=Pool.new();pool.compact_static_parts=false;pool.cooperative_templates=true;pool.publication_budget_us=3000
	var context:=Node.new();context.set_meta("native_entry_loading",true);pool.bind_publication_world(context)
	var template=Current.new() if kind=="candidate" else ControlTemplate.new()
	var pending: Dictionary={};var roots: Array=[];var callbacks: Array=[];var phase_cpu: Dictionary={};var phase_calls: Dictionary={}
	var began:=Time.get_ticks_usec();var setup_began:=Time.get_ticks_usec();var failure:=""
	if not template.begin_staged_build(bundle,pool):failure=template.failure
	pool.construction_finished(setup_began)
	var first_us:=0;var first_cpu_us:=0;var active_us:=Time.get_ticks_usec()-setup_began;var frames:=0;var ready:=false
	while roots.size()<3 and failure.is_empty() and frames<300:
		var callback_began:=Time.get_ticks_usec();var attempts:=0
		while pool.can_publish() and roots.size()<3:
			if attempts>0 and Time.get_ticks_usec()-callback_began>=Current.callback_budget(pool):break
			var phase: String="template:"+str(template._build_progress.get("phase","sync-build")) if not ready else "placement"
			var unit_began:=Time.get_ticks_usec();var status: String="pending"
			if not ready:
				var built: Dictionary=template.staged_build_step(8,Current.step_budget(pool));status=str(built.status)
				if status=="failed":failure=str(built.reason)
				ready=status=="ready";pool.construction_finished(unit_began)
			else:
				var placed: Dictionary=template.create_step(pending,8,Current.step_budget(pool));status=str(placed.status)
				if status=="failed":failure=str(placed.get("reason","placement-failed"))
				elif status=="ready":
					if placed.instance==null:failure="empty-placement"
					else:
						roots.append(placed.instance)
						if roots.size()==1:first_us=Time.get_ticks_usec()-began
					pool.publication_finished(unit_began)
				else:pool.construction_finished(unit_began)
			var unit_us:=Time.get_ticks_usec()-unit_began;active_us+=unit_us
			phase_cpu[phase]=int(phase_cpu.get(phase,0))+unit_us;phase_calls[phase]=int(phase_calls.get(phase,0))+1
			if roots.size()==1 and first_cpu_us==0:first_cpu_us=active_us
			attempts+=1
		callbacks.append(Time.get_ticks_usec()-callback_began);frames+=1
		if roots.size()<3 and failure.is_empty():await process_frame
	var full_us:=Time.get_ticks_usec()-began;var max_callback_us:=0
	for value in callbacks:max_callback_us=maxi(max_callback_us,int(value))
	var snapshot: Dictionary=template.construction_snapshot()
	var result:={"kind":kind,"failure":failure,"placements":roots.size(),"frames":frames,"first_us":first_us,"full_us":full_us,"first_cpu_us":first_cpu_us,"active_cpu_us":active_us,"max_callback_us":max_callback_us,"phase_cpu_us":phase_cpu,"phase_calls":phase_calls,"mode":snapshot.mode,"staged_max_step_us":snapshot.staged_max_step_us,"staged_steps":snapshot.staged_steps,"node_parts":template.physical_part_count}
	for owner in roots:owner.free()
	Current.cancel_creation(pending);template.cancel_staged_build();template=null;pool.clear();context.free()
	return result
func run() -> void:
	Engine.max_fps=60
	var args: Dictionary={}
	for item in OS.get_cmdline_user_args():
		var pair:=item.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var report:={"success":false,"model":"plc_hoist","legs":[],"scope":"Exact sealed original model, normal separate-Part layout, matched 3 ms publication ledger and 60 Hz headless frame pacing. Template build plus three placements; no GPU/FPS claim."}
	var catalog:=Recorded.new()
	if not catalog.mount(str(args.catalog)):report.failure=catalog.failure;write_report(args.report,report);return
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.completed.connect(func(id,value):completed[id]=value)
	var id:=service.request("plc_hoist",2002,"static-model");var deadline:=Time.get_ticks_msec()+30000
	while not completed.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	if not completed.has(id):report.failure="source-timeout";service.close();service.free();write_report(args.report,report);return
	var bundle: Dictionary=completed[id]
	if not str(bundle.get("error","")).is_empty():report.failure=str(bundle.error);service.close();service.free();write_report(args.report,report);return
	report.source_sha256=str(bundle.sha256)
	report.control_recipe_sha256=FileAccess.get_sha256("res://.cache/nwn62/hoist-control-a/native_model_recipe.gd")
	report.control_template_sha256=FileAccess.get_sha256("res://.cache/nwn62/hoist-control-a/model_template.gd")
	report.candidate_recipe_sha256=FileAccess.get_sha256("res://systems/native_render/native_model_recipe.gd")
	report.candidate_template_sha256=FileAccess.get_sha256("res://systems/native_render/model_template.gd")
	for kind in ["control","candidate","candidate","control"]:report.legs.append(await measure(bundle,kind))
	report.success=report.legs.size()==4 and report.legs.all(func(row):return str(row.failure).is_empty() and int(row.placements)==3 and str(row.mode)=="known-node-recipe")
	service.close();service.free();completed.clear()
	write_report(args.report,report)
func write_report(path: String,report: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("NWN62_HOIST_PUBLICATION ",report.success," legs ",report.legs.size())
	quit(0 if report.success else 1)
