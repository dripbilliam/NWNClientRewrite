extends RefCounted
# Private optional lease for one explicitly classified native menu owner.
signal admission_changed(admitted: bool)
var owner_ref: WeakRef
var order
var surfaces
var ticket: Dictionary={}
var lifetime:=0
var active:=false
var input_root: Control
var mouse_mode:=0
var focus_mode:=0
var recursive_input:=false
var allowed:=true
var activating:=false
var revision:=0
static func property(owner: Object,name: String) -> Variant:
	if not is_instance_valid(owner):return null
	for row in owner.get_property_list():
		if row.name==name:return owner.get(name)
	return null
func configure(owner: Object,value,value_surfaces=null,canvas: CanvasLayer=null) -> void:
	if is_instance_valid(order) and order==value and owner_ref!=null and owner_ref.get_ref()==owner:
		if is_instance_valid(value_surfaces) and is_instance_valid(canvas):value_surfaces.bind_layer(owner,canvas)
		return
	retire()
	if is_instance_valid(order) and order.changed.is_connected(update_input):order.changed.disconnect(update_input)
	owner_ref=weakref(owner);order=value;surfaces=value_surfaces
	if is_instance_valid(order):order.changed.connect(update_input)
	if is_instance_valid(surfaces) and is_instance_valid(canvas):surfaces.bind_layer(owner,canvas)
	update_input()
func bind_input(root: Control) -> void:
	if input_root==root:return
	if is_instance_valid(input_root) and recursive_input:input_root.set("mouse_behavior_recursive",mouse_mode);input_root.set("focus_behavior_recursive",focus_mode)
	input_root=root;recursive_input=false
	if is_instance_valid(root):
		var names: Array=root.get_property_list().map(func(row):return str(row.name))
		recursive_input=names.has("mouse_behavior_recursive") and names.has("focus_behavior_recursive")
		if recursive_input:mouse_mode=int(root.get("mouse_behavior_recursive"));focus_mode=int(root.get("focus_behavior_recursive"))
	update_input()
func activate(scope: Array=[],kind: String="other",superseded: Callable=Callable()) -> void:
	if not is_instance_valid(order) or activating:return
	var owner=owner_ref.get_ref() if owner_ref!=null else null
	if not is_instance_valid(owner):return
	if not ticket.is_empty() and ticket.scope!=scope:retire()
	if ticket.is_empty():
		if lifetime>=9007199254740991:return
		lifetime+=1
	var source=order;var before:=revision;activating=true
	var result: Dictionary=source.activate(owner,kind,lifetime,scope,Callable(),superseded)
	activating=false
	if revision!=before or order!=source or owner_ref==null or owner_ref.get_ref()!=owner:
		if is_instance_valid(source) and result.has("registry"):source.retire(result)
		update_input();return
	ticket=result if result.has("registry") else {};active=true;update_input()
func admits() -> bool:return not activating and (not is_instance_valid(order) or not active or order.admits(ticket))
func update_input() -> void:
	# Order emits its synchronous change before returning the new ticket. Do
	# not briefly mask our own already-focused edit against an empty ticket.
	if activating:return
	var next:=admits()
	if is_instance_valid(input_root) and recursive_input:
		# A registered top leaf may be nested below a registered lower parent.
		# Explicit enable applies only to this active root, then original modes
		# return on retirement; inheritance would retain the lower parent's mask.
		var explicit_top:=next and active and is_instance_valid(order)
		input_root.set("mouse_behavior_recursive",2 if explicit_top else mouse_mode if next else 1)
		input_root.set("focus_behavior_recursive",2 if explicit_top else focus_mode if next else 1)
		if not next and input_root.is_inside_tree():
			var focused:=input_root.get_viewport().gui_get_focus_owner()
			if is_instance_valid(focused) and (focused==input_root or input_root.is_ancestor_of(focused)):focused.release_focus()
	if next!=allowed:allowed=next;admission_changed.emit(next)
func retire() -> void:
	revision+=1
	if is_instance_valid(order) and not ticket.is_empty():order.retire(ticket)
	ticket.clear();active=false;update_input()
func close() -> void:
	retire()
	if is_instance_valid(order) and order.changed.is_connected(update_input):order.changed.disconnect(update_input)
	order=null;surfaces=null;owner_ref=null
