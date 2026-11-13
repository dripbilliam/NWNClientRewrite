extends Node
# PRIVATE identical observer in BOTH application views. Never forces rendering,
# blocks admission, changes visibility, or attributes async counters as CPU time.
const Fence=preload("res://tests/nwn71_presentation_fence.gd")
const MAX_ROWS:=8
var source: SceneTree
var output:=""
var rows: Array=[]
var fences: Array=[]
var monitors: Dictionary={}
var generation:=-1
var started_us:=0
var stopped:=false
var done:=false
var visible_submissions:=0
var headless:=false
var loading_ref: WeakRef
func _ready() -> void:
	source=get_tree();headless=DisplayServer.get_name()=="headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=").trim_suffix(".json")+".nwn71-presentation.json"
	if headless:return
	source.node_added.connect(added)
	for name in ClassDB.class_get_integer_constant_list("Performance"):
		if str(name).begins_with("PIPELINE_COMPILATIONS_") or str(name).begins_with("RENDER_PIPELINE_COMPILATIONS_"):monitors[str(name)]=ClassDB.class_get_integer_constant("Performance",name)
	RenderingServer.frame_pre_draw.connect(before_draw)
func added(node: Node) -> void:
	var script: Script=node.get_script()
	if script!=null and script.resource_path=="res://systems/native_loading_screen.gd":loading_ref=weakref(node)
func counts() -> Dictionary:
	var result: Dictionary={}
	for name in monitors:result[name]=Performance.get_monitor(int(monitors[name]))
	return result
func before_draw() -> void:
	if done:return
	var loading=loading_ref.get_ref() if loading_ref!=null else null;var world=source.get("world")
	if not is_instance_valid(loading) or not is_instance_valid(world):return
	var marks: Dictionary=loading.milestones
	if generation<0:
		if loading.active or not marks.get("terrain",false) or not marks.get("player",false) or not marks.get("camera",false) or not marks.get("errors",[]).is_empty():return
		generation=int(source.get("epoch"));started_us=Time.get_ticks_usec()
	var now:=Time.get_ticks_usec();var current_counts:=counts()
	if not rows.is_empty() and not rows.back().has("next_pre_draw_us"):
		var previous: Dictionary=rows.back();previous.next_pre_draw_us=now;previous.counts_after_prior_draw_sync=current_counts
		var delta: Dictionary={}
		for name in current_counts:delta[name]=float(current_counts[name])-float(previous.counts_before[name])
		previous.pipeline_counter_delta_to_next_pre_draw=delta
	if stopped:RenderingServer.frame_pre_draw.disconnect(before_draw);maybe_finish();return
	if int(source.get("epoch"))!=generation or world.generation!=generation or source.get("closing") or world.closed or world.retiring:
		stopped=true;RenderingServer.frame_pre_draw.disconnect(before_draw);write_report("generation_or_lifetime_changed");return
	var index:=rows.size();var covered: bool=loading.veil.is_visible_in_tree()
	var row: Dictionary={"index":index,"pre_draw_us":now,"engine_process_frame":Engine.get_process_frames(),"main_thread":Thread.is_main_thread(),"covered_at_submission":covered,"public_active":loading.active,"public_blocks_input":loading.blocks_input(),"world_visible":world.is_visible_in_tree(),"world_object":str(world.get_instance_id()),"generation":generation,"area_id":world.area_id,"viewport_object":str(loading.get_viewport().get_instance_id()),"counts_before":current_counts,"status":"submitted"}
	rows.append(row)
	var fence:=Fence.new();fences.append(fence)
	if not fence.request(self,world,generation,Callable(self,"current").bind(index),Callable(self,"completed").bind(index),Callable(self,"aborted").bind(index)):
		row.status="request_rejected"
	if not covered:visible_submissions+=1
	if visible_submissions>=3 or rows.size()>=MAX_ROWS:stopped=true
func current(world: Object,epoch: int,index: int) -> bool:
	return not done and index<rows.size() and is_instance_valid(source) and not source.get("closing") and int(source.get("epoch"))==epoch and source.get("world")==world and not world.closed and not world.retiring and not world.is_queued_for_deletion()
func completed(_world: Object,_epoch: int,index: int) -> void:
	var row: Dictionary=rows[index];row.status="completed";row.post_draw_main_us=Time.get_ticks_usec();row.submission_to_main_completion_ms=(int(row.post_draw_main_us)-int(row.pre_draw_us))/1000.0
	var loading=source.get("loading_screen")
	row.covered_at_callback=loading.veil.is_visible_in_tree() if is_instance_valid(loading) else false
	row.counts_at_main_completion=counts();maybe_finish()
func aborted(_world: Object,_epoch: int,reason: String,index: int) -> void:
	rows[index].status="aborted";rows[index].reason=reason;maybe_finish()
func maybe_finish() -> void:
	if not stopped or rows.is_empty() or not rows.back().has("next_pre_draw_us"):return
	for row in rows:
		if row.status=="submitted":return
	write_report("bounded_window_complete")
func write_report(reason: String) -> void:
	if done:return
	done=true
	if is_instance_valid(source) and source.node_added.is_connected(added):source.node_added.disconnect(added)
	if RenderingServer.frame_pre_draw.is_connected(before_draw):RenderingServer.frame_pre_draw.disconnect(before_draw)
	for fence in fences:fence.close()
	if output.is_empty():return
	var loading=source.get("loading_screen") if is_instance_valid(source) and not headless else null
	var result: Dictionary={"reason":reason,"generation":generation,"started_us":started_us,"finished_us":Time.get_ticks_usec(),"rows":rows,"max_rows":MAX_ROWS,"visible_submissions":visible_submissions,"pipeline_monitors":monitors.keys(),"headless":headless,"no_forced_draw_or_sync":true,"loading_snapshot":loading.snapshot() if is_instance_valid(loading) else {},"scope":"Bounded first public readiness/hide window: pre_draw visibility is this submitted frame. Render-to-main sentinel excludes older queued postdraw. Main completion wall includes scheduling delay, not exact driver wait. Pipeline counters are cumulative async observations; next-pre_draw sample follows sync of the prior submitted draw. Do not sum spans or interpret counters as CPU time."}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
func _exit_tree() -> void:write_report("exit_before_window_complete")
