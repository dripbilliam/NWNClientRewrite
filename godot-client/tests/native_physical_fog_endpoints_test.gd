extends SceneTree
const Endpoints=preload("res://tools/native_parity/visibility/physical_fog_endpoints.gd")
const Resolver=preload("res://tools/native_parity/visibility/tile_data_participants.gd")
const Reducer=preload("res://tools/native_parity/visibility/physical_tile_fog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Batches=preload("res://systems/native_render/terrain_batches.gd")
var checks:=0
var failures: Array=[]
var output:=""
var scene
var resolver
var endpoints
var fog
var terrain_assoc: Dictionary={}
var static_assoc: Dictionary={}
var scope: Array=[8,2,3]
var facts:={"current":true,"part":true}
class WorldPort extends Node3D:
	var pool:=Pool.new()
	var terrain
	var instances: Dictionary={}
	var generation:=2
	var area_id:=3
	var closed:=false
	var retiring:=false
	func close() -> void:
		closed=true
		for owner in instances.values():
			if is_instance_valid(owner):owner.retire()
		instances.clear()
		if is_instance_valid(terrain):terrain.close()
		pool.clear()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
	if not output.is_empty():trace_phase("check"+str(checks)+" "+label)
func trace_phase(value: String) -> void:
	var file:=FileAccess.open(output+".phase",FileAccess.WRITE);file.store_string(value);file.flush();file.close();print("PHYSICAL_FOG_PHASE ",value)
func _initialize() -> void:run.call_deferred()
func bundle(name_value: String="physical_fog_fixture") -> Dictionary:
	return {"sha256":name_value,"resource_name":name_value,"value":{"name":name_value,"nodes":[{"name":"surface","parent":-1,"position":[0,0,0],"orientation":[0,0,0,1],"scale":1.0,"features":[],"flags":33,"alpha":1.0,"selfillum":[0,0,0],"mesh":{"vertices":PackedFloat32Array([-.5,0,-.5,.5,0,-.5,.5,0,.5,-.5,0,.5]),"indices":PackedInt32Array([0,1,2,0,2,3]),"normals":PackedFloat32Array([0,-1,0,0,-1,0,0,-1,0,0,-1,0]),"uv":[],"textures":[],"render":true,"shadow":false,"diffuse":[1,1,1],"ambient":[0,0,0]}}]}}
func association(key: String,life: Array,part: String) -> Dictionary:
	return resolver.bind_part(key,life,part,[part,1],null,func(_context):return facts.part).get("association_lease",{})
func adopt(value: Dictionary,tile: Dictionary) -> bool:
	return value.get("available",false) and fog.adopt_endpoint(int(tile.tile_token),tile.tile_lifetime,value.key,value.lease,value.lease_current,value.publish).available
func factor(mesh: MeshInstance3D) -> float:return float(mesh.get_instance_shader_parameter(Endpoints.PARAMETER))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	trace_phase("static-factories-no-pose-owner")
	trace_phase("before-world-construction")
	trace_phase("before-resolver-construction")
	resolver=Resolver.new();check(resolver.configure({"connection":8,"generation":2,"area":3},func(_value):return facts.current,2,1,1.,10.).available,"Actual source resolver binds existing approved native BSP kernel")
	trace_phase("before-source-registration")
	var tile: Dictionary=resolver.register_canonical(0,0,1.,["terrain",1]);trace_phase("after-canonical0")
	var outside: Dictionary=resolver.register_canonical(1,0,1.,["terrain",2]);trace_phase("after-canonical1")
	var static_tile: Dictionary=resolver.register_spawn("world:33",["static",1],"static",[5.,5.,0.],func(_context):return facts.current)
	trace_phase("after-static-registration")
	scene=WorldPort.new();root.add_child(scene);scene.set_process(false);scene.pool.native_lighting=true;scene.pool.native_surface_output=true
	trace_phase("before-terrain-construction")
	scene.terrain=Terrain.new();scene.add_child(scene.terrain);scene.terrain.set_process(false)
	trace_phase("after-terrain-construction")
	check(tile.available and outside.available and static_tile.tile_token==tile.tile_token and outside.tile_token!=tile.tile_token,"Real resolver shares physical TileData for static/terrain and separates adjacent outside")
	trace_phase("before-terrain-association")
	terrain_assoc=association("terrain:0",["terrain",1],"surface");trace_phase("before-static-association")
	static_assoc=association("world:33",["static",1],"surface");trace_phase("after-static-association")
	check(not terrain_assoc.is_empty() and not static_assoc.is_empty(),"Actual resolver Part association leases are available")
	var template=scene.pool.model_template(bundle());check(template!=null and scene.pool.failure.is_empty(),"Actual native ModelTemplate prepares source mesh/material metadata")
	trace_phase("after-template-factory")
	if template==null:finish();return
	var floor_model=template.create();trace_phase("created-floor");var static_model=template.create();trace_phase("created-static");var successor=template.create();scene.terrain.add_child(floor_model);scene.add_child(static_model);scene.add_child(successor);scene.terrain.instances[0]=floor_model;scene.instances[33]=static_model
	trace_phase("before-physical-properties")
	var floor_mesh: MeshInstance3D=floor_model.meshes[0];var static_mesh: MeshInstance3D=static_model.meshes[0];var material=static_mesh.material_override;var mesh: Mesh=static_mesh.mesh;var shader: Shader=material.shader;var alpha: float=material.albedo_color.a;var shadow:=static_mesh.cast_shadow
	trace_phase("after-physical-properties")
	check(floor_model.renderer_alpha==null and static_model.renderer_alpha==null and floor_mesh.material_override==material,"Genuine pooled Placements share immutable material without alpha-owner enrollment")
	check(mesh.has_meta("native_scene_geometry") and static_mesh.has_meta("native_mesh_source"),"Genuine pooled factory retains native static geometry/mesh provenance")
	endpoints=Endpoints.new();check(endpoints.configure(scene,scope,func(value):return value==scope and facts.current,resolver.association_current).available,"Cold endpoints compose actual World scope with resolver association_current")
	fog=Reducer.new();check(fog.configure(scope,func(value):return value==scope and facts.current).available and fog.register_tile(tile.tile_token,tile.tile_lifetime).available and fog.register_tile(outside.tile_token,outside.tile_lifetime).available,"Root reducer owns the real physical tokens and separate outside state")
	trace_phase("before-mesh-endpoint-capture")
	var captured:=Endpoints.mesh_endpoint(floor_mesh);trace_phase("after-mesh-endpoint-capture-"+str(captured.size()))
	var floor_end: Dictionary=endpoints.terrain_mesh("floor",terrain_assoc,0,floor_model,floor_mesh);trace_phase("after-terrain-endpoint-bind")
	var static_end: Dictionary=endpoints.static_world_mesh("static",static_assoc,33,static_model,static_mesh);trace_phase("after-static-endpoint-bind")
	check(adopt(floor_end,tile) and adopt(static_end,tile),"Real terrain/static physical endpoints adopt constructor default1")
	check(factor(floor_mesh)==1. and factor(static_mesh)==1.,"Actual instance uniforms receive default1 without shared material writes")
	check(fog.receive_fog(tile.tile_token,tile.tile_lifetime,true).available and factor(static_mesh)==1.,"Incomplete participant certificate retains default1 even after physical fog true")
	check(fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,true).available and factor(floor_mesh)==0. and factor(static_mesh)==0.,"One physical TileData fogs actual terrain and static Placement together")
	fog.receive_fog(tile.tile_token,tile.tile_lifetime,false);fog.advance_collected([tile.tile_token],.125)
	check(factor(floor_mesh)==.5 and factor(static_mesh)==.5 and fog.tile_view(outside.tile_token,outside.tile_lifetime).factor==1.,"Composed original f32 reducer ramps both physical endpoints while adjacent outside stays1")
	var detached: Dictionary=static_end.lease.duplicate(true);detached.association.part_serial=-1
	check(not endpoints.publish(.9,detached) and endpoints.lease_current(static_end.lease),"Malformed detached consumer lease cannot corrupt the current endpoint")
	check(static_mesh.mesh==mesh and static_mesh.material_override==material and material.shader==shader and material.albedo_color.a==alpha and static_mesh.cast_shadow==shadow and static_model.renderer_alpha==null,"Uniform publication preserves exact mesh/material/shader/alpha/shadow ownership")
	var swapped:=StandardMaterial3D.new();static_mesh.material_override=swapped
	check(not endpoints.publish(.7,static_end.lease) and factor(static_mesh)==.5,"Material replacement rejects the old endpoint before any write")
	static_mesh.material_override=material
	check(not endpoints.lease_current(static_end.lease),"Restoring original material cannot revive an observed stale lease")
	check(endpoints.retire(static_end.key,static_end.lease),"Cold retirement releases stale endpoint key")
	var replaced: Dictionary=endpoints.static_world_mesh("replaced",static_assoc,33,static_model,static_mesh);scene.instances[33]=successor
	check(not endpoints.publish(.6,replaced.lease) and factor(static_mesh)==.5,"Same numeric World ID successor rejects the old physical instance")
	scene.instances[33]=static_model
	check(not endpoints.lease_current(replaced.lease),"Restoring previous World ID owner does not revive old generation")
	var mesh_end: Dictionary=endpoints.static_world_mesh("mesh-swap",static_assoc,33,static_model,static_mesh);var alternate=scene.pool.model_template(bundle("physical_fog_alternate")).create();scene.add_child(alternate);static_mesh.mesh=alternate.meshes[0].mesh
	check(not endpoints.publish(.8,mesh_end.lease),"Replacement Mesh resource rejects publication on the old endpoint")
	static_mesh.mesh=mesh
	var shader_end: Dictionary=endpoints.static_world_mesh("shader-swap",static_assoc,33,static_model,static_mesh);material.shader=Shader.new()
	check(not endpoints.publish(.8,shader_end.lease),"Shader replacement within same material rejects old endpoint")
	material.shader=shader
	var unsupported: Dictionary=endpoints.static_world_mesh("wrong-membership",static_assoc,34,static_model,static_mesh)
	check(not unsupported.available and unsupported.default_factor==1.,"Unowned physical instance is explicitly unsupported without guessed fallback")
	static_mesh.material_override=swapped;check(not endpoints.static_world_mesh("unsupported-material",static_assoc,33,static_model,static_mesh).available,"Ordinary non-native material is explicitly unsupported");static_mesh.material_override=material
	var terrain_end: Dictionary=endpoints.terrain_mesh("terrain-replaced",terrain_assoc,0,floor_model,floor_mesh);var previous_terrain=scene.terrain;scene.terrain=Terrain.new();scene.add_child(scene.terrain);scene.terrain.set_process(false)
	check(not endpoints.publish(.2,terrain_end.lease),"Replacing actual terrain owner invalidates its prior physical endpoints")
	scene.terrain.free();scene.terrain=previous_terrain
	var part_end: Dictionary=endpoints.static_world_mesh("part-retired",static_assoc,33,static_model,static_mesh)
	check(resolver.retire_part("world:33",["static",1],"surface",["surface",1]) and not endpoints.publish(.1,part_end.lease),"Actual resolver Part retirement rejects old association before write")
	static_assoc=association("world:33",["static",1],"surface")
	var fresh: Dictionary=endpoints.static_world_mesh("fresh",static_assoc,33,static_model,static_mesh)
	check(fresh.available and endpoints.publish(.4,fresh.lease) and factor(static_mesh)==.4,"Fresh resolver Part lifetime permits cold re-adoption on existing current model")
	var batcher:=Batches.new();scene.terrain.add_child(batcher);scene.terrain.batcher=batcher
	var prepared: Dictionary=batcher.prepare(bundle(),scene.pool,[{"index":0,"position":Vector3.ZERO,"rotation_y":0.,"model":"physical_fog_fixture"},{"index":1,"position":Vector3(2,0,0),"rotation_y":0.,"model":"physical_fog_fixture"}])
	for group in prepared.get("groups",[]):batcher.publish(group)
	check(batcher.owners.size()==1 and batcher.owners[0] is MultiMeshInstance3D,"Actual existing terrain factory publishes a genuine two-slot MultiMesh")
	var batch_end: Dictionary=endpoints.terrain_batch("batch",terrain_assoc,0,batcher)
	check(batch_end.available and endpoints.publish(.25,batch_end.lease) and batcher.tile_fog_factors=={0:.25},"Guarded existing batch callback targets only requested tile in CPU owner; GPU slot pixels are a separate gate")
	var geometry: MultiMeshInstance3D=batcher.owners[0];geometry.material_override=swapped
	check(not endpoints.publish(.75,batch_end.lease) and batcher.tile_fog_factors=={0:.25},"Batch material swap rejects before retained factors or slot callbacks change")
	geometry.material_override=material
	check(not endpoints.lease_current(batch_end.lease),"Restoring batch material cannot revive stale lease")
	var slot_end: Dictionary=endpoints.terrain_batch("slot",terrain_assoc,0,batcher);var transform:=geometry.multimesh.get_instance_transform(0);geometry.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(99,0,0)))
	if DisplayServer.get_name()=="headless":
		check(geometry.multimesh.get_instance_transform(0)==Transform3D.IDENTITY,"Headless Dummy renderer exposes no actual MultiMesh transform readback; strict reuse check belongs GPU fixture")
	else:check(not endpoints.publish(.8,slot_end.lease) and batcher.tile_fog_factors=={0:.25},"Reused same-MultiMesh slot transform rejects old physical slot")
	geometry.multimesh.set_instance_transform(0,transform)
	var members_end: Dictionary=endpoints.terrain_batch("members",terrain_assoc,0,batcher);batcher._bind_tile_fog(0,geometry,1)
	check(not endpoints.publish(.9,members_end.lease),"Newly published batch membership requires fresh cold binding and completeness certificate")
	batcher.tile_fog_targets[0].pop_back()
	var closed_end: Dictionary=endpoints.terrain_batch("closed",terrain_assoc,0,batcher);batcher.close()
	check(not endpoints.publish(.5,closed_end.lease),"Existing batch retirement invalidates all old physical endpoints")
	var scope_end: Dictionary=endpoints.static_world_mesh("scope",static_assoc,33,static_model,static_mesh);scene.generation=3
	check(not endpoints.publish(.1,scope_end.lease),"Actual World generation mutation rejects prior bound endpoint scope")
	scene.generation=2;check(not endpoints.lease_current(scope_end.lease),"Restoring World generation cannot revive stale endpoint scope")
	var last: Dictionary=endpoints.static_world_mesh("close",static_assoc,33,static_model,static_mesh);endpoints.close()
	check(not endpoints.publish(.8,last.lease),"Closing endpoint adapter fences delayed reducer publication")
	finish()
func finish() -> void:
	if fog!=null:fog.close()
	if endpoints!=null:endpoints.close()
	if resolver!=null:resolver.close()
	if is_instance_valid(scene):scene.close();scene.free()
	fog=null;endpoints=null;resolver=null;scene=null
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"serverConnections":0,"gpu":false,"nativeBuilds":0,"scope":"Explicit World ownership port, actual AreaStream, genuine pooled static Placement and terrain batch factories, actual TileData resolver leases and physical reducer. Authored model source and source-guard fixture ports. Headless uniform/retained batch state and retirement only; no full opened World/GPU slot/pixel or LOS/normal-launch activation claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("PHYSICAL_FOG_ENDPOINTS ",checks," checks ",failures.size()," failures");quit(0 if result.success else 1)
