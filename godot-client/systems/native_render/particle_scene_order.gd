extends Node
# The ordinary ModelParticlePresentation updates all emitters from one current
# scene-root traversal. Keep the existing emitter simulation/rendering owner;
# this node supplies only that once-per-frame iteration order.
const Profile=preload("res://systems/native_render/frame_profile.gd")
var scope_root: Node3D
var members: Dictionary={}
var ordered: Array=[]
var order_dirty:=true
var closed:=false

func configure(root: Node3D) -> void:
	scope_root=root
	process_priority=110 if bool(root.get_meta("native_surface_output",false)) else 70
	root.set_meta("native_particle_scene_order",self)
	root.get_tree().tree_changed.connect(mark_order_dirty)

func mark_order_dirty() -> void:order_dirty=true

func register(emitter: Node3D) -> bool:
	if closed or not is_instance_valid(scope_root) or not scope_root.is_ancestor_of(emitter):return false
	if emitter.get_viewport()!=get_viewport() or emitter.process_priority!=process_priority:return false
	if emitter.retired or not emitter.failure.is_empty() or is_instance_valid(emitter.native_frame_group) or is_instance_valid(emitter.native_stream_group):return false
	var id:=emitter.get_instance_id()
	if members.has(id):return true
	members[id]=weakref(emitter);emitter.native_scene_order=self;emitter.set_process(false);order_dirty=true
	return true

func unregister(emitter: Node3D,restore_process: bool=true) -> void:
	members.erase(emitter.get_instance_id());order_dirty=true
	if emitter.native_scene_order==self:emitter.native_scene_order=null
	if restore_process and not closed and not emitter.retired and emitter.failure.is_empty() and not is_instance_valid(emitter.native_frame_group) and not is_instance_valid(emitter.native_stream_group):
		emitter.set_process(emitter.particles_enabled)

func rebuild_order() -> void:
	ordered.clear()
	for id in members.keys():
		var emitter: Node3D=members[id].get_ref()
		if not is_instance_valid(emitter):members.erase(id);continue
		# A detached model is absent from the old root traversal. Its emitter
		# normally retires on exit; a surviving reparent stays dormant here.
		if not emitter.is_inside_tree() or not scope_root.is_ancestor_of(emitter):continue
		ordered.append(emitter)
	# Old observeRendererHierarchy(root).nodes is a preorder traversal, and
	# Godot's is_greater_than tests that same physical hierarchy order.
	ordered.sort_custom(func(a,b):return a.is_greater_than(b))
	order_dirty=false

func _process(delta: float) -> void:
	if closed or not is_instance_valid(scope_root):return
	# Electron marks a hidden/minimized window's document hidden. The native
	# session already uses this same Window predicate for rendered-frame status.
	if DisplayServer.get_name()!="headless":
		var window:=scope_root.get_window()
		if not is_instance_valid(window) or not window.visible or DisplayServer.window_get_mode(window.get_window_id())==DisplayServer.WINDOW_MODE_MINIMIZED:return
	if order_dirty:rebuild_order()
	var began:=Profile.begin()
	for emitter in ordered:
		if not is_instance_valid(emitter) or not members.has(emitter.get_instance_id()):continue
		if not emitter.is_inside_tree() or not scope_root.is_ancestor_of(emitter) or emitter.get_viewport()!=get_viewport() or not emitter.can_process():continue
		if emitter.retired or not emitter.failure.is_empty() or not emitter.particles_enabled:continue
		if is_instance_valid(emitter.native_frame_group) or is_instance_valid(emitter.native_stream_group):continue
		emitter.tick(delta,true)
	Profile.finish("callback_particles",began)

func close() -> void:
	if closed:return
	closed=true;set_process(false)
	if is_instance_valid(scope_root):
		if scope_root.get_meta("native_particle_scene_order",null)==self:scope_root.remove_meta("native_particle_scene_order")
		if scope_root.is_inside_tree() and scope_root.get_tree().tree_changed.is_connected(mark_order_dirty):scope_root.get_tree().tree_changed.disconnect(mark_order_dirty)
	for reference in members.values():
		var emitter: Node3D=reference.get_ref()
		if is_instance_valid(emitter) and emitter.native_scene_order==self:
			emitter.native_scene_order=null;emitter.set_process(false)
	members.clear();ordered.clear()

func _exit_tree() -> void:close()
