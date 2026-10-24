extends SceneTree
const SkyOwner = preload("res://systems/area_sky.gd")
const EnvironmentOwner = preload("res://systems/area_environment.gd")
func _initialize() -> void:
	var sky := SkyOwner.new()
	var owner := EnvironmentOwner.new()
	sky.free(); owner.free()
	quit(0)
