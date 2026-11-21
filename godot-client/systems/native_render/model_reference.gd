extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Original PartReference owns an independent model. Packed templates keep only
# this immutable header; asynchronous native preparation/publication is scoped
# to the admitted world and never creates a canonical game object.
@export var original_header: Dictionary={}
@export var origin_resource: String=""
var model68: Node3D
var hub
var retired:=false
var failure:=""
var revision:=0
var generation:=-1
var external_anchor: WeakRef
func _ready() -> void:
	process_priority=10; add_to_group("native_original_model_references")
	set_meta("native_reference_origin",origin_resource.to_lower())
	var ancestor:=get_parent(); var ancestors: Array=[origin_resource.to_lower()]; var depth:=0
	while ancestor!=null:
		if ancestor.has_meta("native_reference_origin"):
			ancestors.append(str(ancestor.get_meta("native_reference_origin")).to_lower()); depth+=1
		if hub==null and ancestor.has_meta("native_reference_hub"): hub=ancestor.get_meta("native_reference_hub")
		ancestor=ancestor.get_parent()
	# Binary decoding already terminates the original fixed-width name. Godot
	# Strings cannot contain a NUL delimiter; do not construct one here.
	var resource:=str(original_header.get("model","")).to_lower()
	if resource.is_empty(): reject("Original reference model name is empty"); return
	if resource in ancestors or depth>=16: reject("Original model reference resource cycle/depth: "+resource); return
	if not is_instance_valid(hub): reject("Native reference catalog scope is unavailable: "+resource); return
	hub.request_reference(self,resource)
func reject(reason: String) -> void:
	if retired: return
	failure=reason; revision+=1; set_process(false); push_warning(reason)
	if is_instance_valid(model68): model68.visible=false
func reattach_to(anchor: Node3D) -> bool:
	if retired or not is_instance_valid(model68): return false
	if anchor!=null and (not is_instance_valid(anchor) or is_ancestor_of(anchor)): return false
	external_anchor=weakref(anchor) if anchor!=null else null; failure=""; revision+=1; set_process(true); model68.visible=true; synchronize_reference_pose(); return true
func install_model(value: Node3D,epoch: int) -> bool:
	if retired or not is_inside_tree() or epoch!=generation or model68!=null: return false
	model68=value; add_child(value); value.top_level=true; revision+=1
	synchronize_reference_pose(); return true
func synchronize_reference_pose() -> void:
	if retired or not is_instance_valid(model68) or not get_parent() is Node3D: return
	# P/Q attachment follows the original anchor without inheriting its scale.
	# Synchronize the nearest enclosing reference first for nested models.
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor.has_method("synchronize_reference_pose"): ancestor.synchronize_reference_pose(); break
		ancestor=ancestor.get_parent()
	var anchor: Node3D=get_parent() if external_anchor==null else external_anchor.get_ref()
	if not is_instance_valid(anchor) or anchor.is_queued_for_deletion(): reject("Native reference external anchor retired"); return
	var rotation:=anchor.global_basis.orthonormalized().get_rotation_quaternion()
	model68.global_transform=Transform3D(Basis(rotation),anchor.global_position)
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_reference_poses",began)
func _profile_process(_delta: float) -> void: synchronize_reference_pose()
func snapshot() -> Dictionary:
	return {"resource":original_header.get("model",""),"present":is_instance_valid(model68),"generation":generation,"revision":revision,"failure":failure,"reattachable":original_header.get("reattachable",0)}
func retire() -> void:
	if retired: return
	retired=true; revision+=1; set_process(false)
	if is_instance_valid(hub): hub.cancel_reference(self)
	if is_instance_valid(model68): model68.retire()
	model68=null; hub=null; external_anchor=null
func _exit_tree() -> void: retire()
