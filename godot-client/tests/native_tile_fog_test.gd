extends SceneTree
# Actual AreaStream tile ownership + pooled native materials. No server,
# renderer-method change, model-alpha change, native build or FPS claim.
const Fog=preload("res://systems/native_render/native_tile_fog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Batches=preload("res://systems/native_render/terrain_batches.gd")
var checks:=0
var failures: Array=[]
var output:=""
class World extends Node3D:
	var terrain
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func close(a: float,b: float) -> bool:return absf(a-b)<0.000001
func bits(value: float) -> int:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);return bytes.decode_u32(0)
func bundle(alpha: float=0.6) -> Dictionary:
	return {"sha256":"native-tile-fog-physical-fixture-v1-alpha-"+str(alpha),"resource_name":"fog_fixture","value":{"name":"fog_fixture","nodes":[{"name":"surface","parent":-1,"position":[0,0,0],"orientation":[0,0,0,1],"scale":1.0,"features":[],"flags":33,"alpha":alpha,"selfillum":[0,0,0],"mesh":{"vertices":PackedFloat32Array([0,0,0,1,0,0,0,1,0]),"indices":PackedInt32Array([0,1,2]),"normals":PackedFloat32Array(),"uv":[],"textures":[],"render":true,"shadow":false,"diffuse":[0.2,0.4,0.6],"ambient":[0.2,0.4,0.6]}}]}}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var raw: Array=[0.8,0.4,0.2,0.0,12.0,80.0,0.0,0.0]
	var result:=Fog.packet(raw,1.0)
	check(result.available and not result.forced and result.packet==raw,"Factor1 preserves disabled original scene fog packet exactly")
	result.packet[0]=0
	check(raw[0]==0.8,"Unmodified packet view is detached")
	result=Fog.packet(raw,0)
	check(result.available and result.forced and result.packet.slice(0,4)==[0.0,0.0,0.0,0.0] and close(result.packet[5],0.1) and result.packet[7]==3.0,"Unexplored tile forces near-black fog even if ordinary scene fog is disabled")
	result=Fog.packet(raw,0.5)
	check([bits(result.packet[0]),bits(result.packet[1]),bits(result.packet[2]),bits(result.packet[4]),bits(result.packet[5])]==[0x3e4ccccd,0x3dcccccd,0x3d4ccccd,0x40c00000,0x42206666],"Half-factor raw RGB/range words retain exact f32 values, including 40.1f far offset")
	check(not Fog.packet(raw,NAN).forced and not Fog.packet(raw,2.0).forced,"Native ordered factor comparison skips NaN and values >=1")
	check(Fog.packet(raw,-0.5).forced,"Native ordered comparison does not invent a lower-factor clamp")
	check(not Fog.packet([],0).available,"Unknown base scene fog is explicit")
	var world:=World.new();root.add_child(world);world.terrain=Terrain.new();world.add_child(world.terrain);world.terrain.set_process(false)
	var facts:={"current":true}
	var scope: Array=[4,3,7];var guard:=func(value):return value==scope and facts.current
	var ctor:=Fog.new()
	check(ctor.configure(world,scope,2,"constructor",1,guard).available and ctor.snapshot().factors==PackedFloat32Array([1,1]) and ctor.snapshot().fogged==PackedByteArray([0,0]),"Actual native TileData constructor starts factor1/unfogged")
	ctor.close()
	var fog:=Fog.new();check(fog.configure(world,scope,2,"post-area-loader",1,guard).available,"Explicit native post-loader stage configures")
	check(fog.snapshot().factors==PackedFloat32Array([0,0]) and fog.snapshot().fogged==PackedByteArray([1,1]),"Known flags&3 post-loader zero tile map applies initial fog reset")
	var outside:=Fog.new();outside.configure(world,scope,1,"post-area-loader",0,guard)
	check(outside.snapshot().factors==PackedFloat32Array([1]),"Flags&3 zero preserves constructor fog without guessing room visibility");outside.close()
	check(fog.receive({"tile_index":0,"fogged":false}),"Fresh reveal can be retained before tile visual publication")
	check(fog.advance_collected([],0.1).changed==0 and fog.snapshot().factors[0]==0,"Uncollected revealed tiles do not ramp in another room")
	check(fog.advance_collected([0],0.1).changed==1 and close(fog.snapshot().factors[0],0.4) and fog.snapshot().factors[1]==0,"Only supplied collected/unfogged tile advances by native DeltaT*4")
	var pool:=Pool.new();pool.native_lighting=true;pool.native_surface_output=true
	var template=pool.model_template(bundle());check(template!=null and pool.failure.is_empty(),"Actual native pooled model prepares without scene geometry replacement")
	if template==null:quit(1);return
	var first=template.create();var second=template.create();world.terrain.add_child(first);world.terrain.add_child(second);world.terrain.instances[0]=first;world.terrain.instances[1]=second
	var base=first.meshes[0].material_override;var alpha: float=base.albedo_color.a;var shadows: int=first.meshes[0].cast_shadow;var mesh=first.meshes[0].mesh
	check(base==second.meshes[0].material_override and base.get_meta("native_surface_output",false),"Both physical tile visuals genuinely share the native-gamma material")
	check(fog.model_ready(0,first).available and fog.model_ready(1,second).available,"Actual AreaStream model boundary publishes current factor to native shader instances")
	check(close(float(first.meshes[0].get_instance_shader_parameter(Fog.PARAMETER)),0.4) and float(second.meshes[0].get_instance_shader_parameter(Fog.PARAMETER))==0,"Separate tile factors are published without duplicating shared materials")
	check(first.meshes[0].material_override==base and second.meshes[0].material_override==base and base.albedo_color.a==alpha and first.meshes[0].cast_shadow==shadows and first.meshes[0].mesh==mesh,"Fog publication preserves Part opacity, authored shadows, immutable material and geometry")
	check(fog.receive({"tile_index":0,"fogged":true}) and fog.snapshot().factors[0]==0 and float(first.meshes[0].get_instance_shader_parameter(Fog.PARAMETER))==0,"Native true fog setter resets the visible tile factor immediately")
	check(fog.advance_collected([0],0.2).changed==0,"Fogged tile does not ramp despite being collected")
	fog.receive({"tile_index":0,"fogged":false});fog.advance_collected([0,0],0.1)
	check(close(fog.snapshot().factors[0],0.8),"Repeated native collection calls retain original update multiplicity")
	fog.advance_collected([0],1)
	check(fog.snapshot().factors[0]==1,"Native ramp upper-clamps at1")
	var writes: int=fog.stats.mesh_writes;fog.advance_collected([0],0.1)
	check(fog.stats.mesh_writes==writes,"Settled tile performs no redundant instance-uniform update")
	var before: PackedFloat32Array=fog.snapshot().factors
	check(not fog.advance_collected([0,2],0.1).available and fog.snapshot().factors==before,"Malformed collection list cannot partially mutate earlier tiles")
	var saved:=fog.snapshot();saved.factors[0]=0;saved.scope[0]=99
	check(fog.snapshot().factors[0]==1 and fog.snapshot().scope[0]==4,"Cold snapshots cannot mutate live factors or scope")
	var replacement=template.create();world.terrain.add_child(replacement);world.terrain.instances[0]=replacement
	check(not fog.receive({"tile_index":0,"fogged":true}),"Old physical tile reference cannot publish onto replacement lifetime")
	check(fog.model_ready(0,replacement).available and float(replacement.meshes[0].get_instance_shader_parameter(Fog.PARAMETER))==0,"Actual replacement boundary receives retained current factor")
	var batcher:=Batches.new();world.terrain.add_child(batcher)
	var batch_fog:=Fog.new();check(batch_fog.configure(world,scope,2,"post-area-loader",1,guard,batcher.set_native_tile_fog).available and batcher.tile_fog_factors=={0:0.0,1:0.0},"Native batched owner retains initial loader factors before groups publish")
	var tiles: Array=[{"index":0,"position":Vector3.ZERO,"rotation_y":0.0,"model":"fog_fixture"},{"index":1,"position":Vector3(10,0,0),"rotation_y":0.0,"model":"fog_fixture"}]
	var prepared: Dictionary=batcher.prepare(bundle(1.0),pool,tiles)
	check(not prepared.is_empty() and prepared.groups.size()==1 and prepared.groups[0].tile_ids==[0,1],"Actual terrain batching retains per-instance native tile IDs")
	for group in prepared.get("groups",[]):batcher.publish(group)
	check(batcher.owners.size()==1 and batcher.owners[0] is MultiMeshInstance3D and batcher.owners[0].multimesh.use_custom_data,"Actual opaque terrain group uses existing MultiMesh with native fog custom data")
	if batcher.owners.size()==1:
		var data: MultiMesh=batcher.owners[0].multimesh
		print("NATIVE_TILE_FOG_BATCH_INITIAL ",data.get_instance_custom_data(0)," / ",data.get_instance_custom_data(1)," DisplayServer=",DisplayServer.get_name())
		# Exact pinned engine Dummy MeshStorage getter returns Color() always:
		# servers/rendering/dummy/storage/mesh_storage.h:205. Real slot reads and
		# pixels are asserted separately in native_tile_fog_pixels_test.gd.
		if DisplayServer.get_name()=="headless":check(data.get_instance_custom_data(0)==Color(),"Dummy renderer custom-data readback is explicitly unsupported")
		else:check(data.get_instance_custom_data(0)==Color(0,1,0,0) and data.get_instance_custom_data(1)==Color(0,1,0,0),"Post-loader batch factors are present on both actual GPU-instance slots")
		batch_fog.receive({"tile_index":0,"fogged":false});batch_fog.advance_collected([0],0.125)
		print("NATIVE_TILE_FOG_BATCH_UPDATED ",data.get_instance_custom_data(0)," / ",data.get_instance_custom_data(1)," retained=",batcher.tile_fog_factors)
		if DisplayServer.get_name()=="headless":check(batcher.tile_fog_factors=={0:0.5,1:0.0},"Actual CPU batch owner retains per-tile updates; GPU slot isolation requires pixels gate")
		else:check(data.get_instance_custom_data(0)==Color(0.5,1,0,0) and data.get_instance_custom_data(1)==Color(0,1,0,0),"One collected revealed tile updates only its own batch custom-data slot")
	check(batcher.owners[0].material_override==prepared.groups[0].surface.material,"Batched fog keeps its immutable native material shared")
	batch_fog.close();batcher.close()
	facts.current=false
	check(not fog.receive({"tile_index":0,"fogged":false}),"Connection/area scope retirement blocks publication")
	fog.close();check(not fog.receive({"tile_index":0,"fogged":true}),"Closed helper cannot resurrect tile state")
	world.terrain.instances.clear();first.retire();second.retire();replacement.retire();pool.clear();world.terrain.closed=true;world.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Recovered raw native fog math and actual AreaStream/pooled native-material instance publication; no GPU, server, native build or FPS claim","stats":fog.stats}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NATIVE_TILE_FOG ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
