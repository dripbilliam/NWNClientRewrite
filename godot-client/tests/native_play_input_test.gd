extends SceneTree
const Keyboard=preload("res://systems/native_keyboard.gd")
const Registry=preload("res://systems/entity_registry.gd")
const CameraOwner=preload("res://systems/camera_controller.gd")
var checks:=0
var failures: Array=[]
var current: Dictionary={}
var sent: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	current={"identity":"1/1/1","id":1,"position":Vector3(2,3,4),"state":{"orientation":Vector3(1,0,0),"position":Vector3(2,3,4),"render":Vector3(2,3,4),"path":[],"animation":0}}
	var original: Dictionary=current.duplicate(true)
	var input:=Keyboard.new(); root.add_child(input); input.set_process(false); input.require_focus=false
	input.context_query=func(): return current
	input.transmit=func(value): sent.append(value.duplicate(true))
	check(input.key(KEY_W,true),"Native W input accepted")
	check(sent[-1].operation=="drive" and sent[-1].flags==3 and sent[-1].position==[2.0,3.0],"Drive uses original XY wire shape/run flags")
	var began:=Time.get_ticks_usec()/1000.0; var count:=sent.size()
	input.update_input(began+499); check(sent.filter(func(m):return m.get("transmit",true)).size()==count,"Local preview ticks do not flood the wire")
	input.update_input(began+501); check(sent.filter(func(m):return m.get("transmit",true)).size()==count+1,"Held drive refreshes the wire at 500 ms")
	check(current==original,"Input never invents a rendered or authoritative path/pose/animation")
	input.key(KEY_S,true); check(sent[-1].operation=="stop" and input.held.size()==2,"Opposing keys stop but retain both held keys")
	input.key(KEY_S,false); check(sent[-1].operation=="drive","Releasing opposed key resumes remaining direction")
	input.key(KEY_W,false); check(sent[-1].operation=="stop" and input.held.is_empty(),"Release aborts original drive")
	input.key(KEY_A,true); check(sent[-1].operation=="turn" and is_equal_approx(Vector2(sent[-1].position[0],sent[-1].position[1]).length(),1),"Turn-only input uses normalized original orientation request")
	input.stop(); input.key(KEY_SHIFT,true); input.key(KEY_W,true); input.key(KEY_Q,true)
	check(sent[-1].flags==5,"Walk plus strafe uses original bit mask")
	input.stop(); input.key(KEY_W,true)
	var edit:=LineEdit.new(); root.add_child(edit); edit.grab_focus(); input.update_input()
	check(sent[-1].operation=="stop" and input.held.is_empty(),"Text editing releases movement")
	edit.release_focus(); count=sent.size(); input.update_input(); check(sent.size()==count,"Leaving text focus cannot rearm held input")
	input.key(KEY_W,true); count=sent.size(); current.identity="2/1/2"; input.update_input()
	check(sent.size()==count and input.held.is_empty(),"New area/actor lifetime drops old held input without commanding replacement")
	current={}; check(not input.key(KEY_W,true),"Unadmitted world rejects keyboard movement")
	input.free(); edit.free()
	# Authored WOK fixture: an elevated slope plus a denied ceiling. All four
	# placements must pick the floor using the original tile quarter-turns.
	var registry:=Registry.new(); root.add_child(registry)
	var surface:={"definition":{"tiles":[]},"table":{"orderedRows":[{"Walk":"1"},{"Walk":"0"}]},"meshes":{"test":{"vertices":[[0.0,0.0,0.0],[10.0,0.0,2.0],[10.0,10.0,2.0],[0.0,10.0,0.0],[0.0,0.0,4.0],[10.0,0.0,4.0],[10.0,10.0,4.0]],"faces":[[0,1,2],[0,2,3],[4,5,6]],"materials":[0,0,1]}}}
	for orientation in 4: surface.definition.tiles.append({"model":"test","orientation":orientation,"position":Vector3(orientation*12+5,7,-5)})
	registry.register_walkmesh(surface)
	await physics_frame; await physics_frame
	for orientation in 4:
		var placed: Vector3=Basis(Vector3.UP,orientation*PI/2)*Vector3(3,1.6,3)+surface.definition.tiles[orientation].position
		var query:=PhysicsRayQueryParameters3D.create(placed+Vector3.UP*12,placed-Vector3.UP*12,1); query.hit_back_faces=true
		var hit:=registry.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.position.distance_to(placed)<0.001,"Walkable floor picked below denied ceiling with tile rotation %d"%orientation)
	check(registry.stats.runtime_geometry_reads==0,"Original CPU WOK pick needs no GPU readback")
	var camera:=Camera3D.new(); registry.add_child(camera); camera.position=Vector3(10,14,10); camera.look_at(Vector3.ZERO)
	var follow:=CameraOwner.new(); registry.add_child(follow); follow.configure(camera,Vector3.ZERO); follow.enable_follow(1,Vector3(2,0,-3))
	for frame in 10:
		var player:=Vector3(2+frame*0.1,0,-3); follow.follow_frame(player,0,4,1.0/60.0)
		check(follow.follow_valid(player),"Native follow keeps the moving player in view %d"%frame)
	registry.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Headless native input ownership/focus/lifetime/wire shape and authored rotated walkmesh floor picking/camera. Original-server acceptance is separate."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures})); quit(0 if failures.is_empty() else 1)
