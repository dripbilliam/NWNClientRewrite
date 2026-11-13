extends SceneTree
const Candidate=preload("res://tools/native_parity/visibility/camera_tangent_candidate.gd")
const Collector=preload("res://tools/native_parity/visibility/bsp_collector.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var input:="";var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):input=arg.substr(9)
		elif arg.begins_with("--report="):output=arg.substr(9)
	if input.is_empty() or output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(input))
	if not oracle is Dictionary or oracle.get("binary_sha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or oracle.get("cpu_dispatch_word")!=0 or oracle.get("mxcsr")!=0x1f80:quit(3);return
	for key in oracle.constants:check(Candidate.RAW.get(key)==oracle.constants[key].bytes_le,"Exact original constant bytes: "+key)
	for invalid in [null,true,false,"45",[],{},NAN,INF,-INF,-1,-0.0,0,180,181,1e300,1e-300,179.999999999]:check(not Candidate.evaluate(invalid,"original-sse").available,"Invalid or native-rounded-outside-domain angle unavailable")
	for branch in ["","native-auto","avx","fma","original-fma"]:check(not Candidate.evaluate(45,branch).available,"Unproved/absent native CPU branch rejected")
	var branches: Dictionary={};var mismatches: Array=[];var samples:=0;var plane_cases:=0;var zeros:=0;var category_counts: Dictionary={}
	for row in oracle.cases:
		var angle:=Candidate.scalar(int(row.angle_word));var result:=Candidate.evaluate(angle,"original-sse")
		check(result.available,"Original perspective input available")
		if not result.available:continue
		var exact:=true
		for pair in [["half_tangent_angle_word","angle_word"],["half_angle_word","half_angle_word"],["radians_word","radians_word"],["half_tangent_word","tangent_word"]]:
			var equal: bool=result[pair[0]]==int(row[pair[1]])
			check(equal,"Exact executed original word: "+pair[1]+" / "+str(row.angle_word));exact=exact and equal
		check(result.path==row.branch,"Exact original reachable path")
		if not exact and mismatches.size()<20:mismatches.append({"original":row,"candidate":result})
		branches[result.path]=int(branches.get(result.path,0))+1
		for category in row.categories:category_counts[category]=int(category_counts.get(category,0))+1
		if int(row.tangent_word)==0:zeros+=1;check(not result.plane_usable,"Original f32 underflow0 remains0; no minimum-angle clamp")
		if "ui-slider" in row.categories or "selected-fractional-extreme" in row.categories:
			var camera:={"position":[1.0,2.0,3.0],"quaternion_wxyz":[1.0,0.0,0.0,0.0],"angle":angle,"aspect":Collector.f(16.0/9.0),"near":.1,"far":200.0,"half_tangent_angle_word":result.half_tangent_angle_word,"half_tangent_word":result.half_tangent_word}
			var planes:=Collector.camera_planes(camera)
			check(planes.available==result.plane_usable,"Unchanged native-plane consumer accepts positive candidate word and explicitly rejects underflow")
			plane_cases+=1
		samples+=1
	check(samples==5882 and branches.size()==4,"All5882 original cases and4 reachable SSE paths compared")
	check(category_counts.get("ui-slider")==101,"All integer UI slider20..120 values covered")
	var mismatch_word:=Candidate.evaluate(80.125,"original-sse");mismatch_word.half_tangent_word=0
	check(Candidate.evaluate(80.125,"original-sse").half_tangent_word!=0,"Returned DTO is detached; no persistent result mutation")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"mismatches":mismatches,"samples":samples,"branches":branches,"categories":category_counts,"zero_underflows":zeros,"collector_plane_cases":plane_cases,"production_hooks":0,"gpu_draws":0,"native_builds":0,"server_connections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NATIVE_CAMERA_TANGENT_CANDIDATE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
