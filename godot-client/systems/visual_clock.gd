extends Node

# Native frame clock for an owned visual phase instance. Resource completion,
# selection/placement and canonical effect lifetime remain the outer owner's
# responsibility. A retirement notification does not destroy/reorder its list.
signal retired
var runtime
var started := false
var closed := false
var announced := false
var elapsed_ms := 0.0
var previous_ms := 0.0
var frames := 0
var quiet_host_available: Callable
var last_native_quiet:=false

func configure(value) -> void:
	assert(runtime == null and not closed, "Visual clock cannot be reused")
	runtime = value
	process_priority = 40 # Phase decisions precede effect attachment/animation.

func start() -> void:
	if closed or runtime == null:
		return
	started = true
	runtime.start()

func stop(requested: int = 1) -> void:
	if not closed and runtime != null:
		runtime.stop(requested)

func advance(delta: float) -> bool:
	last_native_quiet=false
	if closed or not started or runtime == null or not is_finite(delta) or delta < 0.0:
		return false
	# Preserve sub-millisecond remainder. Repeated fractional frame deltas must
	# not lose time by truncating each frame independently. This matches the
	# existing scene adapter's elapsed/previous whole-millisecond conversion.
	var quiet_elapsed: Variant=null
	if quiet_host_available.is_valid() and not runtime.disposed and runtime.state.sound118==null:
		quiet_elapsed=ClassDB.class_call_static("NwnParticleKernel","advance_quiet_visual_clock",runtime.state,delta,elapsed_ms,previous_ms,quiet_host_available)
	if quiet_elapsed is float:
		last_native_quiet=true
		elapsed_ms=quiet_elapsed
		previous_ms=floor(elapsed_ms)
	else:
		elapsed_ms += delta * 1000.0
		var now: float = floor(elapsed_ms)
		var step := int(fmod(now - previous_ms, 4294967296.0)) & 0xffffffff
		previous_ms = now
		runtime.update_milliseconds(step)
	frames += 1
	if not announced and runtime.is_retired():
		announced = true
		retired.emit()
	return true

func _process(delta: float) -> void:
	advance(delta)

func close() -> void:
	if closed:
		return
	closed = true
	set_process(false)
	if runtime != null:
		runtime.dispose()
	queue_free()

func _exit_tree() -> void:
	if runtime != null:
		runtime.dispose()
