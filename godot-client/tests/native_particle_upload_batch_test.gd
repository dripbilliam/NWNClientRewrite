extends "res://tests/native_particle_upload_owner_test.gd"
func detached_batch(packet: PackedByteArray) -> Array:
	var value:=resource(); var owner:=owner_for(value)
	var batch: RefCounted=ClassDB.instantiate("NwnParticleUploadBatch")
	var tracked: Array=[weakref(batch),weakref(owner),weakref(value)]
	check(bool(batch.call("enqueue",owner,packet,1)),"Detached batch accepts the retained owner and bytes")
	batch.call_deferred("submit",batch)
	return tracked
func released(tracked: Array) -> bool:
	for reference: WeakRef in tracked:
		if reference.get_ref()!=null: return false
	return true
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	check(ClassDB.class_exists("NwnParticleUploadBatch"),"Native batch class registered")
	if not ClassDB.class_exists("NwnParticleUploadBatch"): quit(1); return
	var batch: RefCounted=ClassDB.instantiate("NwnParticleUploadBatch")
	var resources: Array[MultiMesh]=[]; var owners: Array[RefCounted]=[]
	var data:=PackedFloat32Array()
	for id in 20: data.append(id*0.125)
	var original:=data.to_byte_array()
	for id in 24:
		var value:=resource(); var owner:=owner_for(value)
		resources.append(value); owners.append(owner)
		check(bool(batch.call("enqueue",owner,original,id+1)),"Batch retains resource "+str(id))
	var latest:=original.duplicate(); latest.encode_float(0,99)
	check(bool(batch.call("enqueue",owners[0],latest,50)),"Latest sequence replaces an earlier packet")
	check(bool(batch.call("enqueue",owners[0],original,2)),"Older coalesced packet cannot replace the latest")
	check(bool(batch.call("enqueue",owners[0],original,50)),"Equal coalesced packet cannot replace the latest")
	# PackedByteArray arguments have Godot reference semantics. Published kernel
	# packets are immutable; a caller that edits one must explicitly duplicate it.
	# Retaining a packet is ownership, not a hidden per-frame deep copy.
	latest=latest.duplicate()
	latest.encode_float(0,123)
	owners[1].call("cancel")
	batch.call("submit",batch)
	check(not bool(batch.call("enqueue",owners[0],original,60)),"Sealed batch rejects further mutation")
	await flush()
	var stats: Dictionary=batch.call("stats")
	check(stats.phase==2 and stats.error==0 and stats.submitted==24 and stats.accepted==27 and stats.coalesced==3,"One native render callback consumes 24 coalesced owners")
	for id in 24:
		var state: Dictionary=owners[id].call("stats")
		check(state.error==0 and state.uploads==(0 if id==1 else 1),"Each active owner uploads exactly once "+str(id))
	var observed: PackedByteArray=await readback(resources[0])
	check(observed.decode_float(0)==99 and observed.slice(4,80)==original.slice(4),"Latest immutable packet reaches the real GPU buffer")
	check(observed.slice(80).count(0)==observed.size()-80,"Batched upload preserves the inactive GPU tail")
	var cancelled: PackedByteArray=await readback(resources[1])
	check(cancelled.count(0)==cancelled.size(),"Retirement before batch execution prevents GPU mutation")
	batch.call("submit",batch); await flush()
	check(int(owners[0].call("stats").uploads)==1,"Duplicate submit does not enqueue a second upload")
	var invalid: RefCounted=ClassDB.instantiate("NwnParticleUploadBatch")
	check(not bool(invalid.call("enqueue",RefCounted.new(),original,1)) and invalid.call("stats").error==1102,"Batch rejects unrelated objects rather than borrowing invalid pointers")
	invalid=null
	var detached:=detached_batch(original); await flush()
	check(released(detached),"Deferred and render callbacks release batch, owner and GPU resource without a cycle")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"Actual native coalesced render-thread submission for 24 independent buffers, latest-sequence and immutable-byte ownership, unchanged inactive tails, cancellation, invalid owner rejection and detached callback/resource lifetime. GPU readbacks deliberately synchronize; no speed claim."},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
