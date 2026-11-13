extends Control
signal textures_changed
# Draw original source triangles against raw native rasters. Original portrait
# UVs crop pad rows; do not bind an already-cropped/flipped AtlasTexture here.
class Part extends Control:
	signal texture_changed
	var texture: Texture2D:
		set(value): texture=value; queue_redraw(); texture_changed.emit()
	var faces: Array=[]
	var alpha:=1.0
	func _draw() -> void:
		if texture==null: return
		draw_set_transform(-position)
		for face in faces: draw_polygon(face.vertices,PackedColorArray([Color(1,1,1,alpha)]),face.uv,texture)
var art
var resource:=""
var portrait:=""
var parts: Dictionary={}
var plan: Dictionary={}
var closed:=false
func configure(definition: Dictionary,owner,picture: String="") -> void:
	if closed: return
	mouse_filter=Control.MOUSE_FILTER_IGNORE; focus_mode=Control.FOCUS_NONE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	var rebuild: bool=resource!=str(definition.resource) or art!=owner
	if rebuild:
		clear_parts(); art=owner; resource=str(definition.resource); plan=definition
		for row in plan.parts:
			var image:=Part.new(); add_child(image); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.focus_mode=Control.FOCUS_NONE; image.faces=row.faces; image.alpha=float(row.alpha); image.position=row.bounds.position; image.size=row.bounds.size; image.texture_changed.connect(texture_updated); parts[str(row.id)]=image
			if row.resource!="gui_replace01" and is_instance_valid(art): art.bind(image,str(row.resource))
	if rebuild or portrait!=picture:
		portrait=picture
		for row in plan.parts:
			if row.resource!="gui_replace01": continue
			var image: Control=parts[str(row.id)]
			if is_instance_valid(art): art.unbind(image)
			image.texture=null
			if not picture.is_empty() and is_instance_valid(art): art.bind(image,art.portrait_resource(picture))
func texture_updated() -> void:
	if not closed: textures_changed.emit()
func raster_ready() -> bool:
	return not plan.is_empty() and parts.values().all(func(image):return is_instance_valid(image) and image.texture!=null)
func photo():
	for row in plan.get("parts",[]):
		if row.resource=="gui_replace01": return parts.get(str(row.id))
	return null
func clear_parts() -> void:
	for image in parts.values():
		if is_instance_valid(art): art.unbind(image)
		image.texture=null; remove_child(image); image.queue_free()
	parts.clear(); plan={}; resource=""; portrait=""
func close() -> void:
	if closed: return
	closed=true; hide(); clear_parts(); art=null
func _exit_tree() -> void: close()
