extends SceneTree

# Static-model component experiment: direct Part-tree construction from one
# decoded original MDL bundle versus the current PackedScene template route and
# the existing known-node recipe path, which also skips PackedScene packing.
# No asset I/O, decode, frame pacing, GPU timing or live-scene FPS is measured.
const Instance=preload("res://systems/native_render/model_instance.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const ReferenceGraph=preload("res://systems/native_render/reference_graph.gd")
const FIXTURE="res://.cache/nwn70/counts-b/tcn01_a01_01-original.var"
const PLACEMENTS=32
const CHECKPOINTS=[1,2,3,4,16,32]

var failures: Array=[]

func _initialize() -> void: call_deferred("run")

func load_bundle() -> Dictionary:
	var file:=FileAccess.open(FIXTURE,FileAccess.READ)
	if file==null:failures.append("Pinned decoded original tile fixture is unavailable");return {}
	var value=file.get_var(false);file.close()
	if not value is Dictionary or not value.has("value") or not value.has("sha256"):
		failures.append("Original tile fixture has no decoded model/identity")
		return {}
	return value

func direct_create(bundle: Dictionary,pool) -> Dictionary:
	var source:=Instance.new()
	if not source.install(bundle,pool):
		var reason:=source.failure;source.free()
		return {"error":"Direct model install: "+reason}
	var placement:=Template.Placement.new()
	placement.set_meta("native_model_name",str(source.get_meta("native_model_name",bundle.get("resource_name",""))))
	placement.limitations=source.limitations.duplicate()
	var bounds:=Template.scene_bounds(source)
	var root_node:=Node3D.new()
	if bounds.valid:root_node.set_meta("native_scene_bounds",bounds.bounds);placement.set_meta("native_scene_bounds",bounds.bounds)
	for part in source.parts:
		if part.get_parent()==source:part.reparent(root_node,false)
	placement.add_child(root_node)
	placement.parts=source.parts.duplicate()
	placement.meshes=source.meshes.duplicate()
	placement.pick_surfaces=source.pick_surfaces.duplicate()
	source.parts.clear();source.meshes.clear();source.pick_surfaces.clear();source.free()
	var references: Array=[]
	if bundle.value.nodes.any(func(row):return row.has("reference")):
		for row in bundle.value.nodes:references.append({"name":row.name,"parent":row.parent})
		placement.reference_graph=ReferenceGraph.new()
		if not placement.reference_graph.configure(placement,references,placement.parts):
			placement.free();return {"error":"Direct reference graph configuration failed"}
	return {"instance":placement,"error":""}

func structure(value) -> Dictionary:
	var parts: Array=[]
	for part in value.parts:
		parts.append([int(part.get_meta("native_part_index")),int(part.get_meta("native_part_parent")),str(part.get_meta("native_part_name")),part.transform])
	var meshes: Array=[]
	for mesh in value.meshes:
		var surfaces: Array=[]
		for index in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(index)
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(arrays))
			surfaces.append([arrays[Mesh.ARRAY_VERTEX].size(),arrays[Mesh.ARRAY_INDEX].size(),mesh.mesh.surface_get_primitive_type(index),hash.finish().hex_encode()])
		meshes.append([str(mesh.name),mesh.transform,surfaces,mesh.material_override.get_class() if mesh.material_override!=null else ""])
	return {"parts":parts,"meshes":meshes,"picks":value.pick_surfaces.size(),"bounds":value.get_meta("native_scene_bounds",null),"references":value.reference_graph.rows.size() if value.reference_graph!=null else 0}

func summary(samples: Array) -> Dictionary:
	if samples.is_empty():return {"count":0}
	var sorted:=samples.duplicate();sorted.sort();var total:=0
	for value in sorted:total+=int(value)
	return {"count":sorted.size(),"mean_us":float(total)/sorted.size(),"median_us":sorted[sorted.size()/2],"p95_us":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)],"max_us":sorted[-1]}

func measure(mode: String,bundle: Dictionary) -> Dictionary:
	var pool:=Pool.new()
	pool.cooperative_templates=mode=="recipe"
	var template
	var instances: Array=[]
	var samples: Array=[]
	var checkpoints: Dictionary={}
	var initial:=Time.get_ticks_usec()
	var build_us:=0
	if mode!="direct":
		template=Template.new()
		if not template.build(bundle,pool):
			var reason: String=str(template.failure);pool.clear();return {"mode":mode,"error":"Template build: "+reason}
		build_us=Time.get_ticks_usec()-initial
	for index in PLACEMENTS:
		var began:=Time.get_ticks_usec()
		var instance
		if mode!="direct":instance=template.create()
		else:
			var result:=direct_create(bundle,pool)
			if not str(result.error).is_empty():
				for prior in instances:prior.free()
				pool.clear();return {"mode":mode,"error":result.error}
			instance=result.instance
		if instance==null:
			for prior in instances:prior.free()
			pool.clear();return {"mode":mode,"error":"Null placement at "+str(index)}
		samples.append(Time.get_ticks_usec()-began)
		instances.append(instance)
		if CHECKPOINTS.has(index+1):checkpoints[str(index+1)]=Time.get_ticks_usec()-initial
	var result:={"mode":mode,"template_mode":template.construction_snapshot().mode if template!=null else "direct-part-tree","fallback":template.recipe_fallback_reason if template!=null else "","error":"","build_us":build_us,"first_us":int(checkpoints["1"]),"checkpoints_us":checkpoints,"repeat":summary(samples.slice(1)),"first_structure":structure(instances[0]),"last_structure":structure(instances[-1]),"pool_created":{"templates":pool.stats.templates_created,"meshes":pool.stats.meshes_created,"textures":pool.stats.textures_created,"materials":pool.stats.materials_created},"pool_hits":{"meshes":pool.stats.mesh_hits,"textures":pool.stats.texture_hits,"materials":pool.stats.material_hits}}
	for instance in instances:instance.free()
	template=null;pool.clear()
	return result

func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var bundle:=load_bundle()
	if bundle.is_empty():print(JSON.stringify({"success":false,"failures":failures}));quit(2);return
	var legs: Array=[]
	for mode in ["packed","direct","recipe","recipe","direct","packed"]:
		var leg:=measure(mode,bundle)
		legs.append(leg)
		if not str(leg.error).is_empty():failures.append(str(leg.error));break
	if failures.is_empty():
		for leg in legs:
			if leg.first_structure!=legs[0].first_structure or leg.last_structure!=legs[0].last_structure:
				failures.append("Direct and packed physical Part/mesh/bounds/reference structures differ")
				break
	var output:={"success":failures.is_empty(),"failures":failures,"fixture":FIXTURE,"fixture_sha256":FileAccess.get_sha256(FIXTURE),"engine":Engine.get_version_info(),"model":str(bundle.get("resource_name",bundle.value.name)),"source_nodes":bundle.value.nodes.size(),"placements":PLACEMENTS,"order":"packed-direct-recipe-recipe-direct-packed","legs":legs,"scope":"Actual decoded original static tile; separate fresh ResourcePool per leg; pack/build and 1/2/3/4/16/32 placements timed with all placements retained. Structural Part/mesh-bytes/bounds/reference parity required. Headless CPU component timing only; no native-binary timing, GPU pixels, actor animation, asset I/O, area admission or FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:print("Cannot write benchmark report: ",report);quit(2);return
	file.store_string(JSON.stringify(output,"  ")+"\n");file.close()
	print("NWN75_DIRECT_MODEL_PREP ",JSON.stringify({"success":output.success,"failures":failures,"checkpoints":legs.map(func(leg):return {"mode":leg.mode,"us":leg.checkpoints_us})}))
	quit(0 if failures.is_empty() else 1)
