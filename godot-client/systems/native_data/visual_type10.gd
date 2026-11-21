extends RefCounted
# Direct Type10 projectile timing/start projection from visual_type10.js.
const NativeLog=preload("res://systems/native_data/native_log.gd")
const U32=0xffffffff
const CP1252_EXTENSIONS=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178]
static func object_template_resref(text: String) -> Dictionary:
	# create_object.js::objectTemplateResRef validates the complete CP1252
	# string through nativeItemTag, then copies at most 16 bytes before NUL.
	var output: String=""
	var terminated:=false
	for point in text.length():
		var code: int=text.unicode_at(point)
		if code>255 and not CP1252_EXTENSIONS.has(code): return {"error":"Native stack comparison tag byte encoding is unavailable"}
		if not terminated and output.length()<16:
			if code==0:terminated=true
			else:output+=String.chr(code)
	return {"value":output}
static func f(value: float) -> float:
	return PackedFloat32Array([value])[0]
static func copy(values: Array) -> Array:
	return values.map(func(value):return f(float(value)))
static func delta(a: Array,b: Array) -> Array:
	var result:Array=[]
	for index in 3:result.append(f(f(float(a[index]))-f(float(b[index]))))
	return result
static func magnitude(values: Array) -> float:
	var x:float=f(float(values[0])); var y:float=f(float(values[1])); var z:float=f(float(values[2]))
	var squared:float=f(f(f(x*x)+f(y*y))+f(z*z))
	return f(sqrt(squared)) if squared>0.0 else 0.0
static func cvtt_low(value: float) -> int:
	return int(value)&U32 if is_finite(value) and value>=-9223372036854775808.0 and value<9223372036854775808.0 else 0
static func projectile_time(mode: String,from: Array,to: Array,launch: Array) -> Dictionary:
	var nul:int=mode.find(String.chr(0))
	if nul>=0:mode=mode.left(nul)
	if mode=="log":
		var distance:float=magnitude(delta(to,from))
		var branches:Dictionary=NativeLog.branches(distance)
		if branches.has("error"):return branches
		var times:Array=[]
		for log_value in branches.get("values",[]):
			var divisor:float=f(f(float(log_value)*3.0)+2.0)
			var travel:float=f(f(distance/divisor)*1000.0) if divisor!=0.0 else INF
			times.append(cvtt_low(travel))
		if times.is_empty() or times.any(func(value):return int(value)!=int(times[0])):return {"error":"Native procedural projectile CPU branches produce different travel times"}
		return {"value":int(times[0])}
	var time:int=cvtt_low(f(f(magnitude(delta(to,launch))/55.0)*1000.0))
	return {"value":((time+time)&U32) if mode=="linear2" else time}
static func start(effect: Dictionary,id: int,p: Dictionary) -> Dictionary:
	var target:Variant=p.clientObject.call(int(effect.target54))
	var target_render:Variant=p.renderObject.call(target) if target!=null else null
	var source:Variant=p.clientObject.call(int(effect.source58))
	var source_render:Variant=p.renderObject.call(source) if source!=null else null
	if target_render==null or source_render==null:return {"projectile":null}
	id&=65535
	var model:String=str(p.programString.call(id,"param1").value)
	var spell:Dictionary=p.programInt.call(id,"param2")
	var facing:Dictionary=p.programInt.call(id,"param3")
	var path:Dictionary=p.programInt.call(id,"param4")
	var mode:String=str(p.programString.call(id,"param5").value)
	var projectile:Dictionary=p.constructProjectile.call()
	if projectile.is_empty():return {"error":"Native procedural projectile allocation failed","projectile":null}
	p.configureSpell.call(projectile,int(spell.value) if bool(spell.found) else 340)
	projectile.facing=(int(facing.value) if bool(facing.found) else 0)&255
	var resref:Dictionary=object_template_resref(model)
	if resref.has("error"):return {"error":resref.error,"projectile":projectile}
	if not p.loadProjectileModel.call(projectile,str(resref.value),255,0):p.destroyProjectile.call(projectile);return {"projectile":projectile}
	var position:Array=[0.0,0.0,0.0]
	var quaternion:Array=[1.0,0.0,0.0,0.0]
	var source_model:Variant=p.sourceModel.call(source_render)
	var source_pose:=int(p.sourceNodePose.call(source_model,"handconjure",position,quaternion)) if source_model!=null else 0
	if source_pose<0:return {"error":str(p.partQueryFailure.call()),"projectile":projectile}
	if source_pose==0:position.assign(copy(source_render.position))
	p.projectilePosition.call(projectile,copy(position))
	p.projectileOrientation.call(projectile,copy(source_render.orientation))
	var client:Variant=p.controlledClient.call()
	if client is Dictionary and client.get("videoF8") is Dictionary:
		var scene_result:Variant=p.projectileScene.call(projectile,client.videoF8.get("gui248"))
		if scene_result is bool and not scene_result:
			return {"error":"Native procedural projectile scene publication failed","projectile":projectile}
	p.projectileStage.call(projectile,1)
	var zero_point:bool=effect.point48 is Array and effect.point48.size()==3 and effect.point48.all(func(value):return float(value)==0.0)
	if zero_point:
		projectile.endpoint=copy(target_render.position)
		p.projectileTarget.call(projectile,int(target_render.id),"")
	else:projectile.endpoint=copy(effect.point48)
	var travel:Dictionary=projectile_time(mode,source_render.position,target_render.position,position)
	if travel.has("error"):return {"error":travel.error,"projectile":projectile}
	p.projectileTime.call(projectile,int(travel.value))
	p.projectilePath.call(projectile,int(path.value) if bool(path.found) else 0)
	return {"projectile":projectile}
