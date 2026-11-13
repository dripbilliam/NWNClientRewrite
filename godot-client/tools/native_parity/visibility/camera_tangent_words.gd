extends RefCounted
# Cold, immutable original-instruction SSE tangent cache. Missing angles and
# other CPU branches stay unavailable; no host tan/projection reconstruction.
const CORPUS_SHA256="0787fb0f48d81743adaf79a526b4f44428f36d4063d8a334d99a364cea0c542d"
const BINARY_SHA256="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const ORACLE_SHA256="e35e6193654ab6e8475444af622cc50ce51a82788d750ed9103aafe998ccb90b"
const Math=preload("res://tools/native_parity/visibility/bsp_collector.gd")
var _words: Dictionary={}
var _ready:=false

func load_original_sse(file: String) -> Dictionary:
	if _ready:return {"available":false,"reason":"native-camera-tangent-cache-already-bound"}
	if not FileAccess.file_exists(file) or FileAccess.get_sha256(file)!=CORPUS_SHA256:return {"available":false,"reason":"native-camera-tangent-corpus-pin-unavailable"}
	var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not corpus is Dictionary or corpus.get("binary_sha256")!=BINARY_SHA256 or corpus.get("source_sha256")!=ORACLE_SHA256:return {"available":false,"reason":"native-camera-tangent-authority-unavailable"}
	var pending: Dictionary={}
	for item in corpus.cases:
		for row in item.cameras:
			if row.camera.angle<=0:continue
			var angle:=Math.word(float(row.camera.angle));var value: Variant=row.get("half_tangent_word")
			if not Math.uint(value) or not is_finite(Math.scalar(int(value))) or Math.scalar(int(value))<=0:return {"available":false,"reason":"native-camera-tangent-word-invalid"}
			if pending.has(angle) and pending[angle]!=int(value):return {"available":false,"reason":"native-camera-tangent-word-conflict"}
			pending[angle]=int(value)
	_words=pending;_ready=true
	return {"available":true,"angles":_words.size(),"branch":"original-sse","corpus_sha256":CORPUS_SHA256}

func lookup(angle: float) -> Dictionary:
	var angle_word:=Math.word(angle)
	if not _ready or not _words.has(angle_word):return {"available":false,"reason":"native-camera-tangent-angle-unavailable","angle_word":angle_word}
	return {"available":true,"half_tangent_angle_word":angle_word,"half_tangent_word":_words[angle_word],"branch":"original-sse","corpus_sha256":CORPUS_SHA256}
