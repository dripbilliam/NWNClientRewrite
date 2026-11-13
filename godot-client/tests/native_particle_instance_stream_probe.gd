extends SceneTree
# Isolated capability experiment: no production particle path is selected here.
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var world:=Node3D.new(); root.add_child(world)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,2,4); camera.look_at(Vector3.ZERO); camera.current=true
	var instances:=MultiMesh.new(); instances.transform_format=MultiMesh.TRANSFORM_3D; instances.use_colors=true; instances.use_custom_data=true
	var quad:=QuadMesh.new(); quad.size=Vector2.ONE; instances.mesh=quad; instances.instance_count=64; instances.visible_instance_count=1
	instances.custom_aabb=AABB(Vector3(-10,-10,-10),Vector3(20,20,20))
	var values:=PackedFloat32Array(); values.resize(64*20)
	for id in 64:
		var at:=id*20; values[at]=1; values[at+5]=1; values[at+10]=1
		for index in range(12,20): values[at+index]=float((id*8+index)%1024)
	instances.buffer=values
	var node:=MultiMeshInstance3D.new(); node.multimesh=instances; world.add_child(node)
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color.WHITE; node.material_override=material
	for frame in 4: await RenderingServer.frame_post_draw
	var prefix: PackedByteArray=values.slice(0,20).to_byte_array(); prefix.encode_float(12*4,1023.0)
	var result:={}; var mutex:=Mutex.new()
	# Capture a strong resource reference so its GPU storage outlives the queued
	# command, including main-thread node retirement. No borrowed raw RID owner.
	RenderingServer.call_on_render_thread(func():
		var rd:=RenderingServer.get_rendering_device()
		var rid:=RenderingServer.multimesh_get_buffer_rd_rid(instances.get_rid())
		var row:={"device":rd!=null,"rid_valid":rid.is_valid()}
		if rd!=null and rid.is_valid():
			var before:=rd.buffer_get_data(rid)
			row.buffer_bytes=before.size(); row.initial_exact=before==values.to_byte_array()
			row.update_error=rd.buffer_update(rid,0,prefix.size(),prefix)
			var after:=rd.buffer_get_data(rid)
			row.prefix_exact=after.slice(0,prefix.size())==prefix
			row.tail_unchanged=after.slice(prefix.size())==before.slice(prefix.size())
		mutex.lock(); result.merge(row); result.done=true; mutex.unlock())
	var deadline:=Time.get_ticks_msec()+10000
	var done:=false
	while not done and Time.get_ticks_msec()<deadline:
		await process_frame; mutex.lock(); done=bool(result.get("done",false)); mutex.unlock()
	check(done,"Render-thread experiment completes")
	check(result.get("device",false) and result.get("rid_valid",false),"Pinned renderer exposes the owned instance buffer")
	check(int(result.get("buffer_bytes",0))==64*80 and result.get("initial_exact",false),"Instance records preserve twenty float32 values exactly")
	check(int(result.get("update_error",-1))==OK and result.get("prefix_exact",false) and result.get("tail_unchanged",false),"Only the active eighty-byte prefix is changed")
	check(instances.visible_instance_count==1 and instances.instance_count==64,"Draw count is independent from retained capacity")
	world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":result,"network_connections":0,"scope":"RenderingDevice/MultiMesh storage and partial-upload capability only. Readbacks deliberately synchronize the GPU; no performance or particle pixel parity claim."},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
