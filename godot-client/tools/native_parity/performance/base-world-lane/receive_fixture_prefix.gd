extends "res://candidate_planner.gd"
const EntityLifetime=preload("res://entity_lifetime.gd")
const FrameProfile=preload("res://fake_profile.gd")
const ObjectPose=preload("res://object_pose.gd")
const FakeOwner=preload("res://fake_owner.gd")
signal instance_state_changed(id: int,source: Dictionary)
var placeable_lights=null
var drive_collision=null
var combat=FakeOwner.new()
var motion=FakeOwner.new()
var motion_revisions: Dictionary={}
func signature(object: Dictionary) -> String:return var_to_str([EntityLifetime.token(object),object.get("appearance"),object.get("staticState")])
func observe_facing_target(_object: Dictionary) -> void:pass
func sync_combat(_id: int) -> void:pass
func apply_pose(_id: int) -> void:pass
func apply_poses(_include_statics: bool=false) -> void:pass
func remove_instance(id: int) -> void:
	instances.erase(id);installed.erase(id);hidden.erase(id)
func object_pose(object: Dictionary) -> Dictionary:return ObjectPose.pose(object)
