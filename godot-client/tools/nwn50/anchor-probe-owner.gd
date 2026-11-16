extends "res://systems/native_render/placeable_lights.gd"

var planned: Dictionary={}
var current_anchor: Node3D
var next_anchor: Node3D
var anchor_reads:=0

func plans() -> Dictionary:return planned
func anchor(_id: int) -> Node3D:
	anchor_reads+=1
	return current_anchor
