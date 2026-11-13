extends SceneTree
const Residency=preload("res://systems/native_render/weak_resource_residency.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var expect_recovery:=false
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	expect_recovery=OS.get_cmdline_user_args().has("--expect-recovery=true")
	call_deferred("run")
func helper_checks() -> void:
	var cache:=Residency.new(2)
	var a:=Resource.new();var b:=Resource.new();var c:=Resource.new()
	cache.remember("mesh","a",a);cache.remember("mesh","b",b)
	check(cache.take("mesh","a")==a,"live weak binding recovers the same Resource")
	cache.remember("mesh","a",a) # Reinsert into slot zero, then overwrite the stale slot safely.
	cache.remember("mesh","c",c)
	check(cache.take("mesh","a")==a,"stale ring entries cannot erase a reinserted binding")
	check(cache.take("mesh","b")==null,"weak metadata is bounded and may evict old bindings")
	check(cache.take("mesh","c")==c,"new weak binding survives metadata eviction")
	cache.remember("texture","same",a);cache.remember("material","same",b)
	check(cache.take("texture","same")==a and cache.take("material","same")==b,"kinds with identical keys do not alias")
	cache.remember("texture","expired",c);var weak: WeakRef=weakref(c);c=null
	check(weak.get_ref()==null,"weak residency never extends resource lifetime")
	for ignored in range(32):var replacement:=Resource.new() # Allocate later lifetimes after expiration.
	check(cache.take("texture","expired")==null,"expired references cannot revive a later resource")
	cache.remember("mesh","clear",a);cache.clear()
	check(cache.take("mesh","clear")==null,"explicit clear invalidates even still-live resources")
	cache.remember("mesh","forget",a);cache.forget("mesh","forget")
	check(cache.take("mesh","forget")==null,"primary publication forgets secondary bindings")
	var before:=cache.snapshot();before.entries.mesh=9999
	check(cache.snapshot().entries.mesh!=9999,"numeric snapshots are detached")
	for index in range(100):cache.remember("bounded",str(index),a)
	check(cache.snapshot().entries.bounded<=2 and cache.snapshot().slots.bounded==2,"ring and weak directory stay bounded")
	cache.clear()
	var stale:=Residency.new(3)
	stale.remember("mesh","a",a);stale.remember("mesh","b",b);stale.remember("mesh","third",a)
	check(stale.take("mesh","b")==b,"remove a slot ahead of the replacement cursor")
	stale.remember("mesh","b",b);stale.remember("mesh","fourth",a)
	check(stale.take("mesh","b")==b,"overwriting an old slot cannot erase the same key reinserted into another slot")
	stale.clear()
func raster(key: String,color: PackedByteArray) -> Dictionary:
	return {"sha256":key.repeat(64),"value":{"width":1,"height":1,"format":"rgba8","mips":[{"width":1,"height":1,"data":color}]}}
func geometry() -> Dictionary:
	return {"vertices":PackedFloat32Array([0,0,0,1,0,0,0,1,0]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array([0,0,1,0,0,1,0,0,1]),"uv":[PackedFloat32Array([0,0,1,0,0,1])]}
func pool_checks() -> Dictionary:
	var pool:=Pool.new();pool.maximum_meshes=1;pool.maximum_textures=1;pool.maximum_materials=1;pool.use_prepared_geometry=false
	var red:=raster("a",PackedByteArray([255,0,0,255]));var blue:=raster("b",PackedByteArray([0,0,255,255]))
	var texture_a:=pool.texture(red);var texture_b:=pool.texture(blue)
	check(texture_a!=null and texture_b!=null,"headless publication creates native texture Resources")
	var mesh_data:=geometry();var mesh_a:=pool.geometry("a".repeat(64),0,mesh_data);var mesh_b:=pool.geometry("b".repeat(64),0,mesh_data)
	check(mesh_a!=null and mesh_b!=null,"headless publication creates native mesh Resources")
	var part_a:={"mesh":{"diffuse":[1.0,0.0,0.0]}};var part_b:={"mesh":{"diffuse":[0.0,0.0,1.0]}}
	var material_a:=pool.material(part_a);var material_b:=pool.material(part_b)
	check(material_a!=null and material_b!=null,"headless publication creates native material Resources")
	var first_texture_id:=texture_a.get_instance_id();var first_mesh_id:=mesh_a.get_instance_id();var first_material_id:=material_a.get_instance_id()
	for index in range(100):
		var choice:=index%2==0
		var texture:=pool.texture(red if choice else blue)
		var mesh:=pool.geometry(("a" if choice else "b").repeat(64),0,mesh_data)
		var material:=pool.material(part_a if choice else part_b)
		if expect_recovery:
			check(texture==(texture_a if choice else texture_b),"evicted live texture keeps object identity")
			check(mesh==(mesh_a if choice else mesh_b),"evicted live mesh keeps object identity")
			check(material==(material_a if choice else material_b),"evicted live material keeps object identity")
		else:
			check(texture!=(texture_a if choice else texture_b),"baseline fixture demonstrates live texture recreation")
			check(mesh!=(mesh_a if choice else mesh_b),"baseline fixture demonstrates live mesh recreation")
			check(material!=(material_a if choice else material_b),"baseline fixture demonstrates live material recreation")
		check(pool.meshes.size()==1 and pool.textures.size()==1 and pool.materials.size()==1,"strong cache capacities are unchanged")
	check(material_a.albedo_color==Color(1,0,0,1) and material_b.albedo_color==Color(0,0,1,1),"recovery never mutates shared material inputs")
	var state:=pool.snapshot()
	check(int(state.textures_created)==(2 if expect_recovery else 102),"texture publication count reflects recovery")
	check(int(state.meshes_created)==(2 if expect_recovery else 102),"mesh publication count reflects recovery")
	check(int(state.materials_created)==(2 if expect_recovery else 102),"material publication count reflects recovery")
	pool.clear()
	check(pool.texture(red).get_instance_id()!=first_texture_id,"clear does not resurrect a live texture")
	check(pool.geometry("a".repeat(64),0,mesh_data).get_instance_id()!=first_mesh_id,"clear does not resurrect a live mesh")
	check(pool.material(part_a).get_instance_id()!=first_material_id,"clear does not resurrect a live material")
	pool.clear();pool.maximum_meshes=0;pool.maximum_textures=0;pool.maximum_materials=0
	check(pool.texture(red)!=pool.texture(red),"disabled texture retention stays disabled")
	check(pool.geometry("a".repeat(64),0,mesh_data)!=pool.geometry("a".repeat(64),0,mesh_data),"disabled mesh retention stays disabled")
	check(pool.material(part_a)!=pool.material(part_a),"disabled material retention stays disabled")
	pool.clear();return state
func run() -> void:
	helper_checks();var result:=pool_checks()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_recovery":expect_recovery,"publication_counts":{"meshes":result.meshes_created,"textures":result.textures_created,"materials":result.materials_created},"recovery_counts":{"mesh":result.get("mesh_resident_hits",0),"texture":result.get("texture_resident_hits",0),"material":result.get("material_resident_hits",0)},"limits":result.limits,"weak_residency":result.get("weak_residency",{}),"scope":"Isolated headless Resource identity/weak lifetime/cache-pressure proof; no drawing, GPU or FPS acceptance, and no server connections"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
