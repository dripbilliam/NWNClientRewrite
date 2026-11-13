extends RefCounted
# PRIVATE candidate. Off-thread work is only Callable.call_deferred; all scene,
# readiness and veil operations run after the queue fence on the main thread.
var serial:=0
var closed:=false
var pending: Dictionary={}
var draw_signal: Signal
var draw_callback: Callable
var stats:={"requests":0,"armed":0,"completed":0,"cancelled":0,"stale":0,"unready":0}
func request(owner: Object,world: Object,epoch: int,ready: Callable,complete: Callable,aborted: Callable=Callable(),dispatch: Callable=Callable(),signal_override: Signal=Signal()) -> bool:
	if closed or not is_instance_valid(owner) or not is_instance_valid(world) or not ready.is_valid() or not complete.is_valid():return false
	cancel();serial+=1
	pending={"serial":serial,"epoch":epoch,"owner":weakref(owner),"world":weakref(world),"ready":ready,"complete":complete,"aborted":aborted,"started_us":Time.get_ticks_usec(),"phase":"sentinel"}
	draw_signal=signal_override if not signal_override.is_null() else RenderingServer.frame_post_draw
	var arm:=Callable(self,"arm_on_main").bind(serial)
	stats.requests+=1
	if dispatch.is_valid():dispatch.call(arm)
	else:
		# Rendering FIFO places this after this generation's resource commands.
		# Older _run_post_draw_steps defer calls precede this Main arm defer.
		RenderingServer.call_on_render_thread(func():arm.call_deferred())
	return true
func current(context: Dictionary) -> bool:
	if closed or pending.is_empty() or not is_same(context,pending) or int(context.serial)!=serial:return false
	var owner=context.owner.get_ref();var world=context.world.get_ref()
	return is_instance_valid(owner) and is_instance_valid(world) and (not owner is Node or not owner.is_queued_for_deletion()) and (not world is Node or not world.is_queued_for_deletion())
func arm_on_main(token: int) -> void:
	if pending.is_empty() or token!=serial:stats.stale+=1;return
	var context: Dictionary=pending
	if not current(context):stats.stale+=1;cancel();return
	if not bool(context.ready.call(context.world.get_ref(),int(context.epoch))):abort_context(context,"unready_before_arm");return
	if not current(context):stats.stale+=1;return
	draw_callback=Callable(self,"draw_completed_on_main").bind(token)
	var result:=draw_signal.connect(draw_callback,Object.CONNECT_DEFERRED|Object.CONNECT_ONE_SHOT)
	if result!=OK:abort_context(context,"signal_connect_failed");return
	context.phase="armed";stats.armed+=1
func draw_completed_on_main(token: int) -> void:
	if pending.is_empty() or token!=serial:stats.stale+=1;return
	var context: Dictionary=pending
	if not current(context):stats.stale+=1;cancel();return
	if not bool(context.ready.call(context.world.get_ref(),int(context.epoch))):abort_context(context,"unready_after_draw");return
	# Readiness callbacks can replace/reset/free scene owners reentrantly.
	if not current(context):stats.stale+=1;return
	var complete: Callable=context.complete;var world=context.world.get_ref();var epoch:=int(context.epoch)
	drop_pending();stats.completed+=1
	if complete.is_valid():complete.call(world,epoch)
func abort_context(context: Dictionary,reason: String) -> void:
	if not current(context):cancel();return
	var aborted: Callable=context.aborted;var world=context.world.get_ref();var epoch:=int(context.epoch)
	drop_pending();stats.unready+=1
	if aborted.is_valid():aborted.call(world,epoch,reason)
func drop_pending() -> void:
	if not draw_signal.is_null() and is_instance_valid(draw_signal.get_object()) and draw_callback.is_valid() and draw_signal.is_connected(draw_callback):draw_signal.disconnect(draw_callback)
	pending={};draw_callback=Callable();draw_signal=Signal()
func cancel() -> void:
	serial+=1
	if not pending.is_empty():stats.cancelled+=1
	drop_pending()
func close() -> void:
	if closed:return
	cancel();closed=true
func snapshot() -> Dictionary:
	return {"closed":closed,"serial":serial,"pending":not pending.is_empty(),"phase":str(pending.get("phase","idle")),"stats":stats.duplicate()}
