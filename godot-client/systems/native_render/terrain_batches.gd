extends Node3D
# Native terrain instancing: original geometry/materials, 4x4-tile cull groups.
# Blended surfaces keep separate instances for depth sorting.
const Template=preload("res://systems/native_render/model_template.gd")
var failure:=""
var sources: Dictionary={}
var owners: Array=[]
var chunk_tiles:=4
func prepare(bundle: Dictionary, pool, tiles: Array) -> Dictionary:
	failure=""
	var identity:=Template.identity(bundle,pool)
	if not sources.has(identity):
		var template:=Template.new()
		if not template.build(bundle,pool): failure=template.failure; return {}
		for feature in template.limitations:
			if feature in ["skin","animated-mesh","dangly","reference","emitter"]: failure="Terrain behavior requires native dynamic owner: "+str(feature); return {}
		var prototype=template.create(); add_child(prototype)
		for light in prototype.find_children("*","OmniLight3D",true,false):
			if light.visible:
				prototype.retire(); failure="Experimental mesh-only batching cannot replace active model lights; use the normal terrain owner"; return {}
		var surfaces: Array=[]
		for geometry in prototype.meshes:
			if not geometry.visible: continue
			var material=geometry.material_override
			var blended: bool=material is BaseMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA
			surfaces.append({"mesh":geometry.mesh,"material":material,"transform":global_transform.affine_inverse()*geometry.global_transform,"shadow":geometry.cast_shadow,"blended":blended})
		prototype.retire()
		sources[identity]={"surfaces":surfaces,"limitations":template.limitations.duplicate()}
	var source: Dictionary=sources[identity]; var groups: Dictionary={}; var records: Dictionary={}
	for tile in tiles:
		var position: Vector3=tile.position; var pose:=Transform3D(Basis(Vector3.UP,float(tile.rotation_y)),position)
		records[int(tile.index)]={"position":position,"rotation_y":tile.rotation_y,"model":tile.model,"index":tile.index}
		var chunk:=Vector2i(floori(position.x/(chunk_tiles*10.0)),floori(-position.z/(chunk_tiles*10.0)))
		for index in source.surfaces.size():
			var surface: Dictionary=source.surfaces[index]
			var key:=str(index)+":"+str(chunk.x)+":"+str(chunk.y)
			if surface.blended: key+=":"+str(tile.index)
			if not groups.has(key): groups[key]={"surface":surface,"transforms":[],"bounds":AABB(),"has_bounds":false}
			var group: Dictionary=groups[key]; var transform: Transform3D=pose*surface.transform
			group.transforms.append(transform)
			var bounds: AABB=transform*surface.mesh.get_aabb()
			group.bounds=group.bounds.merge(bounds) if group.has_bounds else bounds; group.has_bounds=true
	return {"groups":groups.values(),"records":records,"limitations":source.limitations,"source_surfaces":source.surfaces.size()}
func publish(group: Dictionary) -> void:
	var surface: Dictionary=group.surface
	if surface.blended:
		var geometry:=MeshInstance3D.new(); geometry.mesh=surface.mesh; geometry.material_override=surface.material; geometry.cast_shadow=surface.shadow; geometry.transform=group.transforms[0]; add_child(geometry); owners.append(geometry)
	else:
		var data:=MultiMesh.new(); data.transform_format=MultiMesh.TRANSFORM_3D; data.mesh=surface.mesh; data.instance_count=group.transforms.size(); data.custom_aabb=group.bounds
		for index in group.transforms.size(): data.set_instance_transform(index,group.transforms[index])
		var geometry:=MultiMeshInstance3D.new(); geometry.multimesh=data; geometry.material_override=surface.material; geometry.cast_shadow=surface.shadow; add_child(geometry); owners.append(geometry)
func retire_scope() -> void:
	for owner in owners:
		if is_instance_valid(owner): owner.queue_free()
	owners.clear()
func close() -> void:
	retire_scope(); sources.clear()
