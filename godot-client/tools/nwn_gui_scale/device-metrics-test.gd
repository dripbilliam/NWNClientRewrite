extends SceneTree
const Session=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var packet: Dictionary=Session.device_properties_packet({"width":2560,"height":1440,"fixed":1.279,"applied":1.0},7,12)
	check(packet.kind=="device-properties" and packet.connection==7 and packet.metricsRevision==12,"Device metrics retain message and connection order")
	check(packet.guiWidth==2560 and packet.guiHeight==1440,"Physical screen pixels are sent unchanged")
	check(packet.guiScalePercent==127,"Requested fixed scale is truncated after multiplication")
	check(Session.device_properties_packet({"width":1920,"height":1080,"fixed":1.0,"applied":1.5},8,13).guiScalePercent==100,"Effective canvas scale does not replace native fixed scale")
	check(Session.device_properties_packet({"width":1920,"height":1080,"fixed":0.0},8,13).guiScalePercent==0,"Native automatic fixed scale zero remains a valid property")
	var same: Dictionary=Session.device_properties_packet({"width":2560,"height":1440,"fixed":1.279,"applied":1.5},7,13)
	var resized: Dictionary=Session.device_properties_packet({"width":1920,"height":1080,"fixed":1.279},7,13)
	var reconnected: Dictionary=Session.device_properties_packet({"width":2560,"height":1440,"fixed":1.279},8,13)
	check(Session.device_properties_signature(packet)==Session.device_properties_signature(same),"Unchanged physical metrics dedupe despite effective-scale changes")
	check(Session.device_properties_signature(packet)!=Session.device_properties_signature(resized),"Changed physical dimensions require a fresh property message")
	check(Session.device_properties_signature(packet)!=Session.device_properties_signature(reconnected),"New connection requires a fresh property message")
	check(Session.device_properties_packet({"width":0,"height":1080,"fixed":1.0},8,13).is_empty(),"Zero width is not published")
	check(Session.device_properties_packet({"width":1920,"height":1080,"fixed":NAN},8,13).is_empty(),"Nonfinite scale is not published")
	check(Session.device_properties_packet({"width":1920,"height":1080,"fixed":1.0},-1,13).is_empty(),"Invalid connection is not published")
	check(Session.device_properties_packet({"width":1920,"height":1080,"fixed":1.0},8,0).is_empty(),"Invalid revision is not published")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
