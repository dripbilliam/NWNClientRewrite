extends "res://tests/native_model_control_test.gd"
class CountedPose extends Pose:
	var read_arrays:=0
	func read(part: Dictionary,offset: int,count: int) -> Array:
		read_arrays+=1
		return super.read(part,offset,count)
var hierarchy_cases:=0
var material_cases:=0
var read_requests:={"reference":0,"direct":0}
func hierarchy_case(row: Dictionary,index: int) -> void:
	super.hierarchy_case(row,index)
	var c: Dictionary=row.case; var calls: Array=[]; var parts: Array=[]; var tree: Array=[]
	var ids: Array=[0]+c.physicalIds+[3]; var animation_ids: Array=[0]+c.animationIds+[3]
	for n in ids.size():
		parts.append({"name":"part"+str(n),"id30":ids[n],"dirty60":c.childDirty if n else c.dirty,"owner50":{},"childCount40":0,"children38":[]})
		tree.append({"name":"node"+str(n),"id34":animation_ids[n],"childCount70":0,"children68":[]})
	parts[0].children38=parts.slice(1,4); parts[0].childCount40=3; parts[1].children38=[parts[4]]; parts[1].childCount40=1
	tree[0].children68=tree.slice(1,4); tree[0].childCount70=3; tree[int(c.grandchildAt)].children68=[tree[4]]; tree[int(c.grandchildAt)].childCount70=1
	var context:={"depth":c.depth}
	Controls.hierarchy_root(parts[0],tree[0],-0.25,0.75,0.3,context,{"control":func(node,part,previous,time,weight):calls.append(["control",node.name,part.name,previous,time,weight]),"light":func(part):calls.append(["light",part.name]);return {"field8c":c.lightFlag} if c.light else null,"animateStaticLight":func(_owner,_light):calls.append(["AnimateStaticLight","light"])})
	expect({"calls":calls,"depth":context.depth},{"calls":row.calls,"depth":row.depth},"Root-quantized hierarchy exact original trace "+str(index)); hierarchy_cases+=1
func material_owner(style: int,direct: bool) -> Dictionary:
	var node:=Node3D.new(); root.add_child(node); var mesh:=MeshInstance3D.new(); node.add_child(mesh); mesh.mesh=BoxMesh.new()
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(0.13,0.52,0.91,0.61)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if style>=2 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if style%2==0: mesh.material_override=material
	else: mesh.set_surface_override_material(0,material)
	var control:={"id34":0,"flags98":0,"controllers78":[],"controllerCount80":0,"values88":PackedFloat32Array(),"children68":[],"childCount70":0}
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"trimesh","node":control,"properties":{},"children":[],"transparencyHint":style==3}]}
	var pose:=CountedPose.new(); pose.compiled_controls=true; pose.direct_flush=direct; pose.root_hierarchy=direct; pose.configure(metadata,{"parts":[0]},[node])
	return {"pose":pose,"node":node,"material":mesh.get_active_material(0),"base":material}
func material_state(value: Dictionary) -> Array:
	return [value.node.transform,value.material.albedo_color,value.material.emission_enabled,value.material.emission,value.material.transparency]
func materials() -> void:
	for style in 4:
		var a:=material_owner(style,false); var b:=material_owner(style,true)
		expect(a.material!=a.base and b.material!=b.base,true,"Both paths animate private active material copies")
		expect(material_state(a),material_state(b),"Initial direct material/transform publication "+str(style))
		for step in 96:
			var alpha: float=[-0.25,0.0,0.2,0.999,1.0,1.5][step%6]
			var color: Array=[[0.0,0.0,0.0],[0.01,0.04045,0.9],[-0.2,2.0,1.0],[1.0,0.5,0.25]][(step/6)%4]
			var q:=Quaternion(Vector3(1,2,3).normalized(),step*0.017)
			for value in [a,b]:
				for scope in 5: value.pose.set_colour_scope(scope,null)
				if step%4 in [1,2,3]: value.pose.set_colour_scope(2,[0.8,0.1,0.4])
				if step%4==2: value.pose.set_colour_scope(0,[0.1,0.6,0.3])
				if step%4==3: value.pose.set_colour_scope(4,[1.0,1.0,1.0])
				value.pose.write(value.pose.parts[0],16,[-0.3,step*0.1,-2.0]); value.pose.write(value.pose.parts[0],28,[q.w,q.x,-q.z,q.y])
				value.pose.write(value.pose.parts[0],44,[[-1.5,0.25,2.0,1.0][step%4]]); value.pose.write(value.pose.parts[0],168,[alpha]); value.pose.write(value.pose.parts[0],128,color)
			var before_a: int=a.pose.read_arrays; var before_b: int=b.pose.read_arrays
			var manual:={0:true} if step%7==0 else {}
			a.pose.flush(manual); b.pose.flush(manual)
			expect(material_state(a),material_state(b),"Exact direct material/scoped-colour/alpha/manual publication %d/%d"%[style,step])
			expect(a.pose.read_arrays-before_a,0 if not manual.is_empty() else 5,"Reference flush read Array requests are actually observed")
			expect(b.pose.read_arrays-before_b,0,"Direct flush constructs no read Arrays")
			material_cases+=1
		read_requests.reference+=a.pose.read_arrays; read_requests.direct+=b.pose.read_arrays
		expect(a.pose.read_arrays>0 and b.pose.read_arrays==0,true,"Instrumented actual read overrides distinguish both paths")
		a.node.free(); b.node.free()
func rejects_and_owner() -> void:
	super.rejects_and_owner(); materials()
func extra_evidence() -> Dictionary:
	return {"optimized_hierarchy_original_cases":hierarchy_cases,"material_cases":material_cases,"explicit_read_array_constructions":read_requests,"allocation_scope":"Counts actual calls that construct read Arrays through a test-only Pose override. Not all engine allocations, transient capacities, rounding arrays, OS memory or a GPU timing claim."}
