extends SceneTree
const Properties=preload("res://systems/native_data/native_device_properties.gd")
func _initialize()->void:
	var expected: PackedByteArray="7036012200000003010e08090000006775695f7363616c650801000000086400000060".hex_decode()
	var result: Dictionary=Properties.request("gui_scale",100)
	if result.has("error") or result.bytes!=expected:fail("native gui_scale packet differs");return
	for key in ["gui_scale","gui_width","gui_height"]:
		var packet: Dictionary=Properties.request(key,0 if key=="gui_scale" else 2560)
		if packet.has("error") or packet.bytes.size()<20:fail("native device property rejected");return
	if not Properties.request("gui_width",0).has("error") or not Properties.request("ui_scale",100).has("error"):fail("invalid native device property was accepted");return
	print("NWN79 Godot native device-property packet PASS")
	quit(0)
func fail(reason: String)->void:
	printerr("NWN79 Godot device-property packet failed: "+reason)
	quit(1)
