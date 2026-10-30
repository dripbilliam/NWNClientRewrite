extends "res://tests/native_particle_schedule_test.gd"
const Bounce=preload("res://systems/native_data/projectile_bounce.gd")
func bits(v: Array) -> Array: return v.map(func(x):return PackedFloat32Array([x]).to_byte_array().decode_u32(0))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report) or not FileAccess.file_exists(args.oracle): quit(2); return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); check(data.binarySha256==BINARY_SHA and data.rows.size()==1500,"Original isolated builder identity/count")
	var index:=0
	for row in data.rows:
		var c: Dictionary=row.case; var calls: Array=[]; var state:={"position":M.values(c.position),"orientation":M.values(c.orientation),"endpoint":M.values(c.endpoint),"targetId":int(c.targetId),"totalTime":int(c.duration),"nodes":[]}; var ray: Array=[0]
		var p:={"clientObject":func(id):calls.append(["clientObject",id]); return {} if c.client else null,"sceneAvailable":func():return bool(c.scene),"random":func():calls.append(["random"]); return c.random,
			"allocateNode":func(_n):calls.append(["allocate",48]),"trace":func(a,b):
				calls.append(["ray",bits(a),bits(b),1,"0xffffffffbfffffff",0]); var at:=int(ray[0]); ray[0]+=1; return {"hit":bool(c.hits[at]),"position":[a[0],a[1],c.heights[at]]}}
		Bounce.build(state,int(c.path),p)
		var nodes: Array=[]
		for n in state.nodes: nodes.append({"point":bits(n.point),"attachment":bits(n.attachment),"targetId":n.targetId,"childPath":n.childPath,"duration":n.duration,"threshold":n.threshold,"radiusBits":PackedFloat32Array([n.radius]).to_byte_array().decode_u32(0),"spawnCount":n.spawnCount,"kind":n.kind})
		check(same(nodes,row.nodes).is_empty() and same(calls,row.calls).is_empty(),"Original bounce/deflection case "+str(index)+": "+same(nodes,row.nodes)+" "+same(calls,row.calls)); index+=1
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"oracleSha256":FileAccess.get_sha256(args.oracle),"scope":"Original isolated path 11/12/13 instructions, exact f32 nodes/durations, finite SSE trig and authored ray responses; does not prove native scene/BSP membership or actual server outcomes"},"\t")); file.close()
	print("NATIVE_PROJECTILE_BOUNCE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
