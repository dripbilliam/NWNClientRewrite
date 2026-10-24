extends RefCounted

# Original area requests1407e69a0/69e0, frame block1407e8f21..903a and
# visual setter1407e63c0. This is state only; no invented rain/snow emitter.
const F = preload("res://systems/area_environment_state.gd")
var current := 0
var target := 0
var remaining := 0
var intensity := 0.0
var instances := 0
var created := 0
var removed := 0
var samples := 0

func request(type: int, enabled: bool) -> void:
	target = type if enabled else 0
	remaining = 6000

func set_visual(type: int, percent: float) -> void:
	var value := F.f(percent)
	if not value >= 0.0: value = 0.0
	elif value > 100.0: value = 100.0
	intensity = value
	if value == 0.0 or current != type:
		removed += instances;instances = 0;current = 0
	if value != 0.0 and current != type:
		if type != 0: instances = 6;created += 6
		current = type
	samples += 1

func advance(milliseconds: int, fade_times: Dictionary) -> void:
	if remaining == 0: return
	if milliseconds < remaining:
		var duration := int(fade_times.get(str(current),6000))
		var type := target if target != 0 else current
		# Original SUB EAX is zero-extended before CVTSI2SS RAX. Preserve
		# unsigned wrapping, including unusual custom FadeTime values.
		var numerator := (duration-remaining)&0xffffffff if target != 0 else remaining
		var ratio := F.f(F.f(float(numerator))/F.f(float(duration))) if duration != 0 else NAN if numerator == 0 else INF
		set_visual(type,F.f(ratio*100.0))
		remaining -= milliseconds
	else:
		remaining = 0
		set_visual(target,100.0 if target != 0 else 0.0)

func snapshot() -> Dictionary:
	return {"current":current,"target":target,"remainingMs":remaining,"intensity":intensity,"clipFraction":F.f(intensity/100.0),"plannedInstances":instances,"created":created,"removed":removed,"samples":samples,"presentationPending":true}
