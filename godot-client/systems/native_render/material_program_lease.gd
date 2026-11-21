extends RefCounted

# Bounded leases on the shader resources of private preparation materials. A
# Shader resource is observable here; the compiled GPU program behind its RID
# is not. Keep those identities separate and never retain area texture or
# callback references through a whole material.
var max_programs:=128
var max_bytes:=8*1024*1024
var entries: Dictionary={}
var order: Array[int]=[]
var shaders: Dictionary={}
var references:=0
var bytes:=0
var epoch:=0
var closed:=false
var stats:={"retained":0,"hits":0,"evicted":0}

func _shader_key(shader: Shader) -> String:
	# A Shader RID/instance ID survives code edits. Three instead hands adopt an
	# immutable compiled program identity, so a changed resource cannot hit an
	# earlier lease under the same owner ID.
	return str(shader.get_instance_id())+"|"+shader.code.sha256_text()

func adopt(material: Material, requested_epoch: int=-1) -> bool:
	if closed or material==null or not material is ShaderMaterial:return false
	if requested_epoch>=0 and requested_epoch!=epoch:return false
	var id:=material.get_instance_id()
	if not material.get_rid().is_valid():return false
	var owner:=material as ShaderMaterial
	var shader: Shader=owner.shader
	if shader==null or not shader.get_rid().is_valid():return false
	var shader_id:=shader.get_instance_id()
	var shader_key:=_shader_key(shader)
	if entries.has(id):
		if str(entries[id].shader_key)==shader_key:return false
		evict_id(id)
	for old_id in order.duplicate():
		if entries.has(old_id) and int(entries[old_id].shader_id)==shader_id and str(entries[old_id].shader_key)!=shader_key:evict_id(old_id)
	if shaders.has(shader_key):
		# Old adopt refuses a second lease on an already retained program, but
		# refreshes all of its existing owners' LRU positions.
		for owner_id in shaders[shader_key].keys():
			order.erase(int(owner_id));order.append(int(owner_id))
		stats.hits+=1
		return false
	var key:=str(material.call("shader_variant_key")) if material.has_method("shader_variant_key") else ""
	var cost:=shader.code.length()*2+key.length()*2
	if cost>max_bytes or max_programs<1:return false
	while not order.is_empty() and (references+1>max_programs or bytes+cost>max_bytes):evict_id(order[0])
	entries[id]={"shader":shader,"shader_id":shader_id,"shader_key":shader_key,"bytes":cost}
	order.append(id)
	var owners: Dictionary={}
	owners[id]=true
	shaders[shader_key]=owners
	references+=1;bytes+=cost;stats.retained+=1
	return true

func evict(material: Material) -> void:
	if material!=null:evict_id(material.get_instance_id())

func evict_id(id: int) -> void:
	if not entries.has(id):return
	var entry: Dictionary=entries[id]
	entries.erase(id);order.erase(id)
	var owners: Dictionary=shaders.get(entry.shader_key,{})
	owners.erase(id)
	if owners.is_empty():shaders.erase(entry.shader_key)
	references-=1;bytes-=int(entry.bytes);stats.evicted+=1
	# Dropping this entry releases only this owner's Shader reference.

func clear() -> void:
	epoch+=1
	for id in order.duplicate():evict_id(id)

func snapshot() -> Dictionary:
	return {"retained":stats.retained,"hits":stats.hits,"evicted":stats.evicted,"materials":entries.size(),"programs":shaders.size(),"references":references,"bytes":bytes,"maxPrograms":max_programs,"maxBytes":max_bytes,"epoch":epoch,"supported":false,"resource_leases_supported":true,"closed":closed,"identity":"Godot Shader resource, not compiled GPU program"}

func dispose() -> void:
	if closed:return
	closed=true
	clear()
