extends RefCounted

# Gob::PlayAnimation140052580 and the run stage of Animate14004e455.
# Port of the retained original-derived owners; callbacks keep allocation,
# physical pose, events and outer scene scheduling explicit.
static var scalar_values:=preload("res://systems/native_data/scalar_representation.gd").configured()
static func f(value: float) -> float:
	return Color(value,0,0,0).r if scalar_values else PackedFloat32Array([value])[0]

static func lower(value: String) -> String:
	var result := ""
	for code in value.length():
		var character := value.unicode_at(code)
		if character == 0: break
		result += String.chr(character + 32 if character >= 65 and character <= 90 else character)
	return result

static func terminate(value: String) -> String:
	for index in value.length():
		if value.unicode_at(index) == 0: return value.substr(0, index)
	return value

static func remove(runs: Array, run: Dictionary) -> void:
	for index in runs.size():
		if is_same(runs[index], run):
			runs.remove_at(index)
			return

static func play(gob: Dictionary, name: Variant, speed: float, flags: int, start: float, p: Dictionary) -> int:
	var runs: Array = gob.runsE0
	speed = f(speed)
	start = f(start)
	if name == null or lower(str(name)) in ["", "null"]:
		for index in range(runs.size() - 1, -1, -1): p.destroyRun.call(runs[index], 40)
		runs.clear()
		return 1
	name = terminate(str(name))
	var run: Variant = null
	if not (flags & 64):
		for index in range(runs.size() - 1, -1, -1):
			if lower(str(runs[index].clip0.name)) == lower(name):
				run = runs[index]
				if flags & 512:
					run.flagsC = int(run.flagsC) | 513
					return 1
				remove(runs, run)
				break
	if run == null and lower(name) == "current":
		for candidate in runs:
			if not (int(candidate.flagsC) & 40):
				run = candidate
				remove(runs, run)
				break
	if flags & 128:
		if run == null: return 0
		p.event.call("done" + str(run.clip0.name), 0)
		p.destroyRun.call(run, 40)
		return 1
	var model: Variant = gob.get("model80")
	var clip: Variant = p.findAnimation.call(model, name) if model != null else null
	if clip == null:
		model = gob.model68
		clip = p.findAnimation.call(model, name)
	var offset := 0.0 if 0 > start else start
	if clip != null: offset = f(clip.length90) if f(clip.length90) < offset else offset
	if run == null:
		if clip == null: return 0
		run = p.createRun.call(clip)
		run.merge({"clip0": clip, "speed8": 1.0, "flagsC": 0, "previous10": 0.0, "time14": 0.0, "weight18": 1.0, "transition1c": 0.0, "scale20": 1.0, "done24": 0}, true)
		if speed < 0: run.time14 = f(f(clip.length90) + f(0.00001))
		if speed > 0: run.time14 = f(-0.00001)
		if offset != 0: run.time14 = offset
		if not (flags & 2):
			run.weight18 = 0.0
			run.transition1c = f(clip.transition94)
	run.scale20 = f(p.animationScale.call(model, clip))
	run.done24 = 0
	run.flagsC = flags
	run.speed8 = f(f(p.playbackScale.call(gob)) * speed)
	var index := 0
	if not (flags & 8):
		while index < runs.size():
			var old := int(runs[index].flagsC)
			if not (old & 8) and ((flags & 32) or not (old & 32)): break
			index += 1
	runs.insert(index, run)
	if (flags & 16) and runs.size() > index + 1:
		run.time14 = runs[index + 1].time14
	elif not (flags & 40):
		while runs.size() > index + 1:
			var old: Dictionary = runs[index + 1]
			remove(runs, old)
			p.event.call("done" + str(old.clip0.name), 0)
			p.destroyRun.call(old, 40)
		p.event.call("start" + str(run.clip0.name), 0)
	return 1

static func advance(gob: Dictionary, delta: float, p: Dictionary) -> void:
	delta = f(delta)
	var runs: Array = gob.runsE0
	if not runs.is_empty() and int(runs[-1].flagsC) & 32:
		runs[-1].flagsC = int(runs[-1].flagsC) - 32
		p.event.call("start" + str(runs[-1].clip0.name), 0)
	for index in range(runs.size() - 1, -1, -1):
		if index >= runs.size(): continue
		var run: Dictionary = runs[index]
		if int(run.flagsC) & 32: continue
		run.previous10 = f(run.time14)
		run.time14 = f(f(run.previous10) + f(f(run.speed8) * delta))
		if int(run.flagsC) & 1:
			if run.done24:
				remove(runs, run)
				p.event.call("done" + str(run.clip0.name), 0)
				p.destroyRun.call(run, 40)
				continue
			var ended := false
			if run.time14 < 0 and run.speed8 <= 0:
				run.time14 = 0.0
				ended = true
			elif run.time14 > f(run.clip0.length90) and run.speed8 >= 0:
				run.time14 = f(run.clip0.length90)
				ended = true
			if int(run.flagsC) & 512 or ended:
				if index > 0 and int(runs[index - 1].flagsC) & 32:
					runs[index - 1].flagsC = int(runs[index - 1].flagsC) - 32
					p.event.call("start" + str(runs[index - 1].clip0.name), 0)
				var transition := f(run.transition1c)
				var decrement := 2.0 if transition <= 0 else f(f(delta + delta) / transition)
				run.weight18 = f(f(run.weight18) - decrement)
				if run.weight18 <= 0:
					run.weight18 = 1.0 if transition == 0 else 0.0
					run.done24 = 1
		else:
			if run.time14 < 0 and run.speed8 <= 0:
				if int(run.flagsC) & 4: p.event.call("loop" + str(run.clip0.name), 0)
				run.time14 = f(f(run.time14) + f(run.clip0.length90))
				if run.time14 < 0: run.time14 = 0.0
			if run.time14 > f(run.clip0.length90) and run.speed8 >= 0:
				if int(run.flagsC) & 4: p.event.call("loop" + str(run.clip0.name), 0)
				run.time14 = f(f(run.time14) - f(run.clip0.length90))
				if run.time14 > f(run.clip0.length90): run.time14 = f(run.clip0.length90)
		if not run.done24 and run.weight18 < 1:
			var increment := 1.0 if run.transition1c <= 0 else f(delta / f(run.transition1c))
			run.weight18 = f(f(run.weight18) + increment)
			if run.weight18 > 1:
				run.weight18 = 1.0
				if not (int(run.flagsC) & 8):
					while runs.size() > index + 1:
						var old: Dictionary = runs[index + 1]
						remove(runs, old)
						p.destroyRun.call(old, 40)
		var reverse := 1 if run.speed8 < 0 else 0
		p.applyClip.call(run.clip0, run.previous10, run.time14, run.weight18, f(run.scale20), run if int(run.flagsC) & 256 else null, reverse)
		p.animateEvents.call(run.clip0, run.previous10, run.time14, reverse)
	if gob.get("root90") != null:
		p.updateRoot.call(gob.root90, delta)
		var old := (int(gob.period188) + 32768) % 65536 - 32768
		gob.period188 = (old + 1) % 5 # Native signed remainder, not positive modulo.
		if gob.period188 == 0: p.periodicUpdate.call(gob)
