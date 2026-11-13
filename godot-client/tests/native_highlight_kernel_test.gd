extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd")
var extension: Resource
var checks:=0
var failures: Array=[]
var unsupported: Array=[]
var max_error:=0.0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func word(value: int) -> float:
	var data:=PackedByteArray();data.resize(4);data.encode_u32(0,value);return data.decode_float(0)
func quaternion(value: Array) -> Quaternion:return Quaternion(value[1],value[3],-value[2],value[0])
func collect(part: Dictionary,parent: Transform3D,case: Dictionary,inputs: Dictionary) -> void:
	if not part.enabled:return
	var pose:=parent*Transform3D(Basis(quaternion(part.quaternion_wxyz))*float(part.scale),Bounds.source_point(part.position))
	if part.kind=="trimesh":
		for point in part.bounds:
			for component in point:inputs.shapes.append(float(component))
		inputs.poses.append(pose);inputs.colors.append(Color(case.rgb[0],case.rgb[1],case.rgb[2]));inputs.alphas.append(1.0);inputs.enabled.append(1)
		inputs.reference.append(Bounds.project({"min":part.bounds[0],"max":part.bounds[1]},pose,Bounds.source_point(case.camera),case.pulse_size,case.intensity,Color(case.rgb[0],case.rgb[1],case.rgb[2]),1.0))
	for child in part.children:collect(case.parts[int(child)],pose,case,inputs)
func build(inputs: Dictionary,camera: Vector3=Vector3(3,4,5),pulse: float=2.5,intensity: float=0.3) -> Dictionary:
	return ClassDB.class_call_static("NwnHighlightGeometry","build",inputs.shapes,inputs.poses,inputs.colors,inputs.alphas,inputs.enabled,camera,pulse,intensity)
func empty_inputs() -> Dictionary:
	return {"shapes":PackedFloat32Array(),"poses":[],"colors":PackedColorArray(),"alphas":PackedFloat32Array(),"enabled":PackedByteArray(),"reference":[]}
func one_input() -> Dictionary:
	return {"shapes":PackedFloat32Array([-1,-1,-1,1,1,1]),"poses":[Transform3D.IDENTITY],"colors":PackedColorArray([Color(0.2,0.4,0.6)]),"alphas":PackedFloat32Array([0.25]),"enabled":PackedByteArray([1]),"reference":[]}
func run() -> void:
	extension=load("res://native/highlight_geometry.gdextension")
	check(extension!=null and ClassDB.class_exists("NwnHighlightGeometry"),"New standalone extension actually loads")
	if extension==null or not ClassDB.class_exists("NwnHighlightGeometry"):quit(1);return
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/native_parity/highlighting/original_leaf_corpus.json"))
	check(corpus.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.leaf.size()==61,"Pinned original61-case geometry corpus")
	for sample in corpus.leaf:
		var case: Dictionary=sample.case;var inputs:=empty_inputs()
		var parent:=Transform3D(Basis(quaternion(case.parent_quaternion_wxyz))*float(case.parent_scale),Bounds.source_point(case.parent_position))
		if not case.parts.is_empty():collect(case.parts[0],parent,case,inputs)
		var result:=build(inputs,Bounds.source_point(case.camera),case.pulse_size,case.intensity)
		check(not result.has("error"),str(case.name)+": native POD call accepted")
		if result.has("error"):continue
		if inputs.reference.any(func(value):return not value.available):
			unsupported.append(case.name);check(int(result.unavailable_parts)>0,str(case.name)+": unsupported scale remains explicit");continue
		check(int(result.vertices)==int(sample.count),str(case.name)+": native eligible geometry count")
		var positions: PackedFloat32Array=result.positions.to_float32_array();var attributes: PackedByteArray=result.attributes
		check(positions.size()==int(sample.count)*3 and attributes.size()==int(sample.count)*12,str(case.name)+": output buffer sizes")
		var same_positions:=true;var same_color:=true;var same_uv:=true;var contains:=true
		for at in sample.vertex_words.size():
			var values: Array=sample.vertex_words[at]
			var expected:=Bounds.source_point([word(int(values[1])),word(int(values[2])),word(int(values[3]))])
			var actual:=Vector3(positions[at*3],positions[at*3+1],positions[at*3+2])
			var error:=actual.distance_to(expected);max_error=maxf(max_error,error)
			if error>maxf(0.00001,expected.abs().length()*0.000002):same_positions=false
			if attributes.decode_u32(at*12)!=int(values[0]):same_color=false
			if Vector2(attributes.decode_float(at*12+4),attributes.decode_float(at*12+8))!=Bounds.UVS[at%6]:same_uv=false
			var box: AABB=result.bounds
			if actual.x<box.position.x-0.00001 or actual.y<box.position.y-0.00001 or actual.z<box.position.z-0.00001 or actual.x>box.end.x+0.00001 or actual.y>box.end.y+0.00001 or actual.z>box.end.z+0.00001:contains=false
		check(same_positions,str(case.name)+": original SSE vertex tolerance1e-5or2ppm")
		check(same_color,str(case.name)+": exact original packed RGBA")
		check(same_uv,str(case.name)+": exact original UV corner order")
		check(contains,str(case.name)+": CPU draw bounds retain every emitted vertex")
	var inputs:=one_input();var before:=inputs.duplicate(true);var result:=build(inputs)
	check(inputs==before and result.available_parts==1 and result.unavailable_parts==0,"Native function borrows but never mutates caller POD inputs")
	var retained: PackedByteArray=result.positions.duplicate();inputs.poses[0]=Transform3D(Basis.IDENTITY,Vector3(100,200,300));var later:=build(inputs)
	check(result.positions==retained and later.positions!=retained,"Later call cannot overwrite earlier queued output buffers")
	inputs.enabled[0]=0;result=build(inputs)
	check(result.unavailable_parts==1 and not result.has_bounds and result.positions==PackedByteArray().duplicate().slice(0,0)+zeros(216),"Disabled owner publishes explicit zero buffers and no AABB")
	inputs=one_input();inputs.alphas=PackedFloat32Array()
	check(build(inputs).has("error"),"Count mismatch rejects before native pointer access")
	inputs=one_input();inputs.shapes[0]=NAN;result=build(inputs)
	check(not result.has_bounds and result.unavailable_parts==1,"Nonfinite shape is unavailable instead of fabricated geometry")
	check(build(one_input(),Vector3.ZERO,0).has("error") and build(one_input(),Vector3.ZERO,1,-1).has("error"),"Invalid pulse/intensity rejects explicitly")
	result=build(empty_inputs());check(result.vertices==0 and not result.has_bounds and result.positions.is_empty(),"Empty membership needs no fake shape")
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"unsupported":unsupported,"maximum_position_error":max_error,"scope":"Actual standalone private GDExtension against original leaf outputs; no scene/GPU/server performance claim"}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE_HIGHLIGHT_KERNEL ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func zeros(count: int) -> PackedByteArray:
	var result:=PackedByteArray();result.resize(count);result.fill(0);return result
