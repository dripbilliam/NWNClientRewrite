extends RefCounted
# Original CG_DOMAIN9cc0f0/9c7010/9ca100. Temporary physical choices only;
# the existing draft remains responsible for the selected class and commit.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
var model: Dictionary={}
var available_ids: Array=[]
var chosen: Array=[]
var selected_available:=-1
var selected_chosen:=-1
var help_title:=6011
var help_description:=5985
func reset(value: Dictionary) -> void:
	model=value.duplicate(true);available_ids=[];chosen=[];selected_available=-1;selected_chosen=-1;help_title=6011;help_description=5985
	if model.get("ready",false):
		for entry in model.entries:available_ids.append(int(entry.id))
func entry(id: int) -> Dictionary:
	for item in model.get("entries",[]):
		if int(item.id)==id:return item
	return {}
func describe(id: int) -> void:
	var value:=entry(id)
	help_title=int(value.title) if not value.is_empty() else 6011;help_description=int(value.description) if not value.is_empty() else 5985
func select_available(index: int) -> bool:
	if not model.get("ready",false) or index<0 or index>=available_ids.size():return false
	selected_available=index;selected_chosen=-1;describe(int(available_ids[index]));return true
func select_chosen(index: int) -> bool:
	if index<0 or index>=chosen.size():return false
	selected_chosen=index;selected_available=-1;describe(int(chosen[index]));return true
func add(index: int) -> bool:
	if not model.get("ready",false) or chosen.size()==2 or index<0 or index>=available_ids.size():return false
	var id:=int(available_ids[index]);available_ids.remove_at(index);chosen.append(id);selected_available=-1;selected_chosen=chosen.size()-1;describe(id);return true
func remove(index: int) -> bool:
	if index<0 or index>=chosen.size():return false
	var id:=int(chosen[index]);chosen.remove_at(index);available_ids.append(id);available_ids.sort();selected_chosen=-1;selected_available=available_ids.find(id);describe(id);return true
func can_recommend() -> bool:
	var values: Array=model.get("recommended",[])
	return model.get("ready",false) and values.size()==2 and int(values[0])!=int(values[1]) and not entry(int(values[0])).is_empty() and not entry(int(values[1])).is_empty()
func recommend() -> bool:
	if not can_recommend():return false
	var values: Array=model.recommended
	var previous:=model;reset(previous)
	for id in values:add(available_ids.find(int(id)))
	select_chosen(0);return true
func can_accept() -> bool:return model.get("ready",false) and chosen.size()==2
static func choices(rules,active_text) -> Dictionary:
	if not rules.tables.has("domains"):return {"ready":false,"entries":[],"reason":"Active domain data has not arrived."}
	var table: Dictionary=rules.tables.domains;var lookup:=Tables.columns(table);var entries: Array=[]
	for id in (table.get("orderedRows",[]).size()&255):
		var name:=Tables.integer(table,id,"Name",lookup)
		if not name.ready:return {"ready":false,"entries":[],"reason":"Active domain name conversion is unresolved."}
		# LoadDomainInfo marks a failed Name read invalid; a successfully loaded
		# zero name is separately omitted by the original picker. Label is unused.
		if not name.ok or int(name.value)==0:continue
		var description:=Tables.integer(table,id,"Description",lookup);var feat:=Tables.integer(table,id,"GrantedFeat",lookup)
		if not description.ready or not feat.ready:return {"ready":false,"entries":[],"reason":"Active domain metadata conversion is unresolved."}
		var icon:=Tables.cell(table,id,"Icon",lookup)
		entries.append({"id":id,"title":int(name.value)&0xffffffff,"description":(int(description.value) if description.ok else -1)&0xffffffff,"name":active_text.raw({"strRef":int(name.value)&0xffffffff}) if active_text!=null else "","icon":str(icon.text).to_lower() if icon.found and icon.text!="****" else "","grantedFeat":(int(feat.value) if feat.ok else 65535)&65535})
	var recommended: Array=[]
	if rules.tables.has("packages"):
		for field in ["Domain1","Domain2"]:
			var read:=Tables.integer(rules.tables.packages,int(rules.draft.get("packageId",-1)),field)
			if not read.ready:return {"ready":false,"entries":[],"reason":"Active package domain conversion is unresolved."}
			recommended.append(int(read.value))
	return {"ready":true,"entries":entries,"recommended":recommended}
