extends SceneTree
# SOURCE ONLY, not parsed or executed. Future isolated capsule must provide the
# corrected immutable-upload baseline and the new private candidate at these
# paths. No ordinary project, autoload, extension, server or GPU is required.
const Baseline=preload("res://baseline/native_light_palette.gd")
const Candidate=preload("res://candidate/native_light_palette.gd")
var checks:=0
var failures: Array[String]=[]
var output:=""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func f32(word: int) -> float:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_u32(0,word)
	return bytes.decode_float(0)
func capture(palette,label: String,rows: Array) -> void:
	var bytes: PackedByteArray=palette.image.get_data()
	rows.append({"label":label,"image":bytes,"active":palette.active.keys(),"free":palette.free_slots.duplicate(),"revision":palette.revision,"flushes":palette.flushes})
func detached_scalars(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not key is String or not detached_scalars(value[key]): return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]
func execute(palette,candidate: bool) -> Array:
	if candidate:
		var cold: Dictionary=palette.diagnostics()
		check(not cold.initialized and cold.flushes==0 and cold.logical_updates==0,"cold readback does not ensure or flush palette")
		check(detached_scalars(cold),"cold readback contains only scalar values and detached dictionaries")
		cold.logical_updates=-900; cold.comparisons.calls=-800
		var unmodified: Dictionary=palette.diagnostics()
		check(unmodified.logical_updates==0 and unmodified.comparisons.calls==0,"top-level and nested diagnostics are mutation isolated")
	palette.ensure()
	var owner:=Node.new(); root.add_child(owner)
	var texture_id: int=palette.texture.get_instance_id(); var texture_rid: RID=palette.texture.get_rid()
	var first_upload: Image=palette.upload_snapshot(); var initial: PackedByteArray=first_upload.get_data()
	var slot: int=palette.acquire(owner); var rows: Array=[]
	var state:={"range":8.0,"inverse":2.0,"factor":0.2,"ambient":false}
	palette.update(slot,Vector3(1,2,3),state); palette.flush(); capture(palette,"first lifetime",rows)
	var before: int=palette.flushes; var logical: int=palette.revision
	for index in 32:
		# RGB/fade fields are outside these two metadata pixels, but may still
		# arrive in the full native state at an unchanged transform boundary.
		state["color"]=Vector3(index,1,2)
		palette.update(slot,Vector3(1,2,3),state); palette.flush()
	capture(palette,"32 identical metadata publications",rows)
	check(palette.revision==logical+32,"logical revision still records every valid update")
	check(palette.flushes==before+(0 if candidate else 32),"only candidate removes identical clean uploads")
	check(not palette.dirty,"clean same-pixel publication leaves no pending upload")
	if candidate:
		var activated: Dictionary=palette.diagnostics()
		check(activated.logical_updates==33 and activated.changed_updates==1 and activated.skipped_updates==32,"cold counters prove actual byte-comparison activation")
		check(activated.comparisons.calls==33 and activated.comparisons.word_checks>=128,"bounded comparison work is observable, not presumed free")
	palette.update(slot,Vector3(4,5,6),state)
	palette.update(slot,Vector3(4,5,6),state)
	check(palette.dirty,"same-pixel publication cannot clear an already-dirty write")
	palette.flush(); capture(palette,"changed then identical before flush",rows)
	# Returning to an earlier GPU-visible value still retains the dirty write;
	# this is current CPU-image equality, not a last-uploaded-image cache.
	palette.update(slot,Vector3(7,8,9),state); palette.update(slot,Vector3(4,5,6),state)
	check(palette.dirty,"round trip before flush still has pending authored writes")
	palette.flush(); capture(palette,"round trip before flush",rows)
	# Check raw signed-zero and quiet-NaN inputs against the original actual
	# Color->Image writer. No assumption is made about NaN constructor payloads.
	for word in [0,0x80000000,0x7fc12345,0x7fc12345,0xffc54321,0x7f800000,0xff800000,0x3f800001]:
		state.inverse=f32(word); state.factor=f32(word)
		var position:=Vector3(f32(word),f32(0x80000000),1)
		palette.update(slot,position,state); palette.flush(); capture(palette,"raw input "+str(word),rows)
		var same_before: int=palette.flushes
		palette.update(slot,position,state); palette.flush()
		check(palette.flushes==same_before+(0 if candidate else 1),"raw repeated bytes compare without float equality "+str(word))
		capture(palette,"raw repeated "+str(word),rows)
	state={"range":8.0,"inverse":2.0,"factor":0.2,"ambient":false}
	palette.update(slot,Vector3(10,11,12),state); palette.flush()
	# A direct canonical Image edit must be observed; a retained-input cache
	# would incorrectly skip restoring this row.
	palette.image.set_pixel(0,slot,Color(100,200,300,400))
	palette.update(slot,Vector3(10,11,12),state); palette.flush(); capture(palette,"restore externally edited actual Image",rows)
	check(palette.image.get_pixel(0,slot)==Color(10,11,12,8),"actual Image edit is restored")
	# Unsupported but valid image layout uses original writes, not an inferred
	# byte match. Do not upload a changed texture format in this headless gate.
	palette.image.convert(Image.FORMAT_RGBAH)
	var pixels_before: int=palette.pixel_revision if candidate else 0
	palette.update(slot,Vector3(2,3,4),state); palette.update(slot,Vector3(2,3,4),state)
	if candidate: check(palette.pixel_revision==pixels_before+2,"non-RGBAF layout falls back for every update")
	capture(palette,"unsupported comparison layout",rows)
	palette.image.convert(Image.FORMAT_RGBAF); palette.flush()
	if candidate:
		check(not palette.comparable_state({"range":1}),"incomplete state selects original evaluator")
		check(not palette.comparable_state({"range":1,"inverse":"bad","factor":1,"ambient":false}),"unsupported numeric type selects original evaluator")
		check(palette.comparable_state({"range":1,"inverse":2,"factor":3,"ambient":"truthy"}),"ordinary truth-value policy remains supported")
	# Compare a real valid truthy policy; missing/type-invalid dictionaries are
	# only classified above, avoiding intentional script errors in normal tests.
	var truthy:={"range":1,"inverse":2,"factor":3,"ambient":"truthy"}
	palette.update(slot,Vector3.ONE,truthy); palette.flush(); capture(palette,"valid nonbool truth value",rows)
	# Original ImageTexture.changed is synchronous. Keep every real callback,
	# but an identical callback publication must not schedule another upload.
	var identical:={"done":false}
	var same_listener:=func():
		if not identical.done:
			identical.done=true; palette.update(slot,Vector3(21,22,23),state)
	palette.texture.changed.connect(same_listener)
	palette.update(slot,Vector3(21,22,23),state); palette.flush()
	check(identical.done,"same-pixel changed callback actually runs")
	check(palette.dirty==(not candidate),"same-pixel callback retains only original redundant pending upload")
	palette.texture.changed.disconnect(same_listener); same_listener=Callable()
	palette.flush(); capture(palette,"same-pixel changed callback",rows)
	var changed:={"done":false}
	var changed_listener:=func():
		if not changed.done:
			changed.done=true; palette.update(slot,Vector3(31,32,33),state)
	palette.texture.changed.connect(changed_listener)
	palette.update(slot,Vector3(30,30,30),state); palette.flush()
	check(changed.done and palette.dirty,"real callback pixel change remains dirty")
	palette.texture.changed.disconnect(changed_listener); changed_listener=Callable()
	palette.flush(); capture(palette,"changed callback retained",rows)
	check(not palette.dirty and palette.image.get_pixel(0,slot)==Color(31,32,33,8),"next upload retains changed callback values")
	var recycled:={"done":false,"slot":-1}
	var recycle_listener:=func():
		if not recycled.done:
			recycled.done=true; palette.release(slot); recycled.slot=palette.acquire(owner)
			palette.update(int(recycled.slot),Vector3(31,32,33),state)
	palette.texture.changed.connect(recycle_listener)
	palette.update(slot,Vector3(32,32,32),state); palette.flush()
	check(recycled.done and recycled.slot==slot and palette.dirty,"release/reacquire in changed callback keeps actual rewrite pending")
	palette.texture.changed.disconnect(recycle_listener); recycle_listener=Callable()
	palette.flush(); capture(palette,"callback lifetime reuse",rows)
	var retained: Image=palette.upload_snapshot(); var retained_bytes: PackedByteArray=retained.get_data()
	palette.release(slot); palette.flush(); capture(palette,"release",rows)
	check(palette.image.get_pixel(1,slot)==Color(0,0,0,0),"release disables the exact policy pixel")
	check(retained.get_data()==retained_bytes,"corrected immutable upload survives retirement")
	logical=palette.revision
	palette.update(slot,Vector3.ZERO,{}); palette.release(slot); palette.flush()
	check(palette.revision==logical,"stale slot ignores even incomplete state before evaluation")
	capture(palette,"stale no-op",rows)
	var reused: int=palette.acquire(owner)
	check(reused==slot,"original LIFO slot lifetime reuse")
	palette.update(reused,Vector3(31,32,33),state); palette.flush(); capture(palette,"next lifetime same payload",rows)
	check(palette.image.get_pixel(1,reused).a==1.0,"first update of reused slot re-enables released row")
	palette.release(reused); palette.flush(); capture(palette,"final retirement",rows)
	check(palette.active.is_empty() and palette.free_slots.size()==palette.CAPACITY,"all slots retire without leaks")
	check(palette.texture.get_instance_id()==texture_id and palette.texture.get_rid()==texture_rid,"one original texture/RID for entire sequence")
	check(first_upload.get_data()==initial,"creation snapshot stays immutable")
	if candidate:
		var final: Dictionary=palette.diagnostics()
		check(detached_scalars(final),"final cold readback still exposes no live Image/Texture/owner references")
		check(final.revision==final.logical_updates+final.logical_releases,"logical counters conserve completed active publications")
		check(final.logical_updates==final.changed_updates+final.skipped_updates,"every completed update is changed or byte-identical")
		check(final.pixel_revision==final.changed_updates+final.logical_releases,"actual pixel revision includes writes and releases only")
		check(final.comparisons.calls==final.logical_updates and final.comparisons.state_fallbacks==0,"all valid numeric fixture updates attempt exact comparison")
		check(final.comparisons.layout_fallbacks==2 and final.fallback_updates==2,"both unsupported-format updates have explicit fallback counters")
		check(final.active_slots==0 and final.free_slots==palette.CAPACITY and not final.dirty,"cold diagnostics report retired, clean slot scope")
		var again: Dictionary=palette.diagnostics()
		check(again==final,"cold diagnostic read does not mutate counters or publish work")
		final.comparisons.word_checks=-1
		check(palette.diagnostics().comparisons.word_checks>=0,"nested final observation cannot modify live counters")
	owner.free(); retained=null; first_upload=null
	for name in ["nwn_native_lights","nwn_native_ambient","nwn_native_environment"]: RenderingServer.global_shader_parameter_remove(name)
	palette.image=null; palette.texture=null; palette.environment_texture=null; palette.empty_environment=null
	palette.active.clear(); palette.free_slots.clear()
	return rows
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var baseline:=execute(Baseline,false); var candidate:=execute(Candidate,true)
	check(baseline.size()==candidate.size(),"same explicit authored boundary sequence")
	for index in mini(baseline.size(),candidate.size()):
		var a: Dictionary=baseline[index]; var b: Dictionary=candidate[index]
		check(a.label==b.label and a.image==b.image,"exact final Image bytes: "+a.label)
		check(a.active==b.active and a.free==b.free,"same membership/allocation/lifetime: "+a.label)
		check(a.revision==b.revision,"same logical publication revision: "+a.label)
		check(b.flushes<=a.flushes,"no extra uploads: "+a.label)
	await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"server_connections":0,"source_only_candidate":true,"scope":"Future isolated actual palette byte/lifetime/callback comparison. Dirty/upload/texture.changed frequencies intentionally differ for identical pixels. No GPU race or FPS acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("NATIVE_PERF140_RENDER_PALETTE_IDEMPOTENT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
