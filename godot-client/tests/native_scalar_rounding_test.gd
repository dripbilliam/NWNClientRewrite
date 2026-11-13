extends SceneTree
const Runs=preload("res://systems/model_runs.gd")
const Controls=preload("res://systems/model_controllers.gd")
const References=preload("res://systems/model_reference_state.gd")
const Phases=preload("res://systems/visual_phases.gd")
# Local representation experiment. Original algorithms keep every rounding
# boundary; this compares only how the engine stores that single binary32.
var checks:=0
var failures: Array=[]
var words:=PackedByteArray()
var rng:=0x5a17c0de
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<16:failures.append(label)
func word(value: float) -> int:
	words.encode_float(0,value);return words.decode_u32(0)
func next_word() -> int:
	rng=(rng*1664525+1013904223)&0xffffffff;return rng
func compare(value: float,label: String) -> void:
	var reference:=PackedFloat32Array([value])[0]
	check(word(Color(value,0,0,0).r)==word(reference),"Color scalar exact IEEE result "+label)
	check(word(Vector2(value,0).x)==word(reference),"Vector scalar exact IEEE result "+label)
	check(word(Runs.f(value))==word(reference),"Production run scalar exact IEEE result "+label)
	check(word(Controls.f(value))==word(reference),"Production controller scalar exact IEEE result "+label)
	check(word(References.f(value))==word(reference),"Production reference scalar exact IEEE result "+label)
	check(word(Phases.f32(value))==word(reference),"Production phase scalar exact IEEE result "+label)
func packed(value: float) -> float:return PackedFloat32Array([value])[0]
func color(value: float) -> float:return Color(value,0,0,0).r
func vector(value: float) -> float:return Vector2(value,0).x
func timed(mode: int,iterations: int) -> Dictionary:
	var pool:=[0.1,0.5,1.1,3.333,-7.77,16777217.0,1e-30,1e20];var checksum:=0.0
	var began:=Time.get_ticks_usec()
	if mode==0:
		for index in iterations:checksum+=packed(pool[index&7])
	elif mode==1:
		for index in iterations:checksum+=color(pool[index&7])
	else:
		for index in iterations:checksum+=vector(pool[index&7])
	return {"ms":(Time.get_ticks_usec()-began)/1000.0,"checksum":checksum}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	words.resize(8)
	var requested:=preload("res://systems/native_data/scalar_representation.gd").configured()
	for selected in [Runs.scalar_values,Controls.scalar_values,References.scalar_values,Phases.scalar_values,preload("res://systems/model_rigs.gd").scalar_values]:check(selected==requested,"Production helper selects the requested scalar representation")
	for value in [0.0,-0.0,INF,-INF,NAN,1e-300,-1e-300,1e300,-1e300,16777217.0,-16777217.0]:compare(value,"special")
	for input_word in [0,1,2,0x007ffffe,0x007fffff,0x00800000,0x00800001,0x3effffff,0x3f000000,0x3f000001,0x3f7fffff,0x3f800000,0x3f800001,0x7f7ffffe]:
		words.encode_u32(0,input_word);var lo:=words.decode_float(0)
		words.encode_u32(0,input_word+1);var hi:=words.decode_float(0)
		var mid:=lo+(hi-lo)*0.5
		for sign_value in [1.0,-1.0]:
			for value in [lo,hi,mid,mid+(hi-lo)*0.000001,mid-(hi-lo)*0.000001]:compare(value*sign_value,"midpoint")
	for index in 65536:
		words.encode_u32(0,next_word());words.encode_u32(4,next_word());compare(words.decode_double(0),"raw64/"+str(index))
	var timings:={"packed":[],"color":[],"vector":[]}
	for mode in 3:timed(mode,10000)
	for pass_index in 7:
		var checksum: Variant=null
		for offset in 3:
			var mode:=(pass_index+offset)%3;var row:=timed(mode,100000)
			if checksum==null:checksum=row.checksum
			check(row.checksum==checksum,"Representation timing checksum remains identical")
			timings[["packed","color","vector"][mode]].append(row.ms)
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"engine":{"version":Engine.get_version_info(),"editor":OS.has_feature("editor"),"debug":OS.is_debug_build()},"production_value_mode":requested,"raw_double_cases":65536,"timings_100k_calls_ms":timings,"public_connections":0,"gpu_execution":false,"scope":"Pinned engine binary32 scalar representation and isolated script helper timing. Includes signed zero, subnormal/normal boundaries, overflow, infinities, NaNs, midpoint ties and raw binary64 samples. No complete-game FPS claim; all original algorithm rounding points remain unchanged."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
