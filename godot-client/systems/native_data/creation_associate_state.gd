extends RefCounted
# CCharacterFamiliarPanel5ca0/a900. Private chooser state only: no live draft,
# Nodes, network commands, character-sheet cache or fabricated creature stats.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Scalars=preload("res://systems/native_data/creation_spells_state.gd")
var ready:=false
var reason:=""
var entries: Array=[]
var selected:=-1
var arcane:=0
var class_level:=1
var current_name:=""
static func unavailable(message: String) -> Dictionary:return {"ready":false,"reason":message}
static func kinds(raw_arcane: int) -> Dictionary:
	# Original table selection tests ==1, while name/type storage tests !=0.
	# Preserve that distinction even for unusual active class metadata.
	return {"table":"hen_familiar" if raw_arcane==1 else "hen_companion","field":"familiar" if raw_arcane!=0 else "companion"}
static func choices(table: Variant,raw_arcane: Variant,level: Variant,text) -> Dictionary:
	if not Scalars.scalar(raw_arcane) or not Scalars.scalar(level):return unavailable("The native associate class context is unavailable.")
	if int(level)<0 or int(level)>255:return unavailable("The native associate class level is outside its received byte range.")
	if not table is Dictionary or not table.get("orderedRows") is Array:return unavailable("The active associate table has not loaded.")
	if text==null or not text.has_method("raw"):return unavailable("Active associate names are unavailable.")
	var result: Array=[];var lookup:=Tables.columns(table)
	for id in table.orderedRows.size():
		var title:=Tables.integer(table,id,"STRREF",lookup)
		if not title.ready:return unavailable("An associate name-reference conversion is unresolved.")
		if not title.ok:continue
		var base:=Tables.cell(table,id,"BASERESREF",lookup)
		if not base.found or str(base.text).is_empty():continue
		var ref:=int(title.value)&0xffffffff
		var description:=Tables.integer(table,id,"DESCRIPTION",lookup)
		# The original help callback initializes GetINTEntry's output to zero.
		if not description.ready:return unavailable("An associate description-reference conversion is unresolved.")
		result.append({"id":id,"title":ref,"name":text.raw({"strRef":ref}),"base":str(base.text),"description":int(description.value) if description.ok else 0})
	return {"ready":true,"entries":result,"arcane":int(raw_arcane),"level":int(level),"kinds":kinds(int(raw_arcane))}
func configure(source: Dictionary,stored_type: Variant,name: Variant) -> Dictionary:
	ready=false;reason="";entries.clear();selected=-1
	if not source.get("ready",false):reason=str(source.get("reason","The native associate choices are unavailable."));return view()
	if not source.get("entries") is Array or not Scalars.scalar(source.get("arcane")) or not Scalars.scalar(source.get("level")) or not Scalars.scalar(stored_type) or not name is String:
		reason="The owned associate selection is incomplete.";return view()
	for row in source.entries:
		if not row is Dictionary or not Scalars.scalar(row.get("id")) or not Scalars.scalar(row.get("title")) or not row.get("base") is String or not row.get("name") is String:
			reason="An active associate row is incomplete.";return view()
	arcane=int(source.arcane);class_level=int(source.level);entries=source.entries.duplicate(true);current_name=name
	var initial:=int(stored_type)&0xffffffff
	initial=initial-4294967296 if initial&0x80000000 else initial
	if initial== -1:initial=0
	if initial<0:
		# Original SelectTab stores arbitrary negatives, then a900 dereferences
		# all except -1. Do not emulate an undefined out-of-bounds read.
		reason="The stored associate selection has no safe original row.";return view()
	if entries.size()<initial+1:initial=0
	ready=true;select_index(initial);return view()
func select_index(index: int) -> bool:
	if not ready:return false
	selected=index if index>=0 and index<entries.size() else -1
	return selected>=0
func selected_id() -> Variant:return int(entries[selected].id) if ready and selected>=0 and selected<entries.size() else null
func preview() -> Dictionary:
	if selected_id()==null:return {"ready":false,"reason":"No native associate row is selected."}
	var resource:=(str(entries[selected].base)+("%02d"%class_level)).left(16).to_lower()
	return {"ready":true,"resource":resource,"type":2027,"physicalId":int(entries[selected].id)}
func set_name(value: String) -> void:
	if ready:current_name=value
func commit(generated_name: Variant=null) -> Dictionary:
	if selected_id()==null:return unavailable("Select an available native associate.")
	var name:=current_name
	if name.is_empty():
		if not generated_name is String or generated_name.is_empty():return {"ready":false,"needsGeneratedName":true,"reason":"The original active name generator must supply a name."}
		name=generated_name
	return {"ready":true,"field":kinds(arcane).field,"id":selected_id(),"name":name,"code":0}
func view() -> Dictionary:
	if not ready:return {"ready":false,"reason":reason,"entries":[],"selected":null,"canAccept":false}
	return {"ready":true,"entries":entries.duplicate(true),"selected":selected,"physicalId":selected_id(),"name":current_name,"needsGeneratedName":current_name.is_empty(),"canAccept":selected_id()!=null,"preview":preview()}
