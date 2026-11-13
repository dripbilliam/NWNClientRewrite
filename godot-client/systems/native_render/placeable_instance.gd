extends "res://systems/native_render/actor_instance.gd"
# Received non-creature animation owns private physical Parts. This neither
# changes server state nor turns all static geometry into animated actors.
const Names = preload("res://systems/native_data/object_animation.gd")
const CODES := [0,14,72,73,74,75,76,77,99,100,213,214,215,216,400,401,402,403,404]
var received_animation := -1
var received_speed: Variant = null
var identified_blocker:=false
var show_blocker:=false
var placeable_stats := {"updates": 0, "plays": 0, "unchanged": 0, "missing_clips": [], "unavailable": [], "transient_rest_policy": "server_code_only"}

static func requires_animation(state: Dictionary) -> bool:
	if not state.has("animation"): return false
	var value: Variant = state.animation
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 0 or value > 65535: return false
	return Names.name(9, int(value)) != "default"

func install_placeable(bundle: Dictionary, shared_pool, id: int, state: Dictionary) -> bool:
	actor_alpha_enabled=true
	identified_blocker=preload("res://systems/native_data/blocker_helper.gd").identified(bundle)
	var source_animation: Variant = state.get("animation")
	if not (source_animation is int or source_animation is float) or not is_finite(float(source_animation)) or float(source_animation) != floor(float(source_animation)) or source_animation < 0 or source_animation > 65535:
		failure = "Received native placeable animation WORD is unavailable"
		return false
	var map: Dictionary = {}
	for code in CODES: map[str(code)] = Names.name(9, code)
	var initial := int(source_animation)
	map[str(initial)] = Names.name(9, initial)
	# ActorInstance selects and samples this original clip while configuring
	# the physical rig, before ObjectStream publishes or reveals the instance.
	if not install([{"bundle": bundle, "anchor": "", "follow": true}], shared_pool, id, {"0": map}, initial): return false
	observe_placeable(state)
	return true

func observe_placeable(state: Dictionary) -> void:
	if retired or not is_instance_valid(rigs) or not state.has("animation"): return
	var value: Variant = state.animation
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 0 or value > 65535:
		if not placeable_stats.unavailable.has("animation_word"): placeable_stats.unavailable.append("animation_word")
		return
	var code := int(value) & 65535
	# The bridge currently exposes animationSpeed only for creatures. Keep the
	# generic animationTime alias explicit until its non-creature receiver is
	# proven; do not treat a speed scalar as an absolute animation timestamp.
	var speed: Variant = state.get("animationSpeed", 1.0)
	if not (speed is int or speed is float) or not is_finite(float(speed)):
		if not placeable_stats.unavailable.has("animation_speed"): placeable_stats.unavailable.append("animation_speed")
		return
	if received_animation == code and received_speed == float(speed):
		placeable_stats.unchanged += 1
		return
	received_animation = code
	received_speed = float(speed)
	placeable_stats.updates += 1
	_publish_received()

func set_show_blockers(enabled: bool) -> void:
	if retired or show_blocker==enabled:return
	show_blocker=enabled
	if identified_blocker and received_animation>=0:_publish_received()

func _publish_received() -> void:
	var code:=received_animation
	var presentation_code:=73 if identified_blocker and show_blocker and code==74 else code
	var clip := Names.name(9, presentation_code)
	var entry: Dictionary = rigs.entities.get(object_id, {})
	if entry.is_empty(): return
	entry.clip_map[str(code)] = clip
	var side_map: Dictionary = entry.side_maps.get("0", entry.clip_map)
	side_map[str(code)] = clip
	if rigs.clip_length(object_id, code) <= 0.0:
		if not placeable_stats.missing_clips.has(clip): placeable_stats.missing_clips.append(clip)
		return
	# Explicit transient codes play once; steady server state is retained.
	# No guessed on/off transition or post-transition rest state is generated.
	var once := code in [14,77,99,100,213,214,215,216,400,401,402,403,404]
	# A different clip already starts at its authored pose. Force/restart would
	# engage the clip's transition blend and leave the helper halfway underground.
	rigs.set_playback(object_id, code, float(received_speed), not once, false)
	placeable_stats.plays += 1

func snapshot_placeable() -> Dictionary:
	return {"received_animation": received_animation, "received_speed": received_speed,"identified_original_blocker":identified_blocker,"show_blocker_diagnostic":show_blocker, "playback": rigs.playback_state(object_id, 0) if is_instance_valid(rigs) else {}, "stats": placeable_stats.duplicate(true), "retired": retired}
