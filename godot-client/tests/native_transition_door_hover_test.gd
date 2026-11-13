extends SceneTree
# Installed binary assets, actual native Runs/Pose/storage/materials and
# alpha-independent doorway bounds. No fake animation callbacks or server/GPU.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Door=preload("res://systems/native_render/door_instance.gd")
const Hover=preload("res://systems/native_render/transition_door_hover.gd")
var checks:=0
var failures: Array=[]
var received: Dictionary={}
var models: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<35:failures.append(label)
func _initialize() -> void:call_deferred("run")
func engine(point: Vector3) -> Vector3:return Vector3(point.x,point.z,-point.y)
func near_pose(a: Transform3D,b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin)<0.00001 and a.basis.x.distance_to(b.basis.x)<0.00001 and a.basis.y.distance_to(b.basis.y)<0.00001 and a.basis.z.distance_to(b.basis.z)<0.00001
func pose_delta(a: Transform3D,b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func run_named(door,name: String) -> Dictionary:
	if not door.rigs.entities.has(door.object_id):return {}
	var model: Dictionary=door.rigs.entities[door.object_id].models[0]
	if not model.has("native_owner"):return {}
	for run in model.native_owner.gob.runsE0:
		if str(run.clip0.name).to_lower()==name:return run
	return {}
func source_mesh(part: Node3D) -> MeshInstance3D:
	for child in part.get_children():
		if child is MeshInstance3D:return child
	return null
func alpha(part: Node3D) -> Variant:
	var mesh:=source_mesh(part)
	if mesh==null:return null
	var material=mesh.material_override if mesh.material_override!=null else mesh.get_active_material(0)
	return material.actor_part_color.a if material!=null and material.has_method("publish_actor_part_pose") else null
func doorway_pick(door,part: Node3D,bounds: Dictionary) -> Dictionary:
	var low: Array=bounds.min;var high: Array=bounds.max
	var y: float=(low[1]+high[1])*0.5;var z: float=(low[2]+high[2])*0.5
	return door.native_door_pick(part.global_transform*engine(Vector3(low[0]-5,y,z)),part.global_transform*engine(Vector3(high[0]+5,y,z)))
func request(service,name: String) -> Dictionary:
	var id: int=service.request(name,2002,"actor-model",{"relevant_tracks":true})
	check(id>=0,"installed actor-model request "+name)
	var deadline:=Time.get_ticks_msec()+30000
	while id>=0 and not received.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	check(received.has(id),"bounded worker completes "+name)
	var bundle: Dictionary=received.get(id,{})
	received.erase(id)
	check(str(bundle.get("error","missing")).is_empty(),"actual door decode "+name+": "+str(bundle.get("error")))
	return bundle
func exercise(bundle: Dictionary,name: String,id: int,pool) -> void:
	var state:={"doorOpenState":1,"animation":50,"hasTransition":true,"useable":false}
	var original:=state.duplicate(true)
	var door:=Door.new();root.add_child(door)
	check(door.install_door(bundle,pool,id,state),"actual door installs "+name+": "+door.failure)
	if door.rigs==null:door.free();return
	door.set_process(false);door.rigs.set_process(false);door.rigs._update(0.15)
	var sam_index:=-1
	for index in bundle.value.nodes.size():
		if str(bundle.value.nodes[index].name).to_lower()=="sam":sam_index=index;break
	check(sam_index>=0,"original doorway Part exists "+name)
	if sam_index<0:door.retire();await process_frame;return
	var source: Dictionary=bundle.value.nodes[sam_index]
	var part: Node3D=door.rigs.node_at(id,int(door.rigs.entities[id].model_parts[0][sam_index]))
	var stable:=part.global_transform;var physical:=part.get_instance_id()
	check(source.alpha==0.0 and source.mesh.render and source.mesh.native_bounds_available,"actual doorway is alpha0 render1 with original bounds "+name)
	check(alpha(part)==0.0,"initial material retains source alpha0 "+name)
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"alpha0 doorway remains targetable before hover "+name)
	var before_time: float=door.rigs.entities[id].models[0].last_time
	var ordinary_poses: Array=door.rigs.entities[id].nodes.map(func(node):return node.transform)
	var hover:=Hover.new()
	var context:={"controlled_present":true,"has_transition":true,"useable":false}
	var selected: Dictionary=hover.update(door,context)
	check(selected.available and selected.special_transition and selected.suppress_hover and selected.cursor_id==21,"special native cursor/ordinary-hover suppression, Useable is not11c "+name)
	var main:=run_named(door,"opened1");var trans:=run_named(door,"trans")
	check(not main.is_empty() and not trans.is_empty() and int(trans.flagsC)==8,"native auxiliary Trans retains existing main run "+name)
	check(not main.is_empty() and absf(float(main.time14)-before_time)<0.000001,"main clock seeded before native owner takes over "+name)
	var model: Dictionary=door.rigs.entities[id].models[0]
	check(model.native_owner.pose.native_context!=null,"actual compiled NativePose storage active "+name)
	# A newly-created native owner must not leave the current open leaf at its
	# static/closed pose until a later frame. Trans itself may publish next tick.
	var same_pose:=true
	var maximum_pose_delta:=0.0
	for index in ordinary_poses.size():
		maximum_pose_delta=maxf(maximum_pose_delta,pose_delta(door.rigs.entities[id].nodes[index].transform,ordinary_poses[index]))
		if not near_pose(door.rigs.entities[id].nodes[index].transform,ordinary_poses[index]):same_pose=false
	check(same_pose,"promotion preserves current physical open pose before next frame (1e-5 source-to-native math tolerance) "+name)
	door.rigs._update(0.5)
	check(alpha(part)==0.25,"actual original Trans publishes quarter alpha through native storage/material "+name)
	check(part.get_instance_id()==physical and near_pose(part.global_transform,stable),"Trans does not move or replace stable doorway geometry (1e-5 source-to-native math tolerance) "+name)
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"same original doorway bounds target while Trans visible "+name)
	var clock: float=trans.time14
	var serial: int=model.play_serial
	var repeated: Dictionary=hover.update(door,context)
	check(repeated.available and is_same(run_named(door,"trans"),trans) and trans.time14==clock and model.play_serial==serial,"repeated hover does not restart auxiliary clock or allocate run "+name)
	var update:={"doorOpenState":2,"animation":51,"hasTransition":true}
	var update_original:=update.duplicate(true)
	door.observe_door(update)
	check(not run_named(door,"opening2").is_empty() and is_same(run_named(door,"trans"),trans),"received open-state transition uses native main run without removing Trans "+name)
	var length: float=door.rigs.clip_length(id,301)
	door.rigs._update(0.1);door._process(length+0.01)
	check(not run_named(door,"opened2").is_empty() and not run_named(door,"trans").is_empty(),"received transition timer settles main to current opened2 while hover remains "+name)
	check(hover.clear().available,"native flags128 cleanup and current rest succeed "+name)
	door.rigs._update(0.5)
	check(run_named(door,"trans").is_empty() and not run_named(door,"opened2").is_empty() and door.pending_rest==-1,"cleanup uses CURRENT received state, clears stale pending rest "+name)
	check(alpha(part)==0.0 and not source_mesh(part).visible,"native cleanup restores original alpha0 draw state "+name)
	check(doorway_pick(door,part,source.mesh.native_bounds).get("hit",false),"invisible restored doorway remains targetable "+name)
	check(state==original and update==update_original and door.received_state==2 and door.received_animation==51,"received dictionaries and authoritative door state never overwritten "+name)
	door.observe_door({"doorOpenState":0,"animation":22})
	check(not run_named(door,"closing2").is_empty(),"ordinary received closing still runs after native promotion "+name)
	door._process(door.rigs.clip_length(id,303)+0.01);door.rigs._update(0.0)
	check(not hover.update(door,context).special_transition and run_named(door,"trans").is_empty() and not run_named(door,"closed").is_empty(),"closed door never starts Trans "+name)
	door.observe_door({"doorOpenState":1,"animation":50});door._process(door.rigs.clip_length(id,300)+0.01);door.rigs._update(0.0)
	check(not hover.update(door,{"controlled_present":true,"has_transition":false}).special_transition,"ordinary open nontransition door never starts Trans "+name)
	check(not hover.update(door,{"controlled_present":false,"has_transition":true}).special_transition,"missing controlled character excludes Trans "+name)
	check(not hover.update(door,{"controlled_present":true,"has_transition":true,"native11c":0}).special_transition,"actual11c zero excludes Trans "+name)
	check(not hover.update(door,{"controlled_present":true}).available,"missing transition context explicit unavailable "+name)
	check(hover.update(door,context).available,"reentry can start named auxiliary run again "+name)
	var replacement:=Door.new();root.add_child(replacement)
	check(replacement.install_door(bundle,pool,id+100,{"doorOpenState":2,"animation":51}),"second physical door installs "+name)
	replacement.set_process(false);replacement.rigs.set_process(false)
	check(hover.update(replacement,context).available and run_named(door,"trans").is_empty() and not run_named(replacement,"trans").is_empty(),"pointer target replacement restores old physical door and starts new owner "+name)
	var detached: Dictionary=hover.snapshot();detached.stats.begins=-50
	check(hover.snapshot().stats.begins>0,"detached scalar hover diagnostics "+name)
	replacement.retire()
	check(not hover.snapshot().active and hover.clear().available,"retired weak target cannot resolve another door "+name)
	hover.close()
	check(not hover.update(door,context).available,"closed hover owner refuses late callbacks "+name)
	# Actual installed geometry with a deliberately unavailable native Trans
	# descriptor must preserve its ordinary AnimationPlayer and targeting.
	var unavailable_bundle:=bundle.duplicate()
	unavailable_bundle.value=bundle.value.duplicate()
	unavailable_bundle.value.rig_asset=bundle.value.rig_asset.duplicate()
	unavailable_bundle.value.rig_asset.nativeAnimation=bundle.value.rig_asset.nativeAnimation.duplicate()
	unavailable_bundle.value.rig_asset.nativeAnimation.clips=bundle.value.rig_asset.nativeAnimation.clips.duplicate()
	unavailable_bundle.value.rig_asset.nativeAnimation.clips.trans={"unavailable":"fixture-only missing original controller storage"}
	var unavailable:=Door.new();root.add_child(unavailable)
	check(unavailable.install_door(unavailable_bundle,pool,id+200,{"doorOpenState":1,"animation":50}),"unavailable-controller case retains actual installed geometry "+name)
	unavailable.set_process(false);unavailable.rigs.set_process(false)
	var missing_hover:=Hover.new()
	var missing_result: Dictionary=missing_hover.update(unavailable,context)
	var ordinary: Dictionary=unavailable.rigs.entities[id+200].models[0]
	check(not missing_result.available and missing_result.special_transition and missing_result.suppress_hover and not ordinary.has("native_owner") and ordinary.player.is_playing(),"unavailable Trans stays explicit without stopping ordinary playback "+name)
	check(not unavailable.snapshot_transition_hover().unavailable.is_empty(),"cold diagnostics retain unavailable native controller reason "+name)
	var missing_part: Node3D=unavailable.rigs.node_at(id+200,int(unavailable.rigs.entities[id+200].model_parts[0][sam_index]))
	check(doorway_pick(unavailable,missing_part,source.mesh.native_bounds).get("hit",false),"unavailable Trans preserves original doorway targeting "+name)
	unavailable.observe_door({"doorOpenState":0,"animation":22})
	check(ordinary.clip=="closing1","unavailable Trans leaves ordinary received closing functional "+name)
	missing_hover.close();unavailable.retire()
	models.append({"resource":name,"sha256":bundle.get("sha256"),"doorway_part":source.name,"source_alpha":source.alpha,"source_render":source.mesh.render,"native_bounds":source.mesh.native_bounds,"compiled_native_pose":true,"promotion_max_pose_delta":maximum_pose_delta,"hover":hover.snapshot(),"door":door.snapshot_transition_hover()})
	door.retire();await process_frame;await process_frame
func run() -> void:
	var output:="";var install:="";var cache:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache=arg.substr(8)
	if output.is_empty() or install.is_empty() or cache.is_empty() or FileAccess.file_exists(output):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(install),"original installed catalog mounts read-only")
	if catalog.layers.is_empty():quit(3);return
	catalog.decoder_store=Store.new()
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.cache_directory=cache;service.configure(catalog)
	service.completed.connect(func(id,result):received[id]=result)
	var pool:=Pool.new();pool.picking=true;pool.unshaded=true
	var id:=55000
	for name: String in ["t_door01","t_door02"]:
		var bundle: Dictionary=await request(service,name)
		if str(bundle.get("error","missing")).is_empty():await exercise(bundle,name,id,pool)
		id+=1
	service.close();service.free();await process_frame;await process_frame;pool.clear()
	var report:={"checks":checks,"failures":failures,"models":models,"scope":"Two installed original binary door assets, actual worker/native Runs/NativePose DLL storage/private alpha materials/authored doorway bounds; explicit unavailable-controller fallback. ASCII Trans is still unmet, no server/GPU/frame-rate/visual-parity claim"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
