extends RefCounted
# Last observed visual data only. Never a BIC, inventory owner, login credential
# or source for a gameplay request. Active server tables resolve it on reuse.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const MAX_BYTES:=65536
const MAGIC:="NWNAPV1\n"
var directory:=ProjectSettings.globalize_path("user://character-appearance-v1")
var memory: Dictionary={}
var error:=""
static func identity(state: Dictionary) -> Array:
	var account:=str(state.get("previewAccountScope","")); var endpoint: Variant=state.get("endpoint"); var key:=str(state.get("selected","") if state.get("selected")!=null else "")
	if account.length()!=64 or not account.is_valid_hex_number(false) or not endpoint is Dictionary or not key.begins_with("server:") or key.length()>256: return []
	var host:=str(endpoint.get("host","")).to_lower().trim_suffix("."); var port:=int(endpoint.get("port",0))
	if host.is_empty() or host.length()>255 or port<1 or port>65535: return []
	return [account,host,port,key]
static func bounded_int(value: Variant,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=maximum
static func visual(actor: Dictionary) -> Dictionary:
	if int(actor.get("objectType",-1))!=5 or actor.get("replicationRemoved",false) or not actor.get("appearance") is Dictionary: return {}
	var raw: Dictionary=actor.appearance; var a: Dictionary={}; var equipment: Array=[]
	for field in ["appearance","head","phenotype","gender","skin","hair","tattoo1","tattoo2","fieldAA4","fieldAA8"]:
		var value: Variant=raw.get(field,0) if field!="appearance" else raw.get(field)
		if not bounded_int(value,4294967295 if field in ["fieldAA4","fieldAA8"] else 65535): return {}
		a[field]=int(value)
	if not raw.get("bodyParts") is Array or raw.bodyParts.size()>19 or not raw.get("equipment") is Array or raw.equipment.size()>18: return {}
	a.bodyParts=[]; a.equipment=[]; var seen: Dictionary={}
	for part in raw.bodyParts:
		if not part is Dictionary or not bounded_int(part.get("index"),18) or not bounded_int(part.get("value"),65535) or seen.has(int(part.index)): return {}
		seen[int(part.index)]=true; a.bodyParts.append({"index":int(part.index),"value":int(part.value)})
	seen={}
	for entry in raw.equipment:
		if not entry is Dictionary or not bounded_int(entry.get("slot"),131072) or int(entry.slot)==0 or int(entry.slot)&(int(entry.slot)-1)!=0 or seen.has(int(entry.slot)) or not entry.get("item") is Dictionary: return {}
		seen[int(entry.slot)]=true; var item: Dictionary=entry.item
		if not bounded_int(item.get("baseItem"),2147483647) or not bounded_int(item.get("modelType"),3): return {}
		var parts: Variant=item.get("parts"); var colors: Variant=item.get("colors",[]); var per_part: Variant=item.get("partColors",[])
		if not parts is Array or parts.size()!=(19 if int(item.modelType)==3 else 3 if int(item.modelType)==2 else 1) or not colors is Array or colors.size()>6 or not per_part is Array or per_part.size()>19: return {}
		if not parts.all(func(value):return bounded_int(value,65535)) or not colors.all(func(value):return bounded_int(value,255)): return {}
		for channels in per_part:
			if not channels is Array or channels.size()>6 or not channels.all(func(value):return bounded_int(value,255)): return {}
		var model: Array=parts.duplicate() if int(item.modelType)!=3 else [0,0,0]
		while model.size()<3: model.append(0)
		equipment.append({"slot":int(entry.slot),"item":{"baseItem":int(item.baseItem),"savedModelType":int(item.modelType),"modelParts":model,"armorParts":parts.duplicate() if int(item.modelType)==3 else [],"colors":colors.duplicate(),"partColors":per_part.duplicate(true)}})
	var stats: Dictionary=actor.get("replicated",{}).get("stats",{}); var race: Variant=stats.get("racialType",stats.get("fieldD20"))
	if not bounded_int(race,255): return {}
	return {"appearance":a,"equipment":equipment,"equipmentComplete":true,"race":int(race),"native_only":true}
static func valid_source(source: Dictionary) -> bool:
	if source.get("equipmentComplete")!=true or not source.get("appearance") is Dictionary or not source.get("equipment") is Array or not bounded_int(source.get("race"),255): return false
	var a: Dictionary=source.appearance.duplicate(true); a.equipment=[]
	for entry in source.equipment:
		if not entry is Dictionary or not entry.get("item") is Dictionary: return false
		var item: Dictionary=entry.item
		if not bounded_int(item.get("savedModelType"),3) or not item.get("modelParts") is Array or item.modelParts.size()!=3 or not item.get("armorParts") is Array: return false
		var type:=int(item.savedModelType)
		if item.armorParts.size()!=(19 if type==3 else 0): return false
		a.equipment.append({"slot":entry.get("slot"),"item":{"baseItem":item.get("baseItem"),"modelType":type,"parts":item.armorParts if type==3 else item.modelParts.slice(0,3 if type==2 else 1),"colors":item.get("colors"),"partColors":item.get("partColors")}})
	return visual({"objectType":5,"appearance":a,"replicated":{"stats":{"racialType":source.race}}})==source
func filename(scope: Array) -> String: return directory.path_join(Cache.digest(var_to_bytes(scope))+".appearance")
func save_seen(scope: Array,actor: Dictionary) -> bool:
	error=""
	if scope.size()!=4: return false
	var source:=visual(actor)
	if source.is_empty(): error="Appearance was incomplete; the previous preview was kept."; return false
	var entry:={"version":1,"scope":scope.duplicate(),"source":source,"seenAt":int(Time.get_unix_time_from_system()),"digest":Cache.digest(var_to_bytes(source))}
	var bytes:=var_to_bytes(entry)
	if bytes.size()+76>MAX_BYTES or DirAccess.make_dir_recursive_absolute(directory)!=OK: error="Appearance preview storage is unavailable."; return false
	var path:=filename(scope); var temporary:=path+".tmp"; var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: error="Appearance preview could not be saved."; return false
	file.store_buffer(MAGIC.to_ascii_buffer()); file.store_buffer(Cache.digest(bytes).to_ascii_buffer()); file.store_32(bytes.size()); file.store_buffer(bytes); file.flush(); file.close()
	if DirAccess.rename_absolute(temporary,path)!=OK:
		DirAccess.remove_absolute(temporary); error="Appearance preview could not be replaced."; return false
	memory[Cache.digest(var_to_bytes(scope))]=entry; return true
func read_seen(scope: Array) -> Dictionary:
	if scope.size()!=4: return {}
	var key:=Cache.digest(var_to_bytes(scope))
	if memory.has(key): return memory[key].duplicate(true)
	var value: Dictionary={}; var file:=FileAccess.open(filename(scope),FileAccess.READ)
	if file!=null:
		if file.get_length()>=76 and file.get_length()<=MAX_BYTES and file.get_buffer(8).get_string_from_ascii()==MAGIC:
			var digest:=file.get_buffer(64).get_string_from_ascii(); var count:=file.get_32()
			if count==file.get_length()-76:
				var bytes:=file.get_buffer(count)
				if Cache.digest(bytes)==digest:
					var decoded: Variant=bytes_to_var(bytes)
					if decoded is Dictionary and decoded.get("version")==1 and decoded.get("scope")==scope and decoded.get("source") is Dictionary and bounded_int(decoded.get("seenAt"),4294967295) and str(decoded.get("digest",""))==Cache.digest(var_to_bytes(decoded.source)) and valid_source(decoded.source): value=decoded
		file.close()
	memory[key]=value; return value.duplicate(true)
