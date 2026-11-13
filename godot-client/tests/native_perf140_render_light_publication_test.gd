extends SceneTree
const Baseline=preload("res://baseline/model_point_light.gd")
const Candidate=preload("res://candidate/model_point_light.gd")
const TracedBaseline=preload("res://baseline/traced_model_point_light.gd")
const TracedCandidate=preload("res://candidate/traced_model_point_light.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
var stages: Array=[]
var output:=""
var call_evidence: Array=[]
class FocusOwner extends Node3D:
	var registrations:=0
	var retirements:=0
	func register(_lamp: Node)->void: registrations+=1
	func unregister(_lamp: Node)->void: retirements+=1
func _initialize()->void: call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value: failures.append(label);print("FAIL: ",label)
func state(node)->Dictionary:
	var shape: Variant=null;var policy: Variant=null
	if node.native_slot>=0:
		node.set_meta("test_last_palette_slot",node.native_slot)
		shape=Palette.image.get_pixel(0,node.native_slot)
		policy=Palette.image.get_pixel(1,node.native_slot)
	# Two simultaneous worlds necessarily own different physical slots. On
	# tree exit both retain the old encoded specular value until re-entry.
	var specular: float=node.light_specular
	if specular>=16 and node.has_meta("test_last_palette_slot"):specular-=float(node.get_meta("test_last_palette_slot"))*0.5
	return {"color":node.light_color,"energy":node.light_energy,"range":node.omni_range,"attenuation":node.omni_attenuation,"specular":specular,"visible":node.visible,"in_tree_visible":node.is_visible_in_tree(),"shadow":node.shadow_enabled,"requested":node.get_meta("native_shadow_requested",null),"admitted":node.native_admitted,"fade":node.native_fade,"state":node.native_state.duplicate(true),"properties":node.native_properties.duplicate(true),"revision":node.native_properties_revision,"meta_properties":node.get_meta("native_model_light_properties",{}).duplicate(true),"animation_cached":node.animation_cached,"animation_color":node.animation_color,"animation_values":node.animation_values,"animation_publications":node.animation_publications,"shape":shape,"policy":policy,"group":node.is_in_group("native_original_model_lights"),"focus_owner":node.focus_owner!=null,"has_slot":node.native_slot>=0}
func pair(enhanced: bool)->Dictionary:
	var owner:=FocusOwner.new();root.add_child(owner)
	owner.set_meta("native_focus_light_owner",weakref(owner))
	var a=Baseline.new();var b=Candidate.new()
	for lamp in [a,b]: lamp.set_meta("native_enhanced_light",enhanced)
	return {"a":a,"b":b,"owner":owner}
func same(value: Dictionary,label: String)->void:
	check(state(value.a)==state(value.b),label+": exact final physical/properties/animation/palette state")
	stages.append(label)
func both(value: Dictionary,method: String,args: Array)->void:
	value.a.callv(method,args);value.b.callv(method,args)
func attach(value: Dictionary)->void:
	value.owner.add_child(value.a);value.owner.add_child(value.b)
func close(value: Dictionary)->void:
	value.a.free();value.b.free()
	check(value.owner.registrations==value.owner.retirements,"Weak focus registrations retired exactly")
	value.owner.free()
func run_case(enhanced: bool)->void:
	var value:=pair(enhanced)
	var properties:={"color":[.8,.4,.2],"radius":8.0,"multiplier":.7,"shadow":1,"ambientonly":0,"fadinglight":1,"isdynamic":1,"affectdynamic":1}
	both(value,"configure",[properties]);same(value,"outside configure "+str(enhanced))
	attach(value);same(value,"inside initial "+str(enhanced))
	check(value.owner.registrations==2,"Both actual light facades register with retained focus owner")
	for lamp in [value.a,value.b]: lamp.shadow_enabled=true
	for step in 120:
		# Color animation and fade preserve range and shadow selection. Repeated
		# unchanged publications must retain the existing animation early return.
		var color:=Color(.2+float(step%11)*.1,.3,.4)
		both(value,"publish_native_light",[color,8.0,6.0,.25,.7]);same(value,"animated color "+str(enhanced)+"/"+str(step))
		check(value.b.shadow_enabled,"Independent selected shadow survives color animation")
		var publications: int=value.b.animation_publications
		both(value,"publish_native_light",[color,8.0,6.0,.25,.7]);same(value,"repeated color "+str(enhanced)+"/"+str(step))
		check(value.b.animation_publications==publications,"Unchanged animation values avoid publication")
		both(value,"apply_native_admission",[step%4!=0,float(step%9)/8.0]);same(value,"fade/admission "+str(enhanced)+"/"+str(step))
	for row in [[Color(2,.3,.2),17,3,0,.7],[Color(0,0,0),0,0,0,0],[Color(.8,.6,.4),1000,1100,-2,1.5],[Color(1,1,1),-1,-1,0,-1],[Color(.3,.2,.1),9,6,.25,0],[Color(.8,.6,.4),9,6,.25,1.5]]:
		both(value,"publish_native_light",row);same(value,"range/disabled/HDR "+str(row))
	for mode in 4:
		properties=value.a.native_properties.duplicate(true)
		properties.shadow=mode%2;properties.ambientonly=1 if mode>=2 else 0
		both(value,"configure",[properties]);same(value,"direct configure clears selected shadow "+str(mode))
		check(not value.b.shadow_enabled,"Existing direct configure reset semantics preserved")
		for lamp in [value.a,value.b]: lamp.shadow_enabled=true
		both(value,"publish_native_light",[Color(.5,.6,.7),12,8,0,1]);same(value,"requested shadow/ambient gate "+str(mode))
		check(value.b.shadow_enabled==(mode==1),"Ambient-only and missing shadow flags still suppress selected shadow")
	value.owner.hide();same(value,"hidden ancestor")
	both(value,"apply_native_admission",[true,.5]);same(value,"publication under hidden ancestor")
	value.owner.show();same(value,"ancestor re-entry")
	for lamp in [value.a,value.b]: lamp.position=Vector3(4,-2,6);lamp.force_update_transform()
	same(value,"transformed physical light updates original palette")
	for lamp in [value.a,value.b]: value.owner.remove_child(lamp)
	same(value,"tree exit releases palette")
	attach(value);same(value,"tree re-entry allocates new palette and resets shadow")
	close(value)
func fallback_case()->void:
	var value:=pair(false);attach(value)
	# Enhanced flag without an acquired slot uses the pre-existing raw fallback.
	for lamp in [value.a,value.b]: lamp.set_meta("native_enhanced_light",true)
	both(value,"configure",[{"color":[.3,.5,.7],"radius":4,"multiplier":2,"shadow":1}]);same(value,"in-tree missing palette slot falls back")
	for lamp in [value.a,value.b]: lamp.shadow_enabled=true
	both(value,"publish_native_light",[Color(2,.3,.4),7,8,.1,.8]);same(value,"fallback animated shadow preserved")
	for lamp in [value.a,value.b]: lamp.set_meta("native_enhanced_light",false)
	both(value,"configure",[{"color":[.3],"radius":0}]);same(value,"raw invalid color keeps original white fallback")
	close(value)
func counts(node)->Dictionary:
	var result:={"calls":{},"changed_range":0,"shadow_version_increments":0}
	for entry in node.publication_trace:
		result.calls[entry[0]]=int(result.calls.get(entry[0],0))+1
		if entry[0]=="shadow_enabled":result.shadow_version_increments+=1
		if entry[0]=="omni_range" and entry[1]!=Vector3(float(entry[2]),0,0).x:result.changed_range+=1
	return result
func trace_case(selected_shadow: bool)->void:
	var owner:=FocusOwner.new();root.add_child(owner)
	owner.set_meta("native_focus_light_owner",weakref(owner))
	var value:={"owner":owner,"a":TracedBaseline.new(),"b":TracedCandidate.new()}
	for lamp in [value.a,value.b]:
		lamp.set_meta("native_enhanced_light",true)
		lamp.configure({"color":[.3,.5,.7],"radius":8,"multiplier":1,"shadow":1})
	attach(value)
	for lamp in [value.a,value.b]:lamp.shadow_enabled=selected_shadow;lamp.publication_trace.clear()
	for step in 20:
		both(value,"publish_native_light",[Color(.2+float(step)*.02,.3,.4),8,6,.25,1])
		both(value,"apply_native_admission",[true,float(step+1)/20.0])
		same(value,"instrumented real setter final state "+str(selected_shadow)+"/"+str(step))
	var previous:=counts(value.a);var candidate:=counts(value.b)
	check(previous.shadow_version_increments==80,"Original color/fade publication performs 80 unconditional shadow version increments")
	check(candidate.shadow_version_increments==0,"Candidate preserves unchanged selected/nonselected shadow without invalidation")
	check(previous.changed_range==80,"Original raw/enhanced range bounce performs 80 changed range publications")
	check(candidate.changed_range==0,"Candidate preserves same final support radius without transient changes")
	call_evidence.append({"selected_shadow":selected_shadow,"authored_color_publications":20,"fade_publications":20,"baseline":previous,"candidate":candidate,"scope":"Instrumented source copies record real native property setter calls. The pinned engine source establishes version effects; headless cannot observe the GPU shadow atlas itself."})
	close(value)
func run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	run_case(false);run_case(true);fallback_case();trace_case(false);trace_case(true)
	await process_frame
	check(Palette.active.is_empty(),"All palette slots retired; no physical light survives")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"stages":stages.size(),"callEvidence":call_evidence,"scope":"Isolated headless SceneTree comparing unmodified production light facade against private final-input publication candidate. Final engine property, authored metadata/revision, actual palette pixel, animation cache, focus weak ownership and lifecycle equivalence. Separate instrumented copies count real engine property writes; no GPU, native NWN pixels, server or FPS claim.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_PERF140_RENDER_LIGHT_PUBLICATION ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
