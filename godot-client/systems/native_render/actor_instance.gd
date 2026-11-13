extends Node3D
signal equipment_colour_changed(slot: int,scope: int,rgb: Variant)
const ColourScopes=preload("res://systems/native_data/model_colour_scopes.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const SkinPreparation=preload("res://systems/native_data/skin_preparation.gd")
const NameplateAnchor=preload("res://systems/native_data/nameplate_anchor.gd")
var use_prepared_skins:=SkinPreparation.configured_enabled()
# Assemble original native model data into the existing Godot rig/skin owner.
# The adapter itself performs no JS export, GLB import or asset transfer.
const Rigs=preload("res://systems/model_rigs.gd")
const SkeletalRigs=preload("res://systems/native_render/skeletal_rigs.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
const ParticleEmitter=preload("res://systems/native_render/particle_emitter.gd")
const ModelReference=preload("res://systems/native_render/model_reference.gd")
const MeshProvenance=preload("res://tools/native_parity/visibility/mesh_provenance.gd")
const ReferenceGraph=preload("res://systems/native_render/reference_graph.gd")
const ActorAlpha=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
# Explicit world-owner enrollment only. GUI/preview and ordinary actors retain
# their existing materials until the caller opts in before install().
var actor_alpha_enabled:=false
var actor_alpha
var renderer_alpha_primary_models: Array[int]=[]
var failure:=""
var rigs
var object_id:=-1
var meshes: Array=[]
var model_names: Array=[]
var source_dependencies: Array=[]
var registry: Dictionary={"meshes_by_name":{}}
var retired:=false
var use_skeleton:=false
var reference_graphs: Array=[]
var emitter_listeners: Array=[]
var unattached_equipment: Array=[]
var impact_parts: Array=[]
var impact_lookup: Dictionary={}
var random_part_model: Dictionary={}
var equipment_models: Dictionary={}
var equipment_visuals: Dictionary={}
var equipment_colour_scopes: Dictionary={}
var body_model_scopes: Dictionary={}
func vector(values: PackedFloat32Array,index: int) -> Vector3:
	return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
func skin_source(row: Dictionary,model_index: int,part_index: int) -> Dictionary:
	var began:=Timing.begin()
	var source: Dictionary=row.skin; var data: Dictionary=row.mesh; var indices: PackedInt32Array=data.indices
	var prepared: Dictionary=source.get("native_upload",{})
	if use_prepared_skins and str(prepared.get("revision",""))==SkinPreparation.REVISION:
		Timing.finish("actor_install_skin_source_ms",began)
		return {"model":model_index,"part":part_index,"position":prepared.position,"normal":prepared.normal,"uv":prepared.source_uv,"weights":prepared.source_weights,"bones":prepared.source_bones,"slots":Array(source.boneConstantSlots),"inversePositions":source.tboneRefInv,"inverseQuaternions":source.qboneRefInv,"groups":[],"native_upload":prepared}
	var positions: Array=[]; var normals: Array=[]; var uv: Array=[]; var weights: Array=[]; var bones: Array=[]
	var authored: PackedFloat32Array=data.normals; var texcoords: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	for face in range(0,indices.size(),3):
		var a:=vector(data.vertices,int(indices[face])); var b:=vector(data.vertices,int(indices[face+1])); var c:=vector(data.vertices,int(indices[face+2])); var normal:=(b-a).cross(c-a).normalized()
		for corner in [0,2,1]:
			var index:=int(indices[face+corner]); var p:=vector(data.vertices,index); var n:=vector(authored,index) if not authored.is_empty() else normal
			positions.append_array([p.x,p.y,p.z]); normals.append_array([n.x,n.y,n.z])
			uv.append_array([texcoords[index*2],texcoords[index*2+1]] if not texcoords.is_empty() else [0.0,0.0])
			for component in 4: weights.append(source.weights[index*4+component]); bones.append(source.boneIndices[index*4+component])
	Timing.finish("actor_install_skin_source_ms",began)
	return {"model":model_index,"part":part_index,"position":positions,"normal":normals,"uv":uv,"weights":weights,"bones":bones,"slots":Array(source.boneConstantSlots),"inversePositions":source.tboneRefInv,"inverseQuaternions":source.qboneRefInv,"groups":[]}
func asset(model: Dictionary) -> Dictionary:
	return model.get("rig_asset",{})
func admitted_pieces(pieces: Array) -> Array:
	var accepted: Array=[]; var anchors: Dictionary={}
	for index in pieces.size():
		var piece: Dictionary=pieces[index]
		if index==0:
			for part in piece.get("bundle",{}).get("value",{}).get("nodes",[]): anchors[str(part.name).to_lower()]=true
		var anchor:=str(piece.get("anchor","")).to_lower()
		if index>0 and piece.get("attachment","")=="pq" and not anchor.is_empty() and not anchors.has(anchor) and str(piece.get("bundle",{}).get("error","")).is_empty():
			# Original Gob::AttachToObject08c540 clears the attachment and returns
			# null when the requested Part is absent; Wield99d340 does not reject
			# the creature. Do not fabricate a hand or draw the item at the origin.
			unattached_equipment.append({"model":piece.get("bundle",{}).get("value",{}).get("name",""),"anchor":anchor,"reason":"Original equipment attachment has no matching physical part"})
			continue
		accepted.append(piece)
	return accepted
func install(pieces: Array,shared_pool,id: int,maps: Dictionary,initial_animation: int=0,animation_context: Dictionary={}) -> bool:
	if rigs!=null or retired or pieces.is_empty(): failure="Native actor owner is unavailable/already used"; return false
	if actor_alpha_enabled:actor_alpha=ActorAlpha.new()
	set_meta("native_light_source",true)
	var began:=Timing.begin()
	object_id=id
	pieces=admitted_pieces(pieces)
	renderer_alpha_primary_models=ActorAlpha.primary_model_indices(pieces)
	var nodes: Array=[]; var models: Array=[]; var assets: Array=[]; var bindings: Array=[]; var anchors: Dictionary={}; var lights: Array=[]; var attachments: Array=[]; var emitters: Array=[]; var references: Array=[]
	var provenance: Array=[]
	var holder:=Node3D.new(); add_child(holder)
	for model_index in pieces.size():
		var piece: Dictionary=pieces[model_index]; var bundle: Dictionary=piece.bundle
		if actor_alpha!=null:actor_alpha.begin_model(model_index)
		var slot:=int(piece.get("equipmentSlot",0))
		if slot==0: body_model_scopes[int(piece.get("nativeVisualScope",255 if model_index==0 else -1))]=true
		if slot!=0:
			if not equipment_models.has(slot): equipment_models[slot]=[]
			equipment_models[slot].append(model_index)
			if piece.has("equipmentVisual"): equipment_visuals[slot]=piece.equipmentVisual.duplicate(true)
		if not str(bundle.get("error","")).is_empty(): failure=bundle.error; holder.free(); return false
		var model: Dictionary=bundle.value; model_names.append(model.name); source_dependencies.append_array(bundle.get("animation_sources",[]))
		var anchor_name:=str(piece.get("anchor","")).to_lower(); var parent:=-1
		if model_index>0:
			if anchor_name.is_empty(): parent=0
			elif not anchors.has(anchor_name): failure="Original actor attachment anchor is absent: "+anchor_name; holder.free(); return false
			else: parent=int(anchors[anchor_name])
		var root_index:=nodes.size(); var scale_value:=float(piece.get("scale",1.0))
		var physical_parent:=parent if parent>0 else int(models[0].parts[0]) if model_index>0 else -1
		if str(piece.get("attachment",""))=="pq":
			attachments.append({"node":root_index,"anchor":parent,"scale":[scale_value,scale_value,scale_value]}); parent=-1
		nodes.append({"name":str(model.name)+"_owner","parent":parent,"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[scale_value,scale_value,scale_value]})
		var converted:=asset(model); var parts: Array=[]
		if converted.is_empty(): failure="Native worker rig preparation is absent"; holder.free(); return false
		if model_index==0: set_meta("native_nameplate_height",NameplateAnchor.model_height(model)*scale_value)
		for index in model.nodes.size():
			var row: Dictionary=model.nodes[index]; var original_parent:=int(row.parent); var target:=nodes.size(); parts.append(target)
			if original_parent>=index or original_parent< -1: failure="Original actor physical parent is invalid"; holder.free(); return false
			var rest: Dictionary=converted.defaults[index]
			impact_parts.append({"index":target,"parent":parts[original_parent] if original_parent>=0 else physical_parent,"name":str(row.name),"area":row.mesh.get("native_area") if (int(row.flags)&0x21)==0x21 or int(row.flags)==0 and not row.mesh.is_empty() else 0.0,"model":model_index})
			if not impact_lookup.has(str(row.name).to_lower()): impact_lookup[str(row.name).to_lower()]=target
			nodes.append({"name":row.name,"parent":root_index if original_parent<0 else parts[original_parent],"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale,"visible":true})
			if model_index==0 and not anchors.has(str(row.name).to_lower()): anchors[str(row.name).to_lower()]=target
			if row.features.has("light") and not row.get("light",{}).is_empty(): lights.append({"node":target,"data":row.light})
			if row.has("reference"): references.append({"node":target,"data":row.reference,"origin":bundle.get("resource_name",model.name)})
			if row.has("emitter"):
				var emitter_raster: Dictionary=bundle.get("emitter_textures",{}).get(str(row.emitter.get("texture","")).to_lower(),{}); var texture: Texture2D=null
				if not emitter_raster.is_empty():
					texture=shared_pool.texture(emitter_raster)
					if texture==null: failure=shared_pool.failure; holder.free(); return false
				emitters.append({"node":target,"root":root_index,"part":index,"model":model_index,"properties":row.emitter,"asset":converted,"texture":texture})
			var data: Dictionary=row.mesh
			var source_facts: Dictionary=MeshProvenance.capture(bundle,row,index,model_index) if not data.is_empty() else {}
			if not source_facts.is_empty(): provenance.append({"node":target,"facts":source_facts})
			if data.is_empty() or not data.get("render",false) or data.indices.is_empty(): continue
			if row.features.has("skin") and not row.has("skin"): failure="Original ASCII skin data requires native decoding: "+str(model.name); holder.free(); return false
			var geometry=shared_pool.geometry(bundle.sha256,index,data,use_skeleton and not row.has("skin"))
			if geometry==null: failure=shared_pool.failure; holder.free(); return false
			var raster: Dictionary={}
			if not data.textures.is_empty() and str(data.textures[0]).to_lower() not in ["","null"]:
				var texture_name:=str(data.textures[0]).to_lower()
				if not bundle.get("textures",{}).has(texture_name): failure="Original actor texture is not prepared: "+texture_name; holder.free(); return false
				raster=bundle.textures[texture_name]
			var material=shared_pool.material(row,raster)
			if material==null: failure=shared_pool.failure; holder.free(); return false
			var mesh:=MeshInstance3D.new(); mesh.name="actor_mesh_"+str(id)+"_"+str(bindings.size()); mesh.mesh=geometry; mesh.material_override=material; mesh.visible=float(row.get("alpha",1))>0
			if actor_alpha!=null and not actor_alpha.enroll(mesh,model_index):
				failure=actor_alpha.failure;mesh.free();holder.free();return false
			# Animated meshes are children of one rig holder, unlike static Parts.
			# Keep physical source identity for per-mesh consumers such as GUI TXI.
			mesh.set_meta("native_source_part_index",index); mesh.set_meta("native_source_model_index",model_index)
			mesh.set_meta("native_mesh_source",source_facts)
			if geometry.has_meta("native_pick_shape"): mesh.set_meta("native_pick_shape",geometry.get_meta("native_pick_shape"))
			mesh.set_meta("native_pick_geometry",geometry.get_meta("native_pick_geometry"))
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mesh); meshes.append(mesh); registry.meshes_by_name[str(mesh.name)]=mesh
			var binding:={"name":str(mesh.name),"objectId":id,"rigNode":target,"rigLocal":{"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}}
			if row.has("skin"): binding.skin=skin_source(row,model_index,index)
			bindings.append(binding)
		assets.append(converted)
		var requested:=str(piece.get("initial_clip",maps.get("0",{}).get(str(initial_animation),""))); var available: bool=converted.clips.any(func(clip): return clip.name==requested)
		models.append({"asset":model_index,"parts":parts,"defaults":converted.defaults,"follow":bool(piece.get("follow",true)),"clip":requested if available else "","time":0.0,"speed":1.0,"loop":true,"playing":available})
	var source:={"id":id,"nodes":nodes,"models":models,"attachments":attachments,"clipMap":maps.get("0",{}),"sideMaps":maps,"animationSource":0,"context":animation_context,"bodyType":int(animation_context.get("fieldDE",0)),"model18":pieces.any(func(piece):return int(piece.get("partIndex",-1))==18)}
	Timing.finish("actor_install_bindings_ms",began); began=Timing.begin()
	rigs=SkeletalRigs.new() if use_skeleton else Rigs.new(); add_child(rigs); rigs.configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})
	Timing.finish("actor_install_rigs_ms",began); began=Timing.begin()
	if not rigs.stats.failures.is_empty(): failure=str(rigs.stats.failures); holder.queue_free(); return false
	for source_row in provenance:
		var part: Node3D=rigs.node_at(id,int(source_row.node))
		if is_instance_valid(part): part.set_meta("native_mesh_source",source_row.facts)
	for row in lights:
		var light:=PointLight.new(); light.set_meta("native_enhanced_light",shared_pool.native_lighting and not shared_pool.unshaded); light.configure(row.data); rigs.node_at(id,int(row.node)).add_child(light)
	for row in references:
		var reference:=ModelReference.new(); reference.name="native_reference"; reference.original_header=row.data; reference.origin_resource=str(row.origin); rigs.node_at(id,int(row.node)).add_child(reference)
	for row in emitters:
		var emitter:=ParticleEmitter.new(); emitter.name="native_emitter"; emitter.original_properties=row.properties; emitter.channel_asset=row.asset; emitter.physical_part=int(row.part); emitter.original_texture=row.texture; emitter.clock_provider=rigs.playback_state.bind(id,int(row.model))
		var target: Node3D=rigs.node_at(id,int(row.node)); var source_root: Node3D=rigs.node_at(id,int(row.root))
		# Source path must be assigned before add_child invokes _ready.
		var piece_model: Dictionary=pieces[int(row.model)].bundle.value
		emitter.origin_resource=str(pieces[int(row.model)].bundle.get("resource_name",piece_model.name))
		# Source Gob owns the primary model, including held-part emitters.
		emitter.source_model_flags=int(pieces[0].bundle.value.get("classification_flags",-1))
		for child in piece_model.nodes.size():
			if int(piece_model.nodes[child].parent)==int(row.part) and piece_model.nodes[child].has("reference"):
				var reference=rigs.node_at(id,int(models[int(row.model)].parts[child])).get_node("native_reference")
				emitter.reference_paths.append(NodePath("../"+str(target.get_path_to(reference))))
		emitter.source_path=NodePath("../"+str(target.get_path_to(source_root))); target.add_child(emitter)
		# Original MdlNodeEmitter::InternalCreateInstance 1400622aa..2c7
		# registers Detonate on this Gob only for Explosion emitters.
		if str(row.properties.get("update",""))=="Explosion":
			var emitter_model_index:=int(row.model)
			var listener:=func(actor: int,index: int,event: String,_serial: int):
				if not retired and actor==object_id and index==emitter_model_index and event.to_lower()=="detonate" and is_instance_valid(emitter): emitter.detonate()
			rigs.model_event.connect(listener); emitter_listeners.append(listener)
	for model_index in pieces.size():
		var original: Dictionary=pieces[model_index].bundle.value; var physical: Array=[]; var part_indices: Array=models[model_index].parts
		if not original.nodes.any(func(row):return row.has("reference")): reference_graphs.append(null); continue
		for index in part_indices: physical.append(rigs.node_at(id,int(index)))
		var owner_index:=int(nodes[int(part_indices[0])].parent); var graph:=ReferenceGraph.new()
		if not graph.configure(rigs.node_at(id,owner_index),original.nodes,physical): failure=graph.failure; holder.queue_free(); return false
		reference_graphs.append(graph)
	holder.queue_free(); Timing.finish("actor_install_helpers_ms",began); return true
func reattach_references(target: Node3D,model_index: int=0) -> bool:
	return not retired and model_index>=0 and model_index<reference_graphs.size() and (reference_graphs[model_index]==null or reference_graphs[model_index].reattach(target))
func physical_part(name_value: String) -> Node3D:
	return rigs.node_at(object_id,int(impact_lookup[name_value.to_lower()])) if not retired and rigs!=null and impact_lookup.has(name_value.to_lower()) else null
func impact_model() -> Dictionary:
	if random_part_model.is_empty(): random_part_model=preload("res://systems/native_data/model_random_part.gd").graph(impact_parts)
	return random_part_model
func equipment_part(slot: int,part: String) -> Node3D:
	if retired or rigs==null: return null
	for model_index in equipment_models.get(slot,[]):
		var found: Node3D=rigs.node_for(object_id,int(model_index),part)
		if found!=null: return found
	return null
func equipment_colour_scope(slot: int,scope: int,rgb: Variant) -> bool:
	if retired or rigs==null or not equipment_models.has(slot): return false
	if not equipment_colour_scopes.has(slot): equipment_colour_scopes[slot]=ColourScopes.create()
	if not ColourScopes.set_colour(equipment_colour_scopes[slot],scope,rgb): return false
	var success:=true
	for index in equipment_models[slot]: success=rigs.set_model_colour_scope(object_id,int(index),scope,rgb) and success
	equipment_colour_changed.emit(slot,scope,rgb)
	return success
func equipment_colour_state(slot: int) -> Dictionary:
	return equipment_colour_scopes[slot].duplicate(true) if equipment_colour_scopes.has(slot) else ColourScopes.create()
func reference_binding_signature() -> Array:
	var result: Array=[]
	for graph in reference_graphs:
		if graph==null: continue
		for row in graph.rows:
			if not is_instance_valid(row.helper): continue
			var model=row.helper.model68
			result.append([row.helper.get_instance_id(),int(row.helper.revision),model.get_instance_id() if is_instance_valid(model) and not model.is_queued_for_deletion() else 0])
	return result
func set_animation(code: int,speed: float=1.0,loop: Variant=null) -> void:
	if is_instance_valid(rigs): rigs.set_playback(object_id,code,speed,loop)
func set_renderer_alpha(value: float,model_indices: Array=[0],gob_flag18: bool=false,colour_shift: bool=true) -> bool:
	return not retired and actor_alpha!=null and actor_alpha.set_alpha(value,model_indices,gob_flag18,colour_shift)
func renderer_alpha_model_indices() -> Array[int]:
	return renderer_alpha_primary_models.duplicate() if not retired else []
func set_renderer_vector(channel: int,value: Variant,model_indices: Array=[0]) -> bool:
	return not retired and actor_alpha!=null and actor_alpha.set_vector(channel,value,model_indices)
func set_presentation_draw_enabled(value: bool,model_indices: Array=[0]) -> bool:
	return not retired and actor_alpha!=null and actor_alpha.set_presentation_draw_enabled(value,model_indices)
func snapshot() -> Dictionary:
	return {"models":model_names.duplicate(),"meshes":meshes.size(),"rigs":rigs.stats.duplicate(true) if is_instance_valid(rigs) else {},"failure":failure,"unattached_equipment":unattached_equipment.duplicate(true),"actor_alpha":actor_alpha.snapshot() if actor_alpha!=null else {"enabled":false}}
func retain_decoded_data() -> Dictionary:
	# Keep only immutable parser/rig source graphs alive through main-thread
	# teardown. Their final destruction can then run on the data-disposal worker.
	# Never transfer scene Parts, animation players, materials or native owners.
	var sources: Array=[]; var skin_sources: Array=[]
	if is_instance_valid(rigs) and rigs.entities.has(object_id):
		for model in rigs.entities[object_id].models:
			if model.has("asset_source"): sources.append(model.asset_source)
		for skin in rigs.entities[object_id].get("skins",[]):
			if skin.has("source"): skin_sources.append(skin.source)
	var payload: Dictionary={}
	if not sources.is_empty(): payload.rig_sources=sources
	if not skin_sources.is_empty(): payload.skin_sources=skin_sources
	return payload
func retire() -> void:
	if retired: return
	retired=true
	renderer_alpha_primary_models.clear()
	if actor_alpha!=null:actor_alpha.close();actor_alpha=null
	if is_instance_valid(rigs):
		for listener in emitter_listeners:
			if rigs.model_event.is_connected(listener): rigs.model_event.disconnect(listener)
	emitter_listeners.clear()
	if is_instance_valid(rigs): rigs.forget_entity(object_id)
	registry.meshes_by_name.clear(); meshes.clear(); model_names.clear(); source_dependencies.clear(); reference_graphs.clear(); unattached_equipment.clear(); impact_parts.clear(); impact_lookup.clear(); random_part_model.clear(); equipment_models.clear(); equipment_visuals.clear(); equipment_colour_scopes.clear(); body_model_scopes.clear(); queue_free()
