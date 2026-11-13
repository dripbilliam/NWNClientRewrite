extends "res://systems/native_feats_chooser.gd"
const Profile=preload("res://tests/native_creation_feat_profile_clock.gd")
func set_context(value: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	var token:=Profile.enter("view.set_context")
	super.set_context(value,recommended,active_text,art,value_scope)
	Profile.leave(token)
func update_model(value: Dictionary) -> void:
	var token:=Profile.enter("view.update_model")
	super.update_model(value)
	Profile.leave(token)
func set_busy(value: bool) -> void:
	var token:=Profile.enter("view.set_busy")
	super.set_busy(value)
	Profile.leave(token)
func refresh() -> void:
	var token:=Profile.enter("view.refresh")
	super.refresh()
	Profile.leave(token)
func clear_rows(kind: String="") -> void:
	var token:=Profile.enter("view.clear_rows")
	super.clear_rows(kind)
	Profile.leave(token)
func rebuild_rows(kind: String,entries: Array) -> void:
	var token:=Profile.enter("view.rebuild_rows")
	super.rebuild_rows(kind,entries)
	Profile.leave(token)
