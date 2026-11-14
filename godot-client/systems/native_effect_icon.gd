extends Control
const Plan=preload("res://systems/native_data/effect_bar_layout.gd")
const F=preload("res://systems/native_render/particle_math.gd")
var icon_texture: Texture2D:
	set(value): icon_texture=value; queue_redraw()
var border_texture: Texture2D:
	set(value): border_texture=value; queue_redraw()
var art
var definition: Dictionary={}
var resource:=""
var flashing:=false
var time:=0.0
var closed:=false
func art_ready() -> bool:
	if icon_texture==null: return false
	for part in definition.get("parts",[]):
		if part.resource!="gui_replace01" and border_texture==null: return false
	return true
func configure(plan: Dictionary,owner,name: String) -> void:
	definition=plan; art=owner; resource=name; mouse_filter=Control.MOUSE_FILTER_IGNORE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	size=plan.models.ctl_ig_plreffect.bounds.size
	art.bind(self,resource,"icon_texture")
	for part in definition.parts:
		if part.resource!="gui_replace01": art.bind(self,part.resource,"border_texture")
func set_state(value: bool) -> void:
	if flashing==value: return
	flashing=value; time=0.0; queue_redraw()
func advance(delta: float) -> void:
	if closed or not flashing: return
	time=F.f(F.f(time)+F.f(delta))
	if time>float(definition.length):
		time=F.f(time-float(definition.length))
		if time>float(definition.length): time=0.0
	queue_redraw()
func _draw() -> void:
	for part in definition.get("parts",[]):
		var image: Texture2D=icon_texture if part.resource=="gui_replace01" else border_texture
		if image==null: continue
		var opacity: float=Plan.alpha(definition,time) if flashing and part.resource=="gui_replace01" else float(part.alpha)
		for face in part.faces: draw_polygon(face.vertices,PackedColorArray([Color(1,1,1,opacity)]),face.uv,image)
func close() -> void:
	if closed: return
	closed=true; definition={}; icon_texture=null; border_texture=null
	if is_instance_valid(art): art.unbind(self,"icon_texture"); art.unbind(self,"border_texture")
	art=null
func _exit_tree() -> void: close()
