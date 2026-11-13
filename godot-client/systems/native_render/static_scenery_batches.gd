extends Node3D
# Optional draw-only terrain instancing. Original model/Part, collision, light,
# material and tile owners remain in place. There is no duplicate world store.
# Only immutable supported surfaces are enrolled, at the existing tile boundary.
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const MaterialContract=preload("res://systems/native_render/native_material_contract.gd")
const MAX_MEMBERS:=65536
const MAX_GROUP_MEMBERS:=128
const DRAW_PROPERTIES: Array[StringName]=[&"cast_shadow",&"layers",&"gi_mode",&"extra_cull_margin",&"ignore_occlusion_culling",&"lod_bias"]
var cell_size:=20.0
var groups: Dictionary={}
var members: Dictionary={}
var model_members: Dictionary={}
var material_groups: Dictionary={}
var tails: Dictionary={}
var dirty: Array[String]=[]
var closed:=false
var _mutating:=false
var _epoch:=0
var stats:={"tiles_considered":0,"source_surfaces":0,"eligible_surfaces":0,"rejected_surfaces":0,"batches_created":0,"batch_rebuilds":0,"active_batched_surfaces":0,"active_batches":0,"source_draws_replaced":0,"withdrawn_surfaces":0,"flush_us":0,"maximum_flush_us":0,"rejections":{}}

func _init() -> void:set_process(false)

func _reject(reason: String,count: int=1) -> void:
	stats.rejected_surfaces+=count
	stats.rejections[reason]=int(stats.rejections.get(reason,0))+count

static func _uniform_positive_basis(value: Basis) -> bool:
	if not value.is_finite() or value.determinant()<=0.000001:return false
	var scale:=value.x.length()
	return scale>0.0001 and is_equal_approx(scale,value.y.length()) and is_equal_approx(scale,value.z.length()) and absf(value.x.dot(value.y))<0.00001*scale*scale and absf(value.x.dot(value.z))<0.00001*scale*scale and absf(value.y.dot(value.z))<0.00001*scale*scale

func eligibility(model: Node3D,mesh: MeshInstance3D) -> String:
	if closed or not is_instance_valid(model) or not model.is_inside_tree() or not is_instance_valid(mesh) or not mesh.is_inside_tree():return "owner-unavailable"
	if not model.get("limitations") is Array:return "static-model-provenance-unavailable"
	for feature in model.get("limitations"):
		if feature in ["skin","animated-mesh","dangly","reference","emitter"]:return "dynamic-model-"+str(feature)
	if not mesh.visible or not mesh.is_visible_in_tree():return "source-not-visible"
	if mesh.layers==0:return "source-render-layers-empty"
	if mesh.get_script()!=null or mesh.mesh==null or mesh.mesh.get_blend_shape_count()>0 or mesh.skin!=null:return "dynamic-mesh"
	if mesh.material_overlay!=null or mesh.material_override==null or mesh.transparency!=0.0:return "overlay-or-instance-transparency"
	if mesh.visibility_range_begin!=0.0 or mesh.visibility_range_end!=0.0 or not mesh.visibility_parent.is_empty() or mesh.sorting_offset!=0.0 or not mesh.sorting_use_aabb_center:return "custom-visibility-or-sorting"
	var provenance: Variant=mesh.get_meta("native_mesh_source",null)
	if not provenance is Dictionary or provenance.get("parsed_render")!=true or provenance.get("native_tilefade_available")!=true or not provenance.get("native_tilefade") is int or int(provenance.native_tilefade)!=0:return "authored-render-or-tilefade"
	var material: Material=mesh.material_override
	if not material is NativeMaterial:return "material-not-native-static"
	if material.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:return "blended-material"
	if material.native_tile_fog_enabled:return "dynamic-per-tile-fog"
	if material.next_pass!=null or material.render_priority!=0:return "material-pass-order"
	# This material revision uses MODEL_MATRIX for native light distance, and
	# MODELVIEW_MATRIX/NORMAL_MATRIX for fog/specular. MultiMesh supplies each
	# placement's transform. Instance-uniform semantics are deliberately refused.
	if not MaterialContract.supports(material.shader,material.native_surface_output and material.native_tile_fog_enabled):return "unowned-or-mutated-shader-contract"
	var pose:=global_transform.affine_inverse()*mesh.global_transform
	if not pose.is_finite() or not _uniform_positive_basis(pose.basis):return "mirrored-sheared-or-singular-transform"
	var box: AABB=mesh.mesh.get_aabb() if mesh.custom_aabb==AABB() else mesh.custom_aabb
	if not box.position.is_finite() or not box.end.is_finite():return "invalid-bounds"
	return ""

func consider_tile(tile: int,model: Node3D) -> void:
	if closed or tile<0 or not is_instance_valid(model) or model.get_meta("native_tile_index",-1)!=tile or not model.get("meshes") is Array:return
	stats.tiles_considered+=1
	var model_id:=model.get_instance_id()
	if not model_members.has(model_id):
		model_members[model_id]={"owner":weakref(model),"rows":[]}
		var removed:=_model_removed.bind(model_id);var visibility:=_model_visibility_changed.bind(model_id)
		if not model.tree_exiting.is_connected(removed):model.tree_exiting.connect(removed,CONNECT_ONE_SHOT)
		if not model.visibility_changed.is_connected(visibility):model.visibility_changed.connect(visibility)
	for source in model.get("meshes"):
		stats.source_surfaces+=1
		if not source is MeshInstance3D:_reject("mesh-type-unavailable");continue
		if members.has(source.get_instance_id()):continue
		var reason:=eligibility(model,source)
		if not reason.is_empty():_reject(reason);continue
		if members.size()>=MAX_MEMBERS:_reject("member-budget");continue
		var pose: Transform3D=global_transform.affine_inverse()*source.global_transform
		var cell:=Vector2i(floori(model.global_position.x/cell_size),floori(model.global_position.z/cell_size))
		var properties: Array=[]
		for key in DRAW_PROPERTIES:properties.append(source.get(key))
		var signature:=str([cell,source.mesh.get_instance_id(),source.material_override.get_instance_id(),properties])
		var tail:=int(tails.get(signature,0));var key:=signature+":"+str(tail)
		if groups.has(key) and groups[key].rows.size()>=MAX_GROUP_MEMBERS:tail+=1;tails[signature]=tail;key=signature+":"+str(tail)
		if not groups.has(key):groups[key]={"mesh":source.mesh,"material":source.material_override,"properties":properties,"rows":[],"geometry":null,"queued":false,"epoch":_epoch}
		var row:={"source":weakref(source),"source_id":source.get_instance_id(),"model_id":model_id,"tile":tile,"pose":pose,"bounds":source.mesh.get_aabb() if source.custom_aabb==AABB() else source.custom_aabb,"layers":source.layers,"group":key,"active":true,"batched":false,"slot":-1}
		groups[key].rows.append(row);members[row.source_id]=row;model_members[model_id].rows.append(row.source_id)
		var source_visibility:=_source_visibility_changed.bind(row.source_id);var source_removed:=_source_removed.bind(row.source_id)
		if not source.visibility_changed.is_connected(source_visibility):source.visibility_changed.connect(source_visibility)
		if not source.tree_exiting.is_connected(source_removed):source.tree_exiting.connect(source_removed,CONNECT_ONE_SHOT)
		var material_id: int=source.material_override.get_instance_id()
		if not material_groups.has(material_id):
			material_groups[material_id]={"material":weakref(source.material_override),"groups":{}}
			var changed:=_material_changed.bind(material_id)
			if not source.material_override.changed.is_connected(changed):source.material_override.changed.connect(changed)
			if not source.material_override.shader.changed.is_connected(changed):source.material_override.shader.changed.connect(changed)
		material_groups[material_id].groups[key]=true
		stats.eligible_surfaces+=1
		_mark_dirty(key)

func _mark_dirty(key: String) -> void:
	if not groups.has(key) or groups[key].queued:return
	groups[key].queued=true;dirty.append(key)

func _current(row: Dictionary) -> MeshInstance3D:
	var source: MeshInstance3D=row.source.get_ref()
	if not row.active or not is_instance_valid(source) or source.get_instance_id()!=row.source_id or source.is_queued_for_deletion() or not source.is_inside_tree():return null
	return source

func _restore(row: Dictionary) -> void:
	var source: MeshInstance3D=row.source.get_ref()
	if row.batched:
		if is_instance_valid(source) and source.get_instance_id()==row.source_id:
			_set_source_draw_enabled(source,source.is_visible_in_tree());source.remove_meta("native_static_batch_draw")
		row.batched=false;stats.active_batched_surfaces-=1

func _withdraw(id: int) -> void:
	if not members.has(id):return
	var row: Dictionary=members[id]
	if not row.active:return
	row.active=false
	var group: Dictionary=groups.get(row.group,{})
	if is_instance_valid(group.get("geometry")) and int(row.slot)>=0:
		# Remove the exact draw immediately; queue compaction under the normal
		# bounded publication callback. Conservative old AABB may overdraw only.
		group.geometry.multimesh.set_instance_transform(int(row.slot),Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO))
	_restore(row);members.erase(id);stats.withdrawn_surfaces+=1;_mark_dirty(str(row.group))

func _source_removed(id: int) -> void: _withdraw(id)
func _source_visibility_changed(id: int) -> void:
	if _mutating or not members.has(id):return
	# Node/ancestor visibility notifications can resend the native draw flag.
	# Withdraw at that event boundary, retaining the authoritative Node state.
	_withdraw(id)
func _set_source_draw_enabled(source: MeshInstance3D,enabled: bool) -> void:
	# Draw-only visibility unpairs native geometry/lights. Zeroing layer masks
	# skipped Forward+ light unpairing and left stale light data during teardown.
	RenderingServer.instance_set_visible(source.get_instance(),enabled)
func _model_removed(id: int) -> void:
	if not model_members.has(id):return
	for member in model_members[id].rows:_withdraw(int(member))
	model_members.erase(id)
func _model_visibility_changed(id: int) -> void:
	if _mutating or not model_members.has(id):return
	var model: Node3D=model_members[id].owner.get_ref()
	if not is_instance_valid(model) or not model.is_visible_in_tree():_model_removed(id)
func withdraw_model(model: Node3D,reason: String="authored-tile-draw-change") -> void:
	# AreaStream owns immutable tile transforms and draw bindings. A future
	# writer must withdraw at its state-update boundary BEFORE changing mesh,
	# material_override/overlay, layers, transforms or instance uniforms. Those
	# individual Node properties do not all emit a general changed signal.
	if is_instance_valid(model):
		_model_removed(model.get_instance_id())
		if not stats.has("explicit_withdrawals"):stats.explicit_withdrawals={}
		stats.explicit_withdrawals[reason]=int(stats.explicit_withdrawals.get(reason,0))+1
func _material_changed(id: int) -> void:
	if closed or not material_groups.has(id):return
	for key in material_groups[id].groups:
		if groups.has(key):
			for row in groups[key].rows:_withdraw(int(row.source_id))

func flush(budget_ms: float=0.75,maximum_groups: int=4) -> void:
	if closed or dirty.is_empty():return
	var began:=Time.get_ticks_usec();var units:=0
	while not dirty.is_empty() and units<maximum_groups:
		if units>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
		var key: String=dirty.pop_front()
		if not groups.has(key):continue
		var group: Dictionary=groups[key];group.queued=false
		var live: Array=[]
		for row in group.rows:
			if _current(row)!=null:live.append(row)
		var old: MultiMeshInstance3D=group.geometry
		if live.size()<2:
			for row in live:_restore(row)
			if is_instance_valid(old):old.free();group.geometry=null;stats.active_batches-=1
			units+=1;continue
		var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D;data.mesh=group.mesh;data.instance_count=live.size()
		var bounds:=AABB();var first:=true
		for index in live.size():
			var row: Dictionary=live[index];data.set_instance_transform(index,row.pose);row.slot=index
			var box: AABB=row.pose*row.bounds;bounds=box if first else bounds.merge(box);first=false
		data.custom_aabb=bounds
		var geometry:=MultiMeshInstance3D.new();geometry.multimesh=data;geometry.material_override=group.material
		for index in DRAW_PROPERTIES.size():geometry.set(DRAW_PROPERTIES[index],group.properties[index])
		geometry.set_meta("native_static_scenery_cell",true);add_child(geometry)
		group.geometry=geometry
		if is_instance_valid(old):old.free();stats.batch_rebuilds+=1
		else:stats.batches_created+=1;stats.active_batches+=1
		# Commit only after the replacement draw is complete. Source visibility,
		# physical/pick geometry and its global transform stay untouched.
		_mutating=true
		for row in live:
			var source:=_current(row)
			if source==null:continue
			_set_source_draw_enabled(source,false);source.set_meta("native_static_batch_draw",true)
			if not row.batched:row.batched=true;stats.active_batched_surfaces+=1;stats.source_draws_replaced+=1
		_mutating=false;units+=1
	var elapsed:=Time.get_ticks_usec()-began;stats.flush_us+=elapsed;stats.maximum_flush_us=maxi(int(stats.maximum_flush_us),elapsed)

func snapshot() -> Dictionary:
	var value:=stats.duplicate(true)
	value.merge({"enabled":true,"closed":closed,"epoch":_epoch,"stats_scope":"area-stream-owner-cumulative","cell_size":cell_size,"groups":groups.size(),"members":members.size(),"pending_groups":dirty.size(),"nominal_instance_reduction":maxi(0,int(stats.active_batched_surfaces)-int(stats.active_batches)),"measured_draw_call_reduction":null,"suppression":"RenderingServer instance visibility; Node visibility and layer masks preserved","policy":"immutable static opaque/scissor terrain surfaces; original physical/collision/light owners retained; unsupported semantics fall back; Forward+ may already auto-instance source draws"})
	return value

func clear() -> void:
	_epoch+=1;_mutating=true
	for row in members.values():_restore(row)
	for group in groups.values():
		if is_instance_valid(group.geometry):group.geometry.free()
	groups.clear();members.clear();model_members.clear();material_groups.clear();tails.clear();dirty.clear();stats.active_batches=0;stats.active_batched_surfaces=0;_mutating=false

func close() -> void:
	if closed:return
	closed=true;clear()

func _exit_tree() -> void:close()
