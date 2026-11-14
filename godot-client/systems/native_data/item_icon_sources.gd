extends RefCounted
# The installed and server-selected item icon payloads stay resident for the
# process. Binding identity keeps a later NWSync/HAK override distinct from the
# installed resource with the same name.
static var mutex:=Mutex.new()
static var payloads: Dictionary={}
static var names: Dictionary={}
static var bytes:=0
static func source_key(name: String,type: int,identity: String) -> String:
	return identity+":"+name.to_lower()+":"+str(type)
static func lookup(catalog,name: String,type: int) -> PackedByteArray:
	if type not in [3,6]: return PackedByteArray()
	var simple:=name.to_lower()+":"+str(type)
	mutex.lock(); var known:=names.has(simple); mutex.unlock()
	if not known: return PackedByteArray()
	var found: Dictionary=catalog.location(name,type)
	if found.is_empty(): return PackedByteArray()
	var key:=source_key(name,type,str(found.layer.get("binding_identity","")))
	mutex.lock(); var result: PackedByteArray=payloads.get(key,PackedByteArray()); mutex.unlock()
	return result
static func preload_all(catalog,stop: Callable=Callable(),progress: Callable=Callable()) -> Dictionary:
	var referenced: Dictionary={}
	for table_name in ["baseitems","iprp_spells"]:
		var table_bytes: PackedByteArray=catalog.get_resource(table_name,2017)
		if table_bytes.is_empty(): continue
		var table: Dictionary=preload("res://systems/native_data/two_da.gd").new().parse(table_bytes.get_string_from_ascii())
		for row in table.get("orderedRows",[]):
			var field: String=str(row.get("DefaultIcon","")) if table_name=="baseitems" else str(row.get("Icon",""))
			if field not in ["","****"]: referenced[field.to_lower()]=true
	var work: Array=[]
	for type in [3,6]:
		for name in catalog.resource_names(type):
			if str(name).begins_with("i") or referenced.has(str(name)): work.append([str(name),type])
	work.sort_custom(func(a,b): return a[1]<b[1] or a[1]==b[1] and a[0]<b[0])
	var loaded:=0; var reused:=0; var failures: Array=[]
	for index in work.size():
		if index%32==0:
			if stop.is_valid() and stop.call(): return {"cancelled":true,"total":work.size(),"completed":index,"loaded":loaded,"reused":reused,"failures":failures}
			if progress.is_valid(): progress.call("item-icons",index,work.size())
		var name: String=work[index][0]; var type: int=work[index][1]
		var found: Dictionary=catalog.location(name,type)
		if found.is_empty(): failures.append(name+":"+str(type)+" unavailable"); continue
		var key:=source_key(name,type,str(found.layer.get("binding_identity","")))
		mutex.lock(); var exists:=payloads.has(key); mutex.unlock()
		if exists: reused+=1; continue
		var payload: PackedByteArray=catalog.read_resource(name,type)
		if not catalog.failure.is_empty() or payload.is_empty(): failures.append(name+":"+str(type)+" "+catalog.failure); continue
		mutex.lock()
		if not payloads.has(key):
			payloads[key]=payload; names[name.to_lower()+":"+str(type)]=true; bytes+=payload.size(); loaded+=1
		mutex.unlock()
	if progress.is_valid(): progress.call("item-icons",work.size(),work.size())
	return {"total":work.size(),"completed":work.size(),"loaded":loaded,"reused":reused,"referenced":referenced.size(),"failures":failures,"resident_bytes":size_bytes()}
static func size_bytes() -> int:
	mutex.lock(); var result:=bytes; mutex.unlock(); return result
static func snapshot() -> Dictionary:
	mutex.lock(); var result:={"sources":payloads.size(),"names":names.size(),"bytes":bytes}; mutex.unlock(); return result
