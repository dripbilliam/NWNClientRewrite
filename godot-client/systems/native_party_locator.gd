extends Control
const Quad=preload("res://systems/native_data/gui_quad.gd")
const Policy=preload("res://systems/native_data/party_locator.gd")
var texture: Texture2D:
	set(value): texture=value; queue_redraw()
var art
var model: Dictionary={}
var faces: Array=[]
var clip:=""
var time:=-1.0
var length:=0.0
var failure:=""
var resource:=""
var closed:=false
var poses:=0
func configure(source: Dictionary,owner,point: Vector2) -> void:
	model=source; art=owner; position=point; mouse_filter=Control.MOUSE_FILTER_IGNORE; focus_mode=Control.FOCUS_NONE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	for animation in model.get("animations",[]):
		if animation.name=="angle": length=float(animation.length)
	if length<=0: failure="Original party locator angle animation is missing"; hide(); return
	set_pose("angle",0.0); hide()
func set_angle(value: float) -> void:
	if not is_finite(value): hide(); return
	set_pose("angle",clampf(Policy.state_time(value,length),0,length)); show()
func set_unknown() -> void: set_pose("angleunknown",0); show()
func set_pose(name: String,seconds: float) -> void:
	if closed or name==clip and seconds==time: return
	var sampled:=Quad.sample(model,name,seconds)
	if not str(sampled.error).is_empty(): failure=str(sampled.error); faces.clear(); queue_redraw(); return
	clip=name; time=seconds; faces=sampled.faces; poses+=1; failure=""
	if str(sampled.resource)!=resource:
		resource=str(sampled.resource); texture=null; art.unbind(self); art.bind(self,resource)
	queue_redraw()
func _draw() -> void:
	if texture==null: return
	for face in faces: draw_polygon(face.vertices,PackedColorArray([Color.WHITE]),face.uv,texture)
func close() -> void:
	if closed: return
	closed=true; hide(); faces.clear(); texture=null; model={}
	if is_instance_valid(art): art.unbind(self)
	art=null
func _exit_tree() -> void: close()
