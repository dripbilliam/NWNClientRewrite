extends Node
const Core = preload("res://systems/area_visual_state.gd")
var manager
var effect_id := 0
var definition: Dictionary
var state: Dictionary
var closed := false
var providers: Dictionary
var clips := ["","impact","duration","cessation"]

func configure(owner,id: int,data: Dictionary) -> bool:
	manager = owner;effect_id = id;definition = data;state = data.state.duplicate(true)
	state.model = manager.create_model(id,str(state.model.resource)) if state.model != null else null
	if data.state.model != null and state.model == null: return false
	state.since = manager.client.client_dummies._world_time()
	var clock: Dictionary = manager.client.client_dummies._providers(0)
	providers = {"now":func():return manager.client.client_dummies._world_time(),"difference":clock.difference,"speed40":func():_diagnose("network.area-visual-speed-unverified","Native special visual speed configuration is unavailable");return 1.0,
		"string":func(_visual,column):return definition.query.string.get(column,{"found":false,"value":""}),
		"oneShot":func(name,position,height,priority,delay,volume):manager.client.world_audio.one_shot(name,position,height,priority,delay,volume,effect_id),
		"animationLength":func(e,phase):return PackedFloat32Array([e.model.clip_length(clips[phase])*1000.0])[0],
		"play":func(e,phase,speed,flags,time):
			if not e.model.play_effect_clip(clips[phase],speed,flags,time): _diagnose("visual.area-animation-unavailable",clips[phase]),
		"createSound":_create_sound,
		"stopSound":func(sound):manager.client.world_audio.stop(sound),"destroySound":func(sound):manager.client.world_audio.destroy(sound),
		"sound3d":func(sound,value):manager.client.world_audio.setting(sound,"setting1401d9e90",value),"soundPriority":func(sound,value):manager.client.world_audio.setting(sound,"setting1401da060",value),"soundLooping":func(sound,value):manager.client.world_audio.setting(sound,"setting1401d9f90",value),"playSound":func(sound):manager.client.world_audio.play(sound),"updateSound":func(sound,position,height):manager.client.world_audio.move(sound,position,height),
		"setScene":func(e,_scene):
			if is_instance_valid(e.model): e.model.visible = false,
		"destroy":func(e):e.destroyed = true}
	if state.model != null:
		state.model.position = Vector3(float(state.position[0]),float(state.position[2]),-float(state.position[1]));state.model.visible = true
	if state.orient198: _diagnose("network.area-visual-ground-orientation-unhandled","Native area visual ground-normal orientation is not connected")
	for warning in definition.warnings:
		var warning_data: Dictionary=warning.duplicate(true);warning_data.erase("code")
		match str(warning.code):
			"visual.area-camera-shake-pending":_diagnose("network.area-visual-shake-unhandled","Native area visual camera shake is not connected",warning_data)
			"visual.area-orientation-mode-pending":_diagnose("network.area-visual-orientation-unhandled","Native special area visual orientation is not connected",warning_data)
			"visual.area-default-animation-pending":_diagnose("network.area-visual-default-animation-unhandled","Native special area visual default playback is not connected",warning_data)
			_:_diagnose(str(warning.code),"Original special area effect renderer owner remains unported",warning_data)
	Core.start(state,1,providers)
	if state.model != null and not state.remaining17c: _diagnose("network.area-visual-zero-animation-length","Native area visual has no positive impact countdown; it is retained by the native AI rule",{"model":str(definition.get("state",{}).get("model",{}).get("resource",""))})
	_diagnose("network.area-visual-scene-adapter-incomplete","Native area-effect selection, playback and AI are connected; asynchronous resource/cache, scene visibility and client clock scheduling remain unverified")
	return true

func _create_sound(name: String) -> Variant:
	var sound: int=manager.client.world_audio.create_sound(name,effect_id)
	return sound if sound>=0 else null

func _diagnose(code: String,detail: String,data: Dictionary={}) -> void: manager.diagnose(code,detail,effect_id,data)
func advance() -> void:
	if not closed: Core.advance(state,providers)
func close() -> void:
	if closed: return
	closed = true
	if state.get("sound170") != null:manager.client.world_audio.stop(state.sound170);manager.client.world_audio.destroy(state.sound170);state.sound170 = null
	if is_instance_valid(state.get("model")): manager.release_model(state.model)
	state.model = null;queue_free()
