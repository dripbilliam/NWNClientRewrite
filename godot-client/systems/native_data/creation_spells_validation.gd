extends RefCounted
# Rebuild the scoped first-level selection against current active rules at the
# final save boundary. A complete native transcript replaces generic exact-
# count/Master/UserType filtering only for this explicitly completed flow.
const State=preload("res://systems/native_data/creation_spells_state.gd")
const Snapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const Plan=preload("res://systems/native_data/creation_spell_recommendation_plan.gd")
const Recommendations=preload("res://systems/native_data/creation_spell_recommendations.gd")
const ABILITIES=["Str","Dex","Con","Int","Wis","Cha"]
static func unavailable(reason: String) -> Dictionary:return {"ready":false,"valid":false,"reason":reason}
static func invalid(reason: String) -> Dictionary:return {"ready":true,"valid":false,"reason":reason}
static func signature(rules) -> Array:
	var draft: Dictionary=rules.draft;var result: Array=[]
	for key in ["classId","raceId","school","packageId"]:
		if not State.scalar(draft.get(key)):return []
		result.append(int(draft[key]))
	if not draft.get("abilities") is Dictionary:return []
	for key in ABILITIES:
		if not State.scalar(draft.abilities.get(key)):return []
		result.append(int(draft.abilities[key]))
	return result
static func books(value: Variant,prepared: bool=false) -> Dictionary:
	if not value is Dictionary:return unavailable("The owned draft spell book is unavailable.")
	var result: Array=[]
	for level in 10:
		var row: Variant=value.get(level,value.get(str(level),[]))
		if not row is Array:return unavailable("An owned draft spell level is unavailable.")
		var ids: Array=[]
		for id in row:
			if prepared and id==null:ids.append(null)
			elif State.scalar(id):ids.append(int(id))
			else:return unavailable("An owned draft spell identity is unavailable.")
		result.append(ids)
	return {"ready":true,"books":result}
static func replay(rules,text,receipt: Dictionary) -> Dictionary:
	var context:=signature(rules)
	if context.is_empty() or context!=receipt.get("signature",[]):return unavailable("The native spell selection belongs to another draft context.")
	if not receipt.get("initialKnown") is Array or receipt.initialKnown.size()!=10 or not receipt.get("events") is Array:return unavailable("The native spell selection transcript is unavailable.")
	var snapshot:=Snapshot.compose(rules,text)
	if not snapshot.ready:return snapshot
	if text!=null and text.has_method("is_complete") and not text.is_complete():return unavailable("The detached spell-name save snapshot is incomplete.")
	snapshot.source.known=receipt.initialKnown.duplicate(true)
	var state:=State.new();var initialized:=state.configure(snapshot.source)
	if not initialized.ready:return initialized
	for event in receipt.events:
		if not event is Dictionary or not event.get("operation") is String:return unavailable("A native spell selection event is unavailable.")
		var operation: String=event.operation;var accepted:=false
		if operation in ["level","add","remove"]:
			if not State.scalar(event.get("id")):return unavailable("A native spell selection event identity is unavailable.")
			var id:=int(event.id)
			if operation=="level":accepted=state.select_level(id)
			elif operation=="add":accepted=state.add(id)
			else:accepted=state.remove(id)
		elif operation=="reset":accepted=state.reset_choices()
		elif operation=="recommend":
			var plan:=Plan.compose(rules,state.source)
			if not plan.ready:return plan
			var result:=Recommendations.apply(state,plan)
			if not result.ready:return result
			accepted=true
		else:return unavailable("An unknown native spell selection event was supplied.")
		if not accepted:return invalid("Active spell rules no longer admit the recorded selection.")
	return {"ready":true,"valid":true,"state":state}
static func preparations(rules,state,receipt: Dictionary) -> Dictionary:
	if not state.source.pickSchool:
		var initial:=books(receipt.get("initialMemorized"),true)
		return {"ready":true,"books":initial.books} if initial.ready else initial
	if rules.draft.get("sourceSpellSlots")!=true:return unavailable("The original school-owned spell-slot cache is unavailable.")
	var slots: Variant=rules.get("creation_spell_slots")
	if not slots is Dictionary:return unavailable("The original memorization slot counts are unavailable.")
	var result: Array=[]
	for level in 10:
		var count: Variant=slots.get(level,slots.get(str(level)))
		if not State.scalar(count) or int(count)<0 or int(count)>255:return unavailable("An original memorization slot count is unavailable.")
		result.append(state.known[level].slice(0,mini(int(count),state.known[level].size())))
	return {"ready":true,"books":result}
static func verify(rules,text,receipt: Dictionary) -> Dictionary:
	if receipt.get("completed")!=true:return invalid("Finish native spell selection before saving.")
	var result:=replay(rules,text,receipt)
	if not result.get("ready",false) or not result.get("valid",false):return result
	var state=result.state
	if not state.can_accept():return invalid("Select every available native spell choice.")
	var actual:=books(rules.draft.get("known"))
	if not actual.ready:return actual
	if actual.books!=state.known:return invalid("The owned known-spell book differs from its native selection.")
	for row in state.known:
		for id in row:
			if id<0 or id>65535:return unavailable("A selected physical spell ID exceeds verified original BIC word storage.")
	var expected:=preparations(rules,state,receipt);var prepared:=books(rules.draft.get("memorized"),true)
	if not expected.ready:return expected
	if not prepared.ready:return prepared
	if expected.books!=prepared.books:return invalid("The owned prepared-spell book differs from the original selection commit.")
	return {"ready":true,"valid":true}
