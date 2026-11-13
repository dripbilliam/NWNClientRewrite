extends SceneTree

# Standalone private Forward+ thread-safety check. It never loads NWN assets or
# changes the accepted client. A separate process timeout guards worker hangs.
var worker_thread: Thread
var source_image: Image
var main_thread_id: int

func _initialize() -> void:
	main_thread_id=OS.get_main_thread_id()
	call_deferred("_run")

func _build_on_worker(image: Image) -> Dictionary:
	var began:=Time.get_ticks_usec()
	var texture:=ImageTexture.create_from_image(image)
	return {"thread_id":OS.get_thread_caller_id(),"elapsed_us":Time.get_ticks_usec()-began,"texture":texture}

func _run() -> void:
	var device:=RenderingServer.get_rendering_device()
	var adapter:=RenderingServer.get_video_adapter_name()
	if device==null:
		print(JSON.stringify({"success":false,"reason":"No RenderingDevice; fixture did not exercise Forward+","adapter":adapter}))
		quit(2)
		return
	source_image=Image.create_empty(64,128,false,Image.FORMAT_RGBA8)
	source_image.fill(Color8(19,107,201,255))
	source_image.set_pixel(3,7,Color8(247,13,85,255))
	worker_thread=Thread.new()
	var start_error:=worker_thread.start(_build_on_worker.bind(source_image))
	if start_error!=OK:
		print(JSON.stringify({"success":false,"reason":"Thread start failed","error":start_error}))
		quit(3)
		return
	var row: Dictionary=worker_thread.wait_to_finish()
	var texture: ImageTexture=row.get("texture")
	var result:={"success":false,"adapter":adapter,"main_thread_id":main_thread_id,"worker_thread_id":int(row.get("thread_id",0)),"worker_elapsed_us":int(row.get("elapsed_us",0)),"texture_valid":texture!=null and texture.get_rid().is_valid(),"width":texture.get_width() if texture!=null else -1,"height":texture.get_height() if texture!=null else -1}
	if texture!=null:
		var readback:=texture.get_image()
		result.readback_valid=readback!=null and not readback.is_empty()
		result.bytes_equal=readback!=null and readback.get_data()==source_image.get_data()
	result.success=result.worker_thread_id!=main_thread_id and result.texture_valid and result.width==64 and result.height==128 and bool(result.get("bytes_equal",false))
	print(JSON.stringify(result))
	texture=null
	await process_frame
	quit(0 if result.success else 4)
