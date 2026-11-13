extends "res://tests/native_particle_presentation_test.gd"
class RetireHit:
	extends RefCounted
	var target: WeakRef
	var events: Array
	func _notification(what: int) -> void:
		if what!=NOTIFICATION_PREDELETE:return
		events.append("retire_hit")
		var owner: RefCounted=target.get_ref()
		if owner==null:events.append("missing_owner");return
		var result: Dictionary=owner.call("dispatch",0,{}, {})
		events.append("retire_config_rejected" if str(result.get("error","")).contains("already configured") else "unexpected_config_result")

func seeded(scene: Node3D,hit: Variant,active: bool=true,direct: bool=true) -> Dictionary:
	var seed: Dictionary=make_owner(false,"fountain",16,false,false)
	seed.state.birthRate=0.0;seed.state.lifeExp=10.0;seed.state.hit1f0=hit;seed.state.mass=0.0
	if active:
		var first: Dictionary=Init.create(seed.state,0.0,seed.providers)
		first.stopped70=0;first.age=0.0;first.velocity58=[0.0,0.0,-0.2]
		seed.state.active188.records=[first,first.duplicate(true)];seed.state.active188.capacity=2
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":scene.get_instance_id(),"sourceId":scene.get_instance_id(),"directFieldKeys":direct},{})
	check(not configured.has("error"),"Normal boundary fixture configures before first hit access")
	seed.providers.clear()
	return {"owner":owner,"seed":seed}

func boundaries(scene: Node3D) -> Array:
	var summaries: Array=[]
	for definition: Dictionary in [{"name":"nil-inactive","hit":null,"active":false,"error":false},{"name":"nil-active","hit":null,"active":true,"error":true},{"name":"integer-active","hit":17,"active":true,"error":true},{"name":"missing-normal","hit":{},"active":true,"error":false},{"name":"nil-normal","hit":{"normal":null},"active":true,"error":false},{"name":"foreign-schema","hit":{"flags":1,"normal":[0,0,0]},"active":true,"error":false}]:
		for direct: bool in [false,true]:
			var fixture: Dictionary=seeded(scene,definition.hit,definition.active,direct)
			var owner: RefCounted=fixture.owner
			var calls: Array=[]
			var providers: Dictionary={"collide":func(_old,_goal,_out,hit):calls.append("collide");hit.normal=[0.0,0.0,1.0];return false}
			var result: Dictionary=owner.call("dispatch",1,{"clip":"","time":0.0,"delta":0.01,"capacity":0,"draw":{"factor":1.0,"camera":[1,0,0,0],"tint":[1,1,1]}},providers)
			check(result.has("error")==definition.error,"First actual normal boundary keeps success/error "+definition.name+str(direct))
			if definition.error:check(result.error=="Native owner record required" and calls.is_empty(),"Invalid captured hit fails at first clear before collision callback")
			else:check(calls.size()==(2 if definition.active else 0),"All original clear/collision iterations remain present")
			summaries.append({"name":definition.name,"direct":direct,"error":result.get("error",""),"calls":calls.duplicate()})
			providers.clear();fixture.clear();owner=null
	return summaries

func replaced_hit(scene: Node3D) -> Dictionary:
	var events: Array=[]
	var retire:=RetireHit.new();retire.events=events
	var fixture: Dictionary=seeded(scene,{"normal":[0,0,0],"sentinel":retire})
	var owner: RefCounted=fixture.owner;retire.target=weakref(owner)
	fixture.seed.state.hit1f0.erase("sentinel");retire=null
	var state: Dictionary={"calls":0,"nested":false,"nested_error":"not reached"}
	var providers: Dictionary={}
	providers.collide=func(_old,_goal,_out,hit):
		events.append("collide"+str(state.calls));state.calls+=1
		if not state.nested:
			state.nested=true
			var nested: Dictionary=owner.call("dispatch",1,{"clip":"","time":0.0,"delta":0.0,"capacity":0,"draw":{"factor":1.0,"camera":[1,0,0,0],"tint":[1,1,1]},"patch":{"hit1f0":{"normal":[9,8,7]},"source50":{"position":[0,0,0],"quaternion":[1,0,0,0],"adjustedScale":1.0,"opacity108":1.0,"instance":{"fade":0.0,"height50":0.0,"opacity70":1.0}}}},providers)
			state.nested_error=nested.get("error","");events.append("nested_frame_ok" if not nested.has("error") else "nested_frame_error")
		hit.normal=[0.0,0.0,1.0]
		return false
	var result: Dictionary=owner.call("dispatch",1,{"clip":"","time":0.0,"delta":0.01,"capacity":0,"draw":{"factor":1.0,"camera":[1,0,0,0],"tint":[1,1,1]}},providers)
	events.append("returned")
	var snapshot: Dictionary=owner.call("dispatch",2,{}, {})
	check(not result.has("error") and state.nested_error.is_empty(),"Actual collision callback reenters a faded frame without reallocating the active pool")
	check(events==["collide0","nested_frame_ok","collide1","retire_hit","retire_config_rejected","returned"],"Captured-hit lifetime and failed configure callback keep exact order")
	check(snapshot.hit1f0.normal==[9,8,7],"Outer clears keep the captured old hit after nested replacement of owner state")
	var summary: Dictionary={"events":events.duplicate(),"normal":snapshot.hit1f0.normal,"calls":state.calls,"nested_error":state.nested_error,"error":result.get("error","")}
	providers.clear();fixture.clear();owner=null
	return summary

func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var probe: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var component: Dictionary=probe.call("dispatch",25,{"oracle":true})
	check(component.get("oracle",{}).get("success",false),"Current-location component oracle passes all identity/shape/lifetime cases")
	var expected: bool="--particle-hit-normal=bound" in OS.get_cmdline_user_args() and not "--particle-hit-normal=legacy" in OS.get_cmdline_user_args()
	check(component.enabled==expected and component.accesses==0,"Startup mode/default-off selected before live work")
	var frames: Dictionary=main_frames()
	var scene:=Node3D.new();root.add_child(scene)
	var semantic: Dictionary={"boundaries":boundaries(scene),"replaced_hit":replaced_hit(scene),"frames":frames.frames,"phase_separation":frames.phase_separation}
	var counters: Dictionary=probe.call("dispatch",25,{})
	if expected:check(counters.bridges>0 and counters.accesses>0 and counters.hits>0 and counters.resolutions>0,"Actual Bridge location reuse is observed")
	else:check(counters.bridges==0 and counters.accesses==0 and counters.hits==0,"Legacy path does not construct or read the location cache")
	probe=null;scene.free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"component":component.oracle,"semantic":semantic,"counters":counters,"scope":"Actual180-frame geometry/state/RNG plus first-access/missing/NIL/map-schema and nested collision hit replacement/predelete failure boundaries; no FPS claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
