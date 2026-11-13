extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3e.gd"
# Report-only nonfinite Float bit encoding; observations/assertions unchanged.
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
	if output.is_empty() or mode.is_empty() or role not in ["baseline","candidate"] or FileAccess.file_exists(output):quit(2);return
	if role=="candidate":
		if candidate_script.is_empty():quit(2);return
		var script=load(candidate_script)
		if script==null:quit(2);return
		factory=script.new()
		if not factory.has_method("create_owner") or not factory.has_method("oracle_statistics"):quit(2);return
	var owner: Node=build_owner()
	var scratch: Dictionary={}
	if mode.begins_with("readonly-") and mode.ends_with("-scratch"):
		scratch=readonly_scratch(owner)
		if scratch.get("pending",true):
			checkpoint({"pending":true,"reason":scratch.get("reason"),"role":role,"case":mode});owner.free();quit(2);return
	checkpoint({"phase":"before-original-call","role":role,"case":mode,"events":events.duplicate(true)})
	var result: Variant=owner.static_candidates(Vector3.ZERO,Vector3.ONE,0.5,77)
	events.append(["after-query-return"])
	verify_result(result)
	var use: Dictionary={}
	var post: Dictionary={"owner_valid":is_instance_valid(owner)}
	if is_instance_valid(owner):
		if role=="candidate":
			use=factory.oracle_statistics(owner)
			verify_use(use)
		post.group_keys=key_labels(owner.static_groups);post.model_keys=key_labels(owner.models)
		owner.static_groups={};events.append(["after-clear-static-groups"])
		owner.model_bounds={};owner.models={};owner.source_rows={}
		owner.free();events.append(["after-owner-free"])
	if not scratch.is_empty():scratch.primer.close(scratch.live);scratch.clear();events.append(["after-primer-close"])
	verify_events()
	var report:={"status":"OBSERVATION_ONLY_EXTERNAL_DIFFERENTIAL_AND_ERROR_ACCEPTANCE_REQUIRED","success":false,"role":role,"case":mode,"checks":checks,"events":events,"result_bytes":var_to_bytes(result).hex_encode(),"post":post,"actual_use":use,"scope":"One isolated actual-Godot G rollback/terminal positive observation; compare baseline/candidate result+PREDELETE/query/cleanup transcript and raw error log plus natural process exit. No standalone PASS or FPS claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report_only(report)));file.close();factory=null
	await process_frame;await process_frame
	quit(0)
