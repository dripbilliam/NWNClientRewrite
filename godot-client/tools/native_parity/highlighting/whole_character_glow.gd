extends "res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd"
# Visual-policy candidate: ONE soft textured billboard per selected physical
# character. Inherits the typed renderer contract, never calls native build.
# Existing tint/illumination/selection/alpha ownership stays in its controller.
const Source=preload("res://systems/native_render/selection_highlight_source.gd")
const PrimaryState=preload("res://tools/native_parity/ui/actor-alpha-state.gd")
const HALO_SCALE_DEFAULT:=1.12
var halo_scale:=HALO_SCALE_DEFAULT
var _world_scope: Dictionary={}
var _scope_guard:=Callable()

func _init() -> void:
	super()
	batch.name="whole_character_glow"
	stats.quads=0;stats.source_parts=0;stats.source_corners=0;stats.primary_queries=0

func bind_scope(scope: Dictionary,guard: Callable) -> bool:
	if closed or scope.is_empty() or not guard.is_valid():return false
	_world_scope=scope.duplicate(true);_scope_guard=guard;revision+=1;batch.visible=false;return true

func _admitted(epoch: int) -> bool:
	if closed or revision!=epoch:return false
	if not _world_scope.is_empty():
		if not _scope_guard.is_valid():return false
		var accepted: Variant=_scope_guard.call(_world_scope.duplicate(true))
		if not accepted is bool or not accepted:return false
	return not closed and revision==epoch

static func collect_parts(owner: Node3D) -> Dictionary:
	# Registration visits only this physical actor's already-published Part
	# index. Skin bounds intentionally join the new whole-body visual policy.
	var physical: Array=[];var rigs: Variant=Source.property(owner,"rigs")
	if rigs is Node and is_instance_valid(rigs):
		var id: Variant=Source.property(owner,"object_id");var entities: Variant=Source.property(rigs,"entities")
		if not entities is Dictionary or not entities.has(id) or not entities[id].get("model_parts") is Array:return {"available":false,"reason":"actor-part-index-unavailable"}
		for model in entities[id].model_parts:
			if not model is Array:return {"available":false,"reason":"actor-model-part-index-unavailable"}
			for index in model:
				var part: Variant=rigs.node_at(int(id),int(index))
				if part is Node3D:physical.append(part)
	else:
		var parts: Variant=Source.property(owner,"parts")
		if not parts is Array:return {"available":false,"reason":"physical-part-index-unavailable"}
		physical=parts
	var rows: Array=[];var seen: Dictionary={}
	for part in physical:
		if not part is Node3D or not is_instance_valid(part) or seen.has(part.get_instance_id()):continue
		seen[part.get_instance_id()]=true
		if not part.has_meta("native_mesh_source"):continue
		var source: Variant=part.get_meta("native_mesh_source")
		if not source is Dictionary or not source.get("node_flags") is int:return {"available":false,"reason":"part-source-kind-unavailable"}
		if (int(source.node_flags)&0x20)==0:continue
		if source.get("native_bounds_available")!=true or source.get("native_bounds_valid")!=true or not valid_bounds(source.get("native_bounds")):return {"available":false,"reason":"whole-body-authored-bounds-unavailable"}
		rows.append({"anchor":weakref(part),"id":part.get_instance_id(),"source":source,"enabled":true,"skin":(int(source.node_flags)&0x40)!=0})
	return {"available":not rows.is_empty(),"parts":rows}

func register_entity(id: int,owner: Node3D,lifetime: Array,_descriptors: Array,color: Color,alpha_provider: Callable=Callable(),color_provider: Callable=Callable()) -> bool:
	if closed or not is_instance_valid(owner) or lifetime.is_empty() or not finite_color(color):return false
	var source:=collect_parts(owner)
	if not source.available:return false
	var layer_property:=""
	for property in owner.get_property_list():
		if str(property.name)=="actor_alpha":layer_property="actor_alpha";break
		if str(property.name)=="renderer_alpha":layer_property="renderer_alpha"
	entries[id]={"owner":weakref(owner),"id":owner.get_instance_id(),"lifetime":lifetime.duplicate(true),"parts":source.parts,"color":color,"alpha":alpha_provider,"color_source":color_provider,"color_provided":not color_provider.is_null(),"draw_source":Callable(),"layer_property":layer_property,"retired_supported":Source.property(owner,"retired") is bool,"last_fit":{}}
	revision+=1;dirty=true;batch.visible=false;stats.registered=entries.size();return true

func bind_draw_provider(id: int,provider: Callable) -> bool:
	if closed or not entries.has(id) or not provider.is_valid():return false
	entries[id].draw_source=provider;revision+=1;batch.visible=false;return true

func _owner(entry: Dictionary) -> Node3D:
	var owner:=alive(entry.owner,entry.id)
	if owner==null or entry.retired_supported and owner.get("retired")==true:return null
	if owner.has_meta("native_selection_scope") and owner.get_meta("native_selection_scope")!=entry.lifetime:return null
	return owner

func _physical_witness(entry: Dictionary,owner: Node3D) -> Dictionary:
	var rows: Array=[]
	for row in entry.parts:
		var part:=alive(row.anchor,row.id)
		if part==null or not owner.is_ancestor_of(part) or not part.has_meta("native_mesh_source") or not is_same(part.get_meta("native_mesh_source"),row.source):return {"available":false,"reason":"physical-part-retired-or-replaced"}
		var enabled: bool=row.enabled;var ancestor: Node=part;var path: Array=[]
		while ancestor!=null:
			var explicit: Variant=null
			if ancestor.has_meta("native_highlight_subtree_enabled"):
				var current: Variant=ancestor.get_meta("native_highlight_subtree_enabled")
				if not current is bool:return {"available":false,"reason":"subtree-state-unavailable"}
				enabled=enabled and current;explicit=current
			path.append([ancestor.get_instance_id(),explicit])
			if ancestor==owner:break
			ancestor=ancestor.get_parent()
		var source: Dictionary=row.source;var bounds: Variant=source.get("native_bounds")
		if source.get("native_bounds_available")!=true or source.get("native_bounds_valid")!=true or not valid_bounds(bounds):return {"available":false,"reason":"current-authored-bounds-unavailable"}
		var transform:=part.global_transform
		if not transform.is_finite():return {"available":false,"reason":"current-part-transform-unavailable"}
		rows.append({"id":row.id,"path":path,"transform":transform,"bounds":bounds.duplicate(true),"enabled":enabled})
	var parent:=owner.get_parent()
	return {"available":true,"owner_parent":parent.get_instance_id() if parent!=null else 0,"owner_transform":owner.global_transform,"rows":rows}

func _points(witness: Dictionary) -> Dictionary:
	var points:=PackedVector3Array();var parts:=0
	for row in witness.rows:
		if not row.enabled:continue
		var bounds: Dictionary=row.bounds;var transform: Transform3D=row.transform
		for x in 2:
			for y in 2:
				for z in 2:
					var native:=Vector3(float(bounds.max[0] if x else bounds.min[0]),float(bounds.max[1] if y else bounds.min[1]),float(bounds.max[2] if z else bounds.min[2]))
					points.append(transform*source_vector(native))
		parts+=1
	return {"available":not points.is_empty(),"points":points,"parts":parts}

func _draw_witness(entry: Dictionary,owner: Node3D,draw: bool) -> Dictionary:
	# Cache the source-owned plain primary state during the getter stage.
	# Final publication reads these same fields without invoking the getter.
	if entry.layer_property.is_empty():return {"available":false}
	var layer: Variant=owner.get(entry.layer_property)
	if not layer is RefCounted or Source.property(layer,"closed")!=false:return {"available":false}
	var models: Variant=Source.property(layer,"models")
	if not models is Dictionary:return {"available":false}
	var state: Variant=models.get(0)
	if not state is PrimaryState or state.closed or state.presentation_draw_enabled!=draw:return {"available":false}
	return {"available":true,"layer":weakref(layer),"state":weakref(state),"revision":state.revision,"draw":draw}

func _pure_current(witness: Dictionary) -> bool:
	var entry: Dictionary=witness.entry
	if not entries.has(witness.entity) or not is_same(entries[witness.entity],entry):return false
	var owner:=_owner(entry)
	if owner==null or _physical_witness(entry,owner)!=witness.physical:return false
	var draw: Dictionary=witness.draw;var layer=draw.layer.get_ref();var state=draw.state.get_ref()
	return is_instance_valid(layer) and is_instance_valid(state) and owner.get(entry.layer_property)==layer and not layer.closed and is_same(layer.models.get(0),state) and not state.closed and state.revision==draw.revision and state.presentation_draw_enabled==draw.draw

static func fit(points: PackedVector3Array,camera: Camera3D,scale: float=HALO_SCALE_DEFAULT) -> Dictionary:
	if points.is_empty() or not is_finite(scale) or scale<=0:return {"available":false}
	var view:=camera.get_camera_transform();var inverse:=view.affine_inverse()
	var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF);var near_depth:=INF;var far_depth:=-INF
	var world_bounds:=AABB(points[0],Vector3.ZERO)
	for point in points:
		if not point.is_finite():return {"available":false}
		var depth: float=-(inverse*point).z
		# Crossing the near plane has no finite tight projected rectangle. Do
		# not invent an angular/size cap or a camera-independent box substitute.
		if depth<=camera.near:return {"available":false,"reason":"whole-body-crosses-camera-near-plane"}
		var screen:=camera.unproject_position(point)
		if not screen.is_finite():return {"available":false}
		minimum=minimum.min(screen);maximum=maximum.max(screen);near_depth=minf(near_depth,depth);far_depth=maxf(far_depth,depth);world_bounds=world_bounds.expand(point)
	var center: Vector2=(minimum+maximum)*.5;var half: Vector2=(maximum-minimum)*(.5*scale)
	if half.x<=0 or half.y<=0:return {"available":false,"reason":"whole-body-projection-degenerate"}
	var lo:=center-half;var hi:=center+half;var depth: float=(near_depth+far_depth)*.5
	var corners:=PackedVector3Array()
	for screen in [Vector2(lo.x,lo.y),Vector2(hi.x,lo.y),Vector2(hi.x,hi.y),Vector2(lo.x,hi.y)]:corners.append(camera.project_position(screen,depth))
	return {"available":true,"corners":corners,"body_screen_min":minimum,"body_screen_max":maximum,"halo_screen_min":lo,"halo_screen_max":hi,"world_bounds":world_bounds,"depth":depth,"scale":scale}

func _rebuild() -> void:
	members.clear()
	for id in selected:
		if entries.has(id):members.append({"entity":id,"entry":entries[id]})
	positions.resize(members.size()*6);positions.fill(Vector3.ZERO);colors.resize(positions.size());colors.fill(Color(0,0,0,0));uvs.resize(positions.size());attributes.resize(positions.size()*12);attributes.fill(0)
	for at in positions.size():uvs[at]=UVS[at%6];attributes.encode_float(at*12+4,uvs[at].x);attributes.encode_float(at*12+8,uvs[at].y)
	surface=ArrayMesh.new()
	if not positions.is_empty():
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	batch.mesh=surface;batch.visible=false;dirty=false;stats.quads=members.size();stats.vertices=positions.size();stats.membership_rebuilds+=1

func tick(camera: Camera3D,_old_part_pulse: Variant,intensity: Variant) -> bool:
	batch.visible=false
	if closed or not texture_ready or not is_instance_valid(camera) or not camera.is_inside_tree() or camera.is_queued_for_deletion() or not camera.is_current() or not (intensity is int or intensity is float) or not is_finite(float(intensity)) or intensity<0:return false
	var epoch:=revision
	if not _admitted(epoch):return false
	if dirty:_rebuild()
	if members.is_empty():return true
	var view:=camera.get_camera_transform();var projection:=camera.get_camera_projection();var viewport_id:=camera.get_viewport().get_instance_id();var complete:=true;var has_bounds:=false;var draw_bounds:=AABB();var witnesses: Array=[]
	stats.source_parts=0;stats.source_corners=0
	for index in members.size():
		var member: Dictionary=members[index];var entry: Dictionary=member.entry;var output: Dictionary={"available":false};var tint:=Color(0,0,0,0)
		var owner:=_owner(entry)
		if owner!=null and entries.has(member.entity) and is_same(entries[member.entity],entry):
			# One primary Gob control query per selected entity. No Part alpha.
			var alpha: Variant=entry.alpha.call(0) if entry.alpha.is_valid() else null;stats.primary_queries+=1
			if not _admitted(epoch):return false
			var color: Variant=entry.color_source.call(0) if entry.color_source.is_valid() else entry.color
			if not _admitted(epoch):return false
			var draw: Variant=entry.draw_source.call(0) if entry.draw_source.is_valid() else null
			if not _admitted(epoch):return false
			owner=_owner(entry)
			if owner!=null and (alpha is int or alpha is float) and is_finite(float(alpha)) and alpha>=0 and alpha<=1 and (color is Color and finite_color(color) or color is Vector3 and color.is_finite()):
				if not draw is bool:entry.last_fit={"available":false,"reason":"primary-presentation-draw-unavailable"};return false
				var draw_witness:=_draw_witness(entry,owner,draw)
				if not draw_witness.available:entry.last_fit={"available":false,"reason":"primary-presentation-draw-witness-unavailable"};return false
				var physical:=_physical_witness(entry,owner)
				if not physical.available:entry.last_fit=physical;return false
				witnesses.append({"entity":member.entity,"entry":entry,"physical":physical,"draw":draw_witness})
				var point_set:=_points(physical)
				if not draw:output={"available":false,"suppressed":true,"reason":"primary-presentation-draw-disabled"}
				elif point_set.available:
					stats.source_parts+=point_set.parts;stats.source_corners+=point_set.points.size();output=fit(point_set.points,camera,halo_scale)
					var rgb: Vector3=Vector3(color.r,color.g,color.b) if color is Color else color
					if alpha<.4:rgb*=float(alpha)/.4
					tint=Color(rgb.x,rgb.y,rgb.z,float(intensity))
		if not output.available and not output.get("suppressed",false):complete=false;stats.unavailable+=1
		entry.last_fit=output.duplicate(true)
		for vertex in 6:
			var at:=index*6+vertex;positions[at]=output.corners[ORDER[vertex]] if output.available else Vector3.ZERO
			if output.available and tint.a>0 and (tint.r!=0 or tint.g!=0 or tint.b!=0):draw_bounds=draw_bounds.expand(positions[at]) if has_bounds else AABB(positions[at],Vector3.ZERO);has_bounds=true
			var rgba: Color=tint if output.available else Color(0,0,0,0)
			for component in 4:attributes[at*12+component]=clampi(int(rgba[component]*255.0),0,255)
	# Last arbitrary callback first. Everything afterwards is bounded pure
	# source validation and buffer publication: no provider/guard is re-invoked.
	if not _admitted(epoch):return false
	for witness in witnesses:
		if not _pure_current(witness):return false
	if not is_instance_valid(camera) or camera.is_queued_for_deletion() or not camera.is_current() or camera.get_viewport().get_instance_id()!=viewport_id or camera.get_camera_transform()!=view or camera.get_camera_projection()!=projection:return false
	surface.surface_update_vertex_region(0,0,positions.to_byte_array());surface.surface_update_attribute_region(0,0,attributes);batch.custom_aabb=draw_bounds;batch.visible=has_bounds;stats.updates+=1
	return complete

func diagnostic(id: int) -> Dictionary:return entries[id].last_fit.duplicate(true) if entries.has(id) else {}
func unregister_entity(id: int,lifetime: Array) -> bool:
	if not entries.has(id) or entries[id].lifetime!=lifetime:return false
	forget(id);return true
func set_selected(ids: Array) -> void:mark(ids)
func snapshot() -> Dictionary:
	var result:=super.snapshot();result.route="whole-character-soft-textured-billboard";result.geometry="one quad / six vertices per selected entity; no per-Part fans or skin replay";result.halo_scale=halo_scale;result.old_part_pulse_ignored=true;result.native_visual_parity_claim=false;return result
func close() -> void:
	_world_scope={};_scope_guard=Callable();super.close()
