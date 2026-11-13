extends RefCounted
# Original7eb040 preference-only loop over an already prepared mode1 source.
# The caller owns the successful-String reset and all private publication.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Scalars=preload("res://systems/native_data/level_up_class_state.gd")
static func apply(source: Dictionary,preferences: Dictionary,loaded: bool,candidate: Callable) -> Dictionary:
	if not Scalars.integer(source.get("normal"),0,255) or not Scalars.integer(source.get("bonus"),0,255) or not source.get("selected") is Array or not source.selected.is_empty() or not candidate.is_valid():return {"ready":false,"reason":"Private native feat recommendation context is unavailable."}
	if loaded and not preferences.get("orderedRows") is Array:return {"ready":false,"reason":"Active feat preferences are malformed."}
	var remaining: int=(int(source.normal)+int(source.bonus))&255;var selected: Array=[];var reads: Array=[]
	if loaded:
		var lookup:=Tables.columns(preferences)
		for row in preferences.orderedRows.size():
			# Stop before reading an unreachable conversion, exactly as7eb040.
			if remaining==0:break
			reads.append(row);var read:=Tables.integer(preferences,row,"FeatIndex",lookup)
			if not read.ready:return {"ready":false,"reason":str(read.get("reason","A native feat preference conversion is unresolved."))}
			if not read.ok:continue
			var id:=int(read.value)&65535;var current:=source.duplicate();current.selected=selected.duplicate();var answer: Variant=candidate.call(current,id)
			if not answer is Dictionary or not answer.get("ready",false):return {"ready":false,"reason":str(answer.get("reason","Native feat prerequisites are unavailable.")) if answer is Dictionary else "Native feat prerequisites are unavailable."}
			if answer.get("allowed",false):selected.append(id);remaining=(remaining-1)&255
	return {"ready":true,"selected":selected,"remaining":remaining,"normal":int(source.normal),"bonus":int(source.bonus),"reads":reads}
