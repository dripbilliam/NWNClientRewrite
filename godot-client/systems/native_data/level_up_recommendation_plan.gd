extends RefCounted
# Mode1-only Package selection and successful String gates. No first-level
# character snapshot/state, received mutation or I/O is performed here.
const Context=preload("res://systems/native_data/level_up_recommendation_context.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Scalars=preload("res://systems/native_data/level_up_class_state.gd")
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func failed(plan: Dictionary,reason: String) -> Dictionary:
	var value:=plan.duplicate();value.ready=false;value.reason=reason;return value
static func lookup(received: Dictionary,class_id: int,tables: Dictionary,column: String) -> Dictionary:
	var context:=Context.package(received,class_id,tables)
	if not context.ready:return context
	var state:=Context.table(tables,"packages")
	if not state.ready:return state
	if not state.loaded:return {"ready":true,"invoked":false,"name":"","context":context}
	var entry:=Tables.cell(tables.packages,int(context.packageId),column)
	if not entry.found or entry.text in ["","****"]:return {"ready":true,"invoked":false,"name":"","context":context}
	var name:=str(entry.text).to_lower().left(16);state=Context.table(tables,name)
	state.merge({"invoked":true,"name":name,"context":context},true);return state
static func feats(received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	# Preference INT reads belong to the reached7eb040 loop, after CHAR budget
	# checks. Do not eagerly decode unreachable malformed table rows here.
	return lookup(received,class_id,tables,"FeatPref2DA")
static func spells(received: Dictionary,class_id: int,tables: Dictionary,source: Dictionary) -> Dictionary:
	var value:=lookup(received,class_id,tables,"SpellPref2DA")
	if not value.ready:
		if value.get("invoked",false):value.helperInvoked=true
		return value
	var plan:={"ready":true,"helperInvoked":bool(value.invoked),"invoked":bool(value.invoked),"name":str(value.name),"context":value.context}
	if not value.invoked:return plan
	if not source.get("memorizes") is bool or not Scalars.integer(source.get("school"),0,255):return failed(plan,"Private mode1 spell preference context is unavailable.")
	var restricted:=Tables.integer(tables.get("classes",{}),class_id,"SpellbookRestricted")
	if not restricted.ready or not restricted.ok:return failed(plan,"Native spellbook-restriction metadata is unavailable.")
	# INT traversal belongs to7eb630's reached loop. This worker-only borrowed
	# table is never placed in a private draft, proposal or network message.
	var preferences: Dictionary=tables[value.name] if value.loaded else {}
	var opposition: Variant=null
	if source.memorizes and int(source.school)!=0:
		var state:=Context.table(tables,"spellschools")
		if not state.ready:
			for key in ["helperInvoked","invoked","name","context"]:state[key]=plan[key]
			return state
		var read:=Tables.integer(tables.spellschools,int(source.school),"Opposition")
		if not read.ready:return failed(plan,"Native opposing-school conversion is unresolved.")
		if read.ok:opposition=int(read.value)&255
	plan.merge({"loaded":bool(value.loaded),"restricted":int(restricted.value)!=0,"preferenceTable":preferences,"opposition":opposition},true);return plan
