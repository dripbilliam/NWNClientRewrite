extends "res://tests/native_live_script_floating_probe.gd"
# The inherited strict ScriptFloating16 remain unchanged. Only after those pass
# does this probe submit ordinary speech through the same real native Chat.
var ordinary_result: Dictionary={}
var finishing_ordinary:=false
func completion_payload()->Dictionary:
	var result:=super.completion_payload()
	result.ordinarySpeech=ordinary_result.duplicate(true)
	result.success=result.success and ordinary_result.get("success",false)
	return result
func finish()->void:
	if finishing_ordinary:return
	finishing_ordinary=true
	if failures.is_empty() and current():
		var probe:=preload("res://tests/native_live_ordinary_speech_probe.gd").new();add_child(probe)
		ordinary_result=await probe.run(client,scope,source)
		probe.queue_free()
	else:ordinary_result={"success":false,"failures":["Inherited ScriptFloating proof rejected before ordinary stimulus"]}
	super.finish()
