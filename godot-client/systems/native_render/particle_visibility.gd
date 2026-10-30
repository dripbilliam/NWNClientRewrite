extends Node
# Presentation-only owner. Keeps existing emitters/resources alive while their
# simulation and drawing are disabled; newly admitted emitters inherit the flag.
var enabled:=false
var collision_enabled:=true
var emitters: Dictionary={}
func _enter_tree() -> void: get_parent().set_meta("native_particle_visibility",self)
func register(emitter: Node) -> void:
	emitters[emitter.get_instance_id()]=weakref(emitter)
	emitter.set_collision_enabled(collision_enabled)
	emitter.set_particles_enabled(enabled)
func unregister(emitter: Node) -> void: emitters.erase(emitter.get_instance_id())
func set_enabled(value: bool) -> void:
	enabled=value
	for id in emitters.keys():
		var emitter: Object=emitters[id].get_ref()
		if is_instance_valid(emitter): emitter.set_particles_enabled(value)
		else: emitters.erase(id)
func set_collision_enabled(value: bool) -> void:
	collision_enabled=value
	for id in emitters.keys():
		var emitter: Object=emitters[id].get_ref()
		if is_instance_valid(emitter): emitter.set_collision_enabled(value)
		else: emitters.erase(id)
func snapshot() -> Dictionary: return {"enabled":enabled,"collision_enabled":collision_enabled,"registered":emitters.size()}
func _exit_tree() -> void:
	if is_instance_valid(get_parent()) and get_parent().has_meta("native_particle_visibility"): get_parent().remove_meta("native_particle_visibility")
	emitters.clear()
