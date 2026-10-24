extends RefCounted
# Original CNWCVisualEffect873160 /872330. Loader selection remains the shared
# original-derived JS routine; this owns native per-frame phase/countdown state.
static func start(e: Dictionary,phase: int,p: Dictionary) -> void:
	phase &= 65535;e.remaining17c = 0;e.phase184 = phase
	var speed: float = p.speed40.call() if int(e.visual180) == 40 else 1.0
	if phase == 1 or phase == 3:
		var sound: Dictionary = p.string.call(e.visual180,"SoundImpact" if phase == 1 else "SoundCessation")
		p.oneShot.call(sound.value if sound.found else "",e.position.duplicate(),1.5,11,0,0)
		if phase == 3 and e.sound170 != null: p.stopSound.call(e.sound170);p.destroySound.call(e.sound170);e.sound170 = null
		if e.model != null:
			e.remaining17c = int(PackedFloat32Array([float(p.animationLength.call(e,phase))])[0])&0xffffffff
			p.play.call(e,phase,speed,int(int(e.repeat1a4) == 0),0)
	else:
		var sound: Dictionary = p.string.call(e.visual180,"SoundDuration")
		e.sound170 = p.createSound.call(sound.value if sound.found else "")
		if e.sound170 != null:
			p.sound3d.call(e.sound170,1);p.soundPriority.call(e.sound170,11);p.soundLooping.call(e.sound170,1);p.playSound.call(e.sound170)
		if e.model != null: p.play.call(e,phase,speed,0,0)

static func advance(e: Dictionary,p: Dictionary) -> void:
	if e.suppressed18c: return
	var now: Dictionary = p.now.call()
	e.elapsed58 = int(p.difference.call(now,e.since).time)&0xffffffff;e.since = now.duplicate()
	if e.sound170 != null: p.updateSound.call(e.sound170,e.position.duplicate(),1.5)
	if e.remaining17c:
		if e.elapsed58 < e.remaining17c: e.remaining17c = (int(e.remaining17c)-int(e.elapsed58))&0xffffffff
		else:
			e.remaining17c = 0
			if int(e.phase184) == 1:
				if not e.instant190: start(e,2,p)
				else: e.retiring188 = 1;e.retire178 = 0 if e.skipRetirement1a0 else 3000
			elif int(e.phase184) == 3: e.retiring188 = 1;e.retire178 = 3000
	if e.retiring188:
		if e.elapsed58 < e.retire178: e.retire178 = (int(e.retire178)-int(e.elapsed58))&0xffffffff
		elif not e.destroy194:
			if e.detach19c: p.setScene.call(e,null)
			e.suppressed18c = 1;e.retiring188 = 0
		else: p.destroy.call(e)
