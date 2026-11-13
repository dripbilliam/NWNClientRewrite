extends "res://tests/native_scene_visibility_bridge_test.gd"
# Real factory/asset model adoption; authored source flags stay independent of
# optional shadow lowers. No world/server/GPU acceptance is inferred.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Placeable=preload("res://systems/native_render/placeable_instance.gd")
var completed: Dictionary={}
var source_assets: Array=[]
func mesh_row(name_value: String,casts: bool) -> Dictionary:
	return {"name":name_value,"parent":-1,"position":[0.,0.,0.],"orientation":[0.,0.,0.,1.],"scale":1.,"features":[],"flags":33,"alpha":.8,"selfillum":[0.,0.,0.],"mesh":{"vertices":PackedFloat32Array([0,0,0,1,0,0,0,0,1]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":true,"shadow":casts,"diffuse":[.2,.4,.6],"ambient":[.2,.4,.6]}}
func pooled_bundle() -> Dictionary:
	return {"sha256":"visibility-adoption-authored-mixed-casters-v1","resource_name":"authored_shadow_fixture","value":{"name":"authored_shadow_fixture","nodes":[mesh_row("caster",true),mesh_row("noncaster",false)]}}
func install_target(world: World,bridge: RefCounted,id: int,instance: Node3D,kind: int=9) -> Array:
	var value:=source(id,kind);value.replicated.position=[15.,5.,0.];admit(world,value)
	check(bridge.observe(value,[15.,5.,0.],"area-entry").available,"Native unloaded entity obtains retained opacity before real model adoption "+str(id))
	world.instances[id]=instance;world.installed[id]=world.desired[id].key
	return Lifetime.token(value)
func restored(bridge: RefCounted,world: World,id: int,life: Array,instance: Node3D,label: String) -> void:
	var original: Array=[]
	for mesh in instance.meshes:original.append(mesh.cast_shadow)
	check(bridge.capture_shadow_model(id,life).available,"Authentic cold primary ownership captures "+label)
	check(bridge.publish(id,life,{"kind":"native_shadow","enabled":false}) and instance.meshes.all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Primary shadow-off reaches exact physical endpoints "+label)
	var enabled: bool=bridge.publish(id,life,{"kind":"native_shadow","enabled":true});var matches:=true
	for index in original.size():matches=matches and instance.meshes[index].cast_shadow==original[index]
	check(enabled and matches,"Primary shadow-on restores every authored caster/noncaster exactly "+label)
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	extension=load("res://native/particle_kernel.gdextension")
	check(extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Approved existing native pose library loads without a rebuild")
	var world:=World.new();root.add_child(world);admit(world,source(99))
	world.effects=Effects.new();world.add_child(world.effects);world.effects.world=world;world.effects.client=world.effects;world.effects.set_process(false)
	var scope:={"connection_epoch":4,"area_generation":3,"area_id":7,"controlled_id":99,"controlled_lifetime":Lifetime.token(world.desired[99].object)}
	var bridge:=Bridge.new();var ports:={"scope_current":func(_scope):return true,"tile_center":func(_i,x,y):return [float(x*10+5),float(y*10+5)],"player_info":func():return {"available":true,"present":true,"visibility":{}},"creature_fields":func(_id,_life):return {"available":true,"creature110":0,"creature114":0},"scene_hook":func(_id,_life,_command):return true,"tile_fog":func(_event):return false,"fade_timing":func():return {"available":true,"snapshot_us":200000}}
	check(bridge.configure(world,scope,{"width":2,"height":2,"flags":1,"states":[1,0,0,0]},ports).available,"Actual bridge binds explicit native owner scope")
	var pools: Array=[];var physical: Array=[]
	for compact in [false,true]:
		var pool:=Pool.new();pool.compact_static_parts=compact;pools.append(pool)
		var template=pool.model_template(pooled_bundle());check(template!=null,"Actual single-model static factory builds compact="+str(compact))
		if template==null:continue
		var placement=template.create();world.add_child(placement);physical.append(placement)
		var id:=20+int(compact);var life:=install_target(world,bridge,id,placement)
		check(placement.meshes.size()==2 and not placement.meshes[0].has_meta("native_source_model_index") and placement.meshes[0].has_meta("native_mesh_source"),"Actual packed static clone preserves native model/Part provenance without Actor-only metadata")
		restored(bridge,world,id,life,placement,"pooled-static compact="+str(compact))
		var adopted: Dictionary=bridge.model_ready(id,life)
		check(adopted.available and adopted.shadow_available and not adopted.partial and not placement.meshes[0].visible and not placement.meshes[1].visible,"Actual pooled static alpha adopts retained zero independently of native shadow setting")
		check(placement.meshes[1].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Authored pooled noncaster remains off after opacity adoption")
		var unknown=template.create();world.add_child(unknown);physical.append(unknown);var unknown_id:=30+int(compact);var unknown_life:=install_target(world,bridge,unknown_id,unknown)
		unknown.meshes[0].remove_meta("native_mesh_source")
		adopted=bridge.model_ready(unknown_id,unknown_life)
		check(adopted.available and adopted.partial and not adopted.shadow_available and adopted.shadow_reason=="shadow-original-model-index-unavailable","Missing static provenance reports partial shadow capture without get_meta error")
		check(row(bridge.snapshot(),unknown_id).instance_present and not unknown.meshes[0].visible,"Unavailable shadow provenance cannot block real static alpha/instance adoption")
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Original installed resource catalog mounts read-only")
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.configure(catalog);service.cache_directory=output.get_base_dir().path_join("asset-cache");service.completed.connect(func(id,result):completed[id]=result)
	var jobs: Dictionary={}
	for name_value in ["c_goblina","pwc_block_01"]:jobs[service.request(name_value,2002,"actor-model",{"relevant_tracks":true})]=name_value
	var deadline:=Time.get_ticks_msec()+30000
	while completed.size()<jobs.size() and Time.get_ticks_msec()<deadline:await process_frame
	var actual_pool:=Pool.new();pools.append(actual_pool)
	for job in jobs:
		var bundle: Dictionary=completed.get(job,{})
		check(not bundle.is_empty() and str(bundle.get("error","missing")).is_empty(),"Actual original model preparation completes "+str(jobs[job]))
		if bundle.is_empty() or not str(bundle.get("error","")).is_empty():continue
		source_assets.append({"resource":jobs[job],"sha256":bundle.get("sha256"),"parts":bundle.value.nodes.size()})
		var instance: Node3D;var id: int=40 if jobs[job]=="c_goblina" else 41;var kind: int=5 if id==40 else 9
		if kind==5:
			instance=Actor.new();instance.actor_alpha_enabled=true;world.add_child(instance)
			check(instance.install([{"bundle":bundle}],actual_pool,id,{},0),"Actual installed Actor factory builds original mesh ownership: "+str(instance.failure))
		else:
			instance=Placeable.new();world.add_child(instance)
			check(instance.install_placeable(bundle,actual_pool,id,{"animation":74}),"Actual installed animated Placeable factory builds original ownership: "+str(instance.failure))
		physical.append(instance)
		if instance.rigs==null or instance.meshes.is_empty():continue
		instance.rigs.set_process(false);instance.rigs._update(0.)
		var life:=install_target(world,bridge,id,instance,kind)
		restored(bridge,world,id,life,instance,str(jobs[job]))
		check(bridge.model_ready(id,life).shadow_available,"Installed Actor/Placeable accepts authenticated model index endpoint")
		# Fresh unsupported metadata never acquires a guessed model0 merely
		# because an arbitrary Actor mesh carries a provenance Dictionary.
		var replacement_id:=id+10;var missing_life:=install_target(world,bridge,replacement_id,instance,kind)
		for mesh in instance.meshes:mesh.remove_meta("native_source_model_index")
		var adopted: Dictionary=bridge.model_ready(replacement_id,missing_life)
		check(adopted.available and adopted.partial and not adopted.shadow_available,"Unknown Actor metadata remains explicit unavailable rather than static model0 fallback")
		check(row(bridge.snapshot(),replacement_id).instance_present and instance.meshes.all(func(mesh):return not mesh.visible),"Real Actor/Placeable retained alpha applies even when independent shadow capture is unavailable")
	service.close();service.free();bridge.close();world.effects.closed=true;world.effects.entries.clear();world.effects.records.clear();world.effects.actor_effects.clear()
	for instance in physical:instance.retire()
	world.instances.clear();world.desired.clear();world.installed.clear();world.free();await process_frame;await process_frame
	for pool in pools:pool.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"source_assets":source_assets,"scope":"Actual pooled static ModelInstance->PackedScene->Placement in compact/noncompact modes plus original installed c_goblina Actor and pwc_block_01 animated Placeable. Authenticated cold primary shadow capture/restoration, authored noncaster preservation, missing metadata without engine error, independent real retained-alpha adoption. Explicit fixture native scope/map/clock/creature fields; no server, GPU, new native build, shadowblob or final LOS acceptance claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_SCENE_VISIBILITY_ADOPTION ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
