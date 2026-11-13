extends "res://systems/native_data/creation_feat_state.gd"
const Profile=preload("res://tests/native_creation_feat_profile_clock.gd")
func prepare(rules,text) -> Dictionary:
	var token:=Profile.enter("state.prepare")
	var result: Dictionary=super.prepare(rules,text)
	Profile.leave(token)
	return result
func snapshot(rules,text) -> Dictionary:
	var token:=Profile.enter("state.snapshot")
	var result: Dictionary=super.snapshot(rules,text)
	Profile.leave(token)
	return result
func candidate(source: Dictionary,id: int) -> Dictionary:
	var token:=Profile.enter("state.candidate")
	var result: Dictionary=super.candidate(source,id)
	Profile.leave(token)
	return result
func compose(rules,text) -> Dictionary:
	var token:=Profile.enter("state.compose")
	var result: Dictionary=super.compose(rules,text)
	Profile.leave(token)
	return result
func build_model(rules,text) -> Dictionary:
	var token:=Profile.enter("state.build_model")
	var result: Dictionary=super.build_model(rules,text)
	Profile.leave(token)
	return result
func apply(operation: String,id: int,rules,text,preferences: String="") -> Dictionary:
	var token:=Profile.enter("state.apply")
	var result: Dictionary=super.apply(operation,id,rules,text,preferences)
	Profile.leave(token)
	return result
