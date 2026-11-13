extends SceneTree
const Baseline=preload("res://baseline/model_point_light.gd")
const Candidate=preload("res://candidate/model_point_light.gd")
var failures: Array=[]
var snapshots: Array=[]
var checks:=0
var output:=""
func _initialize()->void: call_deferred("run")
func state(lamp)->PackedByteArray:
	return var_to_bytes([lamp.light_color,lamp.light_energy,lamp.omni_range,lamp.omni_attenuation,lamp.light_specular,lamp.visible,lamp.shadow_enabled,lamp.native_state,lamp.native_properties,lamp.native_properties_revision,lamp.get_meta("native_model_light_properties",{}),lamp.get_meta("native_shadow_requested",null),lamp.animation_cached,lamp.animation_publications])
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	var cases:=[{"color":[]},{"color":[.7]},{"color":null},{"color":"white"},{"color":["bad",.2,.3]},{"color":[.2,.3,.4],"radius":"bad"},{"color":[.2,.3,.4],"shadow":"bad"}]
	for props in cases:
		var a=Baseline.new();var b=Candidate.new()
		for lamp in [a,b]:
			lamp.set_meta("native_enhanced_light",true)
			lamp.configure({"color":[.5,.3,.1],"radius":8,"multiplier":1,"shadow":1})
			lamp.shadow_enabled=true
		checks+=1
		if b._can_publish_final(props):failures.append("Invalid input unexpectedly eligible")
		# Script runtime errors abort the same original function boundary and
		# leave partial physical state. The runner expects these exact cases.
		print("PARTIAL_BEGIN baseline ",snapshots.size())
		a.configure(props)
		print("PARTIAL_END baseline ",snapshots.size())
		print("PARTIAL_BEGIN candidate ",snapshots.size())
		b.configure(props)
		print("PARTIAL_END candidate ",snapshots.size())
		checks+=1
		var same:=state(a)==state(b)
		if not same:failures.append("Partial-state difference at "+str(snapshots.size()))
		snapshots.append({"case":props,"same":same,"baseline":state(a).hex_encode(),"candidate":state(b).hex_encode()})
		a.free();b.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"snapshots":snapshots},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
