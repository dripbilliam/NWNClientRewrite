extends "res://tests/native_particle_schedule_test.gd"
const Projectile=preload("res://systems/native_data/projectile_state.gd")
static func bits(value: float) -> Variant:
	var raw:=PackedFloat32Array([value]).to_byte_array().decode_u32(0)
	return "NaN" if raw&0x7f800000==0x7f800000 and raw&0x7fffff!=0 else raw
static func canonical(value: Variant) -> Variant:
	if value is Array:
		var result: Array=value.map(canonical)
		if result.size()==2 and result[0] is String and result[0] in ["position","orientation","initialize"] and result[1] is Array: result[1]=canonical_bits(result[1])
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key in value: result[key]=canonical_bits(value[key]) if key in ["position","orientation","endpoint","velocity","acceleration","previousPosition","point","attachment","bits"] and value[key] is Array else canonical(value[key])
		return result
	return value
static func canonical_bits(values: Array) -> Array:
	return values.map(func(value):
		if value is int or value is float:
			var raw:=int(value)
			if raw&0x7f800000==0x7f800000 and raw&0x7fffff!=0: return "NaN"
		return value)
func compare_values(a: Variant,b: Variant,path: String="") -> String:
	if (a is int or a is float) and (b is int or b is float): return "" if a==b else path+": "+str(a)+" != "+str(b)
	if typeof(a)!=typeof(b): return path+": value types differ "+str(a)+" != "+str(b)
	if a is Array:
		if a.size()!=b.size(): return path+" array length "+str(a.size())+" != "+str(b.size())
		for i in a.size():
			var difference:=compare_values(a[i],b[i],path+"/"+str(i))
			if not difference.is_empty(): return difference
		return ""
	if a is Dictionary:
		if a.size()!=b.size(): return path+" dictionary size differs"
		for key in b:
			if not a.has(key): return path+" missing "+str(key)
			var difference:=compare_values(a[key],b[key],path+"/"+str(key))
			if not difference.is_empty(): return difference
		return ""
	return "" if a==b else path+": values differ"
static func node_view(n: Variant) -> Variant:
	if n==null: return null
	var out: Dictionary=n.duplicate(true); out.point=n.point.map(bits); out.attachment=n.attachment.map(bits); return out
static func snapshot(s: Dictionary) -> Dictionary:
	var out: Dictionary={}
	for key in ["position","orientation","endpoint","velocity","acceleration","previousPosition"]: out[key]=s[key].map(bits)
	for key in ["remaining","elapsed","totalTime","path","spiralSide","stage"]: out[key]=int(s[key])&0xffffffff
	out.node=node_view(s.node); out.nodes=s.nodes.map(node_view); return out
func path_case(c: Dictionary) -> Dictionary:
	var s: Dictionary=c.duplicate(true); s.path=c.oldPath; s.node=c.node.duplicate(true) if c.hasNode else null; s.nodes=[]; s.model={} if c.model else null
	if c.mode=="next": s.nodes=c.nextNodes.duplicate(true)
	elif c.mode=="configure":
		for i in int(c.oldNodes): s.nodes.append(c.node.duplicate(true))
	var calls: Array=[]; var object:={"position":c.objectPosition,"objectType":c.objectType}; var lookup: Array=[0]; var p: Dictionary={}
	p={"getObject":func(id):
		calls.append(["getObject",id]); lookup[0]+=1; return {"status":c.lookup if lookup[0]<2 else c.get("secondLookup",c.lookup),"object":object},
		"clientObject":func(id):calls.append(["clientObject",id]); return object if c.clientObject else null,
		"model":func(_o):calls.append(["model"]); return {} if c.model else null,
		"nodePose":func(_m,_n,point,_q):
			calls.append(["nodePose"])
			if c.pose: point.assign(c.posePoint)
			return c.pose,
		"allocateNode":func(_n):calls.append(["allocate",48]),"destroyNode":func(n):calls.append(["destroy",node_view(n)]),
		"random":func():calls.append(["random"]); return int(c.random),
		"buildPath":func(state,path):calls.append(["build",path]); state.nodes.append(c.generated.duplicate(true)),
		"initializeNode":func(_state,orientation):calls.append(["initialize",orientation.map(bits)]),
		"setStage":func(_state,stage):calls.append(["stage",stage]); return c.animateResult,
		"animateExternal":func(_model,_delta):calls.append(["animateExternal"]),
		"setPosition":func(state,point):calls.append(["position",point.map(bits)]); state.position=point.duplicate(),
		"nextNode":func(state):
			calls.append(["next",int(state.remaining)&0xffffffff,int(state.elapsed)&0xffffffff])
			if c.advance: state.node=c.generated.duplicate(true) if int(c.advance)==1 else null; state.remaining=777
			return c.nextResult,
		"basicMotion":func(state):calls.append(["basic"]); state.position=[6,7,8]; state.velocity=[9,10,11],
		"spiralMotion":func(state):calls.append(["spiral"]); state.position=[6,7,8]; state.velocity=[9,10,11]}
	if c.mode=="flow":
		p.buildPath=func(state,path):Projectile.build_path(state,path,p)
		p.initializeNode=func(state,orientation):Projectile.initialize_node(state,orientation,p)
		p.nextNode=func(state):return Projectile.next_node(state,p)
		var move=func(state,kind):
			var moving: Dictionary=state.duplicate(); moving.attachment=state.node.attachment; var result:=Projectile.motion(moving,kind); state.velocity=result.velocity
			if result.orientation!=null: calls.append(["orientation",result.orientation.map(bits)]); state.orientation=result.orientation
			p.setPosition.call(state,result.position)
		p.basicMotion=move.bind("basic"); p.spiralMotion=move.bind("spiral")
		Projectile.configure_path(s,int(c.path),p); var observations: Array=[{"state":snapshot(s),"calls":calls.duplicate(true)}]; calls.clear()
		for step in int(c.maxSteps):
			s.elapsed=int(c.step); Projectile.update_path(s,p); observations.append({"state":snapshot(s),"calls":calls.duplicate(true)}); calls.clear()
			if int(s.remaining)==0: break
		p.clear(); return {"observations":observations}
	var result: Variant=null
	match str(c.mode):
		"configure": Projectile.configure_path(s,int(c.path),p)
		"initialize": Projectile.initialize_node(s,s.orientation,p)
		"build": Projectile.build_path(s,int(c.path),p)
		"next": result=Projectile.next_node(s,p)
		_: Projectile.update_path(s,p)
	p.clear(); return {"calls":calls,"state":snapshot(s),"result":result}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var index:=0; var modes: Dictionary={}
	for row in original("native-client-projectile-path-observations",17518):
		var actual:=path_case(row.case); var expected: Dictionary=row.duplicate(true); expected.erase("case")
		var difference:=compare_values(actual,canonical(expected)); check(difference.is_empty(),"Original path/trajectory "+str(index)+" "+difference); index+=1
		modes[row.case.mode]=int(modes.get(row.case.mode,0))+1
	index=0
	for row in original("native-client-projectile-motion-observations",1318):
		var s: Dictionary=row.case.duplicate(true)
		for expected in row.observations:
			var result:=Projectile.motion(s,str(s.kind)); var out:={"position":result.position.map(bits),"velocity":result.velocity.map(bits),"calls":[]}
			if result.orientation!=null: out.calls.append({"kind":"orientation","bits":result.orientation.map(bits)})
			out.calls.append({"kind":"position","bits":result.position.map(bits)})
			var difference:=compare_values(out,canonical(expected)); check(difference.is_empty(),"Original motion "+str(index)+" "+difference)
			s.position=result.position; s.remaining=maxi(0,int(s.remaining)-int(s.elapsed)); index+=1
	index=0
	for row in original("native-client-projectile-ai-observations",1356):
		var c: Dictionary=row.case; var s: Dictionary=c.duplicate(true); s.faceCamera=0; s.position=[1,2,3]; s.sound={} if c.sound else null; s.lastTime={"day":9,"time":900}; s.impactDuration=25; s.destroyed=false
		var calls: Array=[]
		var p:={"difference":func(_a,_b):return {"day":0,"time":c.delta},"updatePath":func(state):calls.append(["path",int(state.remaining)&0xffffffff]); state.remaining=c.pathRemaining; state.elapsed=c.delta if int(c.pathElapsed)<0 else c.pathElapsed,
			"camera":func():calls.append(["camera"]),"getStage":func(state):calls.append(["stage"]); return state.stage,"setStage":func(state,value):calls.append(["setStage",value]); state.stage=value,
			"createSound":func(_n):
				if c.soundFailure: return null
				calls.append(["createSound","loop"]); return {},
			"destroySound":func(_a):calls.append(["destroySound"]),"soundPriority":func(_a,n):calls.append(["priority",n]),"sound3d":func(_a,n):calls.append(["3d",n]),"soundLooping":func(_a,n):calls.append(["loop",n]),
			"updateSound":func(_a,point,gain):calls.append(["soundPosition",point,gain]),"playSound":func(_a):calls.append(["play"]),"stopSound":func(_a):calls.append(["stop"]),
			"oneShot":func(_a,point,priority,gain):calls.append(["oneShot","impact",point,priority,gain]),"attachImpact":func(_a):calls.append(["impactLookup"]),"setScene":func(_a,n):calls.append(["scene",n]),"destroy":func(state):calls.append(["destroy"]); state.destroyed=true}
		Projectile.update(s,{"day":10,"time":1000},p); var state: Dictionary={}
		for key in ["remaining","elapsed","phase","loopStarted","stage","lastTime","destroyed"]: state[key]=s[key]
		state.sound=s.sound!=null
		var difference:=compare_values({"calls":calls,"state":state},{"calls":row.calls,"state":row.state}); check(difference.is_empty(),"Original AI/timer/sound "+str(index)+" "+difference); index+=1
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalEvidence":evidence,"binarySha256":BINARY_SHA,"pathModes":modes,"scope":"Actual native original-derived path/AI/motion over stored original observations; lower model/RNG/scene providers and live delivery require separate acceptance"},"\t")); file.close()
	print("NATIVE_PROJECTILE_STATE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
