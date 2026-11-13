extends RefCounted
# Only finite normal values and signed zero may bypass the original scalar
# reader. Validation uses native integer sort/search, never a GD per-float scan.
const MAX_COUNT:=1048576
static var compatible:=probe_layout()
static func enabled() -> bool: return OS.get_cmdline_user_args().has("--model-float-stream=bulk")
static func probe_layout() -> bool:
	var bytes:=PackedByteArray([0,0,128,63])
	var words:=bytes.to_int32_array(); var values:=bytes.to_float32_array()
	return words.size()==1 and words[0]==0x3f800000 and values.size()==1 and values[0]==1.0
static func has_range(words: PackedInt32Array,low: int,high: int) -> bool:
	var at:=words.bsearch(low)
	return at<words.size() and int(words[at])<=high
static func read(bytes: PackedByteArray,at: int,count: int,layout_proven: Variant=null) -> Dictionary:
	var proven:=compatible if layout_proven==null else bool(layout_proven)
	if not proven or count<0 or count>MAX_COUNT or at<0 or at>bytes.size() or count*4>bytes.size()-at: return {"accepted":false}
	var source:=bytes.slice(at,at+count*4); var words:=source.to_int32_array()
	if words.size()!=count: return {"accepted":false}
	words.sort()
	# Signed integer encodings of negative nonfinite values, positive
	# nonfinite values, negative subnormals and positive subnormals.
	if has_range(words,-8388608,-1) or has_range(words,2139095040,2147483647) or has_range(words,-2147483647,-2139095041) or has_range(words,1,8388607): return {"accepted":false}
	var values:=source.to_float32_array()
	return {"accepted":true,"value":values} if values.size()==count else {"accepted":false}
