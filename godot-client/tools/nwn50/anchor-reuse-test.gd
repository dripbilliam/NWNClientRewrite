extends SceneTree

const Lights=preload("res://systems/native_render/placeable_lights.gd")
const ProbeOwner=preload("res://tools/nwn50/anchor-probe-owner.gd")

class ProbeModel:
	extends Node3D
	var probe_owner
	var switch_anchor_on_pose:=false
	var attached_to: Node3D
	func node_for(_id: int,_name: String) -> Node3D:return self
	func set_part_local_pose(_name: String,_position: Array,_rotation: Array) -> void:
		if switch_anchor_on_pose:probe_owner.current_anchor=probe_owner.next_anchor
	func attach_to(target: Node3D) -> void:attached_to=target
	func detach() -> void:attached_to=null
	func retire() -> void:queue_free()

var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var owner:=ProbeOwner.new();root.add_child(owner)
	owner.set_process(false)
	owner.tables={"placeables":{},"lightcolor":{}}
	owner.bundle={"value":{"nodes":[{"position":[0.0,0.0,0.0]}]}}
	var first:=Node3D.new();owner.add_child(first)
	var second:=Node3D.new();owner.add_child(second)
	owner.current_anchor=first;owner.next_anchor=second
	var model:=ProbeModel.new();owner.add_child(model);model.probe_owner=owner
	var plan:={"dynamic":true,"position":[1.0,2.0,3.0],"offset":[0.0,0.0,0.0]}
	owner.instances[7]=model;owner.configurations[7]=plan.duplicate(true);owner.planned={7:plan}
	owner.dirty=true;owner._process(0)
	check(owner.anchor_reads==1 and model.attached_to==first,"Unchanged dynamic plan uses one admission anchor lookup")
	owner.anchor_reads=0;owner.apply(7,plan)
	check(owner.anchor_reads==1 and model.attached_to==first,"Direct apply keeps its own anchor lookup")
	owner.anchor_reads=0;owner.configurations[7]={};model.switch_anchor_on_pose=true
	owner.dirty=true;owner._process(0)
	check(owner.anchor_reads==2 and model.attached_to==second,"Changed plan resolves anchor after model pose mutation")
	owner.anchor_reads=0;owner.current_anchor=null;owner.dirty=true;owner._process(0)
	check(owner.anchor_reads==1 and model.attached_to==second,"Missing admission anchor leaves existing light untouched")
	owner.anchor_reads=0;var static_plan:=plan.duplicate(true);static_plan.dynamic=false
	owner.planned={7:static_plan};owner.configurations[7]=static_plan.duplicate(true);owner.dirty=true;owner._process(0)
	check(owner.anchor_reads==0 and model.attached_to==null and model.position==Vector3(1.0,3.0,-2.0),"Static plan detaches and applies native world pose without anchor lookup")
	owner.close();owner.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures}
	print(JSON.stringify(result))
	quit(0 if result.success else 1)
