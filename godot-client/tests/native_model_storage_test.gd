extends "res://tests/native_model_plan_test.gd"
class TransformProbe extends Node3D:
	var callback: Callable
	func _notification(what: int) -> void:
		if what==NOTIFICATION_LOCAL_TRANSFORM_CHANGED and callback.is_valid(): callback.call()
var native_material_cases:=0
var lifetime_cases:=0
var native_physical_cases:=0
func hierarchy_case(row: Dictionary,index: int) -> void:
	super.hierarchy_case(row,index)
	var c: Dictionary=row.case
	if int(c.depth)!=0:return
	var host:=Node3D.new();root.add_child(host);var records: Array=[];var tree: Array=[];var manual: Dictionary={}
	var ids: Array=[0]+c.physicalIds+[3];var animation_ids: Array=[0]+c.animationIds+[3]
	for n in ids.size():
		var node:=Node3D.new();host.add_child(node)
		var view:=PackedByteArray();view.resize(0x240);view.fill(0);view.encode_float(28,1.0);view.encode_float(44,7.0)
		var dirty: int=int(c.childDirty if n else c.dirty)
		if dirty:manual[n]=true
		records.append({"object":node,"id30":int(ids[n]),"dirty60":dirty,"field8c":int(c.lightFlag),"view":view,"fields":{16:3,28:4,44:1},"materials":[],"source":{"type":"light" if c.light else "dummy","children":[]}})
		var animation:=source_node(int(animation_ids[n]));animation.controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":n+1,"displacement0":44}];animation.controllerCount80=1;animation.values88=PackedFloat32Array([0,1,2,3,4,5]);tree.append(animation)
	records[0].source.children=[1,2,3];records[1].source.children=[4];tree[0].children68=tree.slice(1,4);tree[0].childCount70=3;tree[int(c.grandchildAt)].children68=[tree[4]];tree[int(c.grandchildAt)].childCount70=1
	var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
	var configured: Dictionary=context.call("dispatch",0,{"parts":records,"binding":[0,1,2,3,4],"root":0,"emitter_fields":{}})
	var plan:=prepare(tree[0]);var actual: Dictionary=context.call("dispatch",1,{"plan":plan.plan,"time":0.75,"weight":0.3,"scale":1.0,"manual":manual,"profile":false,"scope":null})
	expect(configured.get("error",""),"","Native physical topology configures "+str(index))
	expect(actual.get("error",""),"","Native persistent physical case accepts original topology "+str(index))
	if configured.has("error") or actual.has("error"):
		context.call("dispatch",8,{});host.free();return
	var controlled: Dictionary={}
	for call in row.calls:
		if call[0]=="control":controlled[int(str(call[2]).trim_prefix("part"))]=int(str(call[1]).trim_prefix("node"))+1
	expect(int(actual.controls),controlled.size(),"Persistent traversal preserves original physical admission count")
	var snapshot: Dictionary=context.call("dispatch",5,{})
	for n in records.size():
		var expected:=Controls.f(Controls.f(Controls.f(1-Controls.f(0.3))*7.0)+Controls.f(float(controlled[n])*Controls.f(0.3))) if controlled.has(n) else 7.0
		expect(snapshot.views[n].decode_float(44),expected,"Persistent rotated-ID/manual physical walk equals original instruction trace")
	context.call("dispatch",8,{});host.free();native_physical_cases+=1
func material_owner(style: int,direct: bool) -> Dictionary:
	var node:=TransformProbe.new();root.add_child(node);var mesh:=MeshInstance3D.new();node.add_child(mesh);mesh.mesh=BoxMesh.new()
	var material:=StandardMaterial3D.new();material.albedo_color=Color(0.13,0.52,0.91,0.61)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if style>=2 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if style%2==0:mesh.material_override=material
	else:mesh.set_surface_override_material(0,material)
	var control:=source_node()
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":control,"properties":{},"children":[],"transparencyHint":style==3}]}
	var pose:=CountedPose.new();pose.compiled_controls=true;pose.direct_flush=direct;pose.bulk_evaluation=true;pose.prepared_plan=true;pose.native_storage=direct;pose.configure(metadata,{"parts":[0]},[node])
	if direct:expect(pose.native_context!=null and pose.native_failures==0,true,"Native storage actually configures for publication oracle");native_material_cases+=1
	return {"pose":pose,"node":node,"material":mesh.get_active_material(0),"base":material}
func storage_lifetime_owner() -> WeakRef:
	var value:=material_owner(0,true);var pose=value.pose;var context: RefCounted=pose.native_context
	var prior: PackedByteArray=pose.parts[0].view
	pose.write(pose.parts[0],16,[1.0,2.0,3.0]);expect(prior,pose.parts[0].view,"Explicit writes preserve existing exported array aliases")
	expect(pose.read(pose.parts[0],16,3),[1.0,2.0,3.0],"Explicit reads observe current native state")
	var count_before:=int(pose.storage_statistics().snapshot_arrays)
	pose.flush({0:true});expect(pose.parts[0].dirty60,0,"Flush-only manual skip does not change traversal dirty state")
	expect(int(pose.storage_statistics().snapshot_arrays),count_before,"Unchanged snapshot revisions allocate no new Part arrays")
	var tree:=source_node();tree.controllers78=[{"displacement0":16,"rows4":1,"timeIndex6":0,"valueIndex8":1,"columnsA":3}];tree.controllerCount80=1;tree.values88=PackedFloat32Array([0,4,5,6])
	var plan:=prepare(tree);pose.apply(tree,0,0,1,1,{0:true},{"blob":plan.plan})
	expect(pose.parts[0].dirty60,1,"Native traversal publishes observable manual dirty state")
	pose.flush({});expect(pose.parts[0].dirty60,1,"Later publication preserves prior dirty state")
	var observed: Array=[];value.node.set_notify_local_transform(true)
	value.node.callback=func():
		observed.append(pose.read(pose.parts[0],16,3));pose.close()
	pose.apply(tree,0,0,1,1,{}, {"blob":plan.plan})
	expect(observed,[[4.0,5.0,6.0]],"Synchronous transform callback sees current snapshot and can close owner exactly once")
	var after: Dictionary=context.call("dispatch",7,{})
	expect(after.closed and after.parts==0 and pose.native_context==null,true,"In-flight native close defers reclamation and stops remaining publication")
	expect(pose.parts.is_empty() and pose.root_part.is_empty(),true,"Close clears script record bindings too")
	context.call("dispatch",8,{});expect(context.call("dispatch",7,{}).parts,0,"Repeated close is harmless")
	value.node.callback=Callable();value.node.free();value.clear();context=null
	var weak: WeakRef=weakref(pose);pose=null;return weak
func storage_lifetime() -> void:
	var weak:=storage_lifetime_owner()
	expect(weak.get_ref(),null,"No native owner/callback cycle retains the retired Pose after the callback fixture returns")
	lifetime_cases+=1
func publication_callback(native: bool) -> Array:
	var value:=material_owner(0,native);var pose=value.pose;var node=value.node
	pose.direct_flush=true
	pose.write(pose.parts[0],16,[1.0,2.0,3.0]);pose.write(pose.parts[0],168,[0.4])
	var seen: Array=[];node.set_notify_local_transform(true)
	node.callback=func():
		if not seen.is_empty():return
		seen.append(pose.parts[0].view.duplicate());pose.write(pose.parts[0],168,[0.8])
	pose.flush({});var result:=[value.material.albedo_color,pose.read(pose.parts[0],168,1),seen]
	node.callback=Callable();pose.close();node.free();return result
func rejects_and_owner() -> void:
	super.rejects_and_owner();storage_lifetime()
	expect(publication_callback(false),publication_callback(true),"Synchronous explicit writes remain visible to publication through the current Part alias")
func extra_evidence() -> Dictionary:
	var result:=super.extra_evidence();result.native_material_owners=native_material_cases;result.native_storage_lifetime_cases=lifetime_cases;result.native_storage_original_physical_cases=native_physical_cases;return result
