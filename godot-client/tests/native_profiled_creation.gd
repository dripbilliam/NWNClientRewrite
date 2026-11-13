extends "res://systems/native_creation.gd"
const Profile=preload("res://tests/native_creation_feat_profile_clock.gd")
func render() -> void:
	var token:=Profile.enter("creator.render")
	super.render()
	Profile.leave(token)
func refresh_source() -> void:
	var token:=Profile.enter("creator.refresh_source")
	super.refresh_source()
	Profile.leave(token)
func summary_source(identity: Array,mask: int,prefix: String) -> Dictionary:
	var token:=Profile.enter("creator.summary_source")
	var result: Dictionary=super.summary_source(identity,mask,prefix)
	Profile.leave(token)
	return result
