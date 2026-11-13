extends RefCounted
# Cold post-window read only census. No clocks advance, assets resolve, scene
# setters run, providers are called or new gameplay controllers are created.
static func capture(world: Node)->Dictionary:
	var result:={"version":1,"kind":"effect-and-pose-activity","effect_rows":[],"motion_rows":[],"totals":{},"limitations":["Cold snapshot is not a count of writes or CPU attribution.","Raw and unique feat counts describe the same declared arrays used by game_ui_rules.feats; no rules callbacks or providers run.","Owned finished sounds remain semantically owned and are not disposable merely because playing is false."]}
	var effects=world.get("effects")
	if not is_instance_valid(effects):return result
	result.totals={"desired":world.desired.size(),"instances":world.instances.size(),"motion":world.motion.objects.size(),"effect_entries":effects.entries.size(),"effect_records":effects.records.size(),"effect_models":effects.models.size(),"pending":effects.queue.size(),"special_records":effects.special_attacks.records.size(),"special_handles":effects.special_attacks.handles.size(),"equipped_records":effects.equipped_attacks.records.size(),"equipped_warm":effects.equipped_attacks.warm.size(),"voice_records":effects.creature_voices.records.size()}
	for id in effects.entries:
		var entry: Dictionary=effects.entries[id]
		var row:={"id":id,"actor":entry.actor,"token":entry.privateToken,"area":entry.areaVisual,"removed":entry.removed,"runtime":entry.runtime!=null}
		if entry.runtime!=null:
			var runtime=entry.runtime;var state: Dictionary=runtime.state
			row["state"]={}
			for field in ["target54","source58","programPhaseFa","programRemainingCc","programType10d","updateProgramD8","attached114","startedF0","closedEc","finishedF4","retiringE8","modelRemaining5c","modelStates68","retireRemainingC0","retiredDc","durationFc","sound118"]:
				var value: Variant=state.get(field)
				row.state[field]=value.duplicate() if value is Array or value is Dictionary else value
			row["models_nonnull"]=0
			for model in state.get("models88",[]):
				if model!=null:row.models_nonnull+=1
			if not entry.areaVisual and is_instance_valid(runtime.clock):row["clock"]={"started":runtime.clock.started,"frames":runtime.clock.frames,"announced":runtime.clock.announced,"process_enabled":runtime.clock.is_processing()}
		result.effect_rows.append(row)
	var raw_total:=0;var unique_total:=0;var body_missing:=0
	for id in world.motion.objects:
		var object: Dictionary=world.desired.get(id,{}).get("object",{})
		var player: Dictionary=object.get("playerState",{});var inventory: Dictionary=object.get("inventoryStats",{})
		var raw:=0;var unique: Dictionary={}
		for source in [player.get("feats",[]),player.get("bonusFeats",[]),inventory.get("feats",[]),inventory.get("fields118",[]),inventory.get("fields128",[])]:
			for entry in source:
				raw+=1
				var value: Variant=entry.get("id") if entry is Dictionary else entry
				if value is int and value>=0:unique[value]=true
		var host=world.instances.get(id)
		if not is_instance_valid(host):body_missing+=1
		var motion: Dictionary=world.motion.objects[id]
		result.motion_rows.append({"id":id,"object_type":object.get("objectType",-1),"controlled":id==world.controlled_id,"has_instance":is_instance_valid(host),"active":motion.get("active",false),"animation":motion.get("animation",-1),"raw_feat_rows":raw,"unique_integer_feats":unique.size(),"special_record":effects.special_attacks.records.has(id),"equipped_record":effects.equipped_attacks.records.has(id),"equipped_warm":effects.equipped_attacks.warm.has(id)})
		raw_total+=raw;unique_total+=unique.size()
	result.totals.merge({"raw_feat_rows":raw_total,"unique_integer_feats":unique_total,"motion_without_instance":body_missing})
	return result
