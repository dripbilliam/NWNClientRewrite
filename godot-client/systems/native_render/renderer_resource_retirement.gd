extends RefCounted

# Renderer-only disposal queue. WorldRetirement separately waits for scene
# workers before freeing whole worlds; this queue owns only explicit renderer
# resource release callbacks during an incoming area's graphics preparation.
var report: Callable
var holds:=0
var pending: Array[Callable]=[]

func begin() -> Callable:
	holds+=1
	var ended:=false
	return func() -> void:
		if ended:return
		ended=true
		holds=maxi(0,holds-1)
		if holds==0:flush()

func retire(dispose: Callable) -> void:
	if holds>0:pending.append(dispose)
	else:_dispose(dispose)

func _dispose(dispose: Callable) -> void:
	if not dispose.is_valid():
		_failure("Renderer retirement callback is unavailable")
		return
	var result: Variant=dispose.call()
	# GDScript has no catchable exception equivalent. Callers can return an
	# explicit error so one failure does not stop the remaining queue.
	if result is Dictionary and result.has("error"):_failure(str(result.error))

func _failure(message: String) -> void:
	if report.is_valid():report.call("renderer.retirement-failed",message)
	else:push_error("renderer.retirement-failed: "+message)

func flush() -> void:
	var released:=pending.duplicate()
	pending.clear()
	for dispose in released:_dispose(dispose)

func snapshot() -> Dictionary:
	return {"holds":holds,"pending":pending.size()}
