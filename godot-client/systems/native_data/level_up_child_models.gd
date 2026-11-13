extends RefCounted
# Original mode1 post-feat children consume the advanced current class and
# copied Package/associate fields. Only their mode-independent list builders
# are shared with creation; no first-level character draft is composed.
const Domains=preload("res://systems/native_data/creation_domains_state.gd")
const School=preload("res://systems/native_data/creation_school_state.gd")
const Associate=preload("res://systems/native_data/creation_associate_state.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
class ActiveRows extends RefCounted:
	var tables: Dictionary={}
	var draft: Dictionary={}
static func package_view(received: Dictionary,tables: Dictionary,class_id: int):
	var view:=ActiveRows.new();view.tables=tables.duplicate()
	#9c9230/9c9860 use copied Package6c for slot0, class+4e4 for later
	# slots. LoadClassInfo writes that field from the active "Package" column.
	var advanced:=Vitals.next_classes(received,class_id);var package_id: Variant=null
	if advanced.ready:
		if int(advanced.current)==0:package_id=received.get("fieldD4")
		elif tables.has("classes"):
			var read:=Tables.integer(tables.classes,class_id,"Package")
			if read.ready and read.ok:package_id=int(read.value)
	# Unknown/invalid package recommendation remains explicitly unavailable;
	# no creation Package or received slot0 value can fill a later class slot.
	if Vitals.Class.integer(package_id,0,2147483647) and tables.has("packages") and int(package_id)<tables.packages.get("orderedRows",[]).size():view.draft.packageId=int(package_id)
	else:view.tables.erase("packages")
	return view
static func domains(received: Dictionary,tables: Dictionary,text,class_id: int) -> Dictionary:
	if text==null or not text.has_method("raw"):return {"ready":false,"entries":[],"reason":"Active mode1 domain names are unavailable."}
	var view=package_view(received,tables,class_id);var model:=Domains.choices(view,text)
	model.recommendationReady=view.draft.has("packageId") and model.get("ready",false) and model.get("recommended",[]).size()==2
	return model
static func school(received: Dictionary,tables: Dictionary,class_id: int) -> Dictionary:
	var view=package_view(received,tables,class_id);var model:=School.choices(view)
	model.recommendationReady=view.draft.has("packageId") and model.get("recommended") is int
	return model
static func associate(received: Dictionary,class_id: int,tables: Dictionary,text) -> Dictionary:
	var advanced:=Vitals.next_classes(received,class_id)
	if not advanced.ready:return advanced
	var table: Dictionary=tables.get("classes",{})
	if class_id<0 or class_id>=(table.get("orderedRows",[]).size()&255):return {"ready":false,"reason":"Active mode1 associate class is unavailable."}
	var arcane:=Tables.integer(table,class_id,"Arcane")
	if not arcane.ready or not arcane.ok:return {"ready":false,"reason":"Original mode1 associate context is unavailable."}
	var kinds:=Associate.kinds(int(arcane.value));var type_key:="fieldE34" if kinds.field=="familiar" else "fieldE30";var name_key:="fieldE48" if kinds.field=="familiar" else "fieldE38"
	if not Vitals.Class.integer(received.get(type_key),-2147483648,2147483647) or not received.get(name_key) is String:return {"ready":false,"reason":"Copied original associate selection/name is unavailable."}
	var level:=int(advanced.classes[int(advanced.current)].level)
	var choices:=Associate.choices(tables.get(kinds.table),int(arcane.value),level,text)
	if not choices.ready:return choices
	return {"ready":true,"choices":choices,"storedType":int(received[type_key]),"name":str(received[name_key]),"classId":class_id,"classLevel":level,"table":kinds.table,"field":kinds.field}
