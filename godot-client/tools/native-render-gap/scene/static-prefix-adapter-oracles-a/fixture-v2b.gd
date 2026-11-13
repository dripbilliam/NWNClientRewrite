extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v2.gd"
# Serialization ONLY, after all original actual input/assertion/var_to_bytes work.
# A nonfinite Float is represented by its exact original f64 little-endian bits;
# no numeric value is reconstructed from these report strings for any test.
func report_only(value: Variant)->Variant:
	if value is float and not is_finite(value):
		var bits:=PackedByteArray();bits.resize(8);bits.encode_double(0,value)
		return {"nwn_report_nonfinite_float64_le_hex":bits.hex_encode()}
	if value is Array:
		var result: Array=[]
		for child in value:result.append(report_only(child))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[key]=report_only(value[key])
		return result
	return value

func run()->void:
	var candidate_script:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.substr(9)
		elif argument.begins_with("--candidate-script="):candidate_script=argument.substr(19)
		elif argument=="--baseline-self-check":self_check=true
	if output.is_empty():quit(2);return
	if candidate_script.is_empty():
		var missing:=FileAccess.open(output,FileAccess.WRITE);missing.store_string(JSON.stringify({"success":false,"pending":true,"reason":"Actual adapter factory required; canonical native counters cannot be substituted"}));missing.close();quit(2);return
	var source=load(candidate_script)
	if source==null:quit(2);return
	factory=source.new()
	if not factory.has_method("create_owner") or not factory.has_method("oracle_statistics"):quit(2);return
	for mode in ["ordinary","flat-control","empty-bounds-before-pending","early-query-unready","witness-failure-before-later-query","door-state-out-of-range","pending-model","replace-live-models","replace-live-bounds","nested-same-alias-pending","later-group-now-distant","replace-live-groups-retain-original-iterator","source-witness-mutated-in-query","source-pose-mutated-in-query","unknown-key","stringname-key"]:
		exercise(mode,Vector3.ZERO,Vector3.ONE,0.5)
	for radius in [-1.0,0.0,-0.0,INF,-INF,NAN]:exercise("ordinary",Vector3.ZERO,Vector3.ONE,radius)
	for mode in ["canonical-admitted","canonical-flat-control","canonical-pending-after-admit","canonical-463-groups"]:
		exercise(mode,Vector3.ZERO,Vector3.ONE,0.5)
	await process_frame;await process_frame
	var report:={"success":failures.is_empty() and not self_check,"self_check_only":self_check,"checks":checks,"failures":failures,"cases":cases,"scope":"Source-prepared V2 full-owner differential:22 opaque/mutation cases plus4 actual canonical Spatial positives including463 groups. No candidate/execution/acceptance claimed by source preparation."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report_only(report)));file.close();factory=null
	quit(0 if failures.is_empty() else 1)
