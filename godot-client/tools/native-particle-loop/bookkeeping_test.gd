extends "res://tests/native_particle_presentation_lifetime_test.gd"

func boundary_cases() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var nodes: Array[Node3D]=[]
	for index in 3:
		var node:=Node3D.new();scene.add_child(node);nodes.append(node)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var first:=simple_owner(nodes[1]);var second:=simple_owner(nodes[2])
	var common:={"delta":1.0/60,"view":view_packet(7000000,false),"animating":true}
	var action:={"animate":false,"hide":false,"pose":false,"rejects":0}
	var providers:={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	var callback:=func(_delta):
		common.animating=action.animate
		if action.hide:nodes[1].hide()
		if action.pose:nodes[2].position=Vector3(7,3,2)
		for result in [presentation.call("dispatch",3,{"id":nodes[1].get_instance_id()}),presentation.call("dispatch",6,{"ids":nodes.map(func(n):return n.get_instance_id())}),presentation.call("dispatch",5,{})]:
			if result.has("error"):action.rejects+=1
	presentation.call("dispatch",0,{"id":nodes[0].get_instance_id(),"fallback":callback})
	for index in 2:presentation.call("dispatch",0,{"id":nodes[index+1].get_instance_id(),"owner":[first,second][index],"providers":providers,"culling":false})
	var result: Dictionary=presentation.call("dispatch",1,common)
	check(not result.has("error") and result.active==0,"An earlier fallback can stop animation for later native emitters in this same frame")
	action.animate=true;action.pose=true;common.view=view_packet(7000001,false)
	result=presentation.call("dispatch",1,common)
	check(not result.has("error") and result.active==2,"A changed shared frame Dictionary is observed at the next emitter boundary")
	check(same(second.call("dispatch",2,{},{}).source50.position,[7.0,-2.0,3.0]).is_empty(),"Later source pose is read after the opaque fallback mutation")
	action.hide=true;common.view=view_packet(7000002,false)
	result=presentation.call("dispatch",1,common)
	check(not result.has("error") and result.prepared==1,"Later visibility is read after an earlier callback hides the emitter")
	check(action.rejects==9,"Entry removal, order changes and close are rejected during traversal")
	nodes[1].show()
	# Reordering changes callback observations, and a removed owner must release.
	var ids:=nodes.map(func(n):return n.get_instance_id())
	check(not presentation.call("dispatch",6,{"ids":[ids[1],ids[2],ids[0]]}).has("error"),"Reorder is accepted at a frame boundary")
	action.hide=false;action.animate=false;common.animating=true;common.view=view_packet(7000003,false)
	result=presentation.call("dispatch",1,common)
	check(not result.has("error") and common.animating==false and presentation.call("dispatch",10,{"id":ids[1]}).frames==3,"Reordered native entries run before the mutating fallback")
	var held: WeakRef=weakref(first);first=null
	presentation.call("dispatch",3,{"id":ids[1]})
	check(held.get_ref()==null,"Removing an entry retires cached traversal pointers and releases its owner")
	# Rehash the owning map after its order cache has already been used.
	var seen: Array=[];var extra: Array=[]
	for index in 192:
		var node:=Node3D.new();scene.add_child(node);extra.append(node.get_instance_id())
		var event:=func(_delta):seen.append(index)
		check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"fallback":event}).has("error"),"Post-frame registration "+str(index))
	common.view=view_packet(7000004,false);result=presentation.call("dispatch",1,common)
	check(not result.has("error") and seen==range(192),"Map rehash preserves insertion order and native entry addresses")
	for index in range(0,192,2):presentation.call("dispatch",3,{"id":extra[index]})
	seen.clear();common.view=view_packet(7000005,false);result=presentation.call("dispatch",1,common)
	check(not result.has("error") and seen==range(1,192,2),"Removing alternating entries rebuilds the exact remaining traversal")
	presentation.call("dispatch",3,{"id":ids[0]})
	common.erase("animating");common.view=view_packet(7000006,false)
	check(not presentation.call("dispatch",1,common).has("error"),"Absent animating retains the original enabled default")
	common.animating=null;common.view=view_packet(7000007,false)
	check(presentation.call("dispatch",1,common).has("error"),"Explicit nil animating remains invalid rather than becoming the absent default")
	common.animating=false;common.view=view_packet(7000008,false)
	check(not presentation.call("dispatch",1,common).has("error"),"A valid frame recovers after the invalid optional input")
	presentation.call("dispatch",5,{});presentation=null;second=null;providers.clear();callback=Callable();scene.free()

func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	boundary_cases()
	await process_frame;await process_frame
	var value:={"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"gpu_execution":false,"scope":"Private traversal/control bookkeeping regression: callback-visible Dictionary/visibility/pose mutation, reorder, map rehash, alternating removal, release, rejection recovery and explicit nil semantics. No FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  "));file.close();quit(0 if failures.is_empty() else 1)
