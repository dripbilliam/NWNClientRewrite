extends SceneTree
const Census = preload("res://tools/perf140/render/static_leaf_census.gd")
var checks := 0
var failures: Array[String] = []
class World:
	extends Node3D
	var terrain
class Terrain:
	extends Node3D
	var instances: Dictionary = {}
class Placement:
	extends Node3D
	var meshes: Array = []

func _initialize() -> void:
	call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	var world := World.new(); root.add_child(world)
	var terrain := Terrain.new(); world.terrain = terrain; world.add_child(terrain)
	var mesh := ArrayMesh.new(); var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	for index in 4:
		var tile := Placement.new(); terrain.add_child(tile); terrain.instances[index] = tile
		tile.position.x = [0.0,10.0,40.0,50.0][index]
		tile.set_meta("native_model_name","fixture_tile")
		var leaf := MeshInstance3D.new(); leaf.mesh = mesh; leaf.material_override = material
		tile.add_child(leaf); tile.meshes.append(leaf)
	var first: MeshInstance3D = terrain.instances[0].meshes[0]
	var before := first.global_transform
	var initial := Census.capture(world)
	expect(initial.errors.is_empty(),"no capture errors")
	expect(initial.tiles == 4,"four tile owners")
	expect(initial.tile_mesh_leaves == 4,"four leaves")
	expect(initial.candidate_leaves == 4,"four simple candidates")
	expect(initial.exact_tuple_summary.groups == 1,"exact shared resources and states")
	expect(initial.exact_tuple_summary.instance_slots_removed_if_one_node_per_group == 3,"potential instance count only")
	expect(initial.spatial_4x4_summary.groups == 2,"40 metre cell boundary")
	expect(initial.spatial_4x4_summary.repeat_leaves == 4,"two local repeat groups")
	expect(first.visible and first.global_transform == before,"read only transform and visibility")
	expect(initial.process_tree.nodes == 10,"process tree counts physical nodes")
	first.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadows := Census.capture(world,false)
	expect(shadows.exact_tuple_summary.groups == 2,"shadow state splits tuples")
	first.visible = false
	var hidden := Census.capture(world,false)
	expect(hidden.candidate_leaves == 3,"hidden remains recorded but excluded")
	expect(hidden.tile_mesh_leaves == 4,"hidden owner not silently dropped")
	expect(hidden.reasons.get("currently_hidden",0) == 1,"hidden reason explicit")
	first.visible = true; first.scale = Vector3(1,2,1)
	var scaled := Census.capture(world,false)
	expect(scaled.reasons.get("nonconformal_transform",0) == 1,"nonuniform scale is not guessed safe")
	var serial := JSON.stringify(scaled)
	expect(JSON.parse_string(serial) is Dictionary,"detached JSON report")
	expect(not serial.contains("<Object#") and not serial.contains("<RefCounted#"),"no exposed object handles")
	world.free()
	print(JSON.stringify({"suite":"native_perf140_render_static_leaf_census_test","checks":checks,"failures":failures,"success":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
