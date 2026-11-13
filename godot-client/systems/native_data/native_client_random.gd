extends RefCounted
# Original CRTc7ed00 algorithm. This native client's app-uptime seed/history is
# an explicit adaptation, not another client's TLS or the112 original callers.
static var application_data: Dictionary={"state":1,"draws":0,"initialized":false,"seedKind":"crt_constructor_default"}
var data: Dictionary={"state":1,"draws":0,"initialized":false,"seedKind":"crt_constructor_default"}
var state: int:
	get:return int(data.state)
var draws: int:
	get:return int(data.draws)
var initialized: bool:
	get:return bool(data.initialized)
var seed_kind: String:
	get:return str(data.seedKind)
func seed_once(value: int,kind: String="explicit") -> bool:
	if initialized or OS.get_thread_caller_id()!=OS.get_main_thread_id() or value<0 or value>4294967295:return false
	data.state=value;data.initialized=true;data.seedKind=kind;return true
static func acquire() -> RefCounted:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return null
	# Static primitive data outlives scene/controller handles without a
	# Script→static instance→Script reference cycle at engine shutdown.
	var handle=load("res://systems/native_data/native_client_random.gd").new();handle.data=application_data
	if not handle.initialized:handle.seed_once(Time.get_ticks_msec()&0xffffffff,"godot_application_uptime_msec")
	return handle
func take() -> Dictionary:
	if not initialized or OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"ready":false,"reason":"Native application random state is unavailable on this thread."}
	var before:=state;data.state=(state*0x343fd+0x269ec3)&0xffffffff;data.draws=draws+1
	return {"ready":true,"value":(state>>16)&0x7fff,"seedBefore":before,"seedAfter":state,"draw":draws,"seedKind":seed_kind}
