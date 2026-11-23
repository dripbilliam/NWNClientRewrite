extends Texture2D
# The render-server texture references a device allocation shared for canvas
# sampling. Keep both handles alive as long as any control or cache owns this
# immutable snapshot, independent of the producing viewport's lifetime.
const USAGE := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

var _canvas_texture := RID()
var _device_texture := RID()
var _size := Vector2i.ZERO

static func capture(rendered: RID, size: Vector2i) -> Texture2D:
	var device := RenderingServer.get_rendering_device()
	if device == null:
		return null
	var source := RenderingServer.texture_get_rd_texture(rendered, false)
	if not device.texture_is_valid(source):
		return null
	var format := device.texture_get_format(source)
	if format.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM or format.samples != RenderingDevice.TEXTURE_SAMPLES_1 or format.texture_type != RenderingDevice.TEXTURE_TYPE_2D or format.array_layers != 1:
		return null
	if format.width != size.x or format.height != size.y or not (format.usage_bits & RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT):
		return null
	format.depth = 1
	format.mipmaps = 1
	format.usage_bits = USAGE
	var snapshot := device.texture_create(format, RDTextureView.new())
	if not snapshot.is_valid():
		return null
	if device.texture_copy(source, snapshot, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 1), 0, 0, 0, 0) != OK:
		device.free_rid(snapshot)
		return null
	var texture := RenderingServer.texture_rd_create(snapshot)
	if not texture.is_valid():
		device.free_rid(snapshot)
		return null
	var result := new()
	result._canvas_texture = texture
	result._device_texture = snapshot
	result._size = size
	return result

static func deliver(viewport: RID, size: Vector2i, epoch: int, receiver: Callable) -> void:
	if not receiver.is_valid():
		return
	var rendered := RenderingServer.viewport_get_texture(viewport)
	var texture := capture(rendered, size)
	if texture!=null:
		receiver.call_deferred(epoch, texture, {})
		return
	# The next viewport resize/draw can already be queued behind this command.
	# A fallback must finish using this frame here, before that queued reuse.
	var began := Time.get_ticks_usec()
	var image := RenderingServer.texture_2d_get(rendered) if rendered.is_valid() else null
	var readback := Time.get_ticks_usec()
	if image!=null and not image.is_empty():
		texture = ImageTexture.create_from_image(image)
	receiver.call_deferred(epoch, texture, {"icon_gpu_readback_ms":(readback-began)/1000.0,"icon_texture_upload_ms":(Time.get_ticks_usec()-readback)/1000.0})

func _get_width() -> int:
	return _size.x

func _get_height() -> int:
	return _size.y

func _get_rid() -> RID:
	return _canvas_texture

func _get_image() -> Image:
	return RenderingServer.texture_2d_get(_canvas_texture)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or not _canvas_texture.is_valid() or not is_instance_valid(RenderingServer):
		return
	# Drop the server's shared views before freeing their device allocation.
	RenderingServer.free_rid(_canvas_texture)
	var allocation := _device_texture
	RenderingServer.call_on_render_thread(func():
		if not is_instance_valid(RenderingServer):
			return
		var device := RenderingServer.get_rendering_device()
		if device != null and device.texture_is_valid(allocation):
			device.free_rid(allocation))
