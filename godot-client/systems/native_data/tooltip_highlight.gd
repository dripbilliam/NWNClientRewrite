extends RefCounted
# Original action97 / switch49 in6ed720 and held refresh6f16f9..1736.
# World highlight enable and the latched/physical state are distinct fields.
const DEFAULT_MS:=200
const MIN_MS:=0
const MAX_MS:=1000
const REFRESH_MS:=100
var held:=0
var phase:=0
var previous:=0
var refresh:=0
var enabled:=false
static func uint32(value: int) -> int: return value&0xffffffff
func key(pressed: bool,now: int,threshold: int=DEFAULT_MS) -> int:
	var value:=int(pressed)
	if held==value: return -1
	enabled=pressed; now=uint32(now)
	var elapsed:=uint32(now-previous); var keep_held:=pressed
	match phase:
		0: phase=1 if pressed else 0
		1: phase=2 if not pressed and elapsed<uint32(threshold) else 0
		2: phase=3 if pressed and elapsed<uint32(threshold) else 0
		3:
			if not pressed and elapsed<uint32(threshold): phase=4; keep_held=true
			else: phase=0
		_: phase=0
	held=int(keep_held); previous=now; return value
func advance(now: int) -> int:
	now=uint32(now)
	if held==0 or uint32(now-refresh)<=REFRESH_MS: return -1
	enabled=true; refresh=now; return held
func clear() -> void:
	held=0; phase=0; previous=0; refresh=0; enabled=false
