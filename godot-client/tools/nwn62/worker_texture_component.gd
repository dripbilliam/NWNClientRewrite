extends SceneTree

const RasterUpload=preload("res://systems/native_data/raster_upload_preparation.gd")
const ResourcePool=preload("res://systems/native_render/resource_pool.gd")

func _initialize() -> void:
	call_deferred("_run")

func _make_sidecar(record: Dictionary) -> Dictionary:
	return RasterUpload.sidecar_on_worker(record,true)

func _run() -> void:
	ProjectSettings.set_setting("nwn/private/worker_texture_creation",true)
	var main_id:=OS.get_main_thread_id()
	var image:=Image.create_empty(64,128,false,Image.FORMAT_RGBA8)
	image.fill(Color8(21,81,169,255))
	image.set_pixel(3,7,Color8(241,17,77,255))
	var record:={"sha256":"a".repeat(64),"value":{"width":64,"height":128,"format":"rgba8","mips":[{"width":64,"height":128,"data":image.get_data()}],"generate_mips":false}}
	var pool:=ResourcePool.new()
	var worker:=Thread.new()
	var start_error:=worker.start(_make_sidecar.bind(record))
	if start_error!=OK:
		print(JSON.stringify({"success":false,"reason":"worker start failed","error":start_error}))
		quit(3)
		return
	var sidecar: Dictionary=worker.wait_to_finish()
	var accepted:=pool.accept_raster_upload_sidecar(sidecar)
	var texture: Texture2D=pool.prepare_texture(record)
	var reused: Texture2D=pool.prepare_texture(record)
	var readback: Image=texture.get_image() if texture!=null else null
	var mutated:=Image.create_empty(64,128,false,Image.FORMAT_RGBA8)
	mutated.fill(Color8(67,31,197,255))
	var changed_record: Dictionary=record.duplicate(true)
	changed_record.value.mips[0].data=mutated.get_data()
	var changed_pool:=ResourcePool.new()
	var accepted_changed:=changed_pool.accept_raster_upload_sidecar(sidecar)
	var changed_texture: Texture2D=changed_pool.prepare_texture(changed_record)
	var changed_readback: Image=changed_texture.get_image() if changed_texture!=null else null
	var result:={"success":false,"adapter":RenderingServer.get_video_adapter_name(),"main_thread_id":main_id,"worker_thread_id":int(sidecar.get("thread",0)),"gpu_rows":sidecar.get("gpu_rows",{}).size(),"accepted":accepted,"used":int(pool.stats.get("worker_textures_used",0)),"cache_hits":int(pool.stats.texture_hits),"same_ref":texture==reused,"texture_valid":texture!=null and texture.get_rid().is_valid(),"bytes_equal":readback!=null and readback.get_data()==image.get_data(),"changed_accepted":accepted_changed,"changed_worker_uses":int(changed_pool.stats.get("worker_textures_used",0)),"changed_invalid_fallbacks":int(changed_pool.raster_upload_counts.get("worker_invalid_fallbacks",0)),"changed_bytes_equal":changed_readback!=null and changed_readback.get_data()==mutated.get_data(),"worker_memo":RasterUpload.worker_texture_snapshot()}
	result.success=pool.use_worker_texture_creation and result.worker_thread_id!=main_id and result.gpu_rows==1 and result.accepted==1 and result.used==1 and result.cache_hits==1 and result.same_ref and result.texture_valid and result.bytes_equal and result.changed_accepted==1 and result.changed_worker_uses==0 and result.changed_invalid_fallbacks==1 and result.changed_bytes_equal
	pool.clear();changed_pool.clear()
	sidecar={}
	worker=null;pool=null;changed_pool=null
	texture=null;reused=null;changed_texture=null
	await process_frame
	var retry_worker:=Thread.new()
	var retry_error:=retry_worker.start(_make_sidecar.bind(record))
	var retry_sidecar: Dictionary=retry_worker.wait_to_finish() if retry_error==OK else {}
	var memo_after_retry: Dictionary=RasterUpload.worker_texture_snapshot()
	result.redundant_retry_gpu_rows=retry_sidecar.get("gpu_rows",{}).size()
	result.redundant_retry_skips=int(memo_after_retry.get("redundant_skips",0))
	result.redundant_retry_builds=int(memo_after_retry.get("builds",0))
	result.success=result.success and retry_error==OK and result.redundant_retry_gpu_rows==0 and result.redundant_retry_skips>=1 and result.redundant_retry_builds==1
	RasterUpload.clear()
	var reset_worker:=Thread.new()
	var reset_error:=reset_worker.start(_make_sidecar.bind(record))
	var reset_sidecar: Dictionary=reset_worker.wait_to_finish() if reset_error==OK else {}
	result.after_reset_gpu_rows=reset_sidecar.get("gpu_rows",{}).size()
	result.after_reset_builds=int(RasterUpload.worker_texture_snapshot().get("builds",0))
	result.success=result.success and reset_error==OK and result.after_reset_gpu_rows==1 and result.after_reset_builds==2
	print(JSON.stringify(result))
	quit(0 if result.success else 4)
