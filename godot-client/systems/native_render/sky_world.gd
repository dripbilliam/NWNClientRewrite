extends "res://systems/area_sky.gd"
# Native sky admission. Only original 2DA/MDL/bitmap data enters this path;
# the inherited sky phase/material equations do not invoke its GLB installer.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
var assets
var pool
var closed:=false
var request_revision:=0
var requested_id:=-1
var pending: Dictionary={}
var waiting: Array=[]
var staged: Dictionary={}
var desired_phases: Array=[]
var published:=0
var table_reads:=0
var table: Dictionary={}
var failures: Array=[]
var world_owner: WeakRef
var sky_shader: Shader
func configure(world: Node,source,shared_pool,cache_path: String="") -> void:
	world_owner=weakref(world); pool=shared_pool; native_surface_output=world.get_meta("native_surface_output",false)
	sky_shader=_shader(native_surface_output)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=1; assets.configure(source); assets.cache_directory=cache_path; assets.completed.connect(completed)
	# The phase owner is advanced by AreaEnvironment after camera/area updates.
	set_process(true)
func current(revision_value: int) -> bool:
	var world=world_owner.get_ref() if world_owner!=null else null
	return not closed and revision_value==request_revision and is_instance_valid(world) and not world.is_queued_for_deletion() and not world.get("closed") and not world.get("retiring")
func select_sky(value: int) -> bool:
	if closed or value<0 or value>255: return false
	if requested_id==value: return true
	requested_id=value; request_revision+=1; pending.clear(); waiting.clear(); staged.clear(); desired_phases.clear(); error=""
	clear_staging()
	assets.retire_scope()
	if value==0:
		clear_models(); sky_id=0; configured=true; return true
	if not table.is_empty(): select_row(); return true
	var id: int=assets.request("skyboxes",2017,"2da")
	if id<0: reject(assets.failure); return false
	pending[id]={"kind":"table","revision":request_revision}; table_reads+=1
	return true
func select_row() -> void:
	if not current(request_revision): return
	var rows: Array=table.get("orderedRows",[])
	if requested_id>=rows.size(): reject("SkyBoxes physical row is unavailable: "+str(requested_id)); return
	var row: Dictionary=rows[requested_id]
	for column in ["DAWN","DAY","DUSK","NIGHT"]:
		var name:=str(row.get(column,"")).to_lower()
		if not valid_name(name):
			reject("SkyBoxes phase has no valid original model: "+column); return
		desired_phases.append(name)
	for name in desired_phases+["skyfade1"]:
		if waiting.has(name): continue
		waiting.append(name)
	for name in waiting:
		var id: int=assets.request(name,2002,"static-model")
		if id<0: reject(assets.failure); return
		pending[id]={"kind":"model","name":name,"revision":request_revision}
static func valid_name(value: String) -> bool:
	if value.is_empty() or value.length()>16: return false
	for c in value.to_ascii_buffer():
		if not (c>=97 and c<=122 or c>=48 and c<=57 or c==95): return false
	return true
func completed(id: int,result: Dictionary) -> void:
	if not pending.has(id): return
	var job: Dictionary=pending[id]; pending.erase(id)
	if not current(int(job.revision)): return
	if not str(result.get("error","")).is_empty(): reject(str(result.error)); return
	if job.kind=="table":
		table=result.value; select_row(); return
	staged[job.name]=result
func _process(_delta: float) -> void:
	if not current(request_revision) or waiting.is_empty() or staged.size()!=waiting.size() or not pool.can_publish(): return
	var began:=Time.get_ticks_usec()
	# At most one original model is published per frame. All five must finish
	# before they replace the preceding sky, so a phase never has missing art.
	var next:=str(waiting[0]); var bundle: Dictionary=staged[next]
	var model:=build_model(next,bundle)
	if model==null: reject(error); return
	staged.erase(next); waiting.pop_front()
	if not has_meta("sky_staging"): set_meta("sky_staging",{})
	var prepared: Dictionary=get_meta("sky_staging"); prepared[next]=model
	pool.publication_finished(began); Profile.finish("native_sky_publication",began)
	if waiting.is_empty(): publish_set(prepared)
func build_model(resource: String,bundle: Dictionary) -> Node3D:
	var model:=Node3D.new(); model.name="sky_"+resource; model.hide(); add_child(model)
	var parts: Array=[]; var rows: Array=[]; var source: Dictionary=bundle.value
	var basis:=Quaternion(Vector3.RIGHT,-PI/2)
	for index in source.nodes.size():
		var row: Dictionary=source.nodes[index]; var parent:=int(row.parent)
		if parent>=index or parent< -1: error="Invalid original sky hierarchy"; model.free(); return null
		if row.features.any(func(feature):return feature in ["skin","animated-mesh","dangly","light","emitter","reference"]):
			error="Original sky requires unsupported dynamic part: "+str(row.name); model.free(); return null
		var part:=Node3D.new(); (model if parent<0 else parts[parent]).add_child(part); parts.append(part)
		part.position=Vector3(row.position[0],row.position[2],-row.position[1]); var q:=Quaternion(row.orientation[0],row.orientation[1],row.orientation[2],row.orientation[3])
		part.quaternion=basis*q.normalized()*basis.inverse() if q.length_squared()>1e-16 else Quaternion.IDENTITY; part.scale=Vector3.ONE*float(row.scale)
		var data: Dictionary=row.mesh
		if data.is_empty() or not data.render or data.indices.is_empty(): continue
		var mesh=pool.geometry(str(bundle.sha256),index,data)
		if mesh==null: error=pool.failure; model.free(); return null
		var texture: Texture2D
		if not data.textures.is_empty() and str(data.textures[0]).to_lower() not in ["","null"]:
			var name:=str(data.textures[0]).to_lower()
			if not bundle.get("textures",{}).has(name): error="Original sky bitmap is unavailable: "+name; model.free(); return null
			texture=pool.texture(bundle.textures[name])
			if texture==null: error=pool.failure; model.free(); return null
		var geometry:=MeshInstance3D.new(); part.add_child(geometry); geometry.mesh=mesh; geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; geometry.extra_cull_margin=1000
		var pair: Array=[]
		for overlay in [false,true]:
			var material:=ShaderMaterial.new(); material.shader=sky_shader; material.render_priority=-126 if resource=="skyfade1" else -127 if overlay else -128
			material.set_meta("native_surface_output",native_surface_output)
			material.set_shader_parameter("horizon",resource=="skyfade1"); material.set_shader_parameter("original_texture",texture); material.set_shader_parameter("textured",texture!=null)
			color_parameter(material,"original_color",Color(1,1,1,float(row.alpha)),native_surface_output); material.set_shader_parameter("vertex_tint",not data.get("vertex_colors",PackedByteArray()).is_empty())
			pair.append(material)
		rows.append({"mesh":geometry,"surface":0,"base":pair[0],"overlay":pair[1]})
	model.set_meta("sky_materials",rows); model.set_meta("sky_sha256",str(bundle.sha256)); return model
func publish_set(prepared: Dictionary) -> void:
	clear_models(false)
	instances=prepared.duplicate(); materials={}
	for name in instances: materials[name]=instances[name].get_meta("sky_materials")
	phases=desired_phases.duplicate(); horizon="skyfade1"; sky_id=requested_id; configured=true; published+=1
	last_draw.clear(); last_period=-1; remove_meta("sky_staging")
func clear_models(include_staging: bool=true) -> void:
	for node in instances.values():
		if is_instance_valid(node): node.free()
	instances.clear(); materials.clear(); phases.clear(); horizon=""; last_draw.clear(); configured=false
	if include_staging: clear_staging()
func clear_staging() -> void:
	if has_meta("sky_staging"):
		for node in get_meta("sky_staging").values():
			if is_instance_valid(node): node.free()
		remove_meta("sky_staging")
func reject(reason: String) -> void:
	error=reason; failures.append(reason); pending.clear(); waiting.clear(); staged.clear()
	# Keep a working preceding sky on a failed replacement, as the reference
	# installer does. Its resources remain private to this world's lifetime.
	clear_staging()
func stop() -> void:
	if closed: return
	closed=true; request_revision+=1; pending.clear(); waiting.clear(); staged.clear(); hide()
	if is_instance_valid(assets): assets.retire_scope()
func close() -> void:
	stop()
	if is_instance_valid(assets): assets.close()
	clear_models(); table.clear(); pool=null
func snapshot() -> Dictionary:
	var result:=super.snapshot()
	result.merge({"native_resources":true,"glb_imports":0,"closed":closed,"requested_id":requested_id,"pending":pending.size(),"staged":staged.size(),"publications":published,"table_reads":table_reads,"failures":failures.duplicate(),"worker_tasks":assets.running.size() if is_instance_valid(assets) else 0})
	return result
func _exit_tree() -> void: close()
