extends "res://tests/native_model_pose_allocations_test.gd"
var native_hierarchy_cases:=0
var private_cases:=0
func hierarchy_case(row: Dictionary,index: int) -> void:
	super.hierarchy_case(row,index)
	var c: Dictionary=row.case;var calls: Array=[];var parts: Array=[];var tree: Array=[]
	var ids: Array=[0]+c.physicalIds+[3];var animation_ids: Array=[0]+c.animationIds+[3]
	for n in ids.size():
		parts.append({"name":"part"+str(n),"id30":ids[n],"dirty60":c.childDirty if n else c.dirty,"owner50":{},"childCount40":0,"children38":[]})
		tree.append({"name":"node"+str(n),"id34":animation_ids[n],"childCount70":0,"children68":[]})
	parts[0].children38=parts.slice(1,4);parts[0].childCount40=3;parts[1].children38=[parts[4]];parts[1].childCount40=1
	tree[0].children68=tree.slice(1,4);tree[0].childCount70=3;tree[int(c.grandchildAt)].children68=[tree[4]];tree[int(c.grandchildAt)].childCount70=1
	var context:={"depth":c.depth}
	var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",parts[0],tree[0],-0.25,0.75,0.3,1.0,context,{"control":func(node,part,previous,time,weight):calls.append(["control",node.name,part.name,previous,time,weight]),"light":func(part):calls.append(["light",part.name]);return {"field8c":c.lightFlag} if c.light else null,"animateStaticLight":func(_owner,_light):calls.append(["AnimateStaticLight","light"])})
	expect(result.has("error"),false,"Native original hierarchy accepts captured case "+str(index))
	expect({"calls":calls,"depth":context.depth},{"calls":row.calls,"depth":row.depth},"Native physical hierarchy exact original trace "+str(index));native_hierarchy_cases+=1
func private_owner(kind: String,flags: int,bulk: bool) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var node:={"id34":0,"flags98":flags,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"children68":[],"childCount70":0}
	var source:={"root":0,"emitterFields":{},"parts":[{"type":kind,"node":node,"properties":{},"children":[],"transparencyHint":false}]}
	var pose:=Pose.new();pose.compiled_controls=true;pose.bulk_evaluation=bulk;pose.configure(source,{"parts":[0]},[host])
	return {"host":host,"pose":pose,"tree":node}
func private_modes() -> void:
	for kind in ["dummy","light","trimesh","emitter"]:
		for flags in [0,128,256,384]:
			var a:=private_owner(kind,flags,false);var b:=private_owner(kind,flags,true)
			for step in 4:
				var manual:={0:true} if step==2 else {}
				a.pose.apply(a.tree,-0.3,step*0.21,0.3,1.25,manual);b.pose.apply(b.tree,-0.3,step*0.21,0.3,1.25,manual)
				expect(a.pose.parts[0].view,b.pose.parts[0].view,"Exact private empty-control Part bytes "+kind+str(flags)+str(step))
				expect(a.host.transform,b.host.transform,"Exact private empty-control placement "+kind+str(flags)+str(step))
				expect(a.pose.diagnostics,b.pose.diagnostics,"Animated vertex/dangly/static light/manual diagnostic order is retained "+kind+str(flags)+str(step));private_cases+=1
			expect(b.pose.bulk_calls>0 and b.pose.bulk_failures==0,true,"Actual pose uses the bulk path without fallback")
			a.host.free();b.host.free()
func mutation_trace(native: bool) -> Dictionary:
	var calls: Array=[];var context:={"depth":0};var second:={"name":"part2","id30":2,"dirty60":0,"owner50":{},"childCount40":0,"children38":[]}
	var root_part:={"name":"root","id30":0,"dirty60":0,"owner50":{},"childCount40":1,"children38":[second]}
	var node2:={"name":"node2","id34":2,"childCount70":0,"children68":[]}
	var node:={"name":"root","id34":0,"childCount70":1,"children68":[node2]}
	var p:={"control":func(n,part,_previous,_time,_weight):calls.append(["control",n.name,part.name]);if part.name=="root":second.dirty60=1;node.children68[0]={"name":"replacement","id34":2,"childCount70":0,"children68":[]},"light":func(part):calls.append(["light",part.name]);return null,"animateStaticLight":func(_owner,_light):pass}
	if native:
		var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",root_part,node,0.0,1.0,0.5,1.0,context,p)
		expect(result.has("error"),false,"Live callback mutation native input accepted")
	else:Controls.hierarchy_root(root_part,node,0.0,1.0,0.5,context,p)
	p.clear();return {"calls":calls,"depth":context.depth}
func partial_failure() -> void:
	var a:=private_owner("dummy",0,false);var child:=private_owner("dummy",0,false)
	var controller:={"displacement0":16,"rows4":1,"timeIndex6":0,"valueIndex8":1,"columnsA":3}
	for value in [a,child]: value.tree.controllers78=[controller];value.tree.controllerCount80=1;value.tree.values88=PackedFloat32Array([0.0,1.0,2.0,3.0])
	a.pose.root_part.children38=[child.pose.root_part];a.pose.root_part.childCount40=1;a.tree.children68=[child.tree];a.tree.childCount70=1
	child.pose.root_part.view=PackedByteArray()
	var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",a.pose.root_part,a.tree,0.0,0.0,1.0,1.0,{"depth":0},{})
	expect(result.has("error") and result.partial,true,"A later invalid Part is an explicit partial imperative failure")
	expect(a.pose.read(a.pose.root_part,16,3),[1.0,2.0,3.0],"Earlier native Part mutation survives exactly once; no automatic script replay")
	a.host.free();child.host.free()
func rejects_and_owner() -> void:
	super.rejects_and_owner();private_modes();expect(mutation_trace(false),mutation_trace(true),"Callback child replacement and manual gate mutations remain live");partial_failure()
func extra_evidence() -> Dictionary:
	var result:=super.extra_evidence();result.merge({"native_hierarchy_original_cases":native_hierarchy_cases,"private_bulk_cases":private_cases,"native_hierarchy_scope":"Exact original generic traversal callback corpus plus private known no-motion production control, manual/diagnostic and partial-failure behavior. Generic custom ports and private optimized execution are separate modes."});return result
