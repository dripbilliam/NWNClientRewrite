extends "res://native_session_world.gd"
# Isolated headless test entry only. The complete ordinary SessionWorld ingress,
# accepted connection and source UI owners remain the real inherited methods.
var script_floating_probe_started:=false
func application_exit_policy()->bool:
	report.scope="Owned original-server ScriptFloating packet/layout lifecycle only. Dedicated Host readiness/provenance checks apply; generic movement/picking and native pixel acceptance are not claimed."
	report.script_floating_entry={"movement_acceptance":false,"pixel_acceptance":false,"dedicated_readiness":true}
	return true
func receive(message: Dictionary)->void:
	if message.get("kind")=="probe-script-floating":
		if args.get("script-floating-check","")!="true" or closing or script_floating_probe_started:return
		if int(message.get("connection",-1))!=session_connection or session_connection==cancelled_connection:return
		script_floating_probe_started=true
		var probe=preload("res://tests/native_live_composed_text_probe.gd").new() if args.get("ordinary-speech-check","")=="true" else preload("res://tests/native_live_script_floating_probe.gd").new();host.add_child(probe);probe.run(self)
		return
	super.receive(message)
