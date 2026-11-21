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
const ModelVisualTransform=preload("res://systems/native_data/model_visual_transform.gd")
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
var model_resource_names: Array=[]
var source_dependencies: Array=[]
var registry: Dictionary={"meshes_by_name":{}}
var retired:=false
var use_skeleton:=false
var reference_graphs: Array=[]
var emitter_listeners: Array=[]
var _install_activating:=false
var unattached_equipment: Array=[]
var failed_equipment_item_id:=-1
# Index in the caller's unfiltered visual plan, retained across failed cleanup.
var failed_piece_source_index:=-1
var impact_parts: Array=[]
var impact_lookup: Dictionary={}
var random_part_model: Dictionary={}
var equipment_models: Dictionary={}
var equipment_visuals: Dictionary={}
var equipment_colour_scopes: Dictionary={}
var body_model_scopes: Dictionary={}
var visual_piece_descriptors: Array=[]
var model_visual_states: Dictionary={}
var visual_owner_indices: Dictionary={}
static func material_owner_part(model: Dictionary,index: int) -> int:
	var row: Dictionary=model.nodes[index]
	var parent:=int(row.get("parentIndex",row.get("parent",-1)))
	if parent<0 or parent>=index or not row.has("source_index"):return -1
	var parent_row: Dictionary=model.nodes[parent]
	# ASCII multi-bitmap face runs share one authored source node. Only the
	# generated run Parts have the same source index as their physical parent.
	return parent if parent_row.has("source_index") and int(parent_row.source_index)==int(row.source_index) else -1
static func visual_descriptors(pieces: Array)->Array:
	var result: Array=[]
	for piece in pieces:
		result.append({"slot":int(piece.get("equipmentSlot",0)),"scope":int(piece.get("nativeVisualScope",-1)),"helmet":str(piece.get("anchor",""))=="head_g" and str(piece.get("attachment",""))=="pq","itemId":int(piece.get("equipmentItemId",-1)),"right":bool(piece.get("heldRight",int(piece.get("equipmentSlot",0))==16))})
	return result
func _ensure_model_visuals(world_timer: Variant,object_type: int)->void:
	if not model_visual_states.is_empty() or not installation_complete or not is_instance_valid(rigs) or not rigs.entities.has(object_id):return
	var entry: Dictionary=rigs.entities[object_id]
	var groups: Dictionary={}
	for index in mini(visual_piece_descriptors.size(),entry.model_parts.size()):
		var descriptor: Dictionary=visual_piece_descriptors[index]
		var key: int=1 if descriptor.helmet else int(descriptor.slot)
		if not groups.has(key):groups[key]=[]
		groups[key].append(index)
	for key in groups:
		var indices: Array=groups[key]
		if indices.is_empty():continue
		var lookup: Dictionary={255:int(indices[0])}
		for index in indices:
			if int(index)==int(indices[0]):continue
			# The old world-item binding owns one root visual transform. Its
			# additional item model components are excluded from scope lookup.
			if object_type==6 and int(key)==0:continue
			var scope:=int(visual_piece_descriptors[int(index)].scope)
			if scope>=0 and scope<256:lookup[scope]=int(index)
		var state:=ModelVisualTransform.new()
		state.configure(int(indices[0]),lookup,world_timer)
		for index in indices:
			var parts: Array=entry.model_parts[int(index)]
			if parts.is_empty():continue
			var owner_index:=int(entry.parents[int(parts[0])])
			var owner: Node3D=rigs.node_at(object_id,owner_index)
			if owner==null:continue
			state.unit(int(index),owner)
			visual_owner_indices[int(index)]=owner_index
			rigs.set_visual_speed_provider(object_id,int(index),state.speed.bind(int(index)))
		model_visual_states[int(key)]=state
	if model_visual_states.has(0):
		var body_state: Variant=model_visual_states[0]
		for scope in range(244,252):
			var held_slot:=-1
			for descriptor in visual_piece_descriptors:
				if descriptor.helmet or int(descriptor.slot) not in [16,32] or bool(descriptor.right)!=(scope<248):continue
				held_slot=int(descriptor.slot);break
			if not model_visual_states.has(held_slot):continue
			var held_state: Variant=model_visual_states[held_slot]
			var component:=252+(scope-244)%4
			if held_state.scope_models.has(component):body_state.external_scope_targets[scope]={"state":held_state,"model_index":int(held_state.scope_models[component])}
func sync_visual_transform(object: Dictionary,world_timer: Variant=null)->void:
	if retired or not installation_complete or int(object.get("id",-1))!=object_id:return
	_ensure_model_visuals(world_timer,int(object.get("objectType",0)))
	if model_visual_states.is_empty():return
	for state in model_visual_states.values():state.world_timer=world_timer
	var replicated: Dictionary=object.get("replicated",{})
	var body_input: Variant=replicated.get("visualTransform")
	if int(object.get("objectType",0))==6:
		var item_data: Variant=object.get("item",replicated.get("item",{}))
		if body_input==null and item_data is Dictionary:body_input=item_data.get("visualTransform")
	if model_visual_states.has(0):model_visual_states[0].sync(body_input)
	var appearance: Variant=object.get("appearance",{})
	var equipment: Array=appearance.get("equipment",[]) if appearance is Dictionary else []
	for slot in [1,16,32]:
		if not model_visual_states.has(slot):continue
		var item_input: Variant=null
		var root_index:=int(model_visual_states[slot].root_model)
		var item_id:=int(visual_piece_descriptors[root_index].get("itemId",-1)) if root_index>=0 and root_index<visual_piece_descriptors.size() else -1
		for row in equipment:
			if row is Dictionary and item_id>=0 and int(row.get("id",-1))==item_id:
				var item: Variant=row.get("item",{})
				item_input=item.get("visualTransform") if item is Dictionary else null
				break
		model_visual_states[slot].sync(item_input)
	for state in model_visual_states.values():state.update()
	_publish_visual_owner_poses()
func _publish_visual_owner_poses()->void:
	if not is_instance_valid(rigs):return
	if model_visual_states.has(0):
		var body_state: Variant=model_visual_states[0]
		if body_state.units.has(body_state.root_model):rigs.set_visual_body_scale(object_id,float(body_state.units[body_state.root_model].scale))
	for state in model_visual_states.values():
		for index in state.units:
			if visual_owner_indices.has(index):rigs.set_visual_owner_pose(object_id,int(visual_owner_indices[index]),state.units[index].pose)
func update_visual_transform()->void:
	if retired or model_visual_states.is_empty():return
	var evaluated:=false
	for state in model_visual_states.values():
		if state.update():evaluated=true
	# Constant units still restore their node transform if another owner wrote it.
	# Their separately stored rig pose and scale were published at assignment.
	if evaluated:_publish_visual_owner_poses()
func vector(values: PackedFloat32Array,index: int) -> Vector3:
	return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
func skin_source(row: Dictionary,model_index: int,part_index: int) -> Dictionary:
	var began:=Timing.begin()
	var source: Dictionary=row.skin; var data: Dictionary=row.mesh; var indices: PackedInt32Array=data.indices
	var prepared: Dictionary=source.get("native_upload",{})
	if use_prepared_skins and str(prepared.get("revision",""))==SkinPreparation.REVISION:
		Timing.finish("actor_install_skin_source_ms",began)
		return {"model":model_index,"part":part_index,"position":prepared.position,"normal":prepared.normal,"uv":prepared.source_uv,"weights":prepared.source_weights,"bones":prepared.source_bones,"source_indices":indices,"slots":Array(source.boneConstantSlots),"inversePositions":source.tboneRefInv,"inverseQuaternions":source.qboneRefInv,"groups":[],"native_upload":prepared}
	var positions: Array=[]; var normals: Array=[]; var uv: Array=[]; var weights: Array=[]; var bones: Array=[]
	var texcoords: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	for face in range(0,indices.size(),3):
		var a:=vector(data.vertices,int(indices[face])); var b:=vector(data.vertices,int(indices[face+1])); var c:=vector(data.vertices,int(indices[face+2])); var normal:=(b-a).cross(c-a).normalized()
		for corner in [0,2,1]:
			var index:=int(indices[face+corner]); var p:=vector(data.vertices,index); var n:=normal
			positions.append_array([p.x,p.y,p.z]); normals.append_array([n.x,n.y,n.z])
			uv.append_array([texcoords[index*2],texcoords[index*2+1]] if not texcoords.is_empty() else [0.0,0.0])
			for component in 4: weights.append(source.weights[index*4+component]); bones.append(source.boneIndices[index*4+component])
	Timing.finish("actor_install_skin_source_ms",began)
	return {"model":model_index,"part":part_index,"position":positions,"normal":normals,"uv":uv,"weights":weights,"bones":bones,"source_indices":indices,"slots":Array(source.boneConstantSlots),"inversePositions":source.tboneRefInv,"inverseQuaternions":source.qboneRefInv,"groups":[]}
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
	failed_piece_source_index=-1
	if rigs!=null or retired or pieces.is_empty(): failure="Native actor owner is unavailable/already used"; return false
	if actor_alpha_enabled:actor_alpha=ActorAlpha.new()
	set_meta("native_light_source",true)
	var began:=Timing.begin()
	object_id=id
	pieces=admitted_pieces(pieces)
	visual_piece_descriptors=visual_descriptors(pieces)
	renderer_alpha_primary_models=ActorAlpha.primary_model_indices(pieces)
	var nodes: Array=[]; var models: Array=[]; var assets: Array=[]; var bindings: Array=[]; var anchors: Dictionary={}; var lights: Array=[]; var attachments: Array=[]; var emitters: Array=[]; var references: Array=[]
	var provenance: Array=[]
	var holder:=Node3D.new(); add_child(holder)
	for model_index in pieces.size():
		var piece: Dictionary=pieces[model_index]; var bundle: Dictionary=piece.bundle
		failed_equipment_item_id=int(piece.get("equipmentItemId",-1))
		failed_piece_source_index=int(piece.get("sourcePieceIndex",-1))
		if actor_alpha!=null:actor_alpha.begin_model(model_index)
		var slot:=int(piece.get("equipmentSlot",0))
		if slot==0: body_model_scopes[int(piece.get("nativeVisualScope",255 if model_index==0 else -1))]=true
		if slot!=0:
			if not equipment_models.has(slot): equipment_models[slot]=[]
			equipment_models[slot].append(model_index)
			if piece.has("equipmentVisual"): equipment_visuals[slot]=piece.equipmentVisual.duplicate(true)
		if not str(bundle.get("error","")).is_empty(): failure=bundle.error; holder.free(); return false
		var model: Dictionary=bundle.value; model_names.append(model.name); model_resource_names.append(str(bundle.get("resource_name",model.name))); source_dependencies.append_array(bundle.get("animation_sources",[]))
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
			var row: Dictionary=model.nodes[index]; var original_parent:=int(row.get("parentIndex",row.get("parent",-1))); var target:=nodes.size(); parts.append(target)
			if original_parent>=index or original_parent< -1: failure="Original actor physical parent is invalid"; holder.free(); return false
			var rest: Dictionary=converted.defaults[index]
			impact_parts.append({"index":target,"parent":parts[original_parent] if original_parent>=0 else physical_parent,"name":str(row.name),"area":row.mesh.get("native_area") if str(row.get("type",""))=="trimesh" else 0.0,"model":model_index})
			if not impact_lookup.has(str(row.name).to_lower()): impact_lookup[str(row.name).to_lower()]=target
			nodes.append({"name":row.name,"parent":root_index if original_parent<0 else parts[original_parent],"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale,"visible":true})
			if model_index==0 and not anchors.has(str(row.name).to_lower()): anchors[str(row.name).to_lower()]=target
			if row.features.has("light") and not row.get("light",{}).is_empty(): lights.append({"node":target,"data":row.light,"priority":int(piece.get("nativeLightPriority",0))})
			if row.has("reference") and (not row.has("type") or str(row.type)=="reference"): references.append({"node":target,"data":row.reference,"origin":bundle.get("resource_name",model.name),"equipmentItemId":piece.get("equipmentItemId",-1),"sourcePieceIndex":piece.get("sourcePieceIndex",-1)})
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
			var material_options: Dictionary=shared_pool.model_material_options(row)
			var mesh:=MeshInstance3D.new(); mesh.name="actor_mesh_"+str(id)+"_"+str(bindings.size()); mesh.mesh=geometry; mesh.material_override=material; mesh.visible=material_options.visible
			mesh.set_meta("native_transparency_hint",material_options.hint)
			if actor_alpha!=null and not actor_alpha.enroll(mesh,model_index):
				failure=actor_alpha.failure;mesh.free();holder.free();return false
			# Animated meshes are children of one rig holder, unlike static Parts.
			# Keep physical source identity for per-mesh consumers such as GUI TXI.
			mesh.set_meta("native_source_part_index",index); mesh.set_meta("native_source_model_index",model_index)
			var material_owner:=material_owner_part(model,index)
			if material_owner>=0:mesh.set_meta("native_material_owner_part_index",material_owner)
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
	failed_equipment_item_id=-1
	failed_piece_source_index=-1
	var source:={"id":id,"nodes":nodes,"models":models,"attachments":attachments,"clipMap":maps.get("0",{}),"sideMaps":maps,"animationSource":0,"context":animation_context,"bodyType":int(animation_context.get("fieldDE",0)),"model18":pieces.any(func(piece):return int(piece.get("partIndex",-1))==18)}
	var relay_source:=creature_animation_source(pieces,assets)
	if relay_source>0:source.animationSource=relay_source
	Timing.finish("actor_install_bindings_ms",began); began=Timing.begin()
	rigs=SkeletalRigs.new() if use_skeleton else Rigs.new(); add_child(rigs); rigs.configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})
	Timing.finish("actor_install_rigs_ms",began); began=Timing.begin()
	if not rigs.stats.failures.is_empty(): failure=str(rigs.stats.failures); holder.queue_free(); return false
	if relay_source>0 and rigs.entities.has(id):rigs.entities[id].relay_animation_source=relay_source
	for source_row in provenance:
		var part: Node3D=rigs.node_at(id,int(source_row.node))
		if is_instance_valid(part): part.set_meta("native_mesh_source",source_row.facts)
	for row in lights:
		var light:=PointLight.new(); light.set_meta("native_enhanced_light",shared_pool.native_lighting and not shared_pool.unshaded);light.set_meta("native_legacy_light",shared_pool.native_legacy_lighting); light.configure(row.data)
		if int(row.priority)!=0:light.set_meta("native_light_priority",int(row.priority))
		rigs.node_at(id,int(row.node)).add_child(light)
	for row in references:
		var reference:=ModelReference.new(); reference.name="native_reference"; reference.original_header=row.data; reference.origin_resource=str(row.origin); reference.set_meta("native_equipment_item_id",int(row.get("equipmentItemId",-1))); reference.set_meta("native_source_piece_index",int(row.get("sourcePieceIndex",-1))); rigs.node_at(id,int(row.node)).add_child(reference)
	for row in emitters:
		var emitter:=ParticleEmitter.new(); emitter.name="native_emitter"; emitter.original_properties=row.properties; emitter.channel_asset=row.asset; emitter.physical_part=int(row.part); emitter.original_texture=row.texture; emitter.clock_provider=rigs.playback_state.bind(id,int(row.model)); emitter.emitter_part_provider=rigs.emitter_properties.bind(id,int(row.model),int(row.node))
		var target: Node3D=rigs.node_at(id,int(row.node)); var source_root: Node3D=rigs.node_at(id,int(row.root))
		# Source path must be assigned before add_child invokes _ready.
		var piece_model: Dictionary=pieces[int(row.model)].bundle.value
		emitter.authored_model_name=str(piece_model.name); emitter.authored_node_name=str(piece_model.nodes[int(row.part)].name)
		emitter.origin_resource=str(pieces[int(row.model)].bundle.get("resource_name",piece_model.name))
		# Source Gob owns the primary model, including held-part emitters.
		emitter.source_model_flags=int(pieces[0].bundle.value.get("classification_flags",-1))
		for child in piece_model.nodes.size():
			if int(piece_model.nodes[child].get("parentIndex",piece_model.nodes[child].get("parent",-1)))==int(row.part) and piece_model.nodes[child].has("reference") and (not piece_model.nodes[child].has("type") or str(piece_model.nodes[child].type)=="reference"):
				var reference=rigs.node_at(id,int(models[int(row.model)].parts[child])).get_node("native_reference")
				emitter.reference_paths.append(NodePath("../"+str(target.get_path_to(reference))))
		emitter.source_path=NodePath("../"+str(target.get_path_to(source_root))); target.add_child(emitter)
		# Original MdlNodeEmitter::InternalCreateInstance 1400622aa..2c7
		# registers Detonate on this Gob only for Explosion emitters.
		if str(row.properties.get("update",""))=="Explosion":
			var emitter_model_index:=int(row.model)
			var listener:=func(_owner: Variant,event: String,target: Variant):
				if not retired and event.to_lower()=="detonate" and is_instance_valid(target): target.detonate()
			var record: Dictionary=rigs.add_model_event_listener(id,emitter_model_index,"Detonate",listener,emitter)
			emitter_listeners.append({"index":emitter_model_index,"record":record})
	for model_index in pieces.size():
		var original: Dictionary=pieces[model_index].bundle.value; var physical: Array=[]; var part_indices: Array=models[model_index].parts
		if not original.nodes.any(func(row):return row.has("reference") and (not row.has("type") or str(row.type)=="reference")): reference_graphs.append(null); continue
		for index in part_indices: physical.append(rigs.node_at(id,int(index)))
		var owner_index:=int(nodes[int(part_indices[0])].parent); var graph:=ReferenceGraph.new()
		if not graph.configure(rigs.node_at(id,owner_index),original.nodes,physical): failure=graph.failure; failed_equipment_item_id=int(pieces[model_index].get("equipmentItemId",-1)); failed_piece_source_index=int(pieces[model_index].get("sourcePieceIndex",-1)); holder.queue_free(); return false
		reference_graphs.append(graph)
	failed_piece_source_index=-1
	holder.queue_free(); installation_complete=true; Timing.finish("actor_install_helpers_ms",began); return true

var _actor_install: Dictionary={}
var installation_complete:=false
var installation_steps:=0
var installation_max_step_us:=0
static func creature_animation_source(pieces: Array,assets: Array)->int:
	if pieces.is_empty() or assets.is_empty() or not assets[0].get("clips",[]).is_empty():return 0
	# Old network binding chooses the first animated robe or tail/wing follower
	# when the invisible body itself has no clips.
	for index in range(1,mini(pieces.size(),assets.size())):
		var piece: Dictionary=pieces[index]
		if int(piece.get("partIndex",-1))!=18 and int(piece.get("nativeVisualScope",-1)) not in [252,253]:continue
		if not assets[index].get("clips",[]).is_empty():return index
	return 0
func begin_install(pieces: Array,shared_pool,id: int,maps: Dictionary,initial_animation: int=0,animation_context: Dictionary={}) -> bool:
	failed_piece_source_index=-1
	if _install_activating:failure="Actor installation cannot restart during helper activation";return false
	if rigs!=null or retired or pieces.is_empty() or not _actor_install.is_empty() or OS.get_thread_caller_id()!=OS.get_main_thread_id():failure="Native actor owner is unavailable/already used";return false
	if actor_alpha_enabled:actor_alpha=ActorAlpha.new()
	set_meta("native_light_source",true);object_id=id;pieces=admitted_pieces(pieces);renderer_alpha_primary_models=ActorAlpha.primary_model_indices(pieces)
	visual_piece_descriptors=visual_descriptors(pieces)
	var holder:=Node3D.new();add_child(holder)
	_actor_install={"pieces":pieces,"pool":shared_pool,"id":id,"maps":maps,"initial_animation":initial_animation,"animation_context":animation_context,"holder":holder,"phase":"model","model_index":0,"index":0,"nodes":[],"models":[],"assets":[],"bindings":[],"anchors":{},"lights":[],"attachments":[],"emitters":[],"references":[],"provenance":[],"current":{},"reference_models":{},"helper_lights":[],"helper_references":[],"helper_emitters":[],"helper_refs":{},"helper_listeners":[]}
	return true
func _install_model_begin(state: Dictionary) -> bool:
	var pieces: Array=state.pieces
	var nodes: Array=state.nodes
	var models: Array=state.models
	var anchors: Dictionary=state.anchors
	var attachments: Array=state.attachments
	var holder: Node3D=state.holder
	var model_index:=int(state.model_index)
	var piece: Dictionary=pieces[model_index]; var bundle: Dictionary=piece.bundle
	if actor_alpha!=null:actor_alpha.begin_model(model_index)
	var slot:=int(piece.get("equipmentSlot",0))
	if slot==0: body_model_scopes[int(piece.get("nativeVisualScope",255 if model_index==0 else -1))]=true
	if slot!=0:
		if not equipment_models.has(slot): equipment_models[slot]=[]
		equipment_models[slot].append(model_index)
		if piece.has("equipmentVisual"): equipment_visuals[slot]=piece.equipmentVisual.duplicate(true)
	if not str(bundle.get("error","")).is_empty(): failure=bundle.error; holder.free(); return false
	var model: Dictionary=bundle.value; model_names.append(model.name); model_resource_names.append(str(bundle.get("resource_name",model.name))); source_dependencies.append_array(bundle.get("animation_sources",[]))
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
	state.current={"piece":piece,"bundle":bundle,"model":model,"converted":converted,"parts":parts,"root_index":root_index,"physical_parent":physical_parent};state.index=0;return true
func _install_model_part(state: Dictionary) -> bool:
	var shared_pool=state.pool
	var id:=int(state.id)
	var nodes: Array=state.nodes
	var bindings: Array=state.bindings
	var anchors: Dictionary=state.anchors
	var lights: Array=state.lights
	var emitters: Array=state.emitters
	var references: Array=state.references
	var provenance: Array=state.provenance
	var holder: Node3D=state.holder
	var model_index:=int(state.model_index)
	var bundle: Dictionary=state.current.bundle
	var model: Dictionary=state.current.model
	var converted: Dictionary=state.current.converted
	var parts: Array=state.current.parts
	var root_index:=int(state.current.root_index)
	var physical_parent:=int(state.current.physical_parent)
	var index:=int(state.index)
	var row: Dictionary=model.nodes[index]; var original_parent:=int(row.get("parentIndex",row.get("parent",-1))); var target:=nodes.size(); parts.append(target)
	if original_parent>=index or original_parent< -1: failure="Original actor physical parent is invalid"; holder.free(); return false
	var rest: Dictionary=converted.defaults[index]
	impact_parts.append({"index":target,"parent":parts[original_parent] if original_parent>=0 else physical_parent,"name":str(row.name),"area":row.mesh.get("native_area") if str(row.get("type",""))=="trimesh" else 0.0,"model":model_index})
	if not impact_lookup.has(str(row.name).to_lower()): impact_lookup[str(row.name).to_lower()]=target
	nodes.append({"name":row.name,"parent":root_index if original_parent<0 else parts[original_parent],"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale,"visible":true})
	if model_index==0 and not anchors.has(str(row.name).to_lower()): anchors[str(row.name).to_lower()]=target
	if row.features.has("light") and not row.get("light",{}).is_empty(): lights.append({"node":target,"data":row.light,"priority":int(state.current.piece.get("nativeLightPriority",0))})
	if row.has("reference") and (not row.has("type") or str(row.type)=="reference"):state.reference_models[model_index]=true;references.append({"node":target,"data":row.reference,"origin":bundle.get("resource_name",model.name),"equipmentItemId":state.current.piece.get("equipmentItemId",-1),"sourcePieceIndex":state.current.piece.get("sourcePieceIndex",-1)})
	if row.has("emitter"):
		var emitter_raster: Dictionary=bundle.get("emitter_textures",{}).get(str(row.emitter.get("texture","")).to_lower(),{}); var texture: Texture2D=null
		if not emitter_raster.is_empty():
			texture=shared_pool.texture(emitter_raster)
			if texture==null: failure=shared_pool.failure; holder.free(); return false
		emitters.append({"node":target,"root":root_index,"part":index,"model":model_index,"properties":row.emitter,"asset":converted,"texture":texture})
	var data: Dictionary=row.mesh
	var source_facts: Dictionary=MeshProvenance.capture(bundle,row,index,model_index) if not data.is_empty() else {}
	if not source_facts.is_empty(): provenance.append({"node":target,"facts":source_facts})
	if data.is_empty() or not data.get("render",false) or data.indices.is_empty(): return true
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
	var material_options: Dictionary=shared_pool.model_material_options(row)
	var mesh:=MeshInstance3D.new(); mesh.name="actor_mesh_"+str(id)+"_"+str(bindings.size()); mesh.mesh=geometry; mesh.material_override=material; mesh.visible=material_options.visible
	mesh.set_meta("native_transparency_hint",material_options.hint)
	if actor_alpha!=null and not actor_alpha.enroll(mesh,model_index):
		failure=actor_alpha.failure;mesh.free();holder.free();return false
	# Animated meshes are children of one rig holder, unlike static Parts.
	# Keep physical source identity for per-mesh consumers such as GUI TXI.
	mesh.set_meta("native_source_part_index",index); mesh.set_meta("native_source_model_index",model_index)
	var material_owner:=material_owner_part(model,index)
	if material_owner>=0:mesh.set_meta("native_material_owner_part_index",material_owner)
	mesh.set_meta("native_mesh_source",source_facts)
	if geometry.has_meta("native_pick_shape"): mesh.set_meta("native_pick_shape",geometry.get_meta("native_pick_shape"))
	mesh.set_meta("native_pick_geometry",geometry.get_meta("native_pick_geometry"))
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh); meshes.append(mesh); registry.meshes_by_name[str(mesh.name)]=mesh
	var binding:={"name":str(mesh.name),"objectId":id,"rigNode":target,"rigLocal":{"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}}
	if row.has("skin"): binding.skin=skin_source(row,model_index,index)
	bindings.append(binding)
	return true
func _install_model_finish(state: Dictionary) -> void:
	var maps: Dictionary=state.maps
	var initial_animation:=int(state.initial_animation)
	var models: Array=state.models
	var assets: Array=state.assets
	var model_index:=int(state.model_index)
	var piece: Dictionary=state.current.piece
	var converted: Dictionary=state.current.converted
	var parts: Array=state.current.parts
	assets.append(converted)
	var requested:=str(piece.get("initial_clip",maps.get("0",{}).get(str(initial_animation),""))); var available: bool=converted.clips.any(func(clip): return clip.name==requested)
	models.append({"asset":model_index,"parts":parts,"defaults":converted.defaults,"follow":bool(piece.get("follow",true)),"clip":requested if available else "","time":0.0,"speed":1.0,"loop":true,"playing":available})

func _install_rigs_begin(state: Dictionary) -> bool:
	var pieces: Array=state.pieces
	var id:=int(state.id)
	var maps: Dictionary=state.maps
	var animation_context: Dictionary=state.animation_context
	var nodes: Array=state.nodes
	var models: Array=state.models
	var assets: Array=state.assets
	var bindings: Array=state.bindings
	var attachments: Array=state.attachments
	var source:={"id":id,"nodes":nodes,"models":models,"attachments":attachments,"clipMap":maps.get("0",{}),"sideMaps":maps,"animationSource":0,"context":animation_context,"bodyType":int(animation_context.get("fieldDE",0)),"model18":pieces.any(func(piece):return int(piece.get("partIndex",-1))==18)}
	var relay_source:=creature_animation_source(pieces,assets)
	if relay_source>0:source.animationSource=relay_source
	rigs=SkeletalRigs.new() if use_skeleton else Rigs.new();add_child(rigs)
	return rigs.begin_configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})
func _install_helper_provenance(state: Dictionary) -> bool:
	var id:=int(state.id)
	var source_row: Dictionary=state.provenance[int(state.index)]
	var part: Node3D=rigs.node_at(id,int(source_row.node))
	if is_instance_valid(part): part.set_meta("native_mesh_source",source_row.facts)
	return true
func _install_helper_light(state: Dictionary) -> bool:
	var shared_pool=state.pool
	var id:=int(state.id)
	var row: Dictionary=state.lights[int(state.index)]
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",shared_pool.native_lighting and not shared_pool.unshaded);light.set_meta("native_legacy_light",shared_pool.native_legacy_lighting); light.configure(row.data)
	if int(row.priority)!=0:light.set_meta("native_light_priority",int(row.priority))
	state.helper_lights.append({"target":rigs.node_at(id,int(row.node)),"helper":light})
	return true
func _install_helper_reference(state: Dictionary) -> bool:
	var id:=int(state.id)
	var row: Dictionary=state.references[int(state.index)]
	var reference:=ModelReference.new(); reference.name="native_reference"; reference.original_header=row.data; reference.origin_resource=str(row.origin); reference.set_meta("native_equipment_item_id",int(row.get("equipmentItemId",-1))); reference.set_meta("native_source_piece_index",int(row.get("sourcePieceIndex",-1))); var target: Node3D=rigs.node_at(id,int(row.node));state.helper_references.append({"target":target,"helper":reference});state.helper_refs[target.get_instance_id()]=reference
	return true
func _install_helper_emitter(state: Dictionary) -> bool:
	var pieces: Array=state.pieces
	var id:=int(state.id)
	var models: Array=state.models
	var emitters: Array=state.emitters
	var row: Dictionary=state.emitters[int(state.index)]
	var emitter:=ParticleEmitter.new(); emitter.name="native_emitter"; emitter.original_properties=row.properties; emitter.channel_asset=row.asset; emitter.physical_part=int(row.part); emitter.original_texture=row.texture; emitter.clock_provider=rigs.playback_state.bind(id,int(row.model)); emitter.emitter_part_provider=rigs.emitter_properties.bind(id,int(row.model),int(row.node))
	var target: Node3D=rigs.node_at(id,int(row.node)); var source_root: Node3D=rigs.node_at(id,int(row.root))
	# Source path must be assigned before add_child invokes _ready.
	var piece_model: Dictionary=pieces[int(row.model)].bundle.value
	emitter.origin_resource=str(pieces[int(row.model)].bundle.get("resource_name",piece_model.name))
	emitter.authored_model_name=str(piece_model.name); emitter.authored_node_name=str(piece_model.nodes[int(row.part)].name)
	# Source Gob owns the primary model, including held-part emitters.
	emitter.source_model_flags=int(pieces[0].bundle.value.get("classification_flags",-1))
	for child in piece_model.nodes.size():
		if int(piece_model.nodes[child].get("parentIndex",piece_model.nodes[child].get("parent",-1)))==int(row.part) and piece_model.nodes[child].has("reference") and (not piece_model.nodes[child].has("type") or str(piece_model.nodes[child].type)=="reference"):
			var reference_parent: Node3D=rigs.node_at(id,int(models[int(row.model)].parts[child]))
			emitter.reference_paths.append(NodePath("../"+str(target.get_path_to(reference_parent))+"/native_reference"))
	emitter.source_path=NodePath("../"+str(target.get_path_to(source_root))); state.helper_emitters.append({"target":target,"helper":emitter})
	# Original MdlNodeEmitter::InternalCreateInstance 1400622aa..2c7
	# registers Detonate on this Gob only for Explosion emitters.
	if str(row.properties.get("update",""))=="Explosion":
		var emitter_model_index:=int(row.model)
		var listener:=func(_owner: Variant,event: String,target: Variant):
			if not retired and event.to_lower()=="detonate" and is_instance_valid(target): target.detonate()
		state.helper_listeners.append({"index":emitter_model_index,"callback":listener,"target":emitter})
	return true
func _activate_install(state: Dictionary) -> bool:
	_install_activating=true
	var accepted:=_activate_install_helpers(state)
	_install_activating=false
	if bool(state.get("cancelled",false)):_discard_install_state(state)
	return accepted
func _activate_install_helpers(state: Dictionary) -> bool:
	for kind in ["helper_lights","helper_references","helper_emitters"]:
		for row in state[kind]:
			if retired or not is_same(_actor_install,state) or not is_instance_valid(row.target) or not is_instance_valid(row.helper):failure="Actor publication retired during helper activation";return false
			row.target.add_child(row.helper)
			if retired or not is_same(_actor_install,state):failure="Actor publication retired during helper activation";return false
	for listener in state.helper_listeners:
		var model_index:=int(listener.index)
		var record: Dictionary=rigs.add_model_event_listener(object_id,model_index,"Detonate",listener.callback,listener.target)
		emitter_listeners.append({"index":model_index,"record":record})
	return true
func install_step(maximum_units: int=8,budget_us: int=1500) -> Dictionary:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return {"status":"failed","reason":"Actor publication requires main thread","units":0}
	if _actor_install.is_empty():return {"status":"ready" if installation_complete else "failed","reason":failure,"units":0}
	var began:=Time.get_ticks_usec();var units:=0;var accepted:=true
	while not _actor_install.is_empty() and units<maxi(1,maximum_units):
		if units>0 and budget_us>0 and Time.get_ticks_usec()-began>=budget_us:break
		var state: Dictionary=_actor_install;var index:=int(state.index)
		match str(state.phase):
			"model":
				if int(state.model_index)>=state.pieces.size():state.phase="rig-begin";continue
				accepted=_install_model_begin(state);state.phase="parts"
			"parts":
				if index>=state.current.model.nodes.size():state.phase="model-finish";continue
				accepted=_install_model_part(state);state.index=index+1
			"model-finish":_install_model_finish(state);state.model_index=int(state.model_index)+1;state.index=0;state.phase="model"
			"rig-begin":accepted=_install_rigs_begin(state);state.phase="rig"
			"rig":
				var result: Dictionary=rigs.configure_step(maxi(1,maximum_units-units),maxi(1,budget_us-(Time.get_ticks_usec()-began)) if budget_us>0 else 0)
				units+=int(result.units)
				if result.status=="failed":failure=str(result.reason);accepted=false
				elif result.status=="pending":break
				elif not rigs.stats.failures.is_empty():failure=str(rigs.stats.failures);accepted=false
				else:
					var relay_source:=creature_animation_source(state.pieces,state.assets)
					if relay_source>0 and rigs.entities.has(object_id):rigs.entities[object_id].relay_animation_source=relay_source
					rigs.set_process(false);state.phase="provenance";state.index=0
				if accepted:continue
			"graphs":
				if index>=state.pieces.size():state.phase="commit";continue
				if not state.reference_models.has(index):reference_graphs.append(null);state.index=index+1;units+=1;continue
				var part_indices: Array=state.models[index].parts
				if not state.has("graph_parts"):state.graph_parts=[];state.graph_cursor=0
				if int(state.graph_cursor)<part_indices.size():state.graph_parts.append(rigs.node_at(object_id,int(part_indices[int(state.graph_cursor)])));state.graph_cursor=int(state.graph_cursor)+1;units+=1;continue
				if not state.has("graph_job"):
					var owner_index:=int(state.nodes[int(part_indices[0])].parent);var graph:=ReferenceGraph.new()
					if not graph.begin_configure(rigs.node_at(object_id,owner_index),state.pieces[index].bundle.value.nodes,state.graph_parts,state.helper_refs):failure=graph.failure;failed_equipment_item_id=int(state.pieces[index].get("equipmentItemId",-1));failed_piece_source_index=int(state.pieces[index].get("sourcePieceIndex",-1));accepted=false;cancel_install();break
					state.graph_job=graph
				var graph_progress: Dictionary=state.graph_job.configure_step(maxi(1,maximum_units-units),maxi(1,budget_us-(Time.get_ticks_usec()-began)) if budget_us>0 else 0);units+=int(graph_progress.units)
				if graph_progress.status=="pending":break
				if graph_progress.status=="failed":failure=str(graph_progress.reason);failed_equipment_item_id=int(state.pieces[index].get("equipmentItemId",-1));failed_piece_source_index=int(state.pieces[index].get("sourcePieceIndex",-1));accepted=false;cancel_install();break
				reference_graphs.append(state.graph_job);state.erase("graph_job");state.erase("graph_parts");state.erase("graph_cursor");state.index=index+1;continue
			"provenance","lights","references","emitters":
				var phase:=str(state.phase);var collection: Array=state[phase]
				if index>=collection.size():
					state.phase={"provenance":"lights","lights":"references","references":"emitters","emitters":"graphs","graphs":"commit"}[phase];state.index=0;continue
				if phase=="provenance":accepted=_install_helper_provenance(state)
				elif phase=="lights":accepted=_install_helper_light(state)
				elif phase=="references":accepted=_install_helper_reference(state)
				elif phase=="emitters":accepted=_install_helper_emitter(state)
				state.index=index+1
			"commit":
				accepted=_activate_install(state)
				if accepted:state.holder.queue_free();rigs.set_process(not rigs.idle_suspended);_actor_install={};installation_complete=true;failed_piece_source_index=-1
		units+=1
		if not accepted:
			if str(state.phase) in ["model","parts","model-finish"] and int(state.model_index)>=0 and int(state.model_index)<state.pieces.size():
				failed_equipment_item_id=int(state.pieces[int(state.model_index)].get("equipmentItemId",-1))
				failed_piece_source_index=int(state.pieces[int(state.model_index)].get("sourcePieceIndex",-1))
			cancel_install();break
	var elapsed:=Time.get_ticks_usec()-began;installation_steps+=1;installation_max_step_us=maxi(installation_max_step_us,elapsed)
	return {"status":"failed" if not accepted else "ready" if installation_complete else "pending","reason":failure,"units":units,"step_us":elapsed}
func cancel_install() -> void:
	if _actor_install.is_empty():return
	var state: Dictionary=_actor_install;_actor_install={}
	# add_child() invokes helper service callbacks synchronously. Keep its parent
	# alive until the callback unwinds, then dispose the cancelled private graph.
	if _install_activating:state.cancelled=true;return
	_discard_install_state(state)
func _discard_install_state(state: Dictionary) -> void:
	if actor_alpha!=null:actor_alpha.close();actor_alpha=null
	if state.has("graph_job"):state.graph_job.cancel_configure()
	for kind in ["helper_lights","helper_references","helper_emitters"]:
		for row in state[kind]:
			if is_instance_valid(row.helper) and row.helper.get_parent()==null:row.helper.free()
	if is_instance_valid(rigs):
		rigs.cancel_configure()
		var entry: Dictionary=rigs.entities.get(object_id,{})
		rigs.forget_entity(object_id)
		if not entry.is_empty() and is_instance_valid(entry.root):entry.root.free()
		rigs.free();rigs=null
	if is_instance_valid(state.holder):state.holder.free()
	emitter_listeners.clear();renderer_alpha_primary_models.clear();registry.meshes_by_name.clear();meshes.clear();model_names.clear();model_resource_names.clear();source_dependencies.clear();reference_graphs.clear();unattached_equipment.clear();impact_parts.clear();impact_lookup.clear();equipment_models.clear();equipment_visuals.clear();equipment_colour_scopes.clear();body_model_scopes.clear();visual_piece_descriptors.clear();visual_owner_indices.clear()
	for visual_state in model_visual_states.values():visual_state.dispose()
	model_visual_states.clear()
func _exit_tree() -> void:
	if not _actor_install.is_empty():cancel_install()

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
	cancel_install()
	if retired: return
	retired=true
	renderer_alpha_primary_models.clear()
	if actor_alpha!=null:actor_alpha.close();actor_alpha=null
	if is_instance_valid(rigs):
		for listener in emitter_listeners:rigs.remove_model_event_listener(object_id,int(listener.index),listener.record)
	emitter_listeners.clear()
	if is_instance_valid(rigs): rigs.forget_entity(object_id)
	for state in model_visual_states.values():state.dispose()
	model_visual_states.clear();visual_piece_descriptors.clear();visual_owner_indices.clear()
	registry.meshes_by_name.clear(); meshes.clear(); model_names.clear(); model_resource_names.clear(); source_dependencies.clear(); reference_graphs.clear(); unattached_equipment.clear(); impact_parts.clear(); impact_lookup.clear(); random_part_model.clear(); equipment_models.clear(); equipment_visuals.clear(); equipment_colour_scopes.clear(); body_model_scopes.clear(); queue_free()
