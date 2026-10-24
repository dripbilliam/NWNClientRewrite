extends RefCounted

const Runs = preload("res://systems/model_runs.gd")
const Pose = preload("res://systems/model_native_pose.gd")
var pose := Pose.new()
var gob: Dictionary
var model: Dictionary
var entry: Dictionary
var descriptors: Dictionary = {}
var events: Array = []
var diagnostics: Array = []
var providers: Dictionary
var closed := false

func configure(asset: Dictionary, source: Dictionary, entity: Dictionary) -> void:
	entry = entity
	pose.configure(asset.nativeAnimation, source, entity.nodes, entity.manual_poses)
	for clip in asset.clips:
		descriptors[str(clip.name)] = {"name": str(clip.name), "length90": clip.length, "transition94": clip.transition, "events": clip.events, "native": asset.nativeAnimation.clips.get(str(clip.name), {})}
	gob = {"model68": descriptors, "model80": null, "runsE0": [], "root90": true, "period188": 0}
	providers = {"findAnimation": func(_resource, name): return descriptors.get(Runs.lower(name)), "createRun": func(_clip): return {}, "destroyRun": func(_run, _bytes): pass,
		"animationScale": func(_resource, _clip): return 1.0, "playbackScale": func(_gob): return 1.0, "event": _event,
		"applyClip": _apply, "animateEvents": _animate_events, "updateRoot": func(_root, _delta): pass, "periodicUpdate": func(_gob): pass}

func diagnose(message: String) -> void:
	if not diagnostics.has(message): diagnostics.append(message)

func play(name: Variant, speed: float, flags: int, time: float) -> bool:
	if flags & 256:
		diagnose("native motion-run controller provider unavailable")
		return false
	var key := Runs.lower(str(name)) if name != null else ""
	if descriptors.has(key) and not descriptors[key].native.has("root"):
		diagnose(str(descriptors[key].native.get("unavailable", "native clip storage unavailable")))
		return false
	return Runs.play(gob, name, speed, flags, time, providers) != 0

func advance(delta: float) -> void:
	Runs.advance(gob, delta, providers)
	for message in pose.diagnostics: diagnose(message)

func _event(name: String, _data: Variant) -> void:
	events.append(name)

func _animate_events(clip: Dictionary, previous: float, time: float, reverse: int) -> void:
	# Same interval/sentinel owner already used by ordinary creature animation.
	for name in event_names(clip.events, previous, time, reverse): _event(name, null)

static func event_names(source: Array, from: float, to: float, flags: int = 0) -> Array:
	from = Runs.f(from); to = Runs.f(to)
	var result: Array = []
	if flags & 2: from = -1e9; to = 1e9; flags &= ~2
	if flags & 1:
		if to > from:
			result.append_array(event_names(source, from, -1e9, flags))
			from = 1e9
		for index in range(source.size() - 1, -1, -1):
			var at := Runs.f(source[index].time)
			if at >= to and from > at: result.append(str(source[index].name))
	else:
		if from > to:
			result.append_array(event_names(source, from, 1e9, flags))
			from = -1e9
		for event in source:
			var at := Runs.f(event.time)
			if to >= at and at > from: result.append(str(event.name))
	return result

func _apply(clip: Dictionary, previous: float, time: float, weight: float, scale_value: float, _motion: Variant, _reverse: int) -> void:
	if clip.native.has("root"):
		pose.apply(clip.native.root, previous, time, weight, scale_value, entry.manual_poses)
	else:
		diagnose("active native clip has no controller storage")

func close() -> void:
	if closed: return
	closed = true
	Runs.play(gob, null, 1, 0, 0, providers)
	events.clear()
	# Parts retain physical dictionaries with child arrays, never parent cycles.
	pose.parts.clear()
	pose.root_part = {}
	pose.nodes = []
	pose.binding = {}
	entry = {}
	model = {}
	descriptors.clear()
	providers.clear()
