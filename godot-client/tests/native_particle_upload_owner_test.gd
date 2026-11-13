extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func resource() -> MultiMesh:
	var value:=MultiMesh.new(); value.transform_format=MultiMesh.TRANSFORM_3D; value.use_colors=true; value.use_custom_data=true; value.mesh=QuadMesh.new(); value.instance_count=16
	var data:=PackedFloat32Array(); data.resize(16*20); value.buffer=data; return value
func owner_for(value: MultiMesh) -> RefCounted:
	var owner: RefCounted=ClassDB.instantiate("NwnParticleUpload"); owner.call("configure",value,96); return owner
func retained(target: WeakRef,value: WeakRef) -> bool:
	# WeakRef.get_ref() returns a temporary strong reference. Keep those
	# temporaries in this short scope, outside the caller's suspended frame.
	return target.get_ref()!=null and value.get_ref()!=null
func queue_detached(packet: PackedByteArray) -> Array:
	var value:=resource(); var owner:=owner_for(value)
	var weak_owner: WeakRef=weakref(owner); var weak_resource: WeakRef=weakref(value)
	var command:=Callable(owner,"upload").bind(owner,packet,3)
	owner=null; value=null
	check(retained(weak_owner,weak_resource),"Pending bound call strongly retains both native target and GPU resource")
	RenderingServer.call_on_render_thread(command)
	return [weak_owner,weak_resource]
func flush() -> void:
	for frame in 3: await RenderingServer.frame_post_draw
func readback(value: MultiMesh) -> PackedByteArray:
	var result:={}; var mutex:=Mutex.new()
	RenderingServer.call_on_render_thread(func():
		var rd:=RenderingServer.get_rendering_device(); var rid:=RenderingServer.multimesh_get_buffer_rd_rid(value.get_rid())
		var data:=rd.buffer_get_data(rid); mutex.lock(); result.data=data; result.done=true; mutex.unlock())
	var ready:=false; var end:=Time.get_ticks_msec()+10000
	while not ready and Time.get_ticks_msec()<end:
		await process_frame; mutex.lock(); ready=bool(result.get("done",false)); mutex.unlock()
	check(ready,"Owned GPU readback completes")
	return result.get("data",PackedByteArray())
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	check(ClassDB.class_exists("NwnParticleUpload"),"Native render-thread class registered")
	if not ClassDB.class_exists("NwnParticleUpload"): quit(1); return
	var data:=PackedFloat32Array()
	for id in 20: data.append(id*0.125)
	var packet:=data.to_byte_array()
	var value:=resource(); var owner:=owner_for(value)
	check(int(owner.call("error"))==0,"Native owner accepts the exact retained resource")
	RenderingServer.call_on_render_thread(Callable(owner,"upload").bind(owner,packet,1))
	await flush()
	var stats: Dictionary=owner.call("stats")
	check(stats.uploads==1 and stats.bytes==80 and stats.sequence==1 and stats.error==0,"Native owner performs one active-prefix write")
	var observed: PackedByteArray=await readback(value)
	check(observed.slice(0,80)==packet and observed.size()==16*80,"Native ABI upload reaches the real GPU buffer with exact bytes")
	check(observed.slice(80).count(0)==observed.size()-80,"Native prefix write leaves retained tail bytes unchanged")
	var changed:=packet.duplicate(); changed.encode_float(0,99)
	RenderingServer.call_on_render_thread(Callable(owner,"upload").bind(owner,changed,1)); await flush()
	check(int(owner.call("stats").uploads)==1,"Duplicate sequence does not perform another write")
	owner.call("cancel"); RenderingServer.call_on_render_thread(Callable(owner,"upload").bind(owner,changed,2)); await flush()
	check(not owner.call("stats").alive and int(owner.call("stats").uploads)==1,"Cancelled owner rejects queued work")
	var after_cancel: PackedByteArray=await readback(value)
	check(after_cancel==observed,"Cancellation preserves existing GPU bytes")
	owner=null; value=null
	for length in [0,81,16*80+80]:
		value=resource(); owner=owner_for(value); var invalid:=PackedByteArray(); invalid.resize(length)
		RenderingServer.call_on_render_thread(Callable(owner,"upload").bind(owner,invalid,1)); await flush()
		check(int(owner.call("error"))==1009 and int(owner.call("stats").uploads)==0,"Native owner rejects an invalid prefix length "+str(length))
		owner=null; value=null
	# Binding self is essential: a normal Object-method Callable alone does not
	# promise ownership of its target. This tests the actual lifetime contract.
	var tracked:=queue_detached(packet); await flush()
	check(tracked[0].get_ref()==null and tracked[1].get_ref()==null,"Completed command releases native target and its resource without a cycle")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"Actual native render-thread upload bytes, untouched retained tail, sequence/cancellation/bounds, and bound Callable/resource lifetime. GPU readbacks deliberately synchronize; no performance claim."},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
