extends SceneTree
const Radial=preload("res://systems/server_radial.gd")
class WorldProbe:
	extends Node
	var presses:=0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: presses+=1
var checks:=0
var failures: Array=[]
var wheel
var events: Array=[]
var children: Dictionary={}
var parents: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func entries(submenu: bool=false) -> Array:
	return [{"slot":0,"label":"Leaf","canDrag":true},{"slot":1,"label":"Deeper" if submenu else "Child leaf","submenu":submenu,"canDrag":not submenu}]
func page(id: int,depth: int=0,submenu: bool=false) -> void:
	wheel.reset(); wheel.open_at(Vector2(400,350),7,Vector3.ZERO,false); wheel.initial_gesture=false
	wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":id,"depth":depth,"title":"Input parity","entries":entries(submenu)})
func received(message: Dictionary) -> void:
	events.append(message.duplicate(true))
	if message.kind=="radial-select" and children.has(int(message.menuId)):
		wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":children[int(message.menuId)],"depth":1,"title":"Synchronous child","entries":entries()})
	elif message.kind=="radial-back" and parents.has(int(message.menuId)):
		wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":parents[int(message.menuId)],"depth":1,"title":"Synchronous parent","entries":entries()})
func mouse(point: Vector2,pressed: bool,button: int=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=pressed
	event.button_mask=(MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event,true); await process_frame
func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=Vector2(100,-100); event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true); await process_frame
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-radial-button-mirror-v1.json"))
	check(original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==960,"Original radial button-handler evidence identity")
	root.size=Vector2i(1000,800)
	var world:=WorldProbe.new(); root.add_child(world); wheel=Radial.new(); root.add_child(wheel); wheel.request.connect(received)
	check(wheel.left_mirrors_right==bool(original.default),"Original left-mirror initializer is enabled")
	children[1]=2; page(1,0,true); var point: Vector2=wheel.buttons[1].get_global_rect().get_center()
	await mouse(point,true); check(wheel.left_gesture and not wheel.click_mode,"A left hold enters the right-button navigation mode")
	await mouse(point,false)
	check(events.size()==1 and events[0].kind=="radial-select" and events[0].menuId==1 and wheel.menu_id==2 and not wheel.pending,"Synchronous submenu replacement cannot receive a second GUI button activation")
	await mouse(point,true); await mouse(point,false)
	check(events.size()==2 and events[1].menuId==2,"A new left click selects exactly one current child leaf")
	events.clear(); children[10]=11; page(10,0,true)
	await mouse(wheel.origin+Vector2(0,-35),true); await motion(wheel.origin+Vector2(135,-135))
	var deadline:=Time.get_ticks_msec()+2000
	while wheel.menu_id!=11 and Time.get_ticks_msec()<deadline: await process_frame
	check(wheel.menu_id==11 and wheel.left_gesture and events.size()==1,"Held left navigation dwells into the nested menu without a release")
	await mouse(wheel.buttons[1].get_global_rect().get_center(),false)
	check(events.size()==2 and events[1].menuId==11 and events[1].slot==1,"Held left release selects the current child with its live identity")
	events.clear(); wheel.left_mirrors_right=false; page(30,1,true); point=wheel.buttons[1].get_global_rect().get_center()
	await mouse(point,true)
	check(events.size()==1 and events[0].kind=="radial-back" and events[0].menuId==30,"Nonmirrored left-down goes back immediately")
	wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":31,"depth":0,"title":"Parent","entries":entries()})
	await mouse(point,false); check(events.size()==1,"Nonmirrored release cannot activate the restored parent")
	events.clear(); page(40); await mouse(wheel.buttons[0].get_global_rect().get_center(),true); await mouse(point,false)
	check(events.size()==1 and events[0].kind=="radial-cancel" and not wheel.active,"Nonmirrored left-down closes the top-level wheel")
	events.clear(); page(50); point=wheel.buttons[0].get_global_rect().get_center(); await mouse(point,true,MOUSE_BUTTON_RIGHT); await mouse(point,false,MOUSE_BUTTON_RIGHT)
	check(events.size()==1 and events[0].kind=="radial-select" and events[0].menuId==50,"Right-button selection is independent of the left-mirror preference")
	events.clear(); wheel.left_mirrors_right=true; page(60); var before: int=world.presses; point=wheel.origin+Vector2(0,-135)
	await mouse(point,true); await mouse(point,false)
	check(world.presses==before and events.size()==1 and events[0].slot==0,"An angular selection gap blocks world click-move and still selects once")
	events.clear(); page(70); before=world.presses; point=Vector2(900,700); await mouse(point,true); await mouse(point,false)
	check(world.presses==before+1 and events.size()==1 and events[0].kind=="radial-cancel","A click outside the wheel still closes it and reaches the world")
	events.clear(); parents[80]=81; page(80,2); point=wheel.origin; await mouse(point,true); await mouse(point,false)
	check(events.size()==1 and events[0].kind=="radial-back" and events[0].menuId==80 and wheel.menu_id==81 and not wheel.pending,"Mirrored center release cannot go back twice after synchronous parent restoration")
	wheel.reset(); wheel.free(); world.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual Godot pointer dispatch: original left/right mirror preference, held nested navigation, synchronous menu replacement, no duplicate button callback, nonmirrored back and world-click routing. Shortcut dragging and original authoritative actions have separate receipts."},"\t")); file.close()
	print("NATIVE_RADIAL_MIRROR_INPUT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
