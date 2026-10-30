extends RefCounted
# Supported rendering-server callback; diagnostics only. No scene/resource access
# on the render thread, and no presentation-thread wait for this observation.
var mutex:=Mutex.new()
var observation: Dictionary={}
func request() -> void:
	if RenderingServer.has_method("call_on_render_thread"): RenderingServer.call_on_render_thread(observe)
func observe() -> void:
	var value:={"observed":true,"thread_id":OS.get_thread_caller_id(),"main_thread_id":OS.get_main_thread_id()}
	value.separate=value.thread_id!=value.main_thread_id
	mutex.lock(); observation=value; mutex.unlock()
func snapshot() -> Dictionary:
	if not mutex.try_lock(): return {"observed":false,"metadata_busy":true}
	var value: Dictionary=observation.duplicate(); mutex.unlock()
	return value if not value.is_empty() else {"observed":false,"pending":true}
