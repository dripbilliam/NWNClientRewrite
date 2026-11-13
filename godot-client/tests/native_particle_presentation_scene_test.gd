extends "res://tests/native_particle_presentation_test.gd"
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const SceneIndex=preload("res://systems/native_render/scene_query_index.gd")
class FloorModel extends Node3D:
	var meshes: Array=[]
	var pick_surfaces: Array=[]
func scene_services(rng: RefCounted,wind: RefCounted,events: Array,index: RefCounted) -> Dictionary:
	return {"random":rng.next,"cosineDouble":func(angle):return cos(angle),
		"collide":func(start,end,out,hit):
			# The existing native path deliberately returns vertical/zero-length
			# rays to its scene callback. Keep that boundary in both fixtures.
			var result: Variant=index.nearest(start,end)
			if result==null: return false
			out.assign(result.position); hit.normal=result.normal; return true,
		"addPointSourceWind":func(position,radius,duration,strength):
			events.append([position.duplicate(),radius,duration,strength])
			var result: Variant=wind.call("dispatch",3,{"position":position,"radius":radius,"duration":duration,"strength":strength})
			check(not result.has("error"),"Explosion adds native point wind during scene update")}
func main_scene() -> Dictionary:
	var scene:=Node3D.new(); root.add_child(scene)
	var floor_model:=FloorModel.new(); scene.add_child(floor_model)
	var geometry:=Geometry.new(); geometry.configure({"vertices":PackedFloat32Array([0,0,0,10,0,0,0,10,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	var part:=MeshInstance3D.new(); floor_model.add_child(part); part.mesh=ArrayMesh.new(); part.mesh.set_meta("native_scene_geometry",geometry); floor_model.meshes=[part]
	floor_model.set_meta("native_scene_bounds",AABB(Vector3(-10,-2,-10),Vector3(20,4,20)))
	var index:=SceneIndex.new(); index.put(floor_model)
	check(index.native_ready(),"Native scene geometry/index configures without a graphical renderer")
	var indices:=[index.native_owner.call("dispatch",5,{}),0]
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var wind: Array[RefCounted]=[]; var rngs: Array=[]; var services: Array=[[],[]]; var events: Array=[[],[]]; var owners: Array=[[],[]]
	for slot in 2:
		var manager: RefCounted=ClassDB.instantiate("NwnWindManager")
		var configured: Dictionary=manager.call("dispatch",0,{"seed":18,"wind":[0.8,-0.3,0.0],"deviation":0.15,"pitch":0.08,"timeout":0.5})
		check(not configured.has("error"),"Native ambient/point wind configures "+str(slot)); wind.append(manager)
		var rng:=Random.new(); rng.seed_value(int(configured.seed)); rngs.append(rng)
	var nodes: Array[Node3D]=[]; var capacities: Array[int]=[]
	for emitter in 6:
		var node:=Node3D.new(); scene.add_child(node); node.position=Vector3(2.0+emitter*0.15,0.1,-2.0); nodes.append(node); capacities.append(0)
		var kind: String=["fountain","explosion","single"][emitter%3]
		var seed_owner:=make_owner(false,kind,4|16|32|128,false,false)
		seed_owner.state.renderMode1a8=emitter; seed_owner.state.lifeExp=1.5; seed_owner.state.mass=1.2
		for slot in 2:
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{})
			check(not configured.has("error"),"Wind/collision typed owner configures "+str(slot)+"/"+str(emitter)); owners[slot].append(owner)
			services[slot].append(scene_services(rngs[slot],wind[slot],events[slot],index))
		var added: Dictionary=presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owners[1][emitter],"providers":services[1][emitter],"source_flags":0,"culling":true,"wind_token":wind[1].call("dispatch",6,{})})
		check(not added.has("error"),"Shared scene retains native wind token "+str(emitter)); seed_owner.providers.clear()
	var queries:=0; var hits:=0; var samples:=0; var point_frames:=0; var last: Dictionary={}
	for frame in 150:
		var delta: float=[1.0/60,0.025,0.0,-0.002,0.7][frame%5]
		var view:=view_packet(frame+3000000,false); events[0].clear(); events[1].clear()
		for slot in 2:
			var before: Dictionary=wind[slot].call("dispatch",7,{})
			var advanced: Dictionary=wind[slot].call("dispatch",1,{"delta":delta,"seed":rngs[slot].state})
			check(not advanced.has("error"),"Shared scene wind advances once before emitters "+str(frame)+"/"+str(slot))
			rngs[slot].state=int(advanced.seed); rngs[slot].draws+=int(advanced.draws)-int(before.draws)
		if frame==60:
			floor_model.position.y=-0.2; index.put(floor_model)
		part.position.y=0.02*sin(frame*0.04)
		var expected: Dictionary={}
		for emitter in 6:
			nodes[emitter].position=Vector3(2.0+emitter*0.15,0.1+0.05*sin(frame*0.03),-2.0)
			var input:={"clip":"","time":frame/60.0,"delta":delta,"view":view,"capacity":capacities[emitter],"source_flags":0,"culling":true,"profile":frame%2==0,"wind_token":wind[0].call("dispatch",6,{}),"scene_indices":indices}
			if frame%30==0:
				input.detonate=emitter%3==1
				presentation.call("dispatch",4,{"id":nodes[emitter].get_instance_id(),"detonate":input.detonate})
			var packet: Dictionary=owners[0][emitter].call("dispatch",1,input,services[0][emitter])
			check(not packet.has("error"),"Existing native direct-scene frame "+str(frame)+"/"+str(emitter)+" "+str(packet.get("error","")))
			if packet.has("error"): break
			capacities[emitter]=int(packet.get("capacity",capacities[emitter])); expected[nodes[emitter].get_instance_id()]=packet
		last=presentation.call("dispatch",1,{"delta":delta,"view":view,"scene_indices":indices,"profile":frame%2==0})
		check(not last.has("error"),"Separated native phases use direct scene wind/collision "+str(frame)+" "+str(last.get("error","")))
		if last.has("error") or expected.size()!=6: break
		var actual: Dictionary=presentation.call("dispatch",2,{})
		var seen: Dictionary={}
		for range_data: Dictionary in actual.ranges:
			var packet: Dictionary=expected[int(range_data.id)]; var begin:=int(range_data.first)*24
			check(actual.buffer.slice(begin,begin+int(range_data.count)*24)==interleave(packet),"Exact scene wind/collision geometry "+str(frame)+"/"+str(range_data.id)); seen[int(range_data.id)]=true
		for id in expected:
			if int(expected[id].get("count",0))>0: check(seen.has(id),"No scene wind/collision effect omitted "+str(frame)+"/"+str(id))
		for emitter in 6:
			var difference:=same(without_ids(owners[0][emitter].call("dispatch",2,{},{})),without_ids(owners[1][emitter].call("dispatch",2,{},{})))
			check(difference.is_empty(),"Exact state after scene wind/collision "+str(frame)+"/"+str(emitter)+" "+difference)
		for diagnostic: Dictionary in actual.emitters:
			var packet: Dictionary=expected[int(diagnostic.id)]
			check(diagnostic.direct_scene_queries==packet.direct_scene_queries and diagnostic.direct_scene_hits==packet.direct_scene_hits,"Identical native scene queries/hits "+str(frame)+"/"+str(diagnostic.id))
			queries+=int(diagnostic.direct_scene_queries); hits+=int(diagnostic.direct_scene_hits)
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"Shared noise/emitter RNG sequence remains exact "+str(frame))
		check(same(events[0],events[1]).is_empty(),"Point-wind registration order remains exact "+str(frame))
		var wind_state: Dictionary=wind[1].call("dispatch",4,{})
		check(same(wind[0].call("dispatch",4,{}),wind_state).is_empty(),"Ambient cache/points/noise/seed remain exact "+str(frame))
		if int(wind_state.points)>0: point_frames+=1
		samples+=1
		if not failures.is_empty(): break
	check(samples==150 and queries>0 and hits>0 and hits<queries and point_frames>0,"Native geometry collision hits/misses and point wind all exercised")
	presentation.call("dispatch",5,{}); presentation=null
	for slot in 2:
		for provider: Dictionary in services[slot]: provider.clear()
		wind[slot].call("dispatch",9,{})
	owners.clear(); wind.clear(); index.clear(); scene.free()
	return {"frames":samples,"queries":queries,"hits":hits,"point_wind_frames":point_frames,"last":last}
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var result:=main_scene(); await process_frame; await process_frame
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scene":result,"gpu_execution":false,"network_connections":0,"scope":"Headless native shared-frame vs existing native path: six actual typed emitters, ambient/point wind, shared RNG/noise refills, direct native geometry/index collisions, moving collision Part/root, profile on/off, exact active geometry and state. No GPU or FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
