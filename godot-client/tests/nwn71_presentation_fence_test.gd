extends SceneTree
const Fence=preload("res://tests/nwn71_presentation_fence.gd")
const Original=preload("res://tests/nwn71_loading_screen_original.gd")
const Candidate=preload("res://tests/nwn71_loading_screen_candidate.gd")
class DrawSource extends RefCounted:
	signal completed
class World extends Node3D:
	var generation:=7
	var closed:=false
	var retiring:=false
	var ready_value:=true
	func ready_for_control() -> bool:return ready_value
class Source extends Node:
	var epoch:=7
	var closing:=false
	var world
	var loading_screen
var output:=""
var checks:=0
var failures: Array=[]
var arms: Array[Callable]=[]
var completed: Array=[]
var aborted: Array=[]
var click_count:=0
var mouse_proof: Array=[]
var ready_value:=true
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func dispatch(arm: Callable) -> void:arms.append(arm)
func is_ready(_world: Object,_epoch: int) -> bool:return ready_value
func complete(world: Object,epoch: int) -> void:completed.append([world.get_instance_id(),epoch])
func abort(_world: Object,epoch: int,reason: String) -> void:aborted.append([epoch,reason])
func drain() -> void:await process_frame;await process_frame
func request(fence,owner,world,draw) -> void:
	check(fence.request(owner,world,7,is_ready,complete,abort,dispatch,draw.completed),"request accepted")
func arm_last() -> void:var arm: Callable=arms.pop_back();arm.call()
func click_at(position: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.global_position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
func gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:click_count+=1
func controls(node: Node) -> Array:
	var result: Array=[]
	if node is Control:result.append(node)
	for child in node.get_children():result.append_array(controls(child))
	return result
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(800,600)
	var owner:=Node.new();root.add_child(owner)
	var world:=World.new();root.add_child(world)
	var draw:=DrawSource.new();var fence:=Fence.new()
	request(fence,owner,world,draw)
	# Simulate a postdraw deferred by an OLDER render before the sentinel.
	draw.completed.emit.call_deferred();arms.back().call_deferred();arms.clear()
	await drain()
	check(completed.is_empty() and fence.snapshot().phase=="armed","old queued postdraw drains before deferred main arm and cannot finish")
	check(draw.completed.get_connections().size()==1,"one bounded future draw subscription")
	draw.completed.emit();check(draw.completed.get_connections().is_empty(),"oneshot disconnects before deferred callback")
	check(completed.is_empty(),"draw callback is deferred onto main queue")
	await drain();check(completed.size()==1 and not fence.snapshot().pending,"future normal completed draw releases exactly once")
	draw.completed.emit();await drain();check(completed.size()==1,"repeated draw cannot complete twice")
	request(fence,owner,world,draw);arm_last();draw.completed.emit();fence.cancel();await drain()
	check(completed.size()==1 and not fence.snapshot().pending,"already queued oneshot completion cannot survive cancellation")
	request(fence,owner,world,draw);var old_arm: Callable=arms.pop_back();request(fence,owner,world,draw);old_arm.call()
	check(fence.snapshot().phase=="sentinel" and draw.completed.get_connections().is_empty(),"old serial arm cannot subscribe a replacement request")
	arm_last();ready_value=false;draw.completed.emit();await drain()
	check(completed.size()==1 and aborted.back()[1]=="unready_after_draw","readiness loss at completed draw aborts")
	request(fence,owner,world,draw);arm_last();check(not fence.snapshot().pending and aborted.back()[1]=="unready_before_arm","unready request never subscribes")
	ready_value=true
	request(fence,owner,world,draw);owner.queue_free();arm_last();await drain();check(not fence.snapshot().pending,"queued owner destruction rejects queued arm")
	owner=Node.new();root.add_child(owner)
	request(fence,owner,world,draw);arm_last();world.free();draw.completed.emit();await drain();check(completed.size()==1 and not fence.snapshot().pending,"freed world rejects queued draw completion")
	world=World.new();root.add_child(world)
	check(fence.request(owner,world,7,func(_w,_e):fence.cancel();return true,complete,abort,dispatch,draw.completed),"reentrant readiness case accepted")
	arm_last();check(not fence.snapshot().pending and draw.completed.get_connections().is_empty(),"reentrant cancellation from readiness cannot connect stale callback")
	fence.close();fence.close();check(not fence.request(owner,world,7,is_ready,complete),"closed helper rejects requests")
	owner.free();world.free()
	# Actual original loading-screen UI and actual viewport GUI hit tests.
	var under:=Control.new();under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);under.mouse_filter=Control.MOUSE_FILTER_STOP;under.gui_input.connect(gui_input);root.add_child(under)
	var source:=Source.new();root.add_child(source);world=World.new();root.add_child(world);source.world=world
	var original:=Original.new();root.add_child(original)
	var candidate:=Candidate.new();root.add_child(candidate);source.loading_screen=candidate;candidate.set_presentation_source(source);candidate.presentation_test_dispatch=dispatch;candidate.presentation_test_signal=draw.completed
	await drain()
	var good:={"terrain":true,"player":true,"camera":true,"tiles":5,"total_tiles":5,"errors":[]}
	original.begin(7,"Fixture");original.advance(7,good)
	candidate.begin(7,"Fixture");await drain()
	var mode_controls:=controls(candidate.veil);var before_modes:=mode_controls.map(func(c):return c.mouse_filter)
	click_count=0;click_at(Vector2(8,8));await drain();check(click_count==0,"active opaque original overlay blocks real viewport GUI mouse hit")
	candidate.advance(7,good)
	check(candidate.active==original.active and candidate.blocks_input()==original.blocks_input() and candidate.modal_lease.active==original.modal_lease.active,"canonical readiness/modal/blocks_input completion matches original")
	check(candidate.stats==original.stats and candidate.history.size()==original.history.size() and candidate.milestones==original.milestones,"original completion stats/history and milestone semantics preserved")
	check(candidate.presentation_pending and candidate.veil.visible and not original.veil.visible,"only candidate presentation remains covered")
	check(controls(candidate.veil).all(func(c):return c.mouse_filter==Control.MOUSE_FILTER_IGNORE),"all actual overlay descendants ignore GUI mouse input during presentation pending")
	var positions: Array[Vector2]=[Vector2(8,8),candidate.back.get_global_rect().get_center()]
	for position in positions:
		click_count=0;click_at(position);await drain();check(click_count==1,"pending cover permits actual underlying GUI input at background and button position")
		mouse_proof.append({"position":[position.x,position.y],"underlying_clicks":click_count})
	draw.completed.emit();await drain();check(candidate.veil.visible,"old unarmed postdraw cannot hide cover")
	arm_last();draw.completed.emit();await drain();check(not candidate.veil.visible and not candidate.presentation_pending,"new completed frame hides veil")
	check(mode_controls.map(func(c):return c.mouse_filter)==before_modes,"completed fence restores exact original descendant mouse filters")
	# Every lifecycle hazard occurs AFTER an emitted oneshot queued its callback.
	for hazard in ["new_epoch","reset","source_replaced","source_closing","source_queued_free","overlay_replaced","world_hidden","world_retiring","world_closed","world_not_ready","new_error","early_dismiss","same_epoch_begin"]:
		source.epoch=7;source.closing=false;source.world=world;source.loading_screen=candidate;world.retiring=false;world.closed=false;world.ready_value=true;world.show()
		candidate.begin(7,"Fixture");candidate.advance(7,good);arm_last();draw.completed.emit()
		match hazard:
			"new_epoch":source.epoch=8;candidate.begin(8,"Next")
			"reset":candidate.reset()
			"source_replaced":source.world=World.new();root.add_child(source.world)
			"source_closing":source.closing=true
			"source_queued_free":source.queue_free()
			"overlay_replaced":source.loading_screen=original
			"world_hidden":world.hide()
			"world_retiring":world.retiring=true
			"world_closed":world.closed=true
			"world_not_ready":world.ready_value=false
			"new_error":var failed: Dictionary=good.duplicate(true);failed.errors=["fixture failure"];candidate.advance(7,failed)
			"early_dismiss":candidate.begin(7,"New active");candidate.dismiss_early()
			"same_epoch_begin":candidate.begin(7,"Same epoch replaced")
		var completed_before:=int(candidate.presentation_stats.completed);await drain()
		check(int(candidate.presentation_stats.completed)==completed_before,"queued draw cannot count stale presentation after "+hazard)
		if hazard in ["new_epoch","same_epoch_begin"]:check(candidate.active and candidate.veil.visible,"stale completion cannot hide replacement active cover "+hazard)
		elif hazard in ["reset","early_dismiss"]:check(not candidate.veil.visible,"reset/early dismissal remains hidden "+hazard)
		else:check(not candidate.veil.visible and not candidate.presentation_pending,"invalid completed-generation cover cannot remain stranded "+hazard)
		if not is_instance_valid(source):source=Source.new();root.add_child(source);source.world=world;source.loading_screen=candidate;candidate.set_presentation_source(source)
		if source.world!=world:source.world.free();source.world=world
		check(draw.completed.get_connections().is_empty(),"no retained postdraw signal after "+hazard)
	candidate.reset();check(candidate.presentation_mouse_modes.is_empty(),"reset clears bounded mouse restoration records")
	candidate.free();original.free();source.free();world.free();under.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"mouse_proof":mouse_proof,"scope":"Headless source/lifecycle/actual viewport GUI input proof only. Fake render sentinel/postdraw ordering; no GPU pipeline or timing claim. Shared loading screen and ACK/control code unchanged."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
