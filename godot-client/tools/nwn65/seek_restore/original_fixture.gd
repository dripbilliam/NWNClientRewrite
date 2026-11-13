extends SceneTree
# Exact original c_goblina MDL, completed pause1 one-shot with a live skin
# and attachment so its rig owner remains scheduled. Manual component ABBA.
const Current=preload("res://systems/model_rigs.gd")
const Candidate=preload("res://tools/nwn65/seek_restore/model_rigs_seek.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var output:=""
var proposal_path:=""
var preflight:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--proposal="):proposal_path=arg.trim_prefix("--proposal=")
		if arg=="--preflight":preflight=true
	call_deferred("run")
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok:failures.append(reason);push_error(reason)
func digest(value: Variant) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value));return context.finish().hex_encode()
func statistics(values: Array) -> Dictionary:
	values.sort();return {"samples":values.size(),"median_us":values[int(values.size()/2)],"p95_us":values[int(ceil(values.size()*0.95))-1],"max_us":values[-1]}
func leg(asset: Dictionary,source_nodes: Array,clip: String,tag: String,skip: bool) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var rigs=(Candidate if skip else Current).new();host.add_child(rigs);rigs.set_process(false);rigs.use_native_skin_publisher=false
	var playback: Array=[];var event_log: Array=[]
	rigs.model_event.connect(func(id,model_index,name,serial):event_log.append([id,model_index,name,serial]))
	rigs.animation_event.connect(func(id,name,serial):event_log.append([id,name,serial]))
	var owner_count:=2 if preflight else 12
	for owner_index in owner_count:
		var rig:=Node3D.new();rigs.add_child(rig)
		var nodes: Array[Node3D]=[];var parents: Array=[];var parts: Array=[]
		for index in source_nodes.size():
			var row: Dictionary=source_nodes[index]
			var defaults: Dictionary=asset.defaults[index]
			var node:=Node3D.new();node.name="part_"+str(index)
			var parent:=int(row.parent)
			(rig if parent<0 else nodes[parent]).add_child(node)
			node.position=rigs._vec(defaults.position);node.quaternion=rigs._quat(defaults.quaternion);node.scale=rigs._vec(defaults.scale)
			nodes.append(node);parents.append(parent);parts.append(index)
		var held:=Node3D.new();rig.add_child(held);nodes.append(held);parents.append(-1)
		var skeleton:=Skeleton3D.new();rig.add_child(skeleton);skeleton.add_bone("root")
		var binding:={"parts":parts,"defaults":asset.defaults,"follow":true,"clip":clip,"loop":false,"speed":1.0,"time":0.0}
		var model: Dictionary=rigs._model(rig,nodes,binding,asset)
		model.event_source=true
		var entry:={"root":rig,"nodes":nodes,"parents":parents,"models":[model],"animated_models":[0],"manual_poses":{},"attachments":[{"node":source_nodes.size(),"anchor":0,"scale":[1,1,1],"flags":0}],"skins":[{"part":0,"bones":[0],"skeleton":skeleton}],"counts":{}}
		rigs.entities[owner_index+1]=entry
		playback.append({"entry":entry,"model":model,"held":held,"skeleton":skeleton})
	var time_samples: Array=[];var finished_count:=0;var event_rows:=0
	var frames:=60 if preflight else 180
	for frame in frames:
		var delta:=0.25 if frame<24 else 1.0/60.0
		var began:=Time.get_ticks_usec()
		rigs._update(delta)
		var elapsed:=Time.get_ticks_usec()-began
		if frame>=32:time_samples.append(elapsed)
		if frame==32:
			for row in playback:finished_count+=int(row.model.dormant_finished and not row.model.player.is_playing())
	var final_state: Array=[]
	for row in playback:
		var model: Dictionary=row.model
		final_state.append({"clip":model.clip,"serial":model.play_serial,"last":model.last_time,"time":model.player.current_animation_position,"playing":model.player.is_playing(),"dormant":model.dormant_finished,"queue":model.player.get_queue(),"nodes":row.entry.nodes.map(func(node):return node.transform),"held":row.held.global_transform,"skin":row.skeleton.get_bone_pose(0)})
	event_rows=event_log.size()
	var result:={"tag":tag,"clip":clip,"skip":skip,"owners":playback.size(),"nodes_per_owner":source_nodes.size(),"finished_at_warmup":finished_count,"events":event_rows,"state_sha256":digest([final_state,event_log]),"timing":statistics(time_samples)}
	for owner_index in owner_count:rigs.forget_entity(owner_index+1)
	host.free()
	return result
func run() -> void:
	if output.is_empty() or proposal_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var proposal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(proposal_path))
	var resource: Dictionary={}
	for row in proposal.resources:
		if str(row.key)=="c_goblina:2002":resource=row
	check(not resource.is_empty(),"Pinned original goblin resource")
	var manifest:=ProjectSettings.globalize_path("res://"+str(proposal.catalog.file))
	check(FileAccess.get_sha256(manifest)==str(proposal.catalog.sha256),"Sealed original catalog manifest")
	var catalog:=Recorded.new();check(catalog.mount(manifest.get_base_dir()),"Sealed original catalog mounts")
	var reader=catalog.fork();var bytes: PackedByteArray=reader.get_resource("c_goblina",2002)
	check(reader.failure.is_empty() and bytes.size()==int(resource.bytes) and Cache.digest(bytes)==str(resource.sha256),"Exact original c_goblina bytes")
	var service:=Assets.new();var decoded_rows: Array=[]
	var task:=WorkerThreadPool.add_task(func():decoded_rows.append(service.actor_data(reader,"c_goblina",bytes,"",[],{},str(resource.sha256))),false,"NWN65 original active event")
	while not WorkerThreadPool.is_task_completed(task):await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var decoded: Dictionary=decoded_rows[0]
	check(str(decoded.get("error","missing")).is_empty(),"Original actor decoder succeeds")
	var model: Dictionary=decoded.value
	var asset: Dictionary=service.rig_data(model,decoded.get("animation_sources",[]),"")
	var clip_names: Array=asset.clips.map(func(row):return str(row.name))
	check(clip_names.has("walk") and clip_names.has("pause1"),"Original eventful and eventless clips exist")
	check(model.nodes.size()==29 and asset.defaults.size()==29,"Original 29-node rig source")
	var source_sha:=FileAccess.get_sha256("res://systems/model_rigs.gd")
	var legs: Array=[]
	for mode in ["A1","B1","B2","A2"]:
		legs.append(leg(asset,model.nodes,"pause1",mode,mode.begins_with("B")))
		await process_frame
	for index in 4:
		var row: Dictionary=legs[index]
		check(row.owners==(2 if preflight else 12) and row.finished_at_warmup==row.owners,"Original completed players "+str(index))
		check(row.state_sha256==legs[0].state_sha256,"Original clocks, pose, skin, attachments and events match "+str(index))
	check(legs[0].events==0,"Original pause1 eventless one-shot is exercised")
	check(FileAccess.get_sha256("res://systems/model_rigs.gd")==source_sha,"Candidate source unchanged during ABBA")
	var original_node_count: int=int(model.nodes.size())
	reader=null;decoded_rows.clear();decoded={};model={};asset={};bytes=PackedByteArray()
	catalog.prepared_store.clear();catalog.decoder_store.clear();catalog=null;service.free()
	var report:={"issue":"NWN-65","passed":failures.is_empty(),"checks":checks,"failures":failures,"preflight":preflight,"source_sha256":source_sha,"original_mdl_sha256":resource.sha256,"original_nodes":original_node_count,"legs":legs,"scope":"Sealed original c_goblina MDL, decoded pause1 one-shot and tracks, 12 scheduled owners with skin and attachment, completed player ABBA. Headless component only; no GPU, whole-client frame intervals, FPS or live completed-clip weighting."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures.size(),"medians_us":legs.map(func(row):return row.timing.median_us)}));quit(0 if failures.is_empty() else 1)
