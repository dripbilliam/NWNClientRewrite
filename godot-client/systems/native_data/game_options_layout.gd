extends RefCounted
const Definition=preload("res://systems/native_data/menu_definition.gd")
# The Game page shares the same builder and controls as Client Options.
# The connection-owned Mods/CD-key component is attached by its controller.
static func definition() -> Array:
	var choice:=Definition.choice("camera_choice",[["Top-down",1],["Chase",0],["Stiff chase",2]])
	return [Definition.control("tabs","tabs",{"custom_minimum_size":Vector2(510,500)},[
		Definition.control("column","game",{"name":"Game"},[
			Definition.check("creature","Show creature equipment slots"),
			Definition.check("fps_toggle","Show FPS counter"),
			Definition.check("debug_toggle","Show debug window"),
			Definition.check("floating_toggle","Floating combat feedback"),
			Definition.check("totals_toggle","Show total damage only"),
			Definition.control("row","",{},[Definition.label("Camera"),choice])])])]
