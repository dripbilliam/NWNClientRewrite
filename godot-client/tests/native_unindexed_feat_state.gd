extends "res://systems/native_data/creation_feat_state.gd"
# Reference route deliberately omits only the optional operation index. The
# original Choice/Requirements fallback loops still own every decision.
const RawSnapshot=preload("res://systems/native_data/creation_feat_snapshot.gd")
func snapshot(rules,text) -> Dictionary:
	var decoded:=prepare(rules,text)
	if not decoded.get("ready",false):return decoded
	return RawSnapshot.resolve_spells(RawSnapshot.compose(rules,selected,decoded),rules)
