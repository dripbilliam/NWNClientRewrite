extends SceneTree
# Isolated real Node3D transform/lifetime tests over authored source descriptors.
# No renderer, original model asset or native instruction execution is claimed.
const Regions=preload("res://tools/native_parity/doors/door_pick_regions.gd")
class DoorOwner extends Node3D:
	var retired:=false
class RigOwner extends Node:
	var entities: Dictionary={}
	var nodes: Array=[]
	func node_at(_id: int,index: int) -> Node3D:return nodes[index] if index>=0 and index<nodes.size() else null
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func source() -> Dictionary:
	return {"value":{"nodes":[{"name":"fixture-hit-part","alpha":0.0,"mesh":{"render":true,"indices":PackedInt32Array([0,1,2]),"native_bounds":{"min":[-0.08,-2.02,0.0],"max":[0.0,0.02,2.97]},"native_bounds_available":true,"native_bounds_valid":true,"native_bounds_source":"binary_mdl_header"}}]}}
func run() -> void:
	var owner:=DoorOwner.new();root.add_child(owner)
	var anchor:=Node3D.new();owner.add_child(anchor)
	var rigs:=RigOwner.new();owner.add_child(rigs);rigs.nodes=[anchor];rigs.entities={77:{"models":[{}],"model_parts":[[0]]}}
	var data:=source();var regions:=Regions.new()
	check(regions.configure(owner,data,rigs,77),"Alpha-zero original Part bounds are retained without a drawn mesh or physics body")
	var hit:=regions.pick(Vector3(1,1,1),Vector3(-1,1,1))
	check(hit.get("hit",false) and hit.position==Vector3(0,1,1) and hit.face==2,"Stable doorway region uses authored maxX0, not vertex-derived -0.08")
	data.value.nodes[0].mesh.native_bounds.max[0]=100
	check(regions.pick(Vector3(1,1,1),Vector3(-1,1,1)).position==Vector3(0,1,1),"Retained numeric bounds are isolated from later input dictionary mutation")
	owner.position=Vector3(10,2,-4);owner.rotation.y=PI/2;owner.scale=Vector3.ONE*2
	var start:=anchor.to_global(Vector3(1,1,1));var end:=anchor.to_global(Vector3(-1,1,1));var expected:=anchor.to_global(Vector3(0,1,1))
	hit=regions.pick(start,end)
	check(hit.get("hit",false) and hit.position.distance_to(expected)<0.00001,"Door root translation/rotation/scale follow the real physical Part")
	anchor.position=Vector3(0.5,0,0)
	start=anchor.to_global(Vector3(1,1,1));end=anchor.to_global(Vector3(-1,1,1));expected=anchor.to_global(Vector3(0,1,1))
	check(regions.pick(start,end).position.distance_to(expected)<0.00001,"A subsequent physical Part transform is read at query time")
	var inside:=regions.pick(anchor.to_global(Vector3(-0.04,1,1)),end)
	check(not inside.available and inside.reason.contains("inside-hit"),"Unimplemented native outer inside-hit semantics remain explicit")
	owner.hide();check(not regions.pick(start,end).available,"A retired/hidden root cannot remain an admitted selection region")
	owner.show();owner.retired=true;check(not regions.pick(start,end).available,"Retirement fences still-live physical Nodes")
	owner.retired=false
	var snapshot:=regions.snapshot();snapshot.missing.append({"fake":true})
	check(regions.snapshot().missing.is_empty(),"Cold diagnostic data is detached from retained state")
	anchor.free();check(not regions.pick(start,end).get("hit",false),"Freed physical Part is rejected through its weak reference")
	owner.free();check(not regions.pick(start,end).available,"Freed model lifetime cannot resolve to a later object with the same object ID")
	var replacement:=DoorOwner.new();root.add_child(replacement)
	check(not regions.pick(start,end).available,"Replacement owner does not revive a retired owner reference")
	replacement.free();regions.retire()
	check(regions.snapshot().retired and regions.snapshot().regions==0,"Explicit retirement releases region references")
	print("NATIVE_PARITY_DOOR_REGIONS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
