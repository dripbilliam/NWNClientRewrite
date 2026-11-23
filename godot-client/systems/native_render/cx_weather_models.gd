extends Node3D
# Custom WeatherTypes rows use the original six model anchors, but their
# emitters register through ActorInstance in the same CX particle presentation.
const Reference=preload("res://systems/native_render/model_reference.gd")
const Placement=preload("res://systems/weather_placement.gd")

var hub: Node
var row_id:=0
var resource:=""
var clip:=""
var references: Array[Node3D]=[]
var density:=-1.0
var anchor_position:=Vector3.INF
var camera_basis:=Basis()
var failures: Dictionary={}

func prepare(owner: Node,next_row: int,model: String,animation: String) -> void:
	set_meta("native_nonblocking_effect",true)
	hub=owner
	row_id=next_row
	resource=model
	clip=animation
	hub.published.connect(_published)
	for index in 6:
		var anchor:=Node3D.new()
		add_child(anchor)
		var reference:=Reference.new()
		reference.original_header={"model":resource}
		references.append(reference)
		anchor.add_child(reference)

func _published(reference: Node3D,model: Node3D) -> void:
	if not reference in references: return
	reference.set_process(false)
	model.rigs.set_process(false)
	for mesh in model.meshes: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if density>=0.0: _sample(reference,density)

func _sample(reference: Node3D,fraction: float) -> void:
	var model: Node3D=reference.model68
	if not is_instance_valid(model) or clip.is_empty(): return
	var accepted: bool=model.rigs.sample_native_clip_fraction(model.object_id,0,clip,fraction)
	if not accepted:
		failures[reference.get_instance_id()]="Original weather clip unavailable: "+resource+"/"+clip
		model.hide()
	else:
		failures.erase(reference.get_instance_id())
		model.show()
	model.rigs.set_process(false)

func advance(position: Vector3,camera: Camera3D,fraction: float) -> void:
	if position!=anchor_position or camera.global_basis!=camera_basis:
		anchor_position=position
		camera_basis=camera.global_basis
		var layout:=Placement.from_camera(position,camera)
		for index in references.size():
			var reference:=references[index]
			var p: Array=layout[index].position
			var q: Array=layout[index].quaternion
			reference.get_parent().global_transform=Transform3D(Basis(Quaternion(q[1],q[3],-q[2],q[0])),Vector3(p[0],p[2],-p[1]))
			reference.synchronize_reference_pose()
	if fraction!=density:
		density=fraction
		for reference in references: _sample(reference,fraction)
	show()

func snapshot() -> Dictionary:
	var entries: Array=[]
	var errors: Array=failures.values()
	for reference in references:
		if not reference.failure.is_empty(): errors.append(reference.failure)
		var model: Node3D=reference.model68
		if is_instance_valid(model):
			entries.append({"position":model.global_position,"clock":model.rigs.playback_state(model.object_id,0)})
	return {"row":row_id,"model":resource,"clip":clip,"instances":entries,"errors":errors}

func retire() -> void:
	hide()
	for reference in references: reference.retire()
	references.clear()
	if is_instance_valid(hub) and hub.published.is_connected(_published): hub.published.disconnect(_published)
	hub=null
	queue_free()
