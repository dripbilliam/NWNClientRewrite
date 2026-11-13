extends "res://tests/model_controllers_test.gd"
# Retained original executable observations, plus the actual bulk Part entry
# point. The motion-callback cases remain on their existing provider path.
const Pose=preload("res://systems/model_native_pose.gd")
var native_samples:=0
var native_parts:=0
func extra_evidence() -> Dictionary: return {}
func compiled_samples(kind: String,rows: Array) -> void:
	var pool: Array=[]
	for index in 65600: pool.append(Controls.f(((index*13)%37-18)*0.125))
	for index in rows.size():
		var row: Dictionary=rows[index]; var c: Dictionary=row.case
		for n in c.times.size(): pool[n]=Controls.f(c.times[n])
		var controller:={"rows4":int(c.rows),"columnsA":int(c.flags),"timeIndex6":0,"valueIndex8":int(c.valueBase),"displacement0":int(c.get("displacement",0))}
		var mode:=1 if kind=="float-sample" else (3 if kind=="vector-sample" else 4)
		if mode==4:
			for n in c.quaternions.size():
				for axis in 4: pool[int(c.valueBase)+n*4+axis]=Controls.f(c.quaternions[n][axis])
		for packed in [false,true]:
			var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_sample",mode,controller,{"values88":PackedFloat32Array(pool) if packed else pool},float(c.time),float(c.get("scale",1.0)))
			expect(result.get("error",""),"","Compiled sample accepts original "+kind+"/"+str(index)+"/"+str(packed))
			expect(result.get("result",-1),int(row.result),"Original sample return "+kind+"/"+str(index)+"/"+str(packed))
			if int(row.result)==1: expect(result.get("value"),row.value,"Original sample exact output "+kind+"/"+str(index)+"/"+str(packed))
			native_samples+=1
func compiled_part(row: Dictionary,index: int) -> void:
	var c: Dictionary=row.case
	if c.motion: return
	var values: Array=[]; values.resize(64); values.fill(0.0)
	for span in [[0,[0,1]],[16,[2,4]],[32,[1,2,3,4,5,6]],[48,[0,0,0,1,0.5,0.5,0.5,0.5]]]:
		for n in span[1].size(): values[int(span[0])+n]=span[1][n]
	var controllers: Array=[]
	for spec in [[44,1,16],[16,3,32],[28,4,48],[44,1,16],[60,2,16]]:
		controllers.append({"displacement0":spec[0],"columnsA":spec[1],"valueIndex8":spec[2],"rows4":2,"timeIndex6":0})
	var source:={"controllers78":controllers,"controllerCount80":c.count,"values88":values}
	var view:=PackedByteArray(); view.resize(0x240)
	for axis in 3: view.encode_float(16+axis*4,[2,-1,3][axis])
	for axis in 4: view.encode_float(28+axis*4,float(c.quaternion[axis]))
	view.encode_float(44,7.0); var before:=view.duplicate()
	var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_control",source,view,{16:3,28:4,44:1},float(c.time),float(c.weight),float(c.scale))
	expect(result.get("error",""),"","Original bulk Part input "+str(index))
	expect(view,before,"Bulk output cannot mutate the retained previous Part view "+str(index))
	if not result.has("view"): return
	var output: PackedByteArray=result.view; var position: Array=[]; var quaternion: Array=[]
	for axis in 3: position.append(output.decode_float(16+axis*4))
	for axis in 4: quaternion.append(output.decode_float(28+axis*4))
	expect({"calls":[],"count":source.controllerCount80,"position":position,"quaternion":quaternion,"scalar":output.decode_float(44)},{"calls":row.calls,"count":row.count,"position":row.position,"quaternion":row.quaternion,"scalar":row.scalar},"Original bulk Part exact state "+str(index))
	native_parts+=1
func rejects_and_owner() -> void:
	var node:={"controllers78":[{"rows4":1,"columnsA":1,"timeIndex6":0,"valueIndex8":1,"displacement0":44}],"controllerCount80":1,"values88":PackedFloat32Array([0,2])}
	var bytes:=PackedByteArray(); bytes.resize(0x240); bytes.encode_float(44,1.0)
	for fields in [{44:3},{16:3},{}]:
		var rejected: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_control",node,bytes,fields,0.0,1.0,1.0)
		expect(rejected.has("error"),true,"Mismatched/absent private field is explicitly rejected")
	var short: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_control",node,PackedByteArray(),{44:1},0.0,1.0,1.0)
	expect(short.has("error"),true,"Short private Part view is rejected without publication")
	var count:=node.duplicate(true); count.controllerCount80=2
	expect(ClassDB.class_call_static("NwnParticleKernel","model_control",count,bytes,{44:1},0.0,1.0,1.0).has("error"),true,"Controller count cannot read beyond source records")
	var key:=node.duplicate(true); key.controllers78[0].valueIndex8=10
	expect(ClassDB.class_call_static("NwnParticleKernel","model_control",key,bytes,{44:1},0.0,1.0,1.0).has("error"),true,"Key range cannot read beyond immutable source storage")
	# Exercise the production owner, rather than only the exported arithmetic.
	var part:=Node3D.new(); root.add_child(part)
	var source_node:={"id34":0,"flags98":0,"controllers78":[{"rows4":2,"columnsA":3,"timeIndex6":0,"valueIndex8":2,"displacement0":16}],"controllerCount80":1,"values88":PackedFloat32Array([0,1,0,0,0,2,4,6]),"children68":[],"childCount70":0}
	var metadata:={"root":0,"emitterFields":{},"parts":[{"type":"dummy","node":source_node,"properties":{},"children":[]}]}
	var scripted:=Pose.new(); scripted.compiled_controls=false; scripted.bulk_evaluation=false; scripted.configure(metadata,{"parts":[0]},[part])
	var other:=Node3D.new(); root.add_child(other)
	var compiled:=Pose.new(); compiled.compiled_controls=true; compiled.bulk_evaluation=false; compiled.configure(metadata,{"parts":[0]},[other])
	var automatic_part:=Node3D.new(); root.add_child(automatic_part)
	var automatic:=Pose.new(); automatic.configure(metadata,{"parts":[0]},[automatic_part])
	expect(automatic.compiled_controls,true,"The Windows production owner selects compiled controls without a launch override")
	expect(automatic.bulk_evaluation,true,"The Windows production owner selects verified bulk evaluation without a launch override")
	for frame in 31:
		var manual:={0:{"position":Vector3(9,8,7),"quaternion":Quaternion.IDENTITY}} if frame in [5,6,7] else {}
		scripted.apply(source_node,float(frame-1)/30.0,float(frame)/30.0,0.75,1.25,manual)
		compiled.apply(source_node,float(frame-1)/30.0,float(frame)/30.0,0.75,1.25,manual)
		automatic.apply(source_node,float(frame-1)/30.0,float(frame)/30.0,0.75,1.25,manual)
		expect(compiled.parts[0].view,scripted.parts[0].view,"Production private Part bytes and manual gating "+str(frame))
		expect(other.transform,part.transform,"Production published pose "+str(frame))
		expect(automatic.parts[0].view,scripted.parts[0].view,"Default owner exact private Part bytes "+str(frame))
		expect(automatic_part.transform,part.transform,"Default owner exact published pose "+str(frame))
	expect(compiled.compiled_control_calls>20 and compiled.compiled_control_failures==0,true,"Production compiled owner actually executes without fallback")
	expect(automatic.bulk_calls>20 and automatic.bulk_failures==0 and automatic.compiled_control_failures==0,true,"The default production owner executes bulk controls without failure")
	expect(automatic.native_publish_calls>20 if automatic.native_context!=null else automatic.direct_flush_calls>20,true,"The default production owner uses its selected direct Part publication")
	expect(automatic.root_hierarchy_calls==0 and automatic.bulk_controls>20,true,"The default production owner traverses the physical hierarchy through the actual bulk path")
	part.free(); other.free(); automatic_part.free()
func run() -> void:
	var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
		elif arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output) or oracle.is_empty(): quit(2); return
	expect(ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","model_control"),true,"Compiled bulk Part entry point is loaded")
	if checks!=1 or not failures.is_empty(): quit(1); return
	var cases: Dictionary=Values.decode(JSON.parse_string(FileAccess.get_file_as_string(oracle))); var counts:={}
	for kind in cases:
		expect(cases[kind].binarySha256,"3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a",kind+" immutable original build")
		counts[kind]=cases[kind].rows.size()
		if kind.ends_with("sample"):
			samples(kind,cases[kind].rows); compiled_samples(kind,cases[kind].rows)
		else:
			for index in cases[kind].rows.size():
				if kind=="controller-apply": apply_case(cases[kind].rows[index],index); compiled_part(cases[kind].rows[index],index)
				else: hierarchy_case(cases[kind].rows[index],index)
	rejects_and_owner(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":counts,"native_sample_cases":native_samples,"native_part_cases":native_parts,"public_connections":0,"scope":"Original instruction sample/Part corpus on Array and packed key pools, unchanged scripted motion/hierarchy corpus, production pose bytes/placements/manual gates and rejected-input ownership. The compiled bulk owner intentionally has no motion-run callbacks; gameplay provider uses no motion run. Full scenes, actual original models, GPU pixels and performance remain separate."}
	report.merge(extra_evidence()); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
