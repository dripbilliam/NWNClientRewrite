extends "res://tests/native_model_hierarchy_test.gd"
const Plans=preload("res://systems/native_data/model_control_plan.gd")
var prepared_samples:=0
var prepared_physical_cases:=0
var prepared_depth_cases:=0
func leaf(view: PackedByteArray,fields: Dictionary,id: int=0) -> Dictionary:
	return {"id30":id,"dirty60":0,"source":{"type":"dummy"},"field8c":0,"owner50":null,"children38":[],"childCount40":0,"view":view,"fields":fields}
func source_node(id: int=0) -> Dictionary:
	return {"id34":id,"flags98":0,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"children68":[],"childCount70":0}
func prepare(node: Dictionary) -> Dictionary:
	return ClassDB.class_call_static("NwnParticleKernel","model_prepare",node)
func evaluate(part: Dictionary,node: Dictionary,blob: Variant,time: float=0.0,weight: float=1.0,scale_value: float=1.0,context: Dictionary={"depth":0}) -> Dictionary:
	return ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",part,node,0.0,time,weight,scale_value,context,{"plan":blob})
func compiled_samples(kind: String,rows: Array) -> void:
	super.compiled_samples(kind,rows)
	var pool: Array=[]
	for index in 65600: pool.append(Controls.f(((index*13)%37-18)*0.125))
	for index in rows.size():
		var row: Dictionary=rows[index];var c: Dictionary=row.case
		for n in c.times.size(): pool[n]=Controls.f(c.times[n])
		var mode:=1 if kind=="float-sample" else 3 if kind=="vector-sample" else 4
		if mode==4:
			for n in c.quaternions.size():
				for axis in 4: pool[int(c.valueBase)+n*4+axis]=Controls.f(c.quaternions[n][axis])
		if int(row.result)!=1: continue
		var offset:=int(c.get("displacement",0));var node:=source_node()
		node.controllers78=[{"rows4":int(c.rows),"columnsA":int(c.flags),"timeIndex6":0,"valueIndex8":int(c.valueBase),"displacement0":offset}];node.controllerCount80=1;node.values88=PackedFloat32Array(pool)
		var view:=PackedByteArray();view.resize(0x240);view.fill(0)
		for axis in mode: view.encode_float(offset+axis*4,1.0 if mode==4 and axis==0 else -0.25*(axis+1))
		var before:=view.duplicate();var fields:={offset:mode};var part:=leaf(view,fields);var plan:=prepare(node)
		expect(plan.has("error"),false,"Original sample compiles into immutable numeric records "+kind+str(index))
		if plan.has("error"):continue
		var reference: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_control",node,view,fields,float(c.time),0.73,float(c.get("scale",1.0)))
		var actual:=evaluate(part,node,plan.plan,float(c.time),0.73,float(c.get("scale",1.0)))
		expect(actual.has("error") or reference.has("error"),false,"Both original-sample blend paths accept exact fields")
		expect(actual.get("prepared",false),true,"Prepared dispatch was actually used")
		if reference.has("view"):expect(part.view,reference.view,"Exact prepared original-sample Part bytes "+kind+str(index))
		expect(view,before,"Prepared output never mutates the prior retained Part view");prepared_samples+=1
func hierarchy_case(row: Dictionary,index: int) -> void:
	super.hierarchy_case(row,index)
	var c: Dictionary=row.case
	if int(c.depth)!=0:return
	var parts: Array=[];var tree: Array=[];var ids: Array=[0]+c.physicalIds+[3];var animation_ids: Array=[0]+c.animationIds+[3]
	var values:=PackedFloat32Array([0,1,2,3,4,5])
	for n in ids.size():
		var view:=PackedByteArray();view.resize(0x240);view.fill(0);view.encode_float(44,7.0)
		var part:=leaf(view,{44:1},int(ids[n]));part.dirty60=c.childDirty if n else c.dirty;part.source.type="light" if c.light else "dummy";part.field8c=c.lightFlag;parts.append(part)
		var node:=source_node(int(animation_ids[n]));node.controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":n+1,"displacement0":44}];node.controllerCount80=1;node.values88=values;tree.append(node)
	parts[0].children38=parts.slice(1,4);parts[0].childCount40=3;parts[1].children38=[parts[4]];parts[1].childCount40=1
	tree[0].children68=tree.slice(1,4);tree[0].childCount70=3;tree[int(c.grandchildAt)].children68=[tree[4]];tree[int(c.grandchildAt)].childCount70=1
	var plan:=prepare(tree[0]);expect(plan.has("error"),false,"Original zero-depth physical case prepares "+str(index))
	if plan.has("error"):return
	var actual:=evaluate(parts[0],tree[0],plan.plan,0.75,0.3);var controlled: Dictionary={}
	for call in row.calls:
		if call[0]=="control": controlled[int(str(call[2]).trim_prefix("part"))]=int(str(call[1]).trim_prefix("node"))+1
	expect(actual.has("error"),false,"Prepared physical walk accepts admitted private case")
	expect(int(actual.controls),controlled.size(),"Prepared physical admission count matches original instruction trace")
	for n in parts.size():
		var expected:=7.0
		if controlled.has(n):expected=Controls.f(Controls.f(Controls.f(1-Controls.f(0.3))*7.0)+Controls.f(float(controlled[n])*Controls.f(0.3)))
		expect(parts[n].view.decode_float(44),expected,"Prepared Part identity/order/manual result matches original trace "+str(index)+"/"+str(n))
	prepared_physical_cases+=1
func ownership_and_cache() -> void:
	var node:=source_node();node.controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":44}];node.controllerCount80=1;node.values88=[0.0,2.0]
	var original:=prepare(node);expect(original.has("error"),false,"Array keys prepare as immutable binary32 data")
	var bytes: PackedByteArray=original.plan;var before:=bytes.duplicate();node.values88[1]=9.0
	expect(bytes,before,"Caller key mutation cannot change the already prepared immutable snapshot")
	var view:=PackedByteArray();view.resize(0x240);view.fill(0);var part:=leaf(view,{44:1});var result:=evaluate(part,node,bytes)
	expect(result.has("error"),false,"Prepared snapshot remains independently evaluable")
	expect(part.view.decode_float(44),2.0,"Immutable snapshot retains the original key, not later caller mutation")
	var a:=Plans.acquire(node);var b:=Plans.acquire(node);var generation:=Plans.acquire(node.duplicate(true))
	expect(a.hit,false,"First source root prepares a shared sidecar")
	expect(b.hit and is_same(a.value,b.value),true,"Exact immutable root identity reuses one shared plan")
	expect(generation.hit,false,"A new resource-generation root cannot reuse a stale plan")
	var reference: WeakRef=weakref(a.value);a.clear();b.clear();generation.clear()
	expect(reference.get_ref()==null and Plans.retained().plans==0,true,"Weak cache cannot retain a closed owner, source tree or packed plan")
	for mode in ["magic","version","offset","length","type"]:
		var broken: Variant=bytes.duplicate()
		if mode=="magic":broken.encode_u32(0,0)
		elif mode=="version":broken.encode_u32(4,2)
		elif mode=="offset":broken.encode_u32(28,0xfffffff0)
		elif mode=="length":broken.resize(broken.size()-1)
		else:broken=[]
		var context:={"depth":0};var prior: PackedByteArray=part.view;var rejected:=evaluate(part,node,broken,0.0,1.0,1.0,context)
		expect(rejected.has("error") and not rejected.partial,true,"Invalid prepared bounds reject before imperative state: "+mode)
		expect(context.depth==0 and part.view==prior,true,"Invalid prepared input changes neither depth nor Part storage")
func deep_gate() -> void:
	var parts: Array=[];var nodes: Array=[]
	for index in 1001:parts.append(leaf(PackedByteArray(),{},index));nodes.append(source_node(index))
	for index in 1000:parts[index].children38=[parts[index+1]];parts[index].childCount40=1;nodes[index].children68=[nodes[index+1]];nodes[index].childCount70=1
	var plan:=prepare(nodes[0]);expect(plan.has("error"),false,"Deep original gate compiles only reachable animation depth")
	if plan.has("error"):return
	var context:={"depth":0};var actual:=evaluate(parts[0],nodes[0],plan.plan,0.0,1.0,1.0,context)
	expect(not actual.has("error") and int(actual.controls)==1000 and int(plan.nodes)==1000 and context.depth==0,true,"Private prepared traversal retains the original 1000-depth boundary")
	prepared_depth_cases+=1
func private_prepared_modes() -> void:
	for kind in ["dummy","light","trimesh","emitter"]:
		for flags in [0,128,256,384]:
			var a:=private_owner(kind,flags,false);var b:=private_owner(kind,flags,true);var result:=prepare(b.tree)
			expect(result.has("error"),false,"Private flags prepare without touching unavailable solver state")
			if result.has("error"):a.host.free();b.host.free();continue
			for step in 4:
				var manual:={0:true} if step==2 else {}
				a.pose.apply(a.tree,-0.3,step*0.21,0.3,1.25,manual);b.pose.apply(b.tree,-0.3,step*0.21,0.3,1.25,manual,{"blob":result.plan})
				expect(a.pose.parts[0].view,b.pose.parts[0].view,"Prepared empty/manual private Part bytes "+kind+str(flags)+str(step))
				expect(a.host.transform,b.host.transform,"Prepared empty/manual physical placement "+kind+str(flags)+str(step))
				expect(a.pose.diagnostics,b.pose.diagnostics,"Prepared animated-vertex/dangly/light diagnostic order "+kind+str(flags)+str(step))
			expect(b.pose.prepared_calls==4 and b.pose.prepared_failures==0,true,"Private prepared modes execute without replay/failure")
			a.host.free();b.host.free()
func ieee_key_identity() -> void:
	var negative:=PackedByteArray([0,0,0,128]).decode_float(0)
	var nodes:=[source_node(),source_node(1)]
	for n in 2:nodes[n].controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":44}];nodes[n].controllerCount80=1;nodes[n].values88=PackedFloat32Array([0.0,0.0 if n==0 else negative])
	nodes[0].children68=[nodes[1]];nodes[0].childCount70=1
	var result:=prepare(nodes[0]);expect(not result.has("error") and result.pools==2,true,"Distinct packed key storage is not merged by numeric zero equality")
	if result.has("error"):return
	var data: PackedByteArray=result.plan;var pool_at:=int(data.decode_u32(36));var float_at:=int(data.decode_u32(44))
	expect(data.decode_u32(float_at+(int(data.decode_u32(pool_at))+1)*4),0,"Prepared positive zero retains its source bits")
	expect(data.decode_u32(float_at+(int(data.decode_u32(pool_at+8))+1)*4),0x80000000,"Prepared negative zero retains its source bits")
	var view:=PackedByteArray();view.resize(0x240);view.fill(0);view.encode_float(44,negative)
	var a:=leaf(view,{44:1});a.children38=[leaf(view.duplicate(),{44:1},1)];a.childCount40=1;var b: Dictionary=a.duplicate(true)
	var dynamic: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",a,nodes[0],0.0,0.0,1.0,1.0,{"depth":0},{})
	var prepared:=evaluate(b,nodes[0],result.plan)
	expect(not dynamic.has("error") and not prepared.has("error") and a.view==b.view and a.children38[0].view==b.children38[0].view,true,"IEEE key distinctions survive actual dynamic/prepared Part blending")
func ignored_kinds_and_partial() -> void:
	var node:=source_node();node.values88=PackedFloat32Array();node.controllerCount80=1
	var view:=PackedByteArray();view.resize(0x240);view.fill(0)
	for kind in [0,2,5,15]:
		node.controllers78=[{"rows4":123,"columnsA":kind,"timeIndex6":65535,"valueIndex8":65535,"displacement0":0x7fffffff}]
		var plan:=prepare(node);var part:=leaf(view,{})
		expect(plan.has("error"),false,"Unused controller metadata prepares without reading absent keys")
		if plan.has("error"):continue
		var result:=evaluate(part,node,plan.plan)
		expect(not result.has("error") and part.view==view,true,"Unsupported controller kinds retain the original no-op without validating unused fields")
	var child:=source_node(1);var values:=PackedFloat32Array([0,2,3])
	for n in [node,child]:n.values88=values;n.controllers78=[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1 if n==node else 2,"displacement0":44}];n.controllerCount80=1
	node.children68=[child];node.childCount70=1
	var plan:=prepare(node);var part:=leaf(view,{44:1});part.children38=[leaf(PackedByteArray(),{44:1},1)];part.childCount40=1;var context:={"depth":0}
	var failed:=evaluate(part,node,plan.plan,0.0,1.0,1.0,context)
	expect(failed.has("error") and failed.partial and context.depth==2,true,"Prepared later-Part failure explicitly retains imperative partial depth/state")
	expect(part.view.decode_float(44),2.0,"Prepared earlier Part mutation survives once, without a scripted replay")
func rejects_and_owner() -> void:
	super.rejects_and_owner();ownership_and_cache();deep_gate();private_prepared_modes();ieee_key_identity();ignored_kinds_and_partial()
func extra_evidence() -> Dictionary:
	var result:=super.extra_evidence();result.merge({"prepared_sample_cases":prepared_samples,"prepared_original_physical_cases":prepared_physical_cases,"prepared_depth_cases":prepared_depth_cases,"prepared_scope":"Original sample fields blended by dynamic and typed key paths, zero-depth private physical cases matched to original callback observations, immutable snapshot storage, shared weak-cache identity/generation/cleanup, malformed plan bounds and actual 1000-depth reachability. Preparation is a private immutable-data contract; generic mutable callback interpreters remain on the retained path."});return result
