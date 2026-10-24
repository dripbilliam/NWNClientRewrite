extends Node3D
# Assemble original native model data into the existing Godot rig/skin owner.
# The adapter itself performs no JS export, GLB import or asset transfer.
const Rigs=preload("res://systems/model_rigs.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
var failure:=""
var rigs
var object_id:=-1
var meshes: Array=[]
var model_names: Array=[]
var source_dependencies: Array=[]
var registry: Dictionary={"meshes_by_name":{}}
var retired:=false
func vector(values: PackedFloat32Array,index: int) -> Vector3:
	return Vector3(values[index*3],values[index*3+2],-values[index*3+1])
func skin_source(row: Dictionary,model_index: int,part_index: int) -> Dictionary:
	var source: Dictionary=row.skin; var data: Dictionary=row.mesh; var indices: PackedInt32Array=data.indices
	var positions: Array=[]; var normals: Array=[]; var uv: Array=[]; var weights: Array=[]; var bones: Array=[]
	var authored: PackedFloat32Array=data.normals; var texcoords: PackedFloat32Array=data.uv[0] if not data.uv.is_empty() else PackedFloat32Array()
	for face in range(0,indices.size(),3):
		var a:=vector(data.vertices,int(indices[face])); var b:=vector(data.vertices,int(indices[face+1])); var c:=vector(data.vertices,int(indices[face+2])); var normal:=(b-a).cross(c-a).normalized()
		for corner in [0,2,1]:
			var index:=int(indices[face+corner]); var p:=vector(data.vertices,index); var n:=vector(authored,index) if not authored.is_empty() else normal
			positions.append_array([p.x,p.y,p.z]); normals.append_array([n.x,n.y,n.z])
			uv.append_array([texcoords[index*2],texcoords[index*2+1]] if not texcoords.is_empty() else [0.0,0.0])
			for component in 4: weights.append(source.weights[index*4+component]); bones.append(source.boneIndices[index*4+component])
	return {"model":model_index,"part":part_index,"position":positions,"normal":normals,"uv":uv,"weights":weights,"bones":bones,"slots":Array(source.boneConstantSlots),"inversePositions":source.tboneRefInv,"inverseQuaternions":source.qboneRefInv,"groups":[]}
func asset(model: Dictionary) -> Dictionary:
	return model.get("rig_asset",{})
func install(pieces: Array,shared_pool,id: int,maps: Dictionary,initial_animation: int=0) -> bool:
	if rigs!=null or retired or pieces.is_empty(): failure="Native actor owner is unavailable/already used"; return false
	object_id=id
	var nodes: Array=[]; var models: Array=[]; var assets: Array=[]; var bindings: Array=[]; var anchors: Dictionary={}; var lights: Array=[]; var attachments: Array=[]
	var holder:=Node3D.new(); add_child(holder)
	for model_index in pieces.size():
		var piece: Dictionary=pieces[model_index]; var bundle: Dictionary=piece.bundle
		if not str(bundle.get("error","")).is_empty(): failure=bundle.error; holder.free(); return false
		var model: Dictionary=bundle.value; model_names.append(model.name); source_dependencies.append_array(bundle.get("animation_sources",[]))
		var anchor_name:=str(piece.get("anchor","")).to_lower(); var parent:=-1
		if model_index>0:
			if anchor_name.is_empty(): parent=0
			elif not anchors.has(anchor_name): failure="Original actor attachment anchor is absent: "+anchor_name; holder.free(); return false
			else: parent=int(anchors[anchor_name])
		var root_index:=nodes.size(); var scale_value:=float(piece.get("scale",1.0))
		if str(piece.get("attachment",""))=="pq":
			attachments.append({"node":root_index,"anchor":parent,"scale":[scale_value,scale_value,scale_value]}); parent=-1
		nodes.append({"name":str(model.name)+"_owner","parent":parent,"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[scale_value,scale_value,scale_value]})
		var converted:=asset(model); var parts: Array=[]
		if converted.is_empty(): failure="Native worker rig preparation is absent"; holder.free(); return false
		for index in model.nodes.size():
			var row: Dictionary=model.nodes[index]; var original_parent:=int(row.parent); var target:=nodes.size(); parts.append(target)
			if original_parent>=index or original_parent< -1: failure="Original actor physical parent is invalid"; holder.free(); return false
			var rest: Dictionary=converted.defaults[index]
			nodes.append({"name":row.name,"parent":root_index if original_parent<0 else parts[original_parent],"position":rest.position,"quaternion":rest.quaternion,"scale":rest.scale,"visible":true})
			if model_index==0 and not anchors.has(str(row.name).to_lower()): anchors[str(row.name).to_lower()]=target
			if row.features.has("light") and not row.get("light",{}).is_empty(): lights.append({"node":target,"data":row.light})
			var data: Dictionary=row.mesh
			if data.is_empty() or not data.get("render",false) or data.indices.is_empty(): continue
			if row.features.has("skin") and not row.has("skin"): failure="Original ASCII skin data requires native decoding: "+str(model.name); holder.free(); return false
			var geometry=shared_pool.geometry(bundle.sha256,index,data)
			if geometry==null: failure=shared_pool.failure; holder.free(); return false
			var raster: Dictionary={}
			if not data.textures.is_empty() and str(data.textures[0]).to_lower() not in ["","null"]:
				var texture_name:=str(data.textures[0]).to_lower()
				if not bundle.get("textures",{}).has(texture_name): failure="Original actor texture is not prepared: "+texture_name; holder.free(); return false
				raster=bundle.textures[texture_name]
			var material=shared_pool.material(row,raster)
			if material==null: failure=shared_pool.failure; holder.free(); return false
			var mesh:=MeshInstance3D.new(); mesh.name="actor_mesh_"+str(id)+"_"+str(bindings.size()); mesh.mesh=geometry; mesh.material_override=material; mesh.visible=float(row.get("alpha",1))>0
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mesh); meshes.append(mesh); registry.meshes_by_name[str(mesh.name)]=mesh
			var binding:={"name":str(mesh.name),"objectId":id,"rigNode":target,"rigLocal":{"position":[0.0,0.0,0.0],"quaternion":[0.0,0.0,0.0,1.0],"scale":[1.0,1.0,1.0]}}
			if row.has("skin"): binding.skin=skin_source(row,model_index,index)
			bindings.append(binding)
		assets.append(converted)
		var requested:=str(piece.get("initial_clip",maps.get("0",{}).get(str(initial_animation),""))); var available: bool=converted.clips.any(func(clip): return clip.name==requested)
		models.append({"asset":model_index,"parts":parts,"defaults":converted.defaults,"follow":bool(piece.get("follow",true)),"clip":requested if available else "","time":0.0,"speed":1.0,"loop":true,"playing":available})
	var source:={"id":id,"nodes":nodes,"models":models,"attachments":attachments,"clipMap":maps.get("0",{}),"sideMaps":maps,"animationSource":0}
	rigs=Rigs.new(); add_child(rigs); rigs.configure(registry,{id:self},{"rigs":{"version":1,"assets":assets,"entities":[source]},"meshes":bindings})
	if not rigs.stats.failures.is_empty(): failure=str(rigs.stats.failures); holder.queue_free(); return false
	for row in lights:
		var light:=PointLight.new(); light.configure(row.data); rigs.entities[id].nodes[int(row.node)].add_child(light)
	holder.queue_free(); return true
func set_animation(code: int,speed: float=1.0,loop: Variant=null) -> void:
	if is_instance_valid(rigs): rigs.set_playback(object_id,code,speed,loop)
func snapshot() -> Dictionary:
	return {"models":model_names.duplicate(),"meshes":meshes.size(),"rigs":rigs.stats.duplicate(true) if is_instance_valid(rigs) else {},"failure":failure}
func retire() -> void:
	if retired: return
	retired=true
	if is_instance_valid(rigs): rigs.forget_entity(object_id)
	registry.meshes_by_name.clear(); meshes.clear(); model_names.clear(); source_dependencies.clear(); queue_free()
