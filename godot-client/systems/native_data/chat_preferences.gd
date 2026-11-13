extends RefCounted
const DEFAULTS={"width":720,"x":0,"bottom":0,"compact_prompt":false,"font_size":14,"opacity":1.0,"timestamps":false,"seconds":false,"autoscroll":true,"locked":false,"split":false,"history":200,"mask_combined":0xffffffff,"mask_left":0x74f,"mask_right":0x100000b0,"show_talk":true,"show_shout":true,"show_whisper":true,"show_tell":true,"show_party":true,"show_dm":true,"show_system":true,"ui.text-bubble-mode":2,"ui.large-font":true}
static func clean(value: Dictionary) -> Dictionary:
	var result:=DEFAULTS.duplicate()
	for key in result:
		if not value.has(key): continue
		if key=="ui.text-bubble-mode":
			# Canonical persisted INT, not a clamped numeric/string or BOOL alias.
			if value[key] is int and value[key]>=0 and value[key]<=2:result[key]=value[key]
		elif result[key] is bool:
			if value[key] is bool: result[key]=value[key]
		elif value[key] is int or value[key] is float:
			if is_finite(float(value[key])): result[key]=value[key]
	result.width=clampi(int(result.width),320,2040); result.font_size=clampi(int(result.font_size),10,28); result.opacity=clampf(float(result.opacity),0,1); result.history=clampi(int(result.history),50,2000)
	result.x=clampi(int(result.x),0,4096); result.bottom=clampi(int(result.bottom),0,4096)
	for key in ["mask_combined","mask_left","mask_right"]: result[key]=clampi(int(result[key]),0,0xffffffff)
	return result
static func load_settings(path: String) -> Dictionary:
	var config:=ConfigFile.new(); var value: Dictionary={}
	if not path.is_empty() and config.load(path)==OK:
		for key in DEFAULTS: value[key]=config.get_value("chat-hud",key,DEFAULTS[key])
	return clean(value)
static func save_settings(path: String,value: Dictionary) -> void:
	if path.is_empty(): return
	var config:=ConfigFile.new(); config.load(path)
	var normalized:=clean(value)
	for key in normalized: config.set_value("chat-hud",key,normalized[key])
	config.save(path)
static func visible(row: Dictionary,settings: Dictionary) -> bool:
	if row.get("system",false): return bool(settings.show_system)
	var channel:=int(row.get("channel",1)); var key: String
	if channel in [14,17,18,19,20,22,30]: key="show_dm"
	elif channel in [2,9]: key="show_shout"
	elif channel in [3,10,19]: key="show_whisper"
	elif channel in [4,20]: key="show_tell"
	elif channel in [6,22]: key="show_party"
	elif channel in [14,30]: key="show_dm"
	else: key="show_talk"
	return bool(settings[key])
