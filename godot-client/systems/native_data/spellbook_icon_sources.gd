extends RefCounted
# Original spell/action bitmap bytes prepared before menu publication. A name
# alone is insufficient: each selected archive/override layer has an identity.
const Table=preload("res://systems/native_data/two_da.gd")
const Plan=preload("res://systems/native_data/spellbook_layout.gd")
const ItemSources=preload("res://systems/native_data/item_icon_sources.gd")
static var mutex:=Mutex.new()
static var payloads: Dictionary={}
static var names: Dictionary={}
static var bytes:=0
static func source_key(name: String,type: int,identity: String) -> String:
	return identity+":"+name.to_lower()+":"+str(type)
static func lookup(catalog,name: String,type: int) -> PackedByteArray:
	if type not in [3,2073,2033,2059]: return PackedByteArray()
	var simple:=name.to_lower()+":"+str(type)
	mutex.lock(); var known:=names.has(simple); mutex.unlock()
	if not known: return PackedByteArray()
	var selected: Dictionary=catalog.location(name,type)
	if selected.is_empty(): return PackedByteArray()
	var key:=source_key(name,type,str(selected.layer.get("binding_identity","")))
	mutex.lock(); var value: PackedByteArray=payloads.get(key,PackedByteArray()); mutex.unlock()
	return value
static func referenced(catalog) -> Dictionary:
	var result: Dictionary={}
	for table_name in ["spells","classes","actions","feat","skills"]:
		var original: PackedByteArray=catalog.get_resource(table_name,2017)
		if original.is_empty(): continue
		var table: Dictionary=Table.new().parse(original.get_string_from_ascii())
		for row in table.get("orderedRows",[]):
			for column in row:
				if str(column).to_lower() in ["icon","iconresref"]:
					var name:=str(row[column]).to_lower()
					if not name.is_empty() and not name.replace("*","").is_empty(): result[name]=true
					break
	for name in Plan.LEVEL_ICONS: result[str(name).to_lower()]=true
	for entry in Plan.META: result[str(entry.icon).to_lower()]=true
	return result
static func preload_all(catalog,stop: Callable=Callable(),progress: Callable=Callable()) -> Dictionary:
	var names_to_load:=referenced(catalog).keys(); names_to_load.sort()
	var loaded:=0; var reused:=0; var item_reused:=0; var missing: Array=[]; var failures: Array=[]
	if progress.is_valid(): progress.call("spellbook-icons",0,names_to_load.size())
	for index in names_to_load.size():
		if index%16==0:
			if stop.is_valid() and stop.call(): return {"cancelled":true,"total":names_to_load.size(),"completed":index,"loaded":loaded,"reused":reused,"item_reused":item_reused,"missing":missing,"failures":failures}
			if progress.is_valid(): progress.call("spellbook-icons",index,names_to_load.size())
		var name: String=names_to_load[index]
		var selected: Dictionary=catalog.raster_location(name)
		if selected.is_empty(): missing.append(name); continue
		var type: int=int(selected.type)
		if not ItemSources.lookup(catalog,name,type).is_empty(): item_reused+=1; continue
		var found: Dictionary=catalog.location(name,type)
		if found.is_empty(): missing.append(name); continue
		var key:=source_key(name,type,str(found.layer.get("binding_identity","")))
		mutex.lock(); var exists:=payloads.has(key); mutex.unlock()
		if exists: reused+=1; continue
		var payload: PackedByteArray=catalog.read_resource(name,type)
		if not catalog.failure.is_empty() or payload.is_empty(): failures.append(name+":"+str(type)+" "+str(catalog.failure)); continue
		mutex.lock()
		if not payloads.has(key):
			payloads[key]=payload; names[name+":"+str(type)]=true; bytes+=payload.size(); loaded+=1
		mutex.unlock()
	if progress.is_valid(): progress.call("spellbook-icons",names_to_load.size(),names_to_load.size())
	return {"total":names_to_load.size(),"completed":names_to_load.size(),"loaded":loaded,"reused":reused,"item_reused":item_reused,"missing":missing,"failures":failures,"resident_bytes":size_bytes()}
static func size_bytes() -> int:
	mutex.lock(); var result:=bytes; mutex.unlock(); return result
static func snapshot() -> Dictionary:
	mutex.lock(); var result:={"sources":payloads.size(),"names":names.size(),"bytes":bytes}; mutex.unlock(); return result
