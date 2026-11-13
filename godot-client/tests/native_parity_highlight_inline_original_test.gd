extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/candidates/bounds_inline.gd")
var checks:=0
var failures: Array=[]
var unsupported: Array=[]
var maximum_error:=0.0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func word(value: int) -> float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,value);return bytes.decode_float(0)
func bits(value: float) -> int:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);return bytes.decode_u32(0)
func quaternion(value: Array) -> Quaternion:return Quaternion(value[1],value[3],-value[2],value[0])
func walk(part: Dictionary,parent: Transform3D,case: Dictionary,outputs: Array) -> void:
	if not part.enabled:return
	var pose:=parent*Transform3D(Basis(quaternion(part.quaternion_wxyz))*float(part.scale),Bounds.source_point(part.position))
	if part.kind=="trimesh":
		outputs.append(Bounds.project({"min":part.bounds[0],"max":part.bounds[1]},pose,Bounds.source_point(case.camera),case.pulse_size,case.intensity,Color(case.rgb[0],case.rgb[1],case.rgb[2]),1.0))
	for child in part.children:walk(case.parts[int(child)],pose,case,outputs)
func run() -> void:
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/native_parity/highlighting/original_leaf_corpus.json"))
	check(corpus.binary_sha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.leaf.size()==61,"Pinned original native leaf corpus identity and61cases")
	for sample in corpus.leaf:
		var case: Dictionary=sample.case;var results: Array=[]
		var parent:=Transform3D(Basis(quaternion(case.parent_quaternion_wxyz))*float(case.parent_scale),Bounds.source_point(case.parent_position))
		if not case.parts.is_empty():walk(case.parts[0],parent,case,results)
		if results.any(func(row):return not row.available):unsupported.append(case.name);continue
		var vertices:=PackedVector3Array();var colors:=PackedByteArray()
		for result in results:vertices.append_array(result.vertices);colors.append_array(result.colors)
		check(vertices.size()==int(sample.count),str(case.name)+": native eligible subtree/skin count")
		var position_match:=true;var color_match:=true
		for at in mini(vertices.size(),sample.vertex_words.size()):
			var words: Array=sample.vertex_words[at]
			var expected:=Bounds.source_point([word(int(words[1])),word(int(words[2])),word(int(words[3]))])
			var error:=vertices[at].distance_to(expected);maximum_error=maxf(maximum_error,error)
			if error>maxf(0.00001,expected.abs().length()*0.000002):position_match=false
			var rgba:=int(words[0])
			for component in 4:
				if colors[at*4+component]!=((rgba>>(component*8))&255):color_match=false
		check(position_match,str(case.name)+": transformed native vertices tolerance1e-5or2ppm")
		check(color_match,str(case.name)+": packed native RGBA bytes exact")
	for sample in corpus.gob_alpha_cases:
		var rgb: Array=sample.rgb_words
		var value:=Bounds.highlight_rgb(Color(word(int(rgb[0])),word(int(rgb[1])),word(int(rgb[2]))),word(int(sample.alpha_word)))
		check(bits(value.x)==int(sample.output_rgb_words[0]) and bits(value.y)==int(sample.output_rgb_words[1]) and bits(value.z)==int(sample.output_rgb_words[2]),"Original Gob alpha RGB attenuation words exact")
	for sample in corpus.pulse_cases:
		var pulse:=Bounds.pulse_step(word(int(sample.phase_word)),word(int(sample.delta_word)),word(int(sample.amplitude_word)),word(int(sample.frequency_word)),word(int(sample.size_word)))
		check(pulse.available and bits(pulse.phase)==int(sample.new_phase_word),"Original Scene pulse phase words exact")
		check(pulse.available and bits(pulse.size)==int(sample.pulse_size_word),"Original Scene pulse size words exact against executed SSE sine")
	var folder:=OS.get_environment("NWN_PARITY_UI_TEST_DIR")
	var file:=FileAccess.open(folder.path_join("original-highlight-comparison.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"unsupported":unsupported,"maximum_position_error":maximum_error,"position_contract":"max(1e-5,2ppm length); source SSE versus Godot transform boundary","color_contract":"exact RGBA bytes","gpu_claim":false},"  "));file.close()
	print("NATIVE_PARITY_HIGHLIGHT_INLINE_ORIGINAL ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
