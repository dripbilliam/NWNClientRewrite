extends RefCounted

# Retained ClientAnimationQueue / world-time arithmetic. Records retain local
# identity; identical server attacks are separate entries, not deduplicated.
var day_length := 7200000
var entries: Array = []
var capacity := 0
var next_identity := 0
var failure := ""

static func f(value: float) -> float:
	return PackedFloat32Array([value])[0]

static func u32(value: int) -> int:
	return value & 0xffffffff

static func signed(value: int) -> int:
	value &= 0xffffffff
	return value - 0x100000000 if value & 0x80000000 else value

static func compare(a: Dictionary, b: Dictionary, length: int) -> int:
	if a.time >= length or b.time >= length:
		return -2
	if a.day == b.day:
		return 0 if a.time == b.time else (1 if a.time > b.time else -1)
	return 1 if a.day > b.day else -1

func clear() -> void:
	entries.clear()
	capacity=0
	failure=""

func insert(cue: Dictionary, now: Dictionary) -> bool:
	failure=""
	if cue.get("record") != null and cue.record.has("_identity"):
		for entry in entries:
			if entry.get("record") != null and entry.record.get("_identity") == cue.record._identity:
				return false
	if entries.size() >= 255:
		failure="Native animation queue BYTE capacity exceeded"
		return false
	if entries.size()==capacity:capacity+=8
	var delay := u32(int(cue.get("delay", 0)))
	if u32(int(now.time)) >= day_length or delay >= day_length:
		failure="Native animation queue start time is invalid"
		return false
	var start := {"day": u32(int(now.day)), "time": u32(int(now.time) + delay)}
	if start.time >= day_length:
		start.day = u32(start.day + 1)
		start.time -= day_length
	next_identity += 1
	var entry := {"identity":next_identity,"active":1,"animation":int(cue.animation)&65535,"start":start,
		"duration":u32(int(cue.duration)),"speed":f(float(cue.speed)),"record":cue.get("record"),"side":cue.get("side",0)}
	var index := entries.size()
	while index > 0 and compare(start, entries[index - 1].start, day_length) == -1:
		index -= 1
	entries.insert(index, entry)
	return true

func next(now: Dictionary) -> Dictionary:
	if entries.is_empty():
		return {"ready":0,"animation":0,"speed":1.0,"duration":500,"record":null}
	var entry: Dictionary = entries[0]
	var start: Dictionary = entry.start
	var elapsed := 0
	if not (now.time < day_length and start.time < day_length and (now.day < start.day or now.day == start.day and now.time < start.time)):
		elapsed = u32(int(now.time) - int(start.time))
		if elapsed >= day_length:
			elapsed = u32(elapsed + day_length)
	if elapsed == 0 and compare(now, start, day_length) == -1:
		return {"ready":0,"animation":0,"speed":1.0,"duration":500,"record":null}
	var duration := maxi(50, u32(int(entry.duration) - elapsed))
	return {"ready":1,"identity": entry.identity, "animation": entry.animation, "duration": duration, "speed": f(f(f(float(entry.duration)) * entry.speed) / f(float(duration))), "record": entry.get("record"), "side": entry.get("side", 0)}

func remove() -> void:
	if not entries.is_empty():
		entries.pop_front()

func snapshot() -> Dictionary:
	var result: Array=[]
	for entry in entries:
		var copied: Dictionary={"animation":entry.animation,"start":entry.start.duplicate(),"duration":entry.duration,
			"speed":entry.speed,"record":entry.record}
		result.append(copied)
	return {"capacity":capacity,"entries":result}
