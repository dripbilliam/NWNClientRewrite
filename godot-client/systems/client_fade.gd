extends RefCounted
# CNWCObject765920 /762e40; provider calls retain native ordering. These are
# presentation objects, never authoritative server effects or gameplay IDs.
static func f(value: float) -> float: return PackedFloat32Array([value])[0]
static func snapshot_milliseconds(value: int) -> int:
	if value >= 0: return (value/1000)&0xffffffff
	# Interpret a negative signed host word as native unsigned64 before /1000.
	return (18446744073709551+value/1000+(-1 if 616+value%1000 < 0 else 0))&0xffffffff

static func set_fade(s: Dictionary,target: int,delay: int,duration: int,p: Dictionary) -> void:
	if int(s.temporary) == 1 or int(s.blocked) != 0: return
	s.fadeTarget = target&255;s.delayEnabled = delay;s.duration = duration&0xffffffff
	if s.delayEnabled != 0: s.since = p.worldTime.call().duplicate()
	var mode: int = int(p.mode.call())&255
	if s.fadeTarget == 1:
		if p.modelHandle.call(s):
			if mode == 2:
				p.display.call(s,0x210);p.display.call(s,0x200);s.visible = 1;return
			if mode == 1 and (int(p.controlledId.call())&0xffffffff) == (int(s.id)&0xffffffff):
				p.display.call(s,0x210);p.display.call(s,0x200);s.visible = 1;return
			p.display.call(s,0x218);p.display.call(s,0x1f8);s.visible = 1
	else:
		if p.modelHandle.call(s):
			if mode == 2: p.display.call(s,0x218);p.display.call(s,0x200)
			elif mode == 1: p.controlledId.call();p.display.call(s,0x218);p.display.call(s,0x200)
			else: p.display.call(s,0x218);p.display.call(s,0x1f8)
		s.visible = 0

static func update(s: Dictionary,p: Dictionary) -> int:
	if (int(s.fadeState)&255) == (int(s.fadeTarget)&255):
		if int(s.delayEnabled) != 0:
			var elapsed: Dictionary = p.difference.call(p.worldTime.call(),s.since)
			if (int(s.duration)&0xffffffff) <= (int(elapsed.time)&0xffffffff): return 1
	else:
		var milliseconds := snapshot_milliseconds(int(p.snapshotDifference.call()))
		if (int(s.fadeTarget)&255) == 1:
			var target := f(p.targetAlpha.call(s))
			if f(s.opacity) < target: s.fadeState = 2;s.opacity = f(f(f(milliseconds)/2000)+f(s.opacity))
			else: s.fadeState = 1;s.opacity = f(p.targetAlpha.call(s))
		elif (int(s.fadeTarget)&255) == 0:
			var target := f(p.targetAlpha.call(s))
			if target < f(s.opacity): s.fadeState = 3;s.opacity = f(f(s.opacity)-f(f(milliseconds)/2000))
			else:
				s.opacity = f(p.targetAlpha.call(s));s.fadeState = 0
				if int(s.delayEnabled) != 0: s.since = p.worldTime.call().duplicate();p.handleScene.call(s,0)
		if s.opacity < 0: s.opacity = 0
		elif s.opacity > 1: s.opacity = 1
		if p.modelHandle.call(s): p.alpha.call(s,f(s.opacity),255)
	return 0
