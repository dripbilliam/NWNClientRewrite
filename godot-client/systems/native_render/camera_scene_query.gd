extends RefCounted

# Scene::HitCheck for the camera uses WOK faces and static tile models. Dynamic
# objects and the separate world static-object index are not camera occluders.
const TileSurface = preload("res://systems/native_data/tile_surface.gd")
const ProjectileScene = preload("res://systems/native_render/projectile_scene.gd")

static func blocked(world: Object, start: Array, finish: Array) -> bool:
	if not is_instance_valid(world) or start.size() != 3 or finish.size() != 3:
		return false
	var surface = world.get("surface")
	if is_instance_valid(surface) and surface.ready():
		for index in surface.definition.tiles.size():
			var origin: Vector2 = surface.tile_origin(index)
			var tile: Dictionary = surface.definition.tiles[index]
			if not surface.meshes.has(tile.model):
				continue
			var orientation := int(tile.orientation)
			var a: Array = TileSurface.canonical([TileSurface.f(float(start[0]) - origin.x), TileSurface.f(float(start[1]) - origin.y)], orientation)
			var b: Array = TileSurface.canonical([TileSurface.f(float(finish[0]) - origin.x), TileSurface.f(float(finish[1]) - origin.y)], orientation)
			a.append(TileSurface.f(float(start[2]) - float(tile.position.y)))
			b.append(TileSurface.f(float(finish[2]) - float(tile.position.y)))
			# SceneGeometry excludes material/surface type 30 and uses the stored
			# native face planes rather than visible render triangles.
			if surface.collision_geometry(str(tile.model)).nearest(a, b) != null:
				return true
	var terrain = world.get("terrain")
	if not is_instance_valid(terrain):
		return false
	var index = terrain.get("collision_index")
	if index != null and index.native_ready():
		return index.nearest(start, finish) != null
	var candidates: Array = terrain.collision_candidates(ProjectileScene.engine(start), ProjectileScene.engine(finish)) if terrain.has_method("collision_candidates") else terrain.instances.values()
	for instance in candidates:
		if is_instance_valid(instance) and ProjectileScene.model_hit(instance, start, finish) != null:
			return true
	return false
