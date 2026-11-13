extends "res://tests/native_particle_typed_pose_test.gd"
const Driver=preload("res://systems/native_render/particle_frame_group.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Metrics=preload("res://systems/native_render/particle_metrics.gd")
class OrderNode extends Node3D:
	var events: Array
	var label: String
	func _ready() -> void: process_priority=20
	func _process(_delta: float) -> void: events.append(label)
class TracedEmitter extends Emitter:
	var events: Array=[]
	var label: String=""
	func _process(delta: float) -> void:
		events.append(label)
		super._process(delta)
func api_order_and_lifetime() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var group: RefCounted=ClassDB.instantiate("NwnParticleFrameGroup")
	var nodes: Array[Node3D]=[]; var events: Array=[]
	for index in 3:
		var node:=Node3D.new(); scene.add_child(node); nodes.append(node)
		var result: Dictionary=group.call("dispatch",0,{"id":node.get_instance_id(),"fallback":func(_delta):events.append(index)})
		check(not result.has("error"),"Native fallback registration "+str(index))
	var ids: Array=nodes.map(func(node):return node.get_instance_id())
	var result: Dictionary=group.call("dispatch",3,{"ids":[ids[0],ids[0],ids[2]]})
	check(result.has("error"),"Duplicate order rejected atomically")
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==[0,1,2],"Rejected order leaves the previous exact order intact")
	group.call("dispatch",3,{"ids":[ids[2],ids[0],ids[1]]}); events.clear()
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==[2,0,1],"Explicit frame order is independent of registry hash order")
	nodes[0].hide(); nodes[1].process_mode=Node.PROCESS_MODE_DISABLED; events.clear()
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==[2],"Native admission honors visibility and engine process mode")
	nodes[0].show(); nodes[1].process_mode=Node.PROCESS_MODE_INHERIT
	group.call("dispatch",1,{"id":ids[2]}); nodes[2].free(); events.clear()
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==[0,1],"Removal and freed node identities do not leave a callable in the order")
	group.call("dispatch",5,{})
	check(group.call("dispatch",2,{"delta":0.01,"view":{}}).has("error"),"Closed group rejects further frames")
	group=null; scene.free()
	# A callback can remove itself/another owner, register a new owner, and
	# attempt a reentrant frame without invalidating the current native entry.
	scene=Node3D.new(); root.add_child(scene); group=ClassDB.instantiate("NwnParticleFrameGroup")
	var a:=Node3D.new(); var b:=Node3D.new(); var c:=Node3D.new()
	scene.add_child(a); scene.add_child(b); scene.add_child(c); events.clear()
	var nested:={"rejected":false}
	group.call("dispatch",0,{"id":a.get_instance_id(),"fallback":func(_delta):
		events.append("a"); nested.rejected=group.call("dispatch",2,{"delta":0.1,"view":{}}).has("error")
		group.call("dispatch",1,{"id":a.get_instance_id()}); group.call("dispatch",1,{"id":b.get_instance_id()})
		group.call("dispatch",0,{"id":c.get_instance_id(),"fallback":func(_dt):events.append("c")})})
	group.call("dispatch",0,{"id":b.get_instance_id(),"fallback":func(_delta):events.append("b")})
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==["a"] and nested.rejected,"Synchronous removal/reentrancy cannot corrupt the frame snapshot")
	group.call("dispatch",2,{"delta":0.01,"view":{}})
	check(events==["a","c"],"Mid-frame registration starts on the next frame")
	group.call("dispatch",5,{}); group=null; scene.free()
func native_frames() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var source:=Node3D.new(); scene.add_child(source)
	var proxy:=Node3D.new(); scene.add_child(proxy)
	var group: RefCounted=ClassDB.instantiate("NwnParticleFrameGroup")
	var seed_owner:=make_owner(false,"fountain",32|128|256,false,false)
	var channels_owner:=Channels.new(); channels_owner.configure(channel_asset(),0)
	var owners: Array[RefCounted]=[]; var rngs: Array=[]; var providers: Array=[]
	for slot in 2:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":source.get_instance_id(),"sourceId":source.get_instance_id(),"clips":channels_owner.clips},{})
		check(not configured.has("error"),"Typed frame owner configures "+str(slot)); owners.append(owner)
		var rng:=Random.new(); rng.seed_value(321); rngs.append(rng)
		providers.append({"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass})
	var context:={"clip":"linear","time":0.0}; var captured:={"output":{},"elapsed":0.0}
	var clock: Callable=func():return context
	var input:={"clip":"constant","capacity":0,"source_flags":0,"culling":true,"draw_enabled":true}
	var added: Dictionary=group.call("dispatch",0,{"id":proxy.get_instance_id(),"owner":owners[1],"input":input,"providers":providers[1],"receiver":func(output,elapsed,_prepare,_dispatch):captured.output=output; captured.elapsed=elapsed; return true,"clock":clock,"clip_length":3.0})
	check(not added.has("error"),"Fast typed group owner registers")
	var capacity:=0; var elapsed:=0.0
	for frame in 180:
		var delta: float=[1.0/60.0,1.0/40.0,0.0,-0.002,0.7][frame%5]; elapsed+=delta
		context.time=fmod(frame/60.0,2.0)
		source.position=Vector3(sin(frame*0.04),0.2,cos(frame*0.03)); source.rotation=Vector3(0.1,frame*0.02,0.3)
		var view:=view_packet(frame,frame%60<10)
		var expected_input:=input.duplicate(true); expected_input.delta=delta; expected_input.capacity=capacity; expected_input.view=view
		if frame==70: group.call("dispatch",4,{"id":proxy.get_instance_id(),"clock":Callable()})
		if frame<70: expected_input.clip=context.clip; expected_input.time=context.time
		else: expected_input.time=fposmod(elapsed,3.0)
		var expected: Dictionary=owners[0].call("dispatch",1,expected_input,providers[0])
		var result: Dictionary=group.call("dispatch",2,{"delta":delta,"view":view})
		var actual: Dictionary=captured.output
		check(not expected.has("error") and not actual.has("error") and not result.has("error"),"Native frame group simulation "+str(frame))
		if actual.has("error") or expected.has("error"): break
		check(same(expected,actual).is_empty(),"Exact native packet including clocks/culling "+str(frame)+" "+same(expected,actual))
		check(same(owners[0].call("dispatch",2,{},{}),owners[1].call("dispatch",2,{},{})).is_empty(),"Exact retained native state "+str(frame))
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws and captured.elapsed==elapsed,"Exact RNG and unrounded emitter clock "+str(frame))
		if expected.has("capacity"): capacity=int(expected.capacity)
	# Only the group retains this owner; removing it must release the retained
	# ref rather than borrowing a dangling native registry pointer.
	var held: WeakRef=weakref(owners[1]); owners[1]=null
	check(held.get_ref()!=null,"Registered group retains the private typed owner")
	group.call("dispatch",1,{"id":proxy.get_instance_id()}); check(held.get_ref()==null,"Removal releases its last native owner reference")
	group.call("dispatch",5,{}); group=null
	for callback in providers: callback.clear()
	seed_owner.providers.clear(); scene.free()
func build_world(texture: Texture2D,grouped: bool,ordered_callbacks: bool=false) -> Dictionary:
	var scene:=Node3D.new(); root.add_child(scene)
	var rng:=Random.new(); rng.seed_value(9841); scene.set_meta("native_particle_random",rng)
	var metrics:=Metrics.new(); scene.set_meta("native_particle_metrics",metrics)
	var driver: Node
	if grouped:
		driver=Driver.new(); scene.add_child(driver); check(driver.configure(scene,ordered_callbacks),"Production frame driver configures"); driver.set_process(false)
	var emitters: Array[Node3D]=[]
	var events: Array=[]
	for index in 7:
		var part:=Node3D.new(); scene.add_child(part); part.position=Vector3(index*0.2,0.1,0)
		var emitter:=TracedEmitter.new(); emitter.events=events; emitter.label=str(index); emitter.source_path=NodePath(".."); emitter.source_model_flags=0; emitter.force_reference=index==3
		emitter.original_texture=texture
		emitter.original_properties={"update":"Explosion" if index==2 else "Fountain","render":Emitter.MODES.keys()[index],"blend":"Normal","flags":32|128,"texture":"authored","birthrate":12.0,"lifeexp":0.6,"loop":1,"velocity":0.4,"randvel":0.3,"spread":0.5,"mass":0.1,"xsize":1.0,"ysize":1.0,"sizestart":0.2,"sizeend":0.1,"alphastart":1.0,"alphaend":0.5,"colorstart":[1.0,0.7,0.5],"colorend":[0.2,0.4,0.8],"fps":2.0,"framestart":0.0,"frameend":3.0,"xgrid":2,"ygrid":2,"blurlength":0.2}
		part.add_child(emitter); emitters.append(emitter); emitter.set_process(false)
		check(emitter.failure.is_empty(),"Actual mixed-path emitter admits "+str(grouped)+"/"+str(index))
	return {"root":scene,"driver":driver,"emitters":emitters,"rng":rng,"metrics":metrics,"events":events}
func production_frames() -> void:
	var camera:=Camera3D.new(); root.add_child(camera); camera.position=Vector3(0,4,8); camera.look_at(Vector3.ZERO); camera.current=true
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color(0.9,0.6,0.2,1)); var texture:=ImageTexture.create_from_image(image)
	var reference:=build_world(texture,false); var grouped:=build_world(texture,true)
	check(grouped.driver.members.size()==7 and grouped.driver.members.values().filter(func(member):return member.fast).size()==6,"Every production emitter joins in order, including the reference fallback")
	for frame in 100:
		var delta:=1.0/60.0
		for world: Dictionary in [reference,grouped]:
			for index in 7:
				var emitter: Node3D=world.emitters[index]; emitter.get_parent().rotation.y=frame*0.01
				if frame==30 and index==1: emitter.hide()
				if frame==40 and index==1: emitter.show()
				if frame==50 and index==4: emitter.set_particles_enabled(false)
				if frame==60 and index==4: emitter.set_particles_enabled(true); emitter.set_process(false)
				if frame%25==0 and index==2: emitter.detonate()
			if world==reference:
				for emitter: Node3D in world.emitters: emitter.tick(delta,true)
			else: world.driver.step(delta)
		check(grouped.driver.failure.is_empty(),"Production frame driver remains valid "+str(frame))
		for index in 7:
			var a: Node3D=reference.emitters[index]; var b: Node3D=grouped.emitters[index]
			var difference:=same(without_ids(a.state),without_ids(b.state))
			check(a.failure.is_empty() and b.failure.is_empty() and difference.is_empty(),"Mixed actual emitter state "+str(frame)+"/"+str(index)+" "+difference)
			check(a.elapsed==b.elapsed and a.frames==b.frames and a.surface.vertex_count==b.surface.vertex_count and a.surface.visible==b.surface.visible,"Exact publication/clock/visibility "+str(frame)+"/"+str(index))
		check(reference.rng.state==grouped.rng.state and reference.rng.draws==grouped.rng.draws,"Shared RNG across native and reference fallback preserves order "+str(frame))
		check(same(reference.metrics.snapshot(),grouped.metrics.snapshot()).is_empty(),"Synchronous full diagnostics publication "+str(frame))
	grouped.driver.close()
	check(grouped.driver.snapshot().native.registered==0,"Closing production driver releases every native entry")
	for world: Dictionary in [reference,grouped]:
		for emitter: Node3D in world.emitters: emitter.retire()
		check(world.metrics.snapshot().emitters==0,"Production retirement releases all counters")
		world.root.free()
	camera.free()
func engine_order() -> void:
	var scene:=Node3D.new(); root.add_child(scene); var events: Array=[]; var nodes: Array[OrderNode]=[]
	for index in 4:
		var node:=OrderNode.new(); node.events=events; node.label=str(index); scene.add_child(node); nodes.append(node); node.add_to_group("native_frame_order_test")
	for change in 3:
		if change==1: scene.move_child(nodes[3],0)
		if change==2:
			var branch:=Node3D.new(); scene.add_child(branch); nodes[0].reparent(branch)
		events.clear(); await process_frame; await process_frame
		var expected: Array=get_nodes_in_group("native_frame_order_test").map(func(node):return node.label)
		evidence.append({"change":change,"events":events.duplicate(),"expected":expected})
		if change==1: check(events.slice(-4)!=expected,"Engine process order remains cached after move_child; a tree-group sort must not replace it")
		else: check(events.slice(-4)==expected,"Engine order agrees after initial registration/reparent "+str(change))
	scene.free()
func ordered_production() -> void:
	# Both automatic worlds receive the same engine delta in each frame; compare
	# their unmodified callbacks rather than substituting a manual tick order.
	var camera:=Camera3D.new(); root.add_child(camera); camera.position=Vector3(0,4,8); camera.look_at(Vector3.ZERO); camera.current=true
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8); image.fill(Color(0.9,0.6,0.2,1)); var texture:=ImageTexture.create_from_image(image)
	var reference:=build_world(texture,false); var grouped:=build_world(texture,true,true)
	for world: Dictionary in [reference,grouped]:
		for emitter: Node3D in world.emitters: emitter.set_process(true)
	grouped.driver.set_process(true)
	for frame in 40:
		if frame in [10,20,30]:
			for world: Dictionary in [reference,grouped]:
				if frame==10: world.root.move_child(world.emitters[6].get_parent(),world.emitters[0].get_parent().get_index())
				if frame==20: world.emitters[1].get_parent().reparent(world.emitters[0].get_parent())
				if frame==30:
					world.emitters[3].set_particles_enabled(false); world.emitters[3].set_particles_enabled(true)
		reference.events.clear(); grouped.events.clear()
		await process_frame; await process_frame
		check(reference.events==grouped.events,"Actual grouped callback order matches original after move/reparent/toggle "+str(frame)+" "+str(reference.events)+" vs "+str(grouped.events))
		check(reference.rng.state==grouped.rng.state and reference.rng.draws==grouped.rng.draws,"Actual ordered callbacks retain shared random stream "+str(frame))
		for index in 7:
			var a: Node3D=reference.emitters[index]; var b: Node3D=grouped.emitters[index]
			var difference:=same(without_ids(a.state),without_ids(b.state))
			check(a.failure.is_empty() and b.failure.is_empty() and difference.is_empty(),"Actual engine-ordered retained state "+str(frame)+"/"+str(index)+" "+difference)
		if not failures.is_empty(): break
	for world: Dictionary in [reference,grouped]:
		for emitter: Node3D in world.emitters: emitter.retire()
		world.root.free()
	camera.free()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(ClassDB.class_exists("NwnParticleFrameGroup"),"Experimental frame group extension registers")
	if not ClassDB.class_exists("NwnParticleFrameGroup"): quit(1); return
	api_order_and_lifetime(); native_frames(); production_frames(); await engine_order(); await ordered_production()
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"evidence":evidence,"network_connections":0,"scope":"Experimental frame group: exact native packets, retained state and RNG; dynamic-to-static clocks, culling, owner retention; real mixed native/reference production emitters, all seven geometry modes, explosions, visibility/toggles and diagnostics; frame-order/removal/reentrancy and actual engine order after hierarchy changes. Headless correctness only, no GPU/FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
