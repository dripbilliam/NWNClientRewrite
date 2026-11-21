extends RefCounted
# src/quickbar.js::emptyQuickbarButton and InitializeQuickbar's 36 distinct
# zeroed records. Network world and assignment use this same field shape.
const QUICKBAR_SIZE:=36
const QUICKBAR_TYPE:={"EMPTY":0,"ITEM":1,"SPELL":2,"SKILL":3,"FEAT":4,"SPELL_LIKE":44}
static func empty_quickbar_button() -> Dictionary:
	return {"type":0,"itemId":0,"secondaryItemId":0,"classIndex":0,"intParam":0,"metamagic":0,"domainLevel":0,"resRef":"","commandLabel":"","commandLine":"","toolTip":"","associateType":0,"associateId":0}
static func initialize_buttons() -> Array:
	var result: Array=[]
	for _index in QUICKBAR_SIZE:result.append(empty_quickbar_button())
	return result
static func normalize_assignment(value: Variant) -> Dictionary:
	# network_game_session.mjs::assignQuickbar selects only fields declared by
	# emptyQuickbarButton, preserving omitted fields for World Object.assign.
	var button: Dictionary=value if value is Dictionary else {"type":0}
	var result: Dictionary={}
	for field in empty_quickbar_button():
		if button.has(field):result[field]=button[field] if not button[field] is Dictionary and not button[field] is Array else button[field].duplicate(true)
	return result
