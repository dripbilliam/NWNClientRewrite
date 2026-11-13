extends SceneTree
const Order=preload("res://systems/native_data/modal_order.gd")
const Surfaces=preload("res://systems/native_modal_surfaces.gd")
const Lease=preload("res://systems/native_data/modal_lease.gd")
class TransformOwner extends Control:
	var transform_events: Array=[]
	var rect_events: Array=[]
	func _ready() -> void:
		set_notify_transform(true);item_rect_changed.connect(func():rect_events.append(str(get_global_transform_with_canvas())))
	func _notification(what: int) -> void:
		if what==NOTIFICATION_TRANSFORM_CHANGED:transform_events.append(str(get_global_transform_with_canvas()))
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func frames(count: int=2) -> void:
	for index in count:await process_frame
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(1100,800);viewport.disable_3d=true;viewport.gui_disable_input=false;viewport.handle_input_locally=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport);viewport.notify_mouse_entered()
	var source_canvas:=CanvasLayer.new();source_canvas.layer=10;viewport.add_child(source_canvas)
	var owner:=TransformOwner.new();source_canvas.add_child(owner);owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var baseline:=Button.new();owner.add_child(baseline);baseline.position=Vector2(100,70);baseline.size=Vector2(120,30);baseline.text="Original parent"
	var order:=Order.new();var surfaces:=Surfaces.new();viewport.add_child(surfaces);surfaces.configure(order)
	var lifted_root:=surfaces.create_root(owner,source_canvas);var lifted:=Button.new();lifted_root.add_child(lifted);lifted.position=baseline.position;lifted.size=baseline.size;lifted.text="Explicit surface"
	var lease:=Lease.new();lease.configure(lifted,order,surfaces,lifted_root.get_parent());lease.bind_input(lifted);lease.activate([1])
	var second_root:=surfaces.create_root(owner,source_canvas);var second:=Button.new();second_root.add_child(second);second.position=baseline.position;second.size=baseline.size
	var second_lease:=Lease.new();second_lease.configure(second,order,surfaces,second_root.get_parent());second_lease.bind_input(second);second_lease.activate([1])
	check(surfaces.transforms.size()==2 and surfaces.parents.size()==1,"Multiple explicit modal roots under the same parent share exactly one observer/rect connection")
	var geometry: Array=[]
	for sample in [{"position":Vector2.ZERO,"scale":Vector2.ONE},{"position":Vector2.ZERO,"scale":Vector2.ONE*1.25},{"position":Vector2(12,21),"scale":Vector2.ONE*1.25},{"position":Vector2(12,21),"scale":Vector2.ONE*.75},{"position":Vector2(3,7),"scale":Vector2.ONE*.75}]:
		owner.position=sample.position;owner.scale=sample.scale;await frames()
		var expected:=baseline.get_global_transform_with_canvas();var actual:=lifted.get_global_transform_with_canvas()
		geometry.append({"position":str(sample.position),"scale":str(sample.scale),"expected":str(expected),"actual":str(actual),"rectSignals":owner.rect_events.size(),"transformNotifications":owner.transform_events.size(),"observerNotifications":surfaces.transforms[0].observer.get_ref().notifications})
		check(expected.is_equal_approx(actual),"Explicit surface preserves exact authored parent transform at scale"+str(sample.scale))
		check(expected.is_equal_approx(second.get_global_transform_with_canvas()),"Second root sharing parent receives the same transform completion at scale"+str(sample.scale))
	source_canvas.offset=Vector2(5,9);viewport.size=Vector2i(1200,900);await frames()
	check(baseline.get_global_transform_with_canvas().is_equal_approx(lifted.get_global_transform_with_canvas()),"Existing viewport completion refreshes explicit source-canvas transform without a frame scan")
	owner.position=Vector2.ZERO;owner.scale=Vector2.ONE;await frames()
	var parent:=Control.new();owner.add_child(parent);parent.position=Vector2(100,400);parent.size=Vector2(300,100)
	var child:=Button.new();parent.add_child(child);child.size=Vector2(100,40);child.text="Nested admitted leaf"
	var parent_lease:=Lease.new();parent_lease.configure(parent,order,surfaces,source_canvas);parent_lease.bind_input(parent);parent_lease.activate([1])
	var child_lease:=Lease.new();child_lease.configure(child,order,surfaces,source_canvas);child_lease.bind_input(child);child_lease.activate([1])
	check(not parent_lease.admits() and child_lease.admits(),"Nested top admission is logically distinct from lower parent admission")
	var clicks: Array=[];child.pressed.connect(func():clicks.append(true));var point:=child.get_global_transform_with_canvas()*(child.size*.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;viewport.push_input(motion,true);await frames()
	var hovered: Control=viewport.gui_get_hovered_control();var hit:={"point":str(point),"hover":str(hovered.get_path()) if is_instance_valid(hovered) else null,"parentMouseMode":parent.get("mouse_behavior_recursive"),"childMouseMode":child.get("mouse_behavior_recursive")}
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.pressed=pressed;viewport.push_input(event,true);await frames()
	check(clicks.size()==1,"Actual admitted nested leaf receives pointer despite lower registered ancestor input mask")
	var dialog:=Control.new();owner.add_child(dialog);dialog.position=Vector2(300,500);dialog.size=Vector2(200,50)
	var edit:=LineEdit.new();dialog.add_child(edit);edit.size=Vector2(180,40)
	var focus_lease:=Lease.new();focus_lease.configure(dialog,order,surfaces,source_canvas);focus_lease.bind_input(dialog)
	edit.grab_focus();check(edit.has_focus(),"Real edit owns focus immediately before its actual modal activation")
	var focus_trace: Array=[];var observe_focus:=func():focus_trace.append({"focused":edit.has_focus(),"active":focus_lease.active,"ticket":focus_lease.ticket.duplicate(true)})
	order.changed.connect(observe_focus);focus_lease.activate([2]);order.changed.disconnect(observe_focus)
	check(edit.has_focus() and focus_lease.admits(),"Own atomic activation preserves preexisting edit focus while assigning the new ticket")
	focus_lease.close()
	var retiring:=Lease.new();retiring.configure(dialog,order,surfaces,source_canvas);retiring.bind_input(dialog)
	var once: Array=[true];var retire_during_change:=func():
		if once[0]:once[0]=false;retiring.retire()
	order.changed.connect(retire_during_change);retiring.activate([3]);order.changed.disconnect(retire_during_change)
	check(not retiring.active and retiring.ticket.is_empty() and not order.snapshot().records.any(func(row):return row.ticket.owner==dialog.get_instance_id()),"Retirement during activation removes the abandoned incoming ticket without reviving a hidden owner")
	retiring.close()
	child_lease.close();parent_lease.close();lease.close();second_lease.close();surfaces.close()
	check(not viewport.size_changed.is_connected(surfaces.synchronize_transforms) and not owner.item_rect_changed.get_connections().any(func(row):return row.callable.get_object()==surfaces),"Close disconnects exact parent/viewport transform callbacks")
	owner.scale=Vector2.ONE*1.1;viewport.size=Vector2i(1000,700);await frames();order.close();viewport.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"geometry":geometry,"nestedHit":hit,"focusTrace":focus_trace,"scope":"Independent3-helper native transform/nested-hit/focus diagnostic; authored Controls only, no Painter/Gameplay/server/GPU or original pixels. A new failure is not masked by prior668 acceptance.","gpu":false,"servers":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_SURFACE_GEOMETRY_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)
