extends Node
# Explicit lease -> presentation projection. Layers never establish membership.
const BASE:=200
const LIMIT:=64
class TransformObserver extends Control:
	signal transform_changed
	var last_transform:=Transform2D.IDENTITY
	var notifications:=0
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE;hide();set_notify_transform(true)
	func _notification(what: int) -> void:
		if what==NOTIFICATION_TRANSFORM_CHANGED:
			# Consume this observer's dirty global transform so a subsequent
			# scale-only change can enqueue its next native notification.
			last_transform=get_global_transform_with_canvas();notifications+=1;transform_changed.emit()
var order
var owners: Dictionary={}
var layers: Dictionary={}
var created: Array=[]
var transforms: Array=[]
var parents: Dictionary={}
var viewport_ref: WeakRef
var closed:=false
var status:={"available":false,"reason":"unconfigured"}
func configure(value) -> void:
	order=value
	if is_instance_valid(order):order.changed.connect(project)
	if is_inside_tree():
		var viewport:=get_viewport();viewport_ref=weakref(viewport);viewport.size_changed.connect(synchronize_transforms)
	project()
func create_root(parent: Node,source: CanvasLayer) -> Control:
	if closed or not is_instance_valid(parent) or not is_instance_valid(source) or created.size()>=LIMIT:return null
	var canvas:=CanvasLayer.new();canvas.layer=source.layer;parent.add_child(canvas);created.append(weakref(canvas))
	var surface:=Control.new();canvas.add_child(surface);surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var row:={"parent":weakref(parent),"canvas":weakref(canvas),"source":weakref(source)}
	var index:=transforms.size();transforms.append(row)
	if parent is CanvasItem:
		var id:=parent.get_instance_id()
		if not parents.has(id):
			var callback:=synchronize_parent.bind(id);var observer:=TransformObserver.new();parent.add_child(observer)
			parents[id]={"ref":weakref(parent),"callback":callback,"indices":[],"observer":weakref(observer)}
			parent.item_rect_changed.connect(callback);observer.transform_changed.connect(callback)
		parents[id].indices.append(index);row.observer=parents[id].observer
	synchronize_transform(row)
	return surface
func synchronize_parent(id: int) -> void:
	# One connection per explicit parent. Bind only its scalar identity, never
	# a row (which would create a row -> Callable -> row reference cycle).
	if closed or not parents.has(id):return
	for index in parents[id].indices:
		if index>=0 and index<transforms.size():synchronize_transform(transforms[index])
func synchronize_transform(row: Dictionary) -> void:
	if closed:return
	var parent=row.parent.get_ref();var canvas=row.canvas.get_ref();var source=row.source.get_ref()
	if not is_instance_valid(canvas):return
	var desired: Transform2D
	if parent is CanvasItem:desired=parent.get_global_transform_with_canvas()
	elif is_instance_valid(source):desired=source.get_final_transform()
	else:return
	# Remove this new canvas's viewport prefix before assigning its local
	# transform; otherwise a viewport-wide transform would be applied twice.
	var prefix: Transform2D=canvas.get_final_transform()*canvas.transform.affine_inverse()
	canvas.transform=prefix.affine_inverse()*desired
func synchronize_transforms() -> void:
	# Existing viewport completion only; at most64 created roots, no frame scan.
	for row in transforms:synchronize_transform(row)
func set_created_visible(value: bool) -> void:
	for ref in created:
		var canvas=ref.get_ref()
		if is_instance_valid(canvas):canvas.visible=value
func bind_layer(owner: Object,canvas: CanvasLayer) -> bool:
	if closed or not is_instance_valid(owner) or not is_instance_valid(canvas):return false
	for stale in owners.keys():
		if owners[stale].ref.get_ref()==null:owners.erase(stale)
	for stale in layers.keys():
		if layers[stale].ref.get_ref()==null:layers.erase(stale)
	var id:=owner.get_instance_id();var layer_id:=canvas.get_instance_id()
	if not owners.has(id) and owners.size()>=LIMIT:return false
	if not layers.has(layer_id):layers[layer_id]={"ref":weakref(canvas),"original":canvas.layer}
	owners[id]={"ref":weakref(owner),"layer":layer_id};project();return true
func restore() -> void:
	for row in layers.values():
		var canvas=row.ref.get_ref()
		if is_instance_valid(canvas):canvas.layer=int(row.original)
func project() -> void:
	if closed:return
	restore()
	if not is_instance_valid(order):status={"available":false,"reason":"order_unavailable"};return
	var records: Array=order.snapshot().records;var ranks: Dictionary={}
	for index in records.size():
		var row: Dictionary=records[index];var id:=int(row.ticket.owner)
		if not row.owner_available or not owners.has(id) or owners[id].ref.get_ref()==null or not layers.has(owners[id].layer) or layers[owners[id].layer].ref.get_ref()==null:
			# An unmapped live top must never become invisible behind a boosted
			# known lower owner. Suspend the whole projection, not just one row.
			status={"available":false,"reason":"unmapped_owner"};return
		ranks[owners[id].layer]=BASE+index
	for id in ranks:layers[id].ref.get_ref().layer=int(ranks[id])
	# Explicit members sharing one existing render group still promote within
	# that group in logical order; sibling order never establishes membership.
	for row in records:
		var owner=owners[int(row.ticket.owner)].ref.get_ref()
		if owner is Control:owner.move_to_front()
	status={"available":true,"members":records.size(),"groups":ranks.size()}
func snapshot() -> Dictionary:return status.duplicate(true)
func close() -> void:
	if closed:return
	closed=true
	var viewport=viewport_ref.get_ref() if viewport_ref!=null else null
	if is_instance_valid(viewport) and viewport.size_changed.is_connected(synchronize_transforms):viewport.size_changed.disconnect(synchronize_transforms)
	for group in parents.values():
		var parent=group.ref.get_ref()
		if parent is CanvasItem and parent.item_rect_changed.is_connected(group.callback):parent.item_rect_changed.disconnect(group.callback)
		var observer=group.observer.get_ref()
		if is_instance_valid(observer):
			if observer.transform_changed.is_connected(group.callback):observer.transform_changed.disconnect(group.callback)
			observer.queue_free()
	transforms.clear();parents.clear();viewport_ref=null
	if is_instance_valid(order) and order.changed.is_connected(project):order.changed.disconnect(project)
	restore();owners.clear();layers.clear();order=null
	for ref in created:
		var canvas=ref.get_ref()
		if is_instance_valid(canvas):canvas.queue_free()
	created.clear();status={"available":false,"reason":"closed"}
func _exit_tree() -> void:close()
