extends RefCounted

# Area phase1407e90b0 -> UpdateSky1407e9cb0 -> Scene::SetSkyAlpha1400d3d40.
# Physical SkyBoxes columns: DAWN=0 DAY=1 DUSK=2 NIGHT=3.
const F = preload("res://systems/area_environment_state.gd")
var current := 1
var target := 1
var alpha := 0.0
var completed := 1
var requested := 1

func reset(index: int) -> void:
	current = index; target = index; completed = index; requested = index; alpha = 0.0

func set_alpha(value: float, index: int) -> void:
	if index == current: return
	alpha = maxf(0.0, F.f(value))
	if alpha >= 1.0:
		current = index; alpha = 0.0
		return
	target = index

func advance(mode: String, elapsed: float, duration: float, night: bool) -> void:
	if mode not in ["dawn", "dusk"]:
		set_alpha(1.0, 3 if night else 1)
		return
	var t := minf(1.0, F.f(F.f(elapsed) / F.f(duration))) if duration > 0 else 1.0
	if t >= 1.0:
		requested = 1 if mode == "dawn" else 3
		completed = requested
		set_alpha(1.0, requested)
		return
	var value := 1.0
	if t < F.f(.4):
		requested = 0 if mode == "dawn" else 2
		value = F.f(t * 2.5)
	elif t > F.f(.6):
		requested = 1 if mode == "dawn" else 3
		value = F.f(F.f(t - F.f(.6)) * 2.5)
	if completed != requested:
		value = clampf(value, 0.0, 1.0)
		if value >= F.f(.99): completed = requested; value = 1.0
		set_alpha(value, requested)
