extends RefCounted
# Original9c9230/9c9860 mode1 callback values only. The source owner/pane
# retains local choices and owns reset, async publication, busy and Cancel.
const Context=preload("res://systems/native_data/level_up_recommendation_context.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Scalar=preload("res://systems/native_data/level_up_class_state.gd")
static func result(stage: String,value: Dictionary) -> Dictionary:
	var answer:=value.duplicate(true);answer.stage=stage;answer.resetBeforeLoad=stage=="domains";return answer
static func unavailable(stage: String,reason: String,values: Array=[]) -> Dictionary:
	return result(stage,{"ready":false,"reason":reason,"nativeValues":values.duplicate()})
static func lookup(stage: String,received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	if stage not in ["domains","school"]:return unavailable(stage,"This pane has no verified package recommendation callback.")
	# Both original callbacks attempt Packages.Load2DArray before choosing the
	# copied slot0 package or the later native class Package field.
	var loaded:=Context.table(tables,"packages")
	if not loaded.ready:return result(stage,loaded)
	if not loaded.loaded:return result(stage,{"ready":true,"loaded":false,"apply":false,"nativeValues":[]})
	var package:=Context.package(received,class_id,tables)
	if not package.ready:return result(stage,package)
	var values: Array=[];var reads: Array=[]
	for column in (["Domain1","Domain2"] if stage=="domains" else ["School"]):
		var read:=Tables.integer(tables.packages,int(package.packageId),column)
		#1a7010 writes zero for an empty/**** cell, or atoi(DEFAULT) for a
		# missing row/header, even when BOOL=false. Both callbacks ignore BOOL.
		# Malformed scanf/overflow remains explicit unresolved; do not invent a
		# previous native stack value or substitute a GUI selection.
		if not read.ready:return unavailable(stage,"Native package choice conversion is unresolved.",values)
		values.append(int(read.value));reads.append({"column":column,"lookupReturned":bool(read.ok),"value":int(read.value)})
	return result(stage,{"ready":true,"loaded":true,"apply":true,"nativeValues":values,"reads":reads,"context":package})
static func selection(stage: String,values: Variant,available_ids: Array=[]) -> Dictionary:
	# Original callbacks assume valid server metadata and can index unsafe
	# native arrays otherwise. Keep those outputs visible as unavailable;
	# never create replacement domains or clamp an invalid school.
	if stage=="school":
		if not values is Array or values.size()!=1 or not Scalar.integer(values[0],0,8):return unavailable(stage,"Native recommended school is outside the original nine tabs.",values if values is Array else [])
		return {"ready":true,"selected":int(values[0])}
	if stage=="domains":
		if not values is Array or values.size()!=2:return unavailable(stage,"Native recommended domain pair is unavailable.")
		var selected: Array=[]
		for value in values:
			if not Scalar.integer(value,0,255) or selected.has(int(value)) or not available_ids.has(int(value)):return unavailable(stage,"Native recommended domains do not identify two distinct current source choices.",values)
			selected.append(int(value))
		return {"ready":true,"selected":selected}
	return unavailable(stage,"This pane has no verified package recommendation callback.")
static func begin_domains(state) -> bool:
	#9c9230 only rebuilds the list when a begun chosen tab exists.9c5be0
	# repopulates physical rows; neither path explicitly replaces help text.
	if state.chosen.is_empty():return false
	var title: int=state.help_title;var description: int=state.help_description
	state.reset(state.model);state.help_title=title;state.help_description=description;return true
static func apply(stage: String,plan: Dictionary,state) -> Dictionary:
	if not plan.get("ready",false):return plan
	if not plan.get("apply",false):return {"ready":true,"applied":false}
	var ids: Array=[]
	if stage=="domains":
		for entry in state.model.get("entries",[]):ids.append(int(entry.id))
	var choice:=selection(stage,plan.get("nativeValues"),ids)
	if not choice.ready:return choice
	var changed:=false
	if stage=="domains":
		state.model.recommended=choice.selected.duplicate();changed=state.recommend()
	elif stage=="school":changed=state.select_index(int(choice.selected))
	return {"ready":changed,"applied":changed,"reason":"" if changed else "Current source choices are unavailable."}
