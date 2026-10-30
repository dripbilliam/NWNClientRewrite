extends Control
# One private native actor; latest selected identity wins. Optional visual work
# never owns character admission, the server connection or the picker's input.
signal changed(state: Dictionary)
const Visual=preload("res://systems/native_data/bic_visual.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Stream=preload("res://systems/native_render/creature_stream.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var surface: SubViewportContainer
var viewport: SubViewport
var stage: Node3D
var pivot: Node3D
var camera: Camera3D
var plinth: Node3D
var asset_service
var catalog
var cache_path:=""
var pool:=Pool.new()
var baseitems: Dictionary={}
var base_job:=-1
var wanted: Array=[]
var pending: Dictionary={}
var stream
var retiring
var retirement
var state:={"phase":"empty","native_only":true}
var closed:=false
var yaw:=PI
var zoom:=1.0
var distance:=4.0
var framing_height:=1.0
var actor_ready:=false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface=SubViewportContainer.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surface.stretch=true; surface.stretch_shrink=1; surface.gui_input.connect(surface_input)
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.msaa_3d=Viewport.MSAA_2X; surface.add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	var particles=preload("res://systems/native_render/particle_visibility.gd").new(); stage.add_child(particles); particles.set_enabled(false); particles.set_collision_enabled(false)
	retirement=preload("res://systems/native_data/data_retirement.gd").new(); stage.add_child(retirement)
	var environment:=WorldEnvironment.new(); var settings:=Environment.new(); settings.background_mode=Environment.BG_COLOR; settings.background_color=Color(0,0,0,0); settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color("b6cadc"); settings.ambient_light_energy=0.6; environment.environment=settings; stage.add_child(environment)
	for light_data in [[Vector3(-25,-30,0),Color("ffe2b1"),1.5],[Vector3(-10,135,0),Color("9bbedd"),0.8]]:
		var light:=DirectionalLight3D.new(); light.rotation_degrees=light_data[0]; light.light_color=light_data[1]; light.light_energy=light_data[2]; light.shadow_enabled=false; stage.add_child(light)
	pivot=Node3D.new(); stage.add_child(pivot)
	plinth=Node3D.new(); stage.add_child(plinth)
	var stone:=MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=0.85; cylinder.bottom_radius=0.9; cylinder.height=0.06; cylinder.radial_segments=48; stone.mesh=cylinder; stone.position.y=-0.04; stone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new(); material.albedo_color=Color("263945"); material.roughness=0.92; stone.material_override=material; plinth.add_child(stone)
	var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=0.81; torus.outer_radius=0.83; torus.rings=48; torus.ring_segments=6; ring.mesh=torus; ring.position.y=-0.006; ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var brass:=StandardMaterial3D.new(); brass.albedo_color=Color("94743e"); brass.metallic=0.45; brass.roughness=0.65; ring.material_override=brass; plinth.add_child(ring)
	camera=Camera3D.new(); camera.fov=32; camera.near=0.05; camera.far=100; camera.current=true; stage.add_child(camera); place_camera()
	visibility_changed.connect(update_visibility)
func configure(source,path: String) -> void:
	catalog=source; cache_path=path
	asset_service=Assets.new(); add_child(asset_service); asset_service.configure(source); asset_service.cache_directory=path; asset_service.maximum_workers=1; asset_service.completed.connect(table_received)
	base_job=asset_service.request("baseitems",2017,"2da")
func publish(phase: String,message: String="") -> void:
	state={"phase":phase,"message":message,"identity":wanted.duplicate(),"native_only":true,"has_actor":actor_ready}; changed.emit(state.duplicate(true))
func observe(identity: Array,source_data: Dictionary,allowed: bool=true) -> void:
	var next: Array=identity.duplicate(true) if allowed and not identity.is_empty() else []
	if next==wanted: return
	wanted=next; pending={}; actor_ready=false; retire_stream(); update_visibility(); yaw=PI; zoom=1.0
	if next.is_empty(): publish("empty"); return
	if source_data.has("error") or not source_data.has("appearance"): publish("unavailable",str(source_data.get("error","Appearance was not included in this character preview."))); return
	if not source_data.get("equipmentComplete",false): publish("unavailable","Portrait preview · The server does not include equipment in its character-selection reply."); return
	pending=source_data.duplicate(true); publish("preparing","Preparing appearance…"); dispatch()
func table_received(id: int,result: Dictionary) -> void:
	if closed or id!=base_job: return
	base_job=-1
	if not str(result.get("error","")).is_empty(): publish("unavailable",str(result.error)); pending={}; return
	baseitems=result.value; dispatch()
func dispatch() -> void:
	if closed or pending.is_empty() or baseitems.is_empty() or is_instance_valid(retiring) or is_instance_valid(stream): return
	var object:=Visual.actor(pending,baseitems); pending={}
	if object.has("error"): publish("unavailable",object.error); return
	stream=Stream.new(); pivot.add_child(stream); stream.configure(catalog,pool,[object],0,cache_path,1); update_visibility()
func retire_stream() -> void:
	if not is_instance_valid(stream): return
	stream.hide(); stream.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(stream.assets): stream.assets.retire_scope()
	retiring=stream; stream=null
func collect_retired() -> void:
	if not is_instance_valid(retiring): return
	if is_instance_valid(retiring.assets) and retiring.assets.running.values().any(func(task):return not WorkerThreadPool.is_task_completed(int(task))): return
	var data: Dictionary=retiring.detach_prepared_data(); var actor_data: Array=[]
	for actor in retiring.actors.values(): actor_data.append(actor.retain_decoded_data())
	data.actors=actor_data
	if is_instance_valid(retiring.assets): data.merge(retiring.assets.detach_retired_results())
	retiring.close(); retiring.queue_free(); retiring=null; retirement.defer_release(data); dispatch()
func _process(_delta: float) -> void:
	if closed: return
	collect_retired()
	if not is_instance_valid(stream) or not stream.done or actor_ready: return
	if not stream.actors.has(1): publish("unavailable","The selected character's native model could not be prepared."); retire_stream(); return
	var actor=stream.actors[1]; var bounds:=AABB(); var found:=false
	for mesh in actor.meshes:
		var box: AABB=(pivot.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb(); bounds=bounds.merge(box) if found else box; found=true
	if not found: publish("unavailable","The selected character has no visible model."); retire_stream(); return
	stream.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z); framing_height=bounds.size.y*0.52; distance=maxf(0.8,maxf(bounds.size.y*1.95,bounds.size.x*2.3)); plinth.scale=Vector3.ONE*maxf(0.5,bounds.size.y*0.55); actor_ready=true; place_camera(); update_visibility(); publish("ready")
func place_camera() -> void:
	if not is_instance_valid(camera): return
	camera.position=Vector3(0,framing_height,distance*zoom); camera.look_at(Vector3(0,framing_height,0)); pivot.rotation.y=yaw
func surface_input(event: InputEvent) -> void:
	if not actor_ready: return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw+=event.relative.x*0.012; place_camera(); surface.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom=clampf(zoom*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),0.6,1.8); place_camera(); surface.accept_event()
func update_visibility() -> void:
	if not is_instance_valid(viewport): return
	surface.visible=actor_ready and is_instance_valid(stream)
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() and surface.visible else SubViewport.UPDATE_DISABLED
	if is_instance_valid(stream): stream.process_mode=Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED
func close() -> void:
	if closed: return
	closed=true; wanted=[]; pending={}
	for owner in [stream,retiring]:
		if is_instance_valid(owner): owner.close(); owner.queue_free()
	stream=null; retiring=null
	if is_instance_valid(asset_service): asset_service.close()
	if is_instance_valid(retirement): retirement.close()
	pool.clear(); catalog=null
	if is_instance_valid(viewport): viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _exit_tree() -> void: close()
