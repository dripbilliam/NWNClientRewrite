extends RefCounted
# Original mode1 recommendation callbacks8e5f60/9c9a30. This is not a
# first-level character draft or a replacement for received level-up state.
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
static func unavailable(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func signed32(value: int) -> int:return (value&0xffffffff)-4294967296 if value&0x80000000 else value&0xffffffff
static func package(received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	var advanced:=Vitals.next_classes(received,class_id)
	if not advanced.ready:return advanced
	var classes: Variant=tables.get("classes")
	if not classes is Dictionary or not classes.get("orderedRows") is Array or class_id<0 or class_id>=(classes.orderedRows.size()&255):return unavailable("Active recommendation class data is unavailable.")
	var id: int=-1;var index:=int(advanced.current)
	if index==0:
		if not Class.integer(received.get("fieldD4"),-2147483648,4294967295):return unavailable("Received package data is unavailable.")
		id=signed32(int(received.fieldD4))
	else:
		var read:=Tables.integer(classes,class_id,"Package")
		if not read.ready:return unavailable("The native class package conversion is unavailable.")
		#2992e0 initializes+4e4=-1;2a4350 leaves it intact and2a4a90
		# overwrites only after a successful active Package INT lookup.
		if read.ok:id=signed32(int(read.value))
	return {"ready":true,"packageId":id,"classId":class_id,"classIndex":index,"source":"received" if index==0 else "native_class"}
static func table(tables: Dictionary,name: String) -> Dictionary:
	if not tables.has(name):return {"ready":false,"pending":true,"dependencies":[name],"reason":"Recommended choices are being prepared."}
	var value: Variant=tables[name]
	if not value is Dictionary:return unavailable("The active recommendation table is malformed.")
	if value.is_empty():return {"ready":true,"loaded":false}
	if not value.get("orderedRows") is Array:return unavailable("The active recommendation table is malformed.")
	return {"ready":true,"loaded":true}
static func attributes(received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	var context:=package(received,class_id,tables)
	if not context.ready:return context
	var state:=table(tables,"packages")
	if not state.ready:return state
	if not state.loaded:return {"ready":true,"loaded":false,"attribute":"","context":context}
	#1a68f0 outputs the table DEFAULT when the row/header is unavailable,
	# even though it returnsfalse.8e5f60 deliberately ignores that BOOL.
	var cell:=Tables.cell(tables.packages,int(context.packageId),"Attribute")
	return {"ready":true,"loaded":true,"attribute":"" if cell.found and cell.text in ["","****"] else str(cell.text),"context":context}
static func skills(received: Dictionary,class_id: int,tables: Dictionary) -> Dictionary:
	var context:=package(received,class_id,tables)
	if not context.ready:return context
	var state:=table(tables,"packages")
	if not state.ready:return state
	if not state.loaded:return {"ready":true,"invoked":false,"context":context}
	var cell:=Tables.cell(tables.packages,int(context.packageId),"SkillPref2DA")
	#9c9a30 honors the string lookup BOOL. Neither DEFAULT nor an absent
	# cell may reset begun private ranks or become a fabricated preference.
	if not cell.found or cell.text in ["","****"]:return {"ready":true,"invoked":false,"context":context}
	var name:=str(cell.text).to_lower().left(16);state=table(tables,name)
	if not state.ready:state.merge({"invoked":true,"name":name,"context":context},true);return state
	var ids: Array=[]
	if state.loaded:
		var preferences: Dictionary=tables[name];var columns:=Tables.columns(preferences)
		for row in preferences.orderedRows.size():
			var read:=Tables.integer(preferences,row,"SkillIndex",columns)
			if not read.ready:
				var invalid:=unavailable("A native recommended skill conversion is unavailable.");invalid.merge({"invoked":true,"name":name,"context":context},true);return invalid
			if read.ok:ids.append(int(read.value)&65535)
	return {"ready":true,"invoked":true,"name":name,"loaded":state.loaded,"ids":ids,"context":context}
