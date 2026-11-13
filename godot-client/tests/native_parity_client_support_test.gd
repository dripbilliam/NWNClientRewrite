extends SceneTree
# Authored lower-provider/controller + optional Motion seam fixture. This does
# not substitute for original-instruction, real SceneGeometry or live bridge
# acceptance. It has not been executed when first authored.
const Support=preload("res://systems/native_data/native_client_support.gd")
const Motion=preload("res://systems/network_motion.gd")
var failures: Array=[]
var checks:=0
var events: Array=[]
var report:=""
var original_corpus:=""
var original_cases:=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,context: String) -> void:
	checks+=1
	if not value and failures.size()<40: failures.append(context)

func exact(a: Vector3,b: Vector3,context: String) -> void:
	check(PackedFloat32Array([a.x,a.y,a.z]).to_byte_array()==PackedFloat32Array([b.x,b.y,b.z]).to_byte_array(),context)

func flat_trace(planes: Array,start: Vector3,end: Vector3) -> Dictionary:
	events.append(["ray",start,end])
	var best: Variant=null
	for z: float in planes:
		if start.z>=z and z>=end.z and (best==null or z>float(best)): best=z
	return {"available":true,"hit":false} if best==null else {"available":true,"hit":true,"position":Vector3(start.x,start.y,best),"normal":Vector3(0,0,1)}

func providers(planes: Array) -> Dictionary:
	var tile: Callable=func(point):
		events.append(["tile",point])
		return true
	var trace: Callable=func(a,b):return flat_trace(planes,a,b)
	return {"available":true,"area_present":true,"scene_present":true,"tile":tile,"trace":trace}

func motion_state() -> Dictionary:
	return {"position":Vector3(0,0,11),"render":Vector3(0,0,11),"orientation":Vector3.RIGHT,"path":[Vector3(2,0,0)],"cursor":0,"script":1,"animation":4}

static func bits(point: Vector3) -> String:
	return PackedFloat32Array([point.x,point.y,point.z]).to_byte_array().hex_encode()

func compare_original() -> void:
	if original_corpus.is_empty(): return
	var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string(original_corpus))
	if not corpus is Dictionary or corpus.get("target")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or corpus.get("entry")!="0x1407ff030" or not corpus.get("cases") is Array:
		check(false,"original controller corpus identity/schema");return
	check(not corpus.cases.is_empty(),"original controller corpus is not empty")
	for row: Dictionary in corpus.cases:
		var c: Dictionary=row.case
		var cursor:={"tile":0,"ray":0}
		var tiles: Array=c.tiles; var rays: Array=c.rays
		var tile_queries: Array=[]; var ray_queries: Array=[]; var calls: Array=[]
		var p:={"available":true,"area_present":c.area,"scene_present":c.scene}
		p.tile=func(point):
			tile_queries.append(point)
			calls.append({"kind":"tile","point":point})
			var index: int=cursor.tile; cursor.tile+=1
			if index>=tiles.size():return {"available":false,"reason":"Unexpected authored tile probe"}
			return tiles[index]
		p.trace=func(a,b):
			ray_queries.append([a,b])
			calls.append({"kind":"ray","start":a,"end":b})
			var index: int=cursor.ray; cursor.ray+=1
			if index>=rays.size():return {"available":false,"reason":"Unexpected authored ray probe"}
			var answer: Variant=rays[index]
			if answer==null:return {"available":true,"hit":false}
			return {"available":true,"hit":true,"position":Motion.vector(answer.position),"normal":Motion.vector(answer.normal)}
		var result: Dictionary=Support.project(Motion.vector(c.point),float(c.previous),p)
		var context:="original/%s"%original_cases
		check(result.available,context+" available")
		check(bits(result.position)==row.position_hex,context+" exactXYZ")
		if c.normal_output:check(bits(result.normal)==row.normal_hex,context+" exactnormal")
		check(tile_queries.size()==row.tile_queries.size(),context+" tile callcount")
		for i in mini(tile_queries.size(),row.tile_queries.size()):exact(tile_queries[i],Motion.vector(row.tile_queries[i]),context+" tile/%s"%i)
		check(ray_queries.size()==row.ray_queries.size(),context+" ray callcount")
		for i in mini(ray_queries.size(),row.ray_queries.size()):
			exact(ray_queries[i][0],Motion.vector(row.ray_queries[i].start),context+" start/%s"%i)
			exact(ray_queries[i][1],Motion.vector(row.ray_queries[i].end),context+" end/%s"%i)
			check(int(row.ray_queries[i].mode)==1,context+" nativeSceneMode/%s"%i)
		check(calls.size()==row.events.size(),context+" complete call order count")
		for i in mini(calls.size(),row.events.size()):
			check(calls[i].kind==row.events[i].kind,context+" interleaved callback order/%s"%i)
			if calls[i].kind==row.events[i].kind and calls[i].kind=="tile":exact(calls[i].point,Motion.vector(row.events[i].point),context+" ordered tile/%s"%i)
			elif calls[i].kind==row.events[i].kind:
				exact(calls[i].start,Motion.vector(row.events[i].start),context+" ordered start/%s"%i)
				exact(calls[i].end,Motion.vector(row.events[i].end),context+" ordered end/%s"%i)
		original_cases+=1

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--original-corpus="):original_corpus=arg.substr(18)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var source:=Vector3(3,4,0)
	var p:=providers([0.0,11.0])
	var result: Dictionary=Support.project(source,11,p)
	check(result.available and result.branch=="original" and result.rays==1 and result.tiles==1,"raised support succeeds in near window")
	exact(result.position,Vector3(3,4,11),"raised MDL surface is not base WOK")
	check(events.size()==2 and events[0][0]=="tile" and events[1][1].z==12 and events[1][2].z==10,"tile then priorZ+1 down to priorZ-1")
	events.clear(); result=Support.project(source,0,providers([0.0,2.0]))
	check(result.position.z==0,"overlap does not blindly select highest surface")
	result=Support.project(source,2,providers([0.0,2.0]))
	check(result.position.z==2,"overlap respects prior support window")
	events.clear(); result=Support.project(source,30,p)
	check(result.rays==2 and result.position.z==11,"narrow miss uses broad 90 to -9")
	check(events[2][1].z==90 and events[2][2].z==-9,"broad ray direction and exact bounds")
	events.clear(); Support.project(source,16777217.0,providers([]))
	check(events[1][1].z==Support.f(Support.f(16777217.0)+1.0) and events[1][2].z==Support.f(Support.f(16777217.0)-1.0),"float ABI narrows previous before near-window arithmetic")
	events.clear(); result=Support.project(source,0,providers([0.0]))
	check(result.available and result.position.z==0,"valid zero is not unavailable")
	result=Support.project(source,11,{"available":false,"reason":"scope retired"})
	check(not result.available and result.reason=="scope retired" and not result.has("normal"),"unavailable has explicit reason and no invented normal")
	exact(result.position,Vector3(3,4,11),"unavailable retains candidateXY prior presentationZ")
	events.clear(); var missing:=providers([]); missing.area_present=false
	result=Support.project(source,11,missing)
	check(result.branch=="missing_area" and result.position.z==9 and events.is_empty(),"known missing area is native9 branch without callbacks")
	missing=providers([]); missing.scene_present=false; events.clear()
	result=Support.project(source,11,missing)
	check(result.branch=="missing_scene" and result.position.z==9 and events.size()==1 and events[0][0]=="tile","known missing scene still checks tile first")
	missing=providers([]); missing.tile=func(_p):return false
	result=Support.project(source,11,missing)
	check(result.branch=="missing_tile" and result.position.z==9 and result.rays==0,"known missing tile is native9 branch")
	missing=providers([]); missing.tile=func(_p):return {"available":false,"reason":"tile not prepared"}
	result=Support.project(source,11,missing)
	check(not result.available and result.reason=="tile not prepared" and result.position.z==11,"pending tile is not known missing tile")
	missing=providers([]); missing.erase("scene_present")
	check(not Support.project(source,11,missing).available,"unknown scene is unavailable")
	missing=providers([]); missing.trace=func(_a,_b):return {"available":true,"hit":true,"position":Vector3.ZERO}
	check(not Support.project(source,11,missing).available,"missing native normal refuses fabricated hit")
	missing.trace=func(_a,_b):return {"available":true,"hit":true,"position":Vector3(NAN,0,0),"normal":Vector3(0,0,1)}
	check(not Support.project(source,11,missing).available,"nonfinite hit rejected")
	check(not Support.project(Vector3(INF,0,0),11,p).available,"nonfinite input unavailable")
	var seam_point:=Vector3(0.0007,4.0009,0)
	var replies: Array=[false,false,true]
	p=providers([])
	p.trace=func(a,b):
		events.append(["ray",a,b])
		var hit: bool=replies.pop_front()
		return {"available":true,"hit":hit,"position":Vector3(a.x,a.y,11),"normal":Vector3(0,1,0)}
	events.clear(); result=Support.project(seam_point,11,p)
	check(result.branch=="negative_seam" and result.rays==3 and result.tiles==2,"negative seam order")
	var negative:=Vector3(Support.f(seam_point.x-Support.f(0.001)),Support.f(seam_point.y-Support.f(0.0001)),9)
	var restored:=Vector3(Support.f(negative.x+Support.f(0.001)),Support.f(negative.y+Support.f(0.0001)),11)
	exact(result.position,restored,"negative seam preserves ordered f32 restore output")
	exact(result.normal,Vector3(0,1,0),"actual hit normal retained")
	check(events[3][0]=="tile" and events[3][1]==negative,"negative XY tile retry")
	check(replies.is_empty(),"negative seam stops after successful near ray")
	replies=[false,false,false,false,false,true]
	p=providers([])
	p.trace=func(a,b):
		events.append(["ray",a,b])
		var hit: bool=replies.pop_front()
		return {"available":true,"hit":hit,"position":Vector3(a.x,a.y,12),"normal":Vector3(1,0,0)}
	events.clear(); result=Support.project(seam_point,11,p)
	check(result.branch=="positive_seam" and result.rays==6 and result.tiles==3,"positive seam is last after four failed rays")
	var positive:=Vector3(Support.f(restored.x+Support.f(0.0001)),Support.f(restored.y+Support.f(0.001)),9)
	exact(result.position,Vector3(Support.f(positive.x-Support.f(0.0001)),Support.f(positive.y-Support.f(0.001)),12),"positive seam retains finalf32 XY")
	check(events[6][0]=="tile" and events[6][1]==positive,"positive XY retry uses restored source then next ordered shift")
	events.clear(); result=Support.project(source,11,providers([]))
	check(result.available and result.branch=="no_hit" and result.position.z==9 and result.rays==6,"completed native miss is distinct from unprepared")
	exact(result.normal,Vector3(0,0,1),"completed miss uses native initialized UP")
	var scope:={"active":true,"calls":0}; p=providers([])
	p.trace=func(_a,_b):
		scope.calls+=1
		if scope.calls==1:
			scope.active=false
			return {"available":true,"hit":false}
		return {"available":false,"reason":"scope replaced"}
	result=Support.project(source,11,p)
	check(not result.available and result.reason=="scope replaced","provider retires between near/far probes without stale fallback")
	var original_authority:={"position":[0.0,0.0,11.0]}; var authority_bytes:=var_to_bytes(original_authority)
	var mover:=Motion.new(); var height_calls:={"count":0}
	mover.height_query=func(_point,_previous):height_calls.count+=1;return 0.0
	var state:=motion_state(); var step: Dictionary=mover.step_path(state,0.5)
	check(step.position.z==0 and height_calls.count==1,"unbound support keeps exact legacy height route")
	mover.support_query=func(point,_previous):return {"available":true,"position":Vector3(point.x,Support.f(point.y+0.0001),11),"normal":Vector3(0,0,1),"branch":"test"}
	state=motion_state(); step=mover.step_path(state,0.5)
	exact(step.position,Vector3(0.5,Support.f(0.0001),11),"Motion accepts full projectedXYZ")
	check(height_calls.count==1 and mover.support_stats.available==1,"bound support bypasses bare tile route")
	mover.support_query=func(_point,_previous):return {"available":false,"reason":"pending"}
	state=motion_state(); step=mover.step_path(state,0.5)
	exact(step.position,Vector3(0.5,0,11),"unavailable Motion support retains previousZ and candidateXY")
	check(mover.support_stats.unavailable==1 and mover.support_stats.last_reason=="pending" and height_calls.count==1,"unavailable counted without old grounding fallback")
	mover.support_query=func(_point,_previous):return null
	state=motion_state(); step=mover.step_path(state,0.5)
	check(step.position.z==11 and mover.support_stats.malformed==1,"malformed Motion support counted without fabricatedZ9")
	var snapshot: Dictionary=mover.support_snapshot(); snapshot.queries=-1
	check(mover.support_stats.queries==3,"support counter snapshot detached")
	check(var_to_bytes(original_authority)==authority_bytes,"authoritative received position untouched")
	compare_original()
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null: quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_corpus":original_corpus,"original_cases":original_cases,"scope":"Authored support-controller/Motion seam; optional original-instruction corpus count explicit; no mesh, GPU or live-server acceptance"},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
