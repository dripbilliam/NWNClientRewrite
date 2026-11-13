extends "res://systems/native_render/static_scenery_merge.gd"
# Optional BASE draw-leaf substitution. Authoritative World/Placement/Part,
# collision, emitters, lights, references and entity lifetime stay in place.
const Base=preload("res://systems/native_render/base_world_scenery.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const Proof=preload("res://systems/native_render/base_static_draw_proof.gd")
const Invalidation=preload("res://systems/native_render/static_draw_invalidation.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var _world: WeakRef
var _scope: Array=[]
var _context_provider:=Callable()
var _placements: Dictionary={}

func configure(world: Node3D,context_provider: Callable=Callable()) -> bool:
	if _world!=null or not is_instance_valid(world) or not world.is_inside_tree() or not world.get("generation") is int or not world.get("area_id") is int:return false
	_world=weakref(world);_scope=[world.get_instance_id(),world.generation,world.area_id];_context_provider=context_provider
	return true
func _scope_current() -> Node3D:
	var world: Variant=_world.get_ref() if _world!=null else null
	if closed or merging_retired or not is_instance_valid(world) or world.is_queued_for_deletion() or not world.is_inside_tree() or world.get("closed")==true or world.get("retiring")==true or [world.get_instance_id(),world.get("generation"),world.get("area_id")]!=_scope:return null
	return world
func _placement_current(record: Dictionary) -> Node3D:
	var world:=_scope_current();var model: Node3D=record.owner.get_ref()
	if world==null or not is_instance_valid(model) or model.is_queued_for_deletion() or not model.is_inside_tree() or model.get("retired")==true or world.get("instances").get(record.id)!=model:return null
	var desired: Variant=world.get("desired").get(record.id)
	if not desired is Dictionary or not desired.get("object") is Dictionary or str(desired.get("key",""))!=record.signature or str(world.get("installed").get(record.id,""))!=record.signature or Lifetime.token(desired.object)!=record.lifetime or not Base.classify(desired.object,int(_scope[2])).base:return null
	return model
func _current(row: Dictionary) -> MeshInstance3D:
	var source:=super._current(row)
	if source==null or not _placements.has(row.model_id) or _placement_current(_placements[row.model_id])==null:return null
	return source
func _context(model: Node3D,mesh: MeshInstance3D) -> Dictionary:
	var material: NativeMaterial=mesh.material_override
	if not material.native_tile_fog_enabled:return {"available":true,"identity":["native-instance-fog-disabled"],"factor":null}
	if not _context_provider.is_valid():return {"available":false,"reason":"authentic-tiledata-context-unavailable"}
	var value: Variant=_context_provider.call(model,mesh)
	if not value is Dictionary or value.get("available")!=true or not value.get("identity") is Array or value.identity.is_empty() or not value.get("factor") is float or not is_finite(value.factor):return {"available":false,"reason":"authentic-tiledata-context-unavailable"}
	if not ProofData.is_data(value.identity):return {"available":false,"reason":"tiledata-identity-not-detached"}
	var actual: Variant=mesh.get_instance_shader_parameter("nwn_tile_fog_factor")
	if not actual is float or actual!=value.factor:return {"available":false,"reason":"tiledata-factor-not-current"}
	return value
const ProofData=preload("res://systems/native_render/base_static_draw_context.gd")
func _candidate_reason(model: Node3D,mesh: MeshInstance3D) -> String:
	if not is_instance_valid(mesh) or not mesh.is_inside_tree() or not mesh.visible or not mesh.is_visible_in_tree():return "source-not-visible"
	var proof: Variant=model.get("static_draw_proof");var source: Variant=mesh.get_meta("native_mesh_source",null)
	if not proof is Dictionary or proof.get("revision")!=Proof.REVISION or proof.get("available")!=true or proof.get("own_animation_count")!=0 or not proof.get("parts") is Dictionary:return "original-static-proof-unavailable"
	if not source is Dictionary or not source.get("part_index") is int or not proof.parts.has(source.part_index) or str(proof.parts[source.part_index].name)!=str(source.get("part_name","")):return "physical-part-proof-unavailable"
	if source.get("parsed_render")!=true or source.get("original_alpha")!=1.0 or source.get("native_tilefade_available")!=true or not source.get("native_tilefade") is int or source.native_tilefade!=0:return "authored-render-alpha-or-tilefade"
	if mesh.layers==0 or mesh.get_script()!=null or mesh.mesh==null or mesh.mesh.get_surface_count()!=1 or mesh.mesh.get_blend_shape_count()!=0 or mesh.skin!=null or mesh.mesh.shadow_mesh!=null:return "unsupported-geometry"
	if mesh.custom_aabb!=AABB() or mesh.mesh.custom_aabb!=AABB():return "custom-render-bounds"
	if mesh.material_overlay!=null or not mesh.material_override is NativeMaterial or mesh.transparency!=0.0 or mesh.gi_mode not in [GeometryInstance3D.GI_MODE_DISABLED,GeometryInstance3D.GI_MODE_STATIC]:return "unsupported-material-or-instance-context"
	for index in mesh.get_surface_override_material_count():
		if mesh.get_surface_override_material(index)!=null:return "surface-material-override"
	var material: NativeMaterial=mesh.material_override
	if material.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] or material.albedo_color.a!=1.0 or material.next_pass!=null or material.render_priority!=0:return "blended-or-ordered-material"
	if mesh.visibility_range_begin!=0.0 or mesh.visibility_range_end!=0.0 or not mesh.visibility_parent.is_empty() or mesh.sorting_offset!=0.0 or not mesh.sorting_use_aabb_center:return "custom-visibility-or-sorting"
	if not MaterialContract.supports(material.shader,material.native_surface_output and material.native_tile_fog_enabled,true):return "unowned-or-mutated-shader-contract"
	var pose:=global_transform.affine_inverse()*mesh.global_transform
	if not pose.is_finite() or not _uniform_positive_basis(pose.basis):return "mirrored-sheared-or-singular-transform"
	var arrays: Variant=mesh.mesh.get_meta(CPU_STREAMS,null)
	if not arrays is Array or MergeData.channel_layout(arrays).is_empty():return "immutable-cpu-draw-streams-unavailable"
	return ""

func consider_instance(id: int,model: Node3D) -> bool:
	var world:=_scope_current()
	if world==null or not is_instance_valid(model) or not model is Template.Placement or not model.is_inside_tree() or _placements.has(model.get_instance_id()) or not model.get("meshes") is Array or model.get("renderer_alpha")!=null:return false
	var wanted: Variant=world.get("desired").get(id)
	if not wanted is Dictionary or not wanted.get("object") is Dictionary or not Base.classify(wanted.object,int(_scope[2])).base:return false
	var model_id:=model.get_instance_id();var record:={"id":id,"owner":weakref(model),"signature":str(wanted.get("key","")),"lifetime":Lifetime.token(wanted.object)}
	if _placement_current(record)!=model:return false
	_placements[model_id]=record;model_members[model_id]={"owner":weakref(model),"rows":[]}
	var removed:=_model_removed.bind(model_id);var visibility:=_model_visibility_changed.bind(model_id)
	if not model.tree_exiting.is_connected(removed):model.tree_exiting.connect(removed,CONNECT_ONE_SHOT)
	if not model.visibility_changed.is_connected(visibility):model.visibility_changed.connect(visibility)
	for source in model.get("meshes"):
		stats.source_surfaces+=1
		if not source is MeshInstance3D:_reject("unsupported-mesh-node");continue
		var reason:=_candidate_reason(model,source)
		if not reason.is_empty():_reject(reason);continue
		var context:=_context(model,source)
		if context.get("available")!=true:_reject(str(context.get("reason","context-unavailable")));continue
		if members.size()>=MAX_MEMBERS:_reject("member-budget");continue
		var arrays: Array=source.mesh.get_meta(CPU_STREAMS);var count: int=arrays[Mesh.ARRAY_VERTEX].size();var indices: int=arrays[Mesh.ARRAY_INDEX].size()
		if count>MergeData.MAX_VERTICES or indices>MergeData.MAX_INDICES:_reject("merge-source-budget");continue
		var pose: Transform3D=global_transform.affine_inverse()*source.global_transform;var cell:=Vector2i(floori(pose.origin.x/cell_size),floori(pose.origin.z/cell_size));var origin:=Vector3(cell.x*cell_size,0,cell.y*cell_size);pose.origin-=origin
		var properties: Array=[]
		for name in DRAW_PROPERTIES:properties.append(source.get(name))
		var signature:=str([cell,source.material_override.get_instance_id(),properties,MergeData.channel_layout(arrays),context.identity,context.factor]);var tail:=int(tails.get(signature,0));var key:=signature+":"+str(tail)
		if groups.has(key) and (groups[key].rows.size()>=MergeData.MAX_SOURCES or groups[key].vertices+count>MergeData.MAX_VERTICES or groups[key].indices+indices>MergeData.MAX_INDICES):tail+=1;tails[signature]=tail;key=signature+":"+str(tail)
		if not groups.has(key):groups[key]={"material":source.material_override,"properties":properties,"rows":[],"geometry":null,"queued":false,"epoch":_epoch,"revision":0,"vertices":0,"indices":0,"origin":origin,"job":false,"context":context.duplicate(true)}
		var row:={"source":weakref(source),"source_id":source.get_instance_id(),"model_id":model_id,"pose":pose,"layers":source.layers,"group":key,"active":true,"batched":false,"slot":-1,"arrays":arrays};var group: Dictionary=groups[key]
		group.rows.append(row);group.vertices+=count;group.indices+=indices;group.revision+=1;members[row.source_id]=row;model_members[model_id].rows.append(row.source_id)
		var source_visibility:=_source_visibility_changed.bind(row.source_id);var source_removed:=_source_removed.bind(row.source_id)
		if not source.visibility_changed.is_connected(source_visibility):source.visibility_changed.connect(source_visibility)
		if not source.tree_exiting.is_connected(source_removed):source.tree_exiting.connect(source_removed,CONNECT_ONE_SHOT)
		var material_id: int=source.material_override.get_instance_id()
		if not material_groups.has(material_id):
			material_groups[material_id]={"material":weakref(source.material_override),"groups":{}};var changed:=_material_changed.bind(material_id)
			if not source.material_override.changed.is_connected(changed):source.material_override.changed.connect(changed)
			if not source.material_override.shader.changed.is_connected(changed):source.material_override.shader.changed.connect(changed)
		material_groups[material_id].groups[key]=true;source.set_meta(Invalidation.OWNER,weakref(self));stats.eligible_surfaces+=1;_mark_dirty(key)
	if model_members[model_id].rows.is_empty():_placements.erase(model_id);model_members.erase(model_id);return false
	model.set_meta(Invalidation.OWNER,weakref(self));return true
func configure_replacement(group: Dictionary,geometry: MeshInstance3D) -> bool:
	for row in group.rows:
		var source:=_current(row)
		if source==null:continue
		var model: Node3D=_placements[row.model_id].owner.get_ref();var current:=_context(model,source)
		if current.get("available")!=true or current.identity!=group.context.identity or current.factor!=group.context.factor:return false
	if group.context.factor!=null:geometry.set_instance_shader_parameter("nwn_tile_fog_factor",group.context.factor)
	return true
func withdraw_draw_owner(owner: Object,reason: String) -> void:
	if owner is MeshInstance3D and members.has(owner.get_instance_id()):
		var record: Dictionary=members[owner.get_instance_id()];var model: Node3D=_placements[record.model_id].owner.get_ref();withdraw_model(model,reason)
	elif owner is Node3D:withdraw_model(owner,reason)
func _withdraw(id: int) -> void:
	var row: Dictionary=members.get(id,{})
	if row.is_empty():return
	super._withdraw(id)
	var group: Dictionary=groups.get(row.group,{})
	if not group.is_empty() and group.rows.has(row):
		group.rows.erase(row);group.vertices-=row.arrays[Mesh.ARRAY_VERTEX].size();group.indices-=row.arrays[Mesh.ARRAY_INDEX].size()
func _model_removed(id: int) -> void:
	super._model_removed(id);_placements.erase(id)
func _material_changed(id: int) -> void:
	if closed or not material_groups.has(id):return
	var ids: Array=[]
	for key in material_groups[id].groups:
		if groups.has(key):
			for row in groups[key].rows:ids.append(int(row.source_id))
	for source_id in ids:_withdraw(source_id)
func clear() -> void:
	super.clear();_placements.clear();_context_provider=Callable();_world=null;_scope.clear()
func snapshot() -> Dictionary:
	var value:=super.snapshot();value.mode="base-static-draw-leaf-merged";value.placements=_placements.size();value.scope=_scope.duplicate();value.policy="Positive received BASE provenance + zero-own-animation proof + exact Placement lifetime + original material/draw/physical-fog context; original Part/light/emitter/collision owners retained";return value
