extends "res://systems/native_data/creation_feat_snapshot.gd"
const Original=preload("res://systems/native_data/creation_feat_snapshot.gd")
const Profile=preload("res://tests/native_creation_feat_profile_clock.gd")
static func compose(rules,chosen: Array=[],prepared: Dictionary={}) -> Dictionary:
	var token:=Profile.enter("snapshot.compose")
	var result: Dictionary=Original.compose(rules,chosen,prepared)
	Profile.leave(token)
	return result
static func resolve_spells(value: Dictionary,rules) -> Dictionary:
	var token:=Profile.enter("snapshot.resolve_spells")
	var result: Dictionary=Original.resolve_spells(value,rules)
	Profile.leave(token)
	return result
