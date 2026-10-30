extends SceneTree
const Prepare=preload("res://systems/native_data/skin_preparation.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Rigs=preload("res://systems/model_rigs.gd")
const Data=preload("res://systems/native_data/actor_model.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
class CapturedErrors:
	extends Rigs
	func _fail(message: String) -> void:
		stats.failures.append(message)
var checks:=0
var failures: Array=[]
var observations: Array=[]
var old_actor: GDScript
var old_rigs: GDScript
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func data_only(value: Variant) -> bool:
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL]: return false
	if value is Dictionary:
		for key in value:
			if not data_only(key) or not data_only(value[key]): return false
	elif value is Array:
		for entry in value:
			if not data_only(entry): return false
	return true
func _initialize() -> void: call_deferred("run")
func authored(normals: bool,uv: bool) -> Dictionary:
	var slots:=PackedInt32Array(); slots.resize(64); slots.fill(-1); slots[0]=1; slots[1]=0
	return {"mesh":{"vertices":PackedFloat32Array([-0.0,0,0,2,0,0,0,3,1]),"normals":PackedFloat32Array([0,1,0,0,0,1,1,0,0]) if normals else PackedFloat32Array(),"uv":[PackedFloat32Array([-0.0,0,1,0,0,1])] if uv else [],"indices":PackedInt32Array([0,1,2,0,2,1])},"skin":{"weights":PackedFloat32Array([0.5,0.5,0,0,-0.25,0,0,0,0.2,0.2,0.2,0.2]),"boneIndices":PackedInt32Array([0,1,-7,100,100,100,-1,0,0,1,0,1]),"boneConstantSlots":slots,"qboneRefInv":[[1,0,0,0],[cos(0.25),0,0,sin(0.25)],[1,0,0,0]],"tboneRefInv":[[0,0,0],[1.25,3.5,-5.75],[0,0,0]]}}
func mesh_node(parent: Node3D) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new(); var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	var geometry:=ArrayMesh.new(); geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.mesh=geometry; mesh.material_override=StandardMaterial3D.new(); parent.add_child(mesh); return mesh
func compare(row: Dictionary,part: int,parts: Array,label: String,expected_error: bool=false) -> void:
	var digest:=Cache.digest(var_to_bytes(row)); var reference_actor=old_actor.new(); var actor:=Actor.new(); actor.use_prepared_skins=true
	var began:=Time.get_ticks_usec(); var a: Dictionary=reference_actor.skin_source(row,0,part); var source_ms:=(Time.get_ticks_usec()-began)/1000.0
	var prepared:=Prepare.prepare(row)
	check(str(prepared.error).is_empty(),label+": data-only skin preparation succeeds")
	check(Cache.digest(var_to_bytes(row))==digest,label+": source geometry, weights, slots and inverse binds stay immutable")
	if not str(prepared.error).is_empty(): reference_actor.free(); actor.free(); return
	var cooked:=row.duplicate(); cooked.skin=row.skin.duplicate(); cooked.skin.native_upload=prepared
	began=Time.get_ticks_usec(); var b: Dictionary=actor.skin_source(cooked,0,part); var cooked_source_ms:=(Time.get_ticks_usec()-began)/1000.0
	for field in ["position","normal","uv","weights"]: check(same(PackedFloat32Array(a[field]),b[field]),label+": exact FLOAT source stream "+field)
	check(same(PackedInt32Array(a.bones),b.bones) and same(a.slots,b.slots) and same(a.inversePositions,b.inversePositions) and same(a.inverseQuaternions,b.inverseQuaternions),label+": raw bone slots/order and inverse-bind data are unchanged")
	var host:=Node3D.new(); root.add_child(host); var first=old_rigs.new(); var second:=CapturedErrors.new(); host.add_child(first); host.add_child(second); first.set_process(false); second.set_process(false)
	var mesh_a:=mesh_node(host); var mesh_b:=mesh_node(host)
	began=Time.get_ticks_usec(); var skin_a: Dictionary=first._skin(mesh_a,a,parts); var runtime_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var skin_b: Dictionary=second._skin(mesh_b,b,parts); var cooked_runtime_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(same(first.stats.failures,second.stats.failures) and skin_a.is_empty()==skin_b.is_empty(),label+": exact nonstandard weight/slot runtime error and scope")
	check((first.stats.failures==["A native skin weight/slot needs an explicit nonstandard-weight adapter"] and skin_a.is_empty()) if expected_error else (first.stats.failures.is_empty() and not skin_a.is_empty()),label+": expected rejection/success is required, not only agreement between paths")
	if not skin_a.is_empty() and not skin_b.is_empty():
		check(same(mesh_a.mesh.surface_get_arrays(0),mesh_b.mesh.surface_get_arrays(0)) and mesh_a.mesh.get_aabb()==mesh_b.mesh.get_aabb() and mesh_a.custom_aabb==mesh_b.custom_aabb,label+": real ArrayMesh streams/winding/bounds remain exact")
		check(same(skin_a.bones,skin_b.bones) and same(skin_a.inverse,skin_b.inverse) and skin_a.part==skin_b.part,label+": private runtime bone mappings and bind matrices remain exact")
		check(skin_a.skeleton!=skin_b.skeleton and mesh_a.skin!=mesh_b.skin and second.stats.skin_prepared_meshes==1 and second.stats.skin_main_meshes==0,label+": prepared streams retain private skeleton/bind owners and bypass main vertex loops")
		for slot in 65:
			var pose:=Vector3(slot*0.001,slot*0.002,-slot*0.003)
			skin_a.skeleton.set_bone_pose_position(slot,pose); skin_b.skeleton.set_bone_pose_position(slot,pose)
		skin_a.skeleton.force_update_all_bone_transforms(); skin_b.skeleton.force_update_all_bone_transforms()
		await process_frame; await process_frame
		var baked_a:=mesh_a.bake_mesh_from_current_skeleton_pose(); var baked_b:=mesh_b.bake_mesh_from_current_skeleton_pose()
		check(baked_a!=null and baked_b!=null and same(baked_a.surface_get_arrays(0),baked_b.surface_get_arrays(0)),label+": real skeleton-pose mesh baking stays byte-exact")
		actor.rigs=second; actor.object_id=17; second.entities[17]={"models":[],"skins":[skin_b]}
		var retained: Dictionary=actor.retain_decoded_data()
		check(retained.get("skin_sources",[]).size()==1 and is_same(retained.skin_sources[0],b) and data_only(retained),label+": deferred actor disposal retains only immutable skin data, never live skeleton/mesh/bind owners")
		actor.rigs=null
		actor.use_prepared_skins=false; var fallback: Dictionary=actor.skin_source(cooked,0,part)
		check(same(fallback,a),label+": explicit main-thread reference ignores the worker derivative without changing source data")
	observations.append({"name":label,"vertices":prepared.positions.size(),"reference_source_ms":source_ms,"prepared_source_ms":cooked_source_ms,"reference_runtime_ms":runtime_ms,"prepared_runtime_ms":cooked_runtime_ms,"error":second.stats.failures.duplicate()})
	host.free(); reference_actor.free(); actor.free(); await process_frame
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var archive:="res://backups/native-loading-background-cache-v1.zip"
	check(FileAccess.get_sha256(archive)=="25be0a6ac95d25d7664eccc7256322696e2c7aa37e19a84c9d059f7d99d1478b","Verified authored pre-skin checkpoint remains unchanged")
	var zip:=ZIPReader.new(); check(zip.open(archive)==OK,"Pinned authored reference opens without original asset copies")
	var actor_code:=zip.read_file("systems/native_render/actor_instance.gd"); var rig_code:=zip.read_file("systems/model_rigs.gd"); zip.close()
	check(Cache.digest(actor_code)=="e53e5e09696961611830a5fb72bd6da9265419f7a8e38d9b4a4dff97e34b5618" and Cache.digest(rig_code)=="5cec928d2bad03fdbaa6f0f7775d025ea9149db374604697a2d0847de37e7116","Both exact pre-change native skin routes are source-hash pinned")
	old_actor=GDScript.new(); old_actor.source_code=actor_code.get_string_from_utf8(); old_rigs=GDScript.new()
	var original_rig_code:=rig_code.get_string_from_utf8()
	check(original_rig_code.count("\tpush_error(message)")==1,"Only the pinned error logger is captured; reference control flow/asserted failures stay intact")
	old_rigs.source_code=original_rig_code.replace("\tpush_error(message)","\tpass # Fixture captures expected errors through stats.failures")
	check(old_actor.reload()==OK and old_rigs.reload()==OK,"Independent original authored skin-source/runtime scripts compile")
	for normals in [false,true]:
		for uv in [false,true]: await compare(authored(normals,uv),2,[0,1,2],"authored normals="+str(normals)+" uv="+str(uv))
	for mode in ["zero","overweight","missing-slot","negative-index","sentinel","degenerate"]:
		var row:=authored(false,false)
		match mode:
			"zero": row.skin.weights.fill(0); row.skin.boneIndices.fill(-999)
			"overweight": row.skin.weights[0]=1.25
			"missing-slot": row.skin.boneConstantSlots[0]=99
			"negative-index": row.skin.boneIndices[0]=-1
			"sentinel": row.skin.boneConstantSlots[0]=0; row.skin.boneConstantSlots[1]=0
			"degenerate": row.mesh.indices=PackedInt32Array([0,0,1])
		await compare(row,2,[0,1,2],"authored "+mode,mode in ["overweight","missing-slot","negative-index","sentinel"])
	var malformed:=authored(false,false); malformed.skin.weights.resize(1)
	check(not str(Prepare.prepare(malformed).error).is_empty(),"Malformed influence shape returns a data-preparation error without indexing outside source")
	malformed=authored(false,false); malformed.mesh.indices[0]=100
	check(not str(Prepare.prepare(malformed).error).is_empty(),"Malformed native triangle is bounded before worker vertex access")
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original skin corpus mounts")
	for name in ["pme0_robe055","pme0_robe021","pfe0_robe103","pfe0_robe033"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=Data.new(); parser.packed_keys=true; var model: Dictionary=parser.parse(bytes)
		check(not bytes.is_empty() and catalog.failure.is_empty() and parser.failure.is_empty(),"Captured original model parses: "+name)
		var count:=0
		for index in model.get("nodes",[]).size():
			var row: Dictionary=model.nodes[index]
			if row.has("skin") and not row.mesh.is_empty() and not row.mesh.indices.is_empty(): count+=1; await compare(row,index,Array(range(model.nodes.size())),name+"/"+str(index))
		check(count>0,"Original source exercises actual skin geometry: "+name)
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"public_connections":0,"scope":"Exact typed skin source, real ArrayMesh/bounds/private binds and posed mesh baking versus hashed authored pre-change code; original sealed models plus normals/UV/zero/nonunit/invalid weights/slots/sentinel cases. Graphical CDB/native heap; not whole-world timing/FPS or original-binary visual parity."},"\t")); output.close(); print("NATIVE_SKIN_PREPARATION ",checks," checks"); quit(0 if failures.is_empty() else 1)
