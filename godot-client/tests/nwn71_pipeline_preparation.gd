extends RefCounted
# PRIVATE fixture only. The same actual object/resources and main viewport are
# used for the covered preparation draw and the later visible draw.
var viewport: Viewport
var cover: CanvasLayer
var world: Node3D
var camera: Camera3D
var mesh: MeshInstance3D
var material: ShaderMaterial
var shader: Shader
var mode:=""
var phase:="new"
var variant:=0
var prepared_draws:=0
var visible_draws:=0
var geometry_sha:=""
var requested_identity: Dictionary={}
func open(parent: Viewport,value: String,seed: int) -> bool:
	if phase!="new" or value not in ["rid","exact_draw"] or seed<0 or seed>=1000000:return false
	viewport=parent;mode=value;variant=seed
	cover=CanvasLayer.new();cover.name="NWN71_LoadingFence";cover.layer=128;viewport.add_child(cover)
	var fill:=ColorRect.new();fill.name="LoadingCover";fill.color=Color.BLACK;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;cover.add_child(fill);fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase="covered";return true
func request_material() -> bool:
	if phase!="covered":return false
	world=Node3D.new();viewport.add_child(world)
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,3);camera.current=true
	var authored:=SphereMesh.new();var arrays:=authored.surface_get_arrays(0)
	var geometry:=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=MeshInstance3D.new();mesh.name="ExactSoonVisibleMesh";mesh.mesh=geometry;world.add_child(mesh)
	shader=Shader.new();var red:=0.25+float(variant)/1048576.0
	shader.code="shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO=vec3("+String.num(red,9)+",0.65,0.9); }"
	material=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	camera.force_update_transform();mesh.force_update_transform()
	# Both cases use the existing get_rid-only request before the paths diverge.
	material.get_rid()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(arrays));geometry_sha=hash.finish().hex_encode()
	phase="requested";requested_identity=identity();return true
func draw_preparation() -> bool:
	if mode!="exact_draw" or phase!="requested" or not cover.visible:return false
	# force_draw itself only queues with a separate renderer. The explicit
	# force_sync completes that exact draw before readiness can be released.
	# No frame step or SceneTree processing is advanced by this fixture call.
	RenderingServer.force_draw(false,0.0);RenderingServer.force_sync()
	return preparation_draw_completed()
func draw_visible() -> bool:
	if phase!="ready" or cover.visible:return false
	RenderingServer.force_draw(true,0.0);RenderingServer.force_sync()
	return visible_draw_completed()
func preparation_draw_completed() -> bool:
	# The GPU fixture invokes this only after frame_post_draw. Headless checks
	# verify lifecycle/identity but do not certify graphics-pipeline completion.
	if mode!="exact_draw" or phase!="requested" or not cover.visible:return false
	if identity()!=requested_identity:return false
	prepared_draws+=1;phase="prepared";return true
func handoff() -> bool:
	if phase not in ["requested","prepared"] or mode not in ["rid","exact_draw"]:return false
	if (mode=="rid" and phase!="requested") or (mode=="exact_draw" and phase!="prepared"):return false
	if identity()!=requested_identity:return false
	phase="ready";cover.hide();return true
func visible_draw_completed() -> bool:
	if phase!="ready" or cover.visible or identity()!=requested_identity:return false
	visible_draws+=1;phase="visible";return true
func identity() -> Dictionary:
	if mesh==null or material==null:return {}
	return {"viewport_object":str(viewport.get_instance_id()),"viewport_rid":str(viewport.get_viewport_rid().get_id()),"mesh_object":str(mesh.get_instance_id()),"geometry_object":str(mesh.mesh.get_instance_id()),"geometry_rid":str(mesh.mesh.get_rid().get_id()),"material_object":str(material.get_instance_id()),"material_rid":str(material.get_rid().get_id()),"shader_object":str(shader.get_instance_id()),"shader_code_sha256":shader.code.sha256_text(),"geometry_sha256":geometry_sha,"surface_count":mesh.mesh.get_surface_count(),"surface_format":str(mesh.mesh.surface_get_format(0)),"msaa_3d":viewport.msaa_3d,"transparent_bg":viewport.transparent_bg,"scaling_3d_mode":viewport.scaling_3d_mode,"scaling_3d_scale":viewport.scaling_3d_scale}
func snapshot() -> Dictionary:
	var fill: ColorRect=cover.get_child(0) if cover!=null else null
	return {"mode":mode,"phase":phase,"variant":variant,"prepared_draws":prepared_draws,"visible_draws":visible_draws,"covered":cover!=null and cover.visible,"cover_full_size":fill!=null and fill.size==viewport.get_visible_rect().size,"cover_opaque":fill!=null and fill.color.a==1.0,"same_viewport":mesh!=null and mesh.get_viewport()==viewport,"same_identity":not requested_identity.is_empty() and identity()==requested_identity,"identity":identity()}
func close() -> void:
	if world!=null:world.free()
	if cover!=null:cover.free()
	world=null;cover=null;camera=null;mesh=null;material=null;shader=null;viewport=null;phase="closed"
