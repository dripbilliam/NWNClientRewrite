extends SceneTree

const Point=preload("res://systems/native_render/model_point_light.gd")
const Policy=preload("res://systems/native_render/native_light_policy.gd")
var checks:=0
var failures: Array=[]
var report_path:=""
var planes: Array=[]
var script_lifetime_witnesses: Array=[]

func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func stats(peer: Dictionary) -> Dictionary:return peer.registry.call("dispatch",9,{})
func weak_valid(reference: WeakRef) -> bool:
	# End the temporary strong-reference frame before the caller tests release.
	return is_instance_valid(reference.get_ref())
func weak_count(reference: WeakRef) -> int:
	var value: RefCounted=reference.get_ref()
	return value.get_reference_count() if is_instance_valid(value) else 0
func isolated_script_lifetime(cached: bool,turn: int) -> Dictionary:
	var cloned_writer:=GDScript.new();cloned_writer.source_code=(Point as GDScript).source_code
	check(cloned_writer.reload()==OK,"Lifetime clone compiles "+str(cached)+"/"+str(turn))
	var weak_writer: WeakRef=weakref(cloned_writer)
	var retained:=scene(cached,false,cloned_writer)
	retained.point.bind_native_input_registry(null)
	retained.point.free()
	cloned_writer=null
	var before:=weak_count(weak_writer)
	if cached:check(before>0,"Registered entry has its documented Script ownership "+str(turn))
	retained.registry.call("dispatch",2,{"id":retained.point_id})
	var after:=weak_count(weak_writer)
	if cached:check(after==before-1,"Removal drops exactly the Entry Script reference "+str(turn))
	dispose(retained)
	return {"weak":weak_writer,"cached":cached,"before":before,"after":after}
func normalize(peer: Dictionary,value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	for row in result.get("rows",[]):
		row.id=1 if int(row.id)==peer.point_id else -1
		row.owner=2 if int(row.owner)==peer.source_id else 0
	for name in ["removed","retired"]:
		if result.has(name):result[name]=result[name].map(func(id):return 1 if int(id)==peer.point_id else -1)
	return result
func poll(peer: Dictionary,view_changed: bool=false) -> Dictionary:
	return normalize(peer,peer.registry.call("dispatch",1,{"planes":planes,"view_changed":view_changed}))
func pair(previous: Dictionary,current: Dictionary,label: String,view_changed: bool=false) -> void:
	var expected:=poll(previous,view_changed);var actual:=poll(current,view_changed)
	check(var_to_bytes(expected)==var_to_bytes(actual),label+": exact typed rows, admission, removals, counters and order")
func claim(peer: Dictionary,writer: Script=Point) -> Dictionary:
	var result: Dictionary=peer.registry.call("dispatch",6,{"id":peer.point_id,"writer":writer,"source_sha256":writer.source_code.sha256_text()})
	if result.get("accepted",false):peer.point.bind_native_input_registry(peer.registry,int(result.token));peer.token=int(result.token)
	return result
func scene(cached: bool,palette: bool=true,writer: Script=Point) -> Dictionary:
	var room:=Node3D.new();root.add_child(room)
	var source:=Node3D.new();source.set_meta("native_light_source",true);room.add_child(source)
	var point=writer.new();point.set_meta("native_enhanced_light",palette)
	point.configure({"color":[0.8,0.4,0.2],"radius":8.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1})
	source.add_child(point)
	if not palette:point.set_meta("native_enhanced_light",true);point.native_state={"range":8.0}
	var registry: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry" if cached else "NwnLightInputRegistry")
	registry.call("dispatch",0,{"id":point.get_instance_id(),"source":source.get_instance_id()})
	var result: Dictionary={"room":room,"source":source,"point":point,"point_id":point.get_instance_id(),"source_id":source.get_instance_id(),"registry":registry,"cached":cached,"token":0,"observations":[]}
	if cached:check(claim(result,writer).get("accepted",false),"Exact source-bearing canonical writer enrolls")
	return result
func dispose(peer: Dictionary) -> void:
	if is_instance_valid(peer.point) and peer.point.has_method("bind_native_input_registry"):peer.point.bind_native_input_registry(null)
	peer.registry.call("dispatch",8,{})
	if is_instance_valid(peer.room):peer.room.free()
	peer.clear()
func observe_configure(peer: Dictionary) -> void:
	peer.observations.append(poll(peer))
	if peer.cached:check(int(stats(peer).cached_members)==0,"Mid-configure visibility callback uses live reflected fields")
	if peer.get("nested_pending",false):
		peer.nested_pending=false
		peer.point.configure(peer.nested_properties)
func observe_reattach(peer: Dictionary) -> void:
	# No observation at detach: the cache must detect the SAME Resource's new
	# instance itself, before an earlier attach listener could consume stale data.
	if peer.point.get_script()==Point:peer.script_observations.append(poll(peer))
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report_path=argument.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path):quit(2);return
	check(ClassDB.class_exists("NwnLightInputRegistry") and ClassDB.class_exists("NwnBuiltinLightInputRegistry"),"Actual old and optional builtin classes loaded")
	if not failures.is_empty():finish();return
	var probe: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	check(not probe.call("dispatch",9,{}).has("error"),"V4 module present; legacy engine cannot silently pass")
	probe.call("dispatch",8,{});probe=null
	if not failures.is_empty():finish();return
	var previous:=scene(false);var current:=scene(true)
	pair(previous,current,"initial")
	var before: Dictionary=stats(current)
	pair(previous,current,"unchanged")
	var after: Dictionary=stats(current)
	check(int(after.field_cache_hits)-int(before.field_cache_hits)==3,"Canonical unchanged eligible light avoids exactly three reflected fields")
	check(after.reflected_field_reads==before.reflected_field_reads,"Canonical unchanged poll uses no reflected fields")
	check(int(after.capability_reads)-int(before.capability_reads)==1,"Canonical poll still performs one explicit live capability scalar lookup")
	var invalid_claim: Dictionary=current.registry.call("dispatch",6,{"id":current.point_id,"writer":Point,"source_sha256":"0".repeat(64)})
	check(not invalid_claim.accepted and int(stats(current).cached_members)==1,"Wrong source hash cannot replace the active capability")
	var wrong_writer: Dictionary=current.registry.call("dispatch",6,{"id":current.point_id,"writer":current.room,"source_sha256":(Point as GDScript).source_code.sha256_text()})
	check(not wrong_writer.accepted,"Wrong native writer class is rejected without a conversion error")
	for peer in [previous,current]:
		peer.point.native_properties={"color":[0.1,0.2,0.3],"radius":4.0,"multiplier":2.0,"lightpriority":5}
		peer.point.native_properties_revision+=1
		peer.point.native_state={"range":6.0}
	pair(previous,current,"direct typed field setters")
	for peer in [previous,current]:peer.point.native_properties.radius=5.0;peer.point.native_state.range=7.0
	pair(previous,current,"in-place Dictionary aliases without invented revision")
	for peer in [previous,current]:peer.point.set_meta("native_light_priority",7);peer.point.position=Vector3(3,1,-2);peer.source.position=Vector3(2,0,1)
	pair(previous,current,"live priority and source/point transforms",true)
	for peer in [previous,current]:peer.source.visible=false
	pair(previous,current,"live parent hidden")
	for peer in [previous,current]:peer.source.visible=true
	pair(previous,current,"live parent visible reentry")
	var old_token: int=current.token
	current.point.bind_native_input_registry(null)
	for peer in [previous,current]:peer.registry.call("dispatch",0,{"id":peer.point_id,"source":peer.source_id})
	check(claim(current).accepted and current.token!=old_token,"Re-registration gets a different lifetime token")
	current.registry.call("dispatch",5,{"id":current.point_id,"token":old_token,"publication":999999,"properties":{"radius":0},"state":{"range":0},"revision":999999})
	pair(previous,current,"stale old-token publication cannot replace current fields")
	check(int(stats(current).stale_packets)>0,"Stale publication is counted explicitly")
	current.registry.call("dispatch",7,{"id":current.point_id,"token":old_token})
	check(int(stats(current).cached_members)==1,"Stale revoke cannot cancel new registration")
	var replaced_claim_token: int=current.token
	check(claim(current).accepted and current.token!=replaced_claim_token,"A replacement claim also rotates the capability token")
	current.registry.call("dispatch",5,{"id":current.point_id,"token":replaced_claim_token,"publication":999999,"properties":{"radius":0},"state":{"range":0},"revision":999999})
	pair(previous,current,"stale earlier-claim packet cannot resume after a new claim")
	for peer in [previous,current]:
		peer.point.native_admitted=false;peer.point.native_fade=0.0
		peer.point.configure({"color":[0.8,0.4,0.2],"radius":8.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1})
	pair(previous,current,"configure setup")
	var next_properties: Dictionary={"color":[0.4,0.2,0.1],"radius":2.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1}
	var next_state: Dictionary=Policy.point(next_properties,2.0,0.2,1.5,0.0)
	var position_x: float=(float(previous.point.native_state.range)+float(next_state.range))*0.5
	for peer in [previous,current]:peer.point.position=Vector3(position_x,0,0);peer.source.position=Vector3.ZERO
	planes=Array()
	for index in 6:planes.append(Plane(Vector3.RIGHT,0.0))
	pair(previous,current,"configure witness initial frustum",true)
	for peer in [previous,current]:peer.point.visibility_changed.connect(observe_configure.bind(peer))
	previous.point.configure(next_properties);current.point.configure(next_properties)
	check(previous.observations.size()>=2,"Witness actually polls before and after the new policy state")
	check(var_to_bytes(previous.observations)==var_to_bytes(current.observations),"Every intermediate visibility callback matches live original reads")
	check(int(stats(current).cached_members)==1,"Completed outer configure resumes field publication")
	pair(previous,current,"configure final state")
	for peer in [previous,current]:
		peer.observations.clear()
		peer.nested_pending=true
		peer.nested_properties={"color":[0.2,0.3,0.4],"radius":6.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1}
	var outer_properties: Dictionary={"color":[0.4,0.3,0.2],"radius":3.0,"multiplier":1.0,"isdynamic":1,"affectdynamic":1}
	previous.point.configure(outer_properties);current.point.configure(outer_properties)
	check(previous.observations.size()>=2,"Nested configure callback witness actually runs")
	check(var_to_bytes(previous.observations)==var_to_bytes(current.observations),"Nested writer intermediate callback observations match exactly")
	check(int(stats(current).cached_members)==1,"Only completed outer writer resumes publication after nesting")
	pair(previous,current,"nested configure final state")
	for peer in [previous,current]:peer.point.visibility_changed.disconnect(observe_configure.bind(peer))
	for peer in [previous,current]:peer.registry.call("dispatch",2,{"id":peer.point_id})
	pair(previous,current,"removal")
	check(int(stats(current).cached_members)==0,"Removal releases publication membership")
	dispose(previous);dispose(current)
	# A distinct Script with the exact same pinned source allows a source-edit
	# guard test without modifying the globally preloaded canonical Script.
	var changed_script:=GDScript.new();changed_script.source_code=(Point as GDScript).source_code
	check(changed_script.reload()==OK,"Isolated exact writer compiles for same-Resource source edit witness")
	var changed:=scene(true,false,changed_script)
	poll(changed)
	var same_source: String=changed_script.source_code
	changed_script.source_code=(same_source+"x").left(same_source.length())
	poll(changed)
	check(int(stats(changed).cached_members)==1 and int(stats(changed).script_revocations)==0,"Equal source contents remain valid even with a different String allocation")
	var held_properties: Dictionary=changed.point.native_properties
	var held_bytes:=var_to_bytes(held_properties)
	changed_script.source_code+="\n# source changed without replacing Script Resource\n"
	poll(changed)
	check(int(stats(changed).cached_members)==0 and int(stats(changed).script_revocations)==1,"Same Script source edit revokes cached fields")
	check(var_to_bytes(held_properties)==held_bytes,"Revocation releases aliases without clearing canonical data")
	dispose(changed);changed_script=null
	var detached_previous:=scene(false,false);var detached_current:=scene(true,false)
	pair(detached_previous,detached_current,"same-Script reattach setup")
	var detached_properties: Dictionary=detached_current.point.native_properties
	var detached_bytes:=var_to_bytes(detached_properties)
	for peer in [detached_previous,detached_current]:
		peer.script_observations=[]
		peer.point.script_changed.connect(observe_reattach.bind(peer))
		peer.point.set_script(null)
		peer.point.set_script(Point)
	check(detached_previous.script_observations.size()==1,"Reattach witness polls exactly in the same-Script attach callback")
	check(var_to_bytes(detached_previous.script_observations)==var_to_bytes(detached_current.script_observations),"Earlier same-Script attach callback sees new fields, never old aliases")
	check(int(stats(detached_current).cached_members)==0 and int(stats(detached_current).binding_revocations)==1,"New script instance's zero token revokes the prior capability")
	check(var_to_bytes(detached_properties)==detached_bytes,"Same-Script retirement does not clear old canonical Dictionary")
	pair(detached_previous,detached_current,"same-Script reattach final live fallback")
	dispose(detached_previous);dispose(detached_current)
	var replacement:=GDScript.new()
	replacement.source_code="extends OmniLight3D\nvar native_properties: Dictionary={\"radius\":3.0,\"color\":[0.2,0.3,0.4]}\nvar native_state: Dictionary={\"range\":4.0}\nvar native_properties_revision:=0\n"
	check(replacement.reload()==OK,"Unknown replacement facade compiles")
	var replaced_previous:=scene(false,false);var replaced_current:=scene(true,false)
	pair(replaced_previous,replaced_current,"different-Script replacement setup")
	for peer in [replaced_previous,replaced_current]:peer.point.set_script(replacement)
	pair(replaced_previous,replaced_current,"different-Script replacement uses live original fields")
	check(int(stats(replaced_current).cached_members)==0 and int(stats(replaced_current).script_revocations)==1,"Different Script revokes exact-writer capability")
	dispose(replaced_previous);dispose(replaced_current);replacement=null
	var drained:=scene(true,false)
	for turn in 16:
		var marker: RefCounted=RefCounted.new()
		var weak_marker: WeakRef=weakref(marker)
		drained.point.native_properties={"radius":8.0,"color":[0.2,0.3,0.4],"retention_marker":marker}
		marker=null
		drained.point._begin_native_input_write()
		drained.point.native_properties={}
		check(weak_valid(weak_marker),"Revoked in-flight alias retains only the prior live publication "+str(turn))
		drained.registry.call("dispatch",2,{"id":drained.point_id})
		check(not weak_valid(weak_marker),"Removal drains prior alias Resource immediately "+str(turn))
		drained.point._end_native_input_write()
		drained.registry.call("dispatch",0,{"id":drained.point_id,"source":drained.source_id})
		check(claim(drained).accepted,"Repeated registration can enroll cleanly after draining "+str(turn))
	dispose(drained)
	var script_controls: Array=[]
	for turn in 4:
		var control:=isolated_script_lifetime(false,turn)
		var candidate:=isolated_script_lifetime(true,turn)
		check(int(candidate.before)==int(control.before)+1,"V4 has exactly the documented one Script reference before removal "+str(turn))
		check(candidate.after==control.after,"Post-removal Script reference count matches the old no-cache control "+str(turn))
		script_controls.append([control,candidate])
	await process_frame
	for index in script_controls.size():
		var control: Dictionary=script_controls[index][0]
		var candidate: Dictionary=script_controls[index][1]
		var control_after:=weak_count(control.weak);var candidate_after:=weak_count(candidate.weak)
		# GDScript.new has a generated gdscript:// path; reload inserts it into
		# the engine's shallow script cache. Expiry before cache shutdown would
		# be an invalid requirement. Compare against that actual old control.
		check(control_after>0 and candidate_after==control_after,"No additional Script ownership after setup frame, relative to actual engine cache control "+str(index))
		script_lifetime_witnesses.append({"control_before":control.before,"candidate_before":candidate.before,"control_after_erase":control.after,"candidate_after_erase":candidate.after,"control_after_frame":control_after,"candidate_after_frame":candidate_after})
	finish()
func finish() -> void:
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"script_lifetime_witnesses":script_lifetime_witnesses,"gpu":false,"server_connections":0},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
