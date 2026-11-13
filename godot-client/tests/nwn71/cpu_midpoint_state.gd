extends SceneTree
const Effect=preload("res://systems/native_render/native_gamma_effect.gd")
const Post=preload("res://systems/native_render/native_postprocess.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty():quit(2);return
	var failures: Array=[];var effect:=Effect.new()
	effect.set_surface_output(true)
	if not effect.set_postprocess({"mask":28,"midpoint":.4,"intensity":.35,"vibrance":.7}):failures.append("contrast selection")
	var frame:=Post.empty_frame();frame[3]=0
	var revision:=int(effect.postprocess_state().revision)
	if not effect.publish_postprocess_frame(frame,revision):failures.append("contrast publication")
	if effect.cpu_midpoint_enabled and effect.cpu_tone_bytes.size()!=16:failures.append("contrast tone packet")
	if effect.snapshot().postprocess_waiting:failures.append("contrast waiting")
	if not effect.set_postprocess({"mask":8,"vibrance":.7}):failures.append("vibrance selection")
	if effect.cpu_midpoint_enabled and effect.cpu_tone_bytes.size()!=16:failures.append("vibrance tone packet")
	if effect.snapshot().postprocess_waiting:failures.append("vibrance waiting")
	if not effect.set_postprocess({}):failures.append("clear selection")
	if effect.cpu_midpoint_enabled and not effect.cpu_tone_bytes.is_empty():failures.append("tone not cleared")
	if not effect.postprocess_state().options.is_empty():failures.append("options not cleared")
	effect.set_surface_output(false)
	if effect.postprocess_state().retail:failures.append("surface output still enabled")
	effect.close()
	var result:={"success":failures.is_empty(),"failures":failures,"cpu_mode":effect.cpu_midpoint_enabled,"scope":"CPU-only state and reset check; no rendering or FPS"}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result));file.close()
	quit(0 if result.success else 1)
