extends "res://native_session_world.gd"
# Distinct graphical inspection entry. Existing headless assertions are untouched.
var visual_probe_started:=false
func activate_window_from_click(event: InputEvent)->void:
	# The inherited local-fixture chooser uses in-viewport synthetic clicks.
	# They must not activate the OS window during automated admission.
	if not visual_probe_started:return
	super.activate_window_from_click(event)
func receive(message: Dictionary)->void:
	if message.get("kind")=="probe-ordinary-speech-visual":
		if args.get("script-floating-visual","")!="true" or DisplayServer.get_name()=="headless" or closing or visual_probe_started:return
		if message.get("connection")!=session_connection or session_connection==cancelled_connection or not is_instance_valid(world):return
		if message.get("generation")!=epoch or message.get("areaId")!=world.area_id:return
		var seconds:=int(args.get("visual-seconds","120"))
		if seconds<30 or seconds>180 or message.get("seconds")!=seconds:return
		visual_probe_started=true
		var probe=preload("res://tests/native_ordinary_speech_visual_probe.gd").new()
		host.add_child(probe)
		probe.run(self,seconds)
		return
	super.receive(message)
func application_exit_policy()->bool:
	report.scope="Owned original-local graphical speech and area-border inspection. Read-only actual-state observations; no automated pixel, FPS, movement or old headless-check acceptance."
	return true
