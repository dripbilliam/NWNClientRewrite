extends "res://tools/native_parity/visibility/camera_tangent_words.gd"
# Drop-in subtype of the frozen Tangents contract. Separate authority and
# policy; the original cache still contains only its two recorded angles.
const Candidate=preload("res://tools/native_parity/visibility/camera_tangent_candidate.gd")
const CANDIDATE_CORPUS_SHA256="802de03c053eecd90d9f6e80e71f4b3c1854c2ce7eb0c979c920b5de5a7aabbb"
const CANDIDATE_SOURCE_SHA256="ccb8dea497d88fbf50275ffd404056b97101585ebd9f96ff26f4ecfa97f0b356"
const CANDIDATE_ORACLE_SOURCE_SHA256="cd6b432b1cc4248c5ced858555bf2524598c130aeec480352a6cd157a52373dd"
var _candidate_ready:=false
var _authority: Dictionary={}

func load_original_sse(file: String) -> Dictionary:
	if _candidate_ready:return {"available":false,"reason":"native-tangent-candidate-provider-already-bound"}
	if not FileAccess.file_exists(file) or FileAccess.get_sha256(file)!=CANDIDATE_CORPUS_SHA256:return {"available":false,"reason":"native-tangent-candidate-provider-corpus-pin-unavailable"}
	if FileAccess.get_sha256("res://tools/native_parity/visibility/camera_tangent_candidate.gd")!=CANDIDATE_SOURCE_SHA256:return {"available":false,"reason":"native-tangent-candidate-provider-source-pin-unavailable"}
	var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not corpus is Dictionary or corpus.get("binary_sha256")!=BINARY_SHA256 or corpus.get("oracle_source_sha256")!=CANDIDATE_ORACLE_SOURCE_SHA256 or corpus.get("cpu_dispatch_word")!=0 or corpus.get("mxcsr")!=0x1f80:return {"available":false,"reason":"native-tangent-candidate-provider-authority-unavailable"}
	if not corpus.get("constants") is Dictionary or corpus.constants.size()!=Candidate.RAW.size():return {"available":false,"reason":"native-tangent-candidate-provider-constants-unavailable"}
	var keys: Array=Candidate.RAW.keys();keys.sort();var constant_bytes:=""
	for key in keys:
		if not corpus.constants.get(key) is Dictionary or corpus.constants[key].get("bytes_le")!=Candidate.RAW[key]:return {"available":false,"reason":"native-tangent-candidate-provider-constant-pin-differs"}
		constant_bytes+=key+"="+Candidate.RAW[key]+"\n"
	_authority={"binary_sha256":BINARY_SHA256,"candidate_source_sha256":CANDIDATE_SOURCE_SHA256,"oracle_source_sha256":CANDIDATE_ORACLE_SOURCE_SHA256,"corpus_sha256":CANDIDATE_CORPUS_SHA256,"constant_bytes_sha256":constant_bytes.sha256_text(),"branch":"original-sse","oracle_cpu_dispatch_word":0,"oracle_mxcsr":0x1f80,"executed_original_cases":5882,"implementation":"scalar-domain-port","native_live_branch_observed":false,"fma_parity_accepted":false,"exhaustive_f32_enumeration":false}
	_candidate_ready=true
	var result:=authority();result.available=true;return result

func authority() -> Dictionary:return _authority.duplicate(true)

func lookup(angle: float) -> Dictionary:
	if not _candidate_ready:return {"available":false,"reason":"native-tangent-candidate-provider-not-bound"}
	var result:=Candidate.evaluate(angle,"original-sse")
	if not result.available:return result
	result.corpus_sha256=CANDIDATE_CORPUS_SHA256
	result.authority=_authority.duplicate(true)
	return result
