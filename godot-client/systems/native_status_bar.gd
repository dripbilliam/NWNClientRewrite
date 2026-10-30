extends Control
const F=preload("res://systems/native_render/particle_math.gd")
const Health=preload("res://systems/native_data/party_health.gd")
# CGuiStatusBar::SetStatus1401ec270 samples original percentage vertices/UVs.
# Keep one in-flight pose; bursts coalesce without stretching a finished image.
var art
var resource:=""
var attachment:=Vector2.ZERO
var desired:=-1.0
var published:=-1.0
var desired_clip:="percentage"
var published_clip:=""
var pending_clip:=""
var pending:=""
var pending_percent:=-1.0
var closed:=false
var failure:=""
var requests:=0
var picture: TextureRect
func configure(owner,name: String,point: Vector2) -> void:
	art=owner; resource=name; attachment=point; mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture=TextureRect.new(); add_child(picture); picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_SCALE
	art.loaded.connect(loaded); set_process(false)
func set_health(health: Variant) -> void:
	if closed: return
	if not health is Dictionary or not health.has("current") or not health.has("maximum"):
		desired=-1; hide(); return
	desired=clampf(F.f(F.f(F.f(float(health.current))/F.f(maxf(1,float(health.maximum))))*100.0),0,100)
	desired_clip=str(health.get("clip","percentage"))
	if not desired_clip in Health.CLIPS: failure="Invalid original health animation state"; hide(); set_process(false); return
	failure=""
	show(); set_process(true)
func _process(_delta: float) -> void:
	if closed: set_process(false); return
	if not pending.is_empty():
		if art.failed.has(pending): failure="Original health status model rendering failed"; pending=""; set_process(false)
		return
	if desired<0 or is_equal_approx(desired,published) and desired_clip==published_clip: set_process(false); return
	var state:=Health.sample(desired,desired_clip)
	if not str(state.error).is_empty(): failure=str(state.error); set_process(false); return
	pending_percent=desired; pending_clip=desired_clip; pending=art.request_model(resource,"",{},0,"",[{"clip":state.clip,"time":state.time}]); requests+=1
	if pending.is_empty(): failure="Original health status pose could not be requested"; set_process(false)
	elif art.textures.has(pending): loaded(pending,art.textures[pending],art.bounds.get(pending,{}))
func loaded(key: String,texture: Texture2D,bounds: Dictionary) -> void:
	if closed or key!=pending: return
	var lo: Array=bounds.get("min",[]); var hi: Array=bounds.get("max",[])
	if lo.size()!=2 or hi.size()!=2: failure="Original health status bounds are missing"; pending=""; set_process(false); return
	picture.texture=texture; picture.position=attachment+Vector2(lo[0],-hi[1])*100.0; picture.size=Vector2(float(hi[0])-float(lo[0]),float(hi[1])-float(lo[1]))*100.0
	published=pending_percent; published_clip=pending_clip; pending=""; set_process(desired>=0 and (not is_equal_approx(desired,published) or desired_clip!=published_clip))
func snapshot() -> Dictionary:
	return {"desired":desired,"published":published,"desired_clip":desired_clip,"published_clip":published_clip,"pending":not pending.is_empty(),"requests":requests,"failure":failure,"native_only":true}
func close() -> void:
	if closed: return
	closed=true; pending=""; set_process(false)
	if is_instance_valid(art) and art.loaded.is_connected(loaded): art.loaded.disconnect(loaded)
func _exit_tree() -> void: close()
