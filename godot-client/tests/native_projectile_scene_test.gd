extends "res://tests/native_particle_schedule_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Binary=preload("res://systems/native_data/binary_model.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
const TerrainSurface=preload("res://systems/native_render/terrain_surface.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
class Terrain extends Node3D:
	var instances: Dictionary={}
	var batcher
class Model extends Node3D:
	var meshes: Array=[]
	var pick_surfaces: Array=[]
class World extends Node3D:
	var terrain
	var surface
	var instances: Dictionary={}
	var desired: Dictionary={}
func digest(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): h.update(bytes)
	return h.finish().hex_encode()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report) or not FileAccess.file_exists(args.oracle): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original binary metadata mounts read-only")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	for source in data.models:
		var bytes:=catalog.get_resource(source.name,2002); check(digest(bytes)==source.sha256,"Original model identity "+str(source.name))
		var parser:=Binary.new(); var model:=parser.parse(bytes); check(parser.failure.is_empty() and model.nodes.size()==source.nodes.size(),"Original collision-plane model parses")
		for i in model.nodes.size():
			var mesh: Dictionary=model.nodes[i].mesh; var planes: PackedFloat32Array=mesh.get("native_planes",PackedFloat32Array()); var types: PackedInt32Array=mesh.get("native_surface_types",PackedInt32Array()); var packed:=PackedByteArray(); packed.resize(types.size()*20)
			for n in types.size():
				for axis in 4: packed.encode_float(n*20+axis*4,planes[n*4+axis])
				packed.encode_u32(n*20+16,int(types[n])&0xffffffff)
			check(model.nodes[i].name==source.nodes[i].name and types.size()==source.nodes[i].faces and digest(packed)==source.nodes[i].sha256,"Exact original stored plane/material metadata "+str(source.name)+"/"+str(i))
	var vertices:=PackedFloat32Array([0,0,0,2,0,0,0,2,0]); var geometry:=Geometry.new(); geometry.configure({"vertices":vertices,"indices":PackedInt32Array([2,1,0]),"collision_indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	check(geometry.nearest([0.25,0.25,1],[0.25,0.25,-1])==[0.25,0.25,0.0],"Scene uses original collision faces rather than reversed GPU draw list")
	geometry.configure({"vertices":vertices,"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([30])})
	check(geometry.nearest([0.25,0.25,1],[0.25,0.25,-1])==null,"Native mode1 mask excludes surface30")
	geometry.configure({"vertices":vertices,"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	var world:=World.new(); root.add_child(world); world.terrain=Terrain.new(); world.add_child(world.terrain)
	var model:=Model.new(); world.add_child(model); var mesh:=MeshInstance3D.new(); model.add_child(mesh); model.meshes=[mesh]; mesh.mesh=ArrayMesh.new(); mesh.mesh.set_meta("native_scene_geometry",geometry); world.terrain.instances[0]=model
	check(Query.trace(world,[0.25,0.25,1000],[0.25,0.25,-1000]).position==[0.25,0.25,0.0],"Native static model query returns the nearest original plane")
	mesh.visible=false; check(Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).hit,"Scene collision is independent of material/visibility")
	world.terrain.instances.clear(); world.instances[10]=model; world.desired[10]={"object":{"objectType":5}}
	check(not Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).hit,"Mode1 excludes dynamic creature instances")
	world.desired[10].object={"objectType":9,"staticState":{}}; check(Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).hit,"Explicit static object membership is admitted")
	model.position.y=0.5; check(Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).position==[0.25,0.25,0.5],"Private original face uses its actual scene transform")
	var detail:=Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1],true)
	check(detail.hit and detail.position==[0.25,0.25,0.5] and detail.normal==[0.0,0.0,1.0],"Particle collision receives the original hit face normal and transformed position")
	var sloped:=Transform3D(Basis(Vector3.RIGHT,0.4).scaled(Vector3(2,3,4)),Vector3(1,2,3))
	var a:=Query.native(sloped*Vector3(0.25,1,-0.25)); var b:=Query.native(sloped*Vector3(0.25,-1,-0.25)); var mesh_detail: Dictionary=Query.mesh_hit(mesh,geometry,sloped,a,b,true)
	check(Query.engine(mesh_detail.position).distance_to(sloped*Vector3(0.25,0,-0.25))<0.00001 and Query.engine(mesh_detail.normal).distance_to((sloped.basis.inverse().transposed()*Vector3.UP).normalized())<0.00001,"Sloped and nonuniformly scaled static geometry preserves the collision plane normal")
	check(Query.tile_normal([1.0,2.0,3.0],1)==[-2.0,1.0,3.0] and Query.tile_normal([1.0,2.0,3.0],3)==[2.0,-1.0,3.0],"Quarter-turn tile normal conversion is inverse to the canonical point transform")
	var local_bounds: Dictionary=Template.scene_bounds(model); model.set_meta("native_scene_bounds",local_bounds.bounds)
	check(local_bounds.valid and Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).position==[0.25,0.25,0.5],"Template bounds preserve the actual transformed hit")
	model.position.x=50; check(not Query.trace(world,[0.25,0.25,1],[0.25,0.25,-1]).hit,"Template bounds reject distant static geometry")
	world.free(); await process_frame
	var indexed:=World.new(); root.add_child(indexed); var surface:=TerrainSurface.new(); indexed.surface=surface; surface.done=true; indexed.add_child(surface)
	surface.definition={"width":3,"height":1,"tiles":[{"model":"wide","orientation":0,"position":Vector3(5,0,-5)},{"model":"small","orientation":1,"position":Vector3(15,0,-5)},{"model":"small","orientation":0,"position":Vector3(25,0,-5)}]}; surface.table={"orderedRows":[{"Walk":"1"}]}
	var wide: Array=[[0.0,0.0,0.0],[40.0,0.0,40.0],[0.0,10.0,0.0]]; var small: Array=[[0.0,0.0,0.0],[10.0,0.0,10.0],[0.0,10.0,0.0]]
	for pair in [["wide",wide,40.0],["small",small,10.0]]:
		var plane:=Polygon.plane(pair[1]); surface.meshes[pair[0]]={"vertices":pair[1],"faces":[[0,1,2]],"materials":[0],"normals":[plane.normal],"constants":[plane.constant],"bounds_min":[0.0,0.0,0.0],"bounds_max":[pair[2],10.0,pair[2]]}
	surface.index_vertical_tiles(); check(surface.vertical_candidates([24.0,1.0,0.0]).has(0),"Index preserves an actual WOK overhang more than one tile away")
	var expected: Variant=Polygon.hit(wide,surface.meshes.wide.normals[0],surface.meshes.wide.constants[0],[24.0,1.0,1000.0],[24.0,1.0,-1000.0]); var actual:=Query.trace(indexed,[24.0,1.0,1000.0],[24.0,1.0,-1000.0])
	check(expected!=null and actual.hit and actual.position[2]==expected[2],"Indexed overhang returns the exact original polygon height")
	surface.definition.tiles[0].model="small"; surface.index_vertical_tiles(); expected=Polygon.hit(small,surface.meshes.small.normals[0],surface.meshes.small.constants[0],[3.0,6.0,1000.0],[3.0,6.0,-1000.0]); actual=Query.trace(indexed,[14.0,3.0,1000.0],[14.0,3.0,-1000.0])
	check(expected!=null and actual.hit and actual.position[2]==expected[2],"Rotated sloped WOK uses corner origin rather than visual tile center")
	surface.meshes.wide.bounds_max=[40000.0,10.0,40.0]; surface.definition.tiles[0].model="wide"; surface.index_vertical_tiles(); check(surface.vertical_global.has(0) and surface.vertical_grid.size()<100,"Huge custom bounds use a bounded global fallback instead of unbounded cell allocation")
	indexed.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(args.oracle),"scope":"Independent original MaxFace plane/material metadata, authored native scene mask/membership/transform/collision-vs-draw cases; complete original BSP/registration/streaming parity remains unaccepted"},"\t")); file.close()
	print("NATIVE_PROJECTILE_SCENE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
