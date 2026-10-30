extends RefCounted
# Original CNWCProjectile path/AI owners, native XYZ and binary32 operations.
# Target/model/RNG/scene services remain explicit. Never mutate server objects.
const M=preload("res://systems/native_render/particle_math.gd")
const Bounce=preload("res://systems/native_data/projectile_bounce.gd")
const INVALID=0x7f000000
static func constructor_state(now: Dictionary) -> Dictionary:
	return {"id":INVALID,"objectType":8,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0],"endpoint":[0.0,0.0,0.0],"previousPosition":[0.0,0.0,0.0],"velocity":[0.0,0.0,0.0],"acceleration":[0.0,0.0,0.0],"nodes":[],"node":null,"model":null,"stage":0,"lastTime":now.duplicate(),"remaining":0,"totalTime":0,"elapsed":0,"tracked":1,"loopStarted":0,"phase":0,"faceCamera":0,"path":0,"attachOnImpact":1,"impactDuration":1,"sound":null,"loopSound":"","impactSound":"","result":0,"rangedEffect":0,"spellId":0,"spiralSide":0,"facing":0,"impactNode":"impact","auxiliaryModel":null,"destroyed":false}
static func divf(a: float,b: float) -> float:
	if b!=0: return M.f(a/b)
	if a==0 or is_nan(a): return NAN
	var sign_a:=PackedFloat32Array([a]).to_byte_array().decode_u32(0)>>31
	var sign_b:=PackedFloat32Array([b]).to_byte_array().decode_u32(0)>>31
	return -INF if sign_a!=sign_b else INF
static func square(v: Array) -> float: return M.f(M.f(M.f(v[0]*v[0])+M.f(v[1]*v[1]))+M.f(v[2]*v[2]))
static func motion(s: Dictionary,kind: String) -> Dictionary:
	var position:=M.values(s.position); var endpoint:=M.values(s.endpoint); var delta:=M.subtract(endpoint,position)
	var remaining:=M.f(M.f(int(s.remaining)&0xffffffff)/1000.0); var dt:=M.f(M.f(int(s.elapsed)&0xffffffff)/1000.0); var velocity: Array=[]
	if kind=="basic":
		var t2:=M.f(remaining*remaining); var scale_value:=divf(1,M.f(remaining+remaining))
		for i in 3: velocity.append(M.f(M.f(M.f(delta[i]+delta[i])-M.f(t2*M.f(s.acceleration[i])))*scale_value))
	elif kind=="spiral":
		var perpendicular: Array=[delta[1],M.f(-delta[0]),0.0] if (int(s.spiralSide)&255)==0 else [M.f(-delta[1]),delta[0],0.0]
		var normal:=M.normalize(perpendicular); var scale_value:=divf(1,remaining)
		for i in 3: velocity.append(M.f(M.f(delta[i]*scale_value)+M.f(normal[i]*7.5)))
	else: return {"error":"Unknown native projectile motion: "+kind}
	var next: Array=[]
	for i in 3: next.append(M.f(position[i]+M.f(dt*velocity[i])))
	if square(M.subtract(position,next))>square(delta): next=endpoint
	var direction:=delta; var orientation: Variant=null; var mode:=int(s.facing)&255
	if mode==1:
		if not s.get("attachment") is Array or s.attachment.size()!=3: return {"error":"Native projectile facing attachment unavailable"}
		direction=M.subtract(M.values(s.attachment),next)
	elif mode==2: direction=M.subtract(next,position)
	if mode!=0 and square(direction)>M.f(1e-10): orientation=M.normalize(direction)
	return {"position":next,"velocity":velocity,"orientation":orientation}
static func node(kind: int,point: Array,attachment: Array,duration: int,target: int,threshold: int=0,spawn: int=0,child: int=0,radius: float=-1) -> Dictionary:
	return {"point":M.values(point),"attachment":M.values(attachment),"targetId":target&0xffffffff,"childPath":child,"duration":duration&0xffffffff,"threshold":threshold&0xffffffff,"radius":radius,"spawnCount":spawn,"kind":kind}
static func append(s: Dictionary,n: Dictionary,p: Dictionary) -> void: p.allocateNode.call(n); s.nodes.append(n)
static func configure_path(s: Dictionary,path: int,p: Dictionary) -> void:
	s.path=path
	if int(s.targetId)!=INVALID:
		var found: Dictionary=p.getObject.call(int(s.targetId))
		if int(found.status)==0: s.endpoint=M.values(found.object.position)
	while not s.nodes.is_empty():
		var old=s.nodes.pop_front()
		if old!=null: p.destroyNode.call(old)
	if path in [1,2,4,5,7,9,10,50]:
		var point: Array=M.values(s.endpoint) if int(s.targetId)==INVALID or p.clientObject.call(int(s.targetId))==null else [0.0,0.0,0.0]
		if path==50:
			var split:=int(((int(s.totalTime)*6)&0xffffffff)/10)
			append(s,node(2,point,s.endpoint,int(s.totalTime),int(s.targetId),split),p)
			append(s,node(4,point,s.endpoint,split,int(s.targetId),0,3,9),p)
		else: append(s,node(12 if path==10 else path,point,[0.0,0.0,0.0] if path==7 else point,int(s.totalTime),int(s.targetId)),p)
	elif path in [3,6,8,11,12,13]: p.buildPath.call(s,path)
	else: return
	s.node=s.nodes.pop_front()
	if s.node==null: return
	s.remaining=int(s.node.duration)&0xffffffff; s.totalTime=s.remaining; s.endpoint=M.values(s.node.point)
	p.initializeNode.call(s,M.values(s.orientation))
static func initialize_node(s: Dictionary,orientation: Array,p: Dictionary) -> void:
	var n: Variant=s.node
	if n==null: return
	var point: Array=[0.0,0.0,0.0]
	if int(s.targetId)==INVALID: point=M.values(n.point)
	else:
		var found: Dictionary=p.getObject.call(int(s.targetId))
		if int(found.status)==0 and int(found.object.objectType)>=5:
			var object: Dictionary=found.object; var model=p.model.call(object)
			if model==null: point=M.values(s.endpoint)
			else:
				var pose: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
				if not p.nodePose.call(p.model.call(object),str(s.get("impactNode","")),pose,q): point=[M.f(object.position[0]),M.f(object.position[1]),M.f(M.f(object.position[2])+1.25)]
				else: point=M.values(pose)
				point=M.add(point,n.point)
	var delta:=M.subtract(point,M.values(s.position))
	if square(delta)<=M.f(1e-10): s.velocity=[0.0,0.0,0.0]; s.acceleration=[0.0,0.0,0.0]; return
	var time:=M.f(M.f(int(s.remaining)&0xffffffff)/1000.0)
	if int(n.kind)==2: s.acceleration=[0.0,0.0,M.f(-9.81)]
	elif int(n.kind) in [1,6]: s.acceleration=[0.0,0.0,0.0]
	elif int(n.kind)==5:
		s.velocity=[0.0,0.0,0.0]; var scale_value:=divf(1,M.f(time*time)); s.acceleration=[]
		for value in delta: s.acceleration.append(M.f(M.f(value+value)*scale_value))
	elif int(n.kind)==10:
		orientation[2]=0.0; s.acceleration=M.normalize(orientation).map(func(v):return M.f(v*7.5)); var scale_value:=divf(2,time); s.velocity=[]
		for i in 3: s.velocity.append(M.f(M.f(delta[i]*scale_value)-s.acceleration[i]))
		for i in 2: s.acceleration[i]=divf(M.f(M.f(s.acceleration[i]*s.acceleration[i])-M.f(s.velocity[i]*s.velocity[i])),M.f(delta[i]*2))
	elif int(n.kind) in [4,7,9,12]: p.initializeSpecial.call(s,orientation,delta,time)
	else: s.velocity=[0.0,0.0,0.0]; s.acceleration=[0.0,0.0,0.0]
static func build_path(s: Dictionary,path: int,p: Dictionary) -> void:
	if path in [11,12,13]: Bounce.build(s,path,p)
	elif path==3:
		var point: Array=M.values(s.endpoint) if int(s.targetId)==INVALID or p.clientObject.call(int(s.targetId))==null else [0.0,0.0,0.0]
		var half: int=(int(s.totalTime)&0xffffffff)>>1; var lift:=M.values(s.position); lift[2]=M.f(lift[2]+30)
		append(s,node(1,lift,point,half,INVALID),p)
		var reset:=M.values(point); reset[2]=M.f(reset[2]+30); append(s,node(11,reset,point,0,int(s.targetId)),p)
		append(s,node(1,point,point,(int(s.totalTime)-half)&0xffffffff,int(s.targetId)),p)
	elif path==6:
		s.spiralSide=int(p.random.call())%2
		var delta:=M.subtract(M.values(s.endpoint),M.values(s.position))
		var perpendicular: Array=[M.f(-delta[1]),delta[0],0.0] if s.spiralSide!=0 else [delta[1],M.f(-delta[0]),0.0]
		if square(perpendicular)<=M.f(1e-10): perpendicular=[0.0,1.0,0.0]
		var point: Array=M.normalize(perpendicular).map(func(v):return M.f(v+v)); var invalid:=int(s.targetId)==INVALID
		if invalid: point=[M.f(point[0]+M.f(s.endpoint[0])),M.f(point[1]+M.f(s.endpoint[1])),M.f(s.position[2])]
		if int(s.totalTime)==2500:
			var admitted:=invalid
			if not invalid:
				var found: Dictionary=p.getObject.call(int(s.targetId))
				if int(found.status)==0: point=[M.f(M.f(found.object.position[0])+point[0]),M.f(M.f(found.object.position[1])+point[1]),M.f(s.position[2])]; admitted=true
			if admitted: p.setPosition.call(s,point)
		else: append(s,node(10,point,s.endpoint if invalid else [0.0,0.0,0.0],(int(s.totalTime)-2500)&0xffffffff,int(s.targetId),0,0,0,2),p)
		var final: Array=s.endpoint if invalid else [0.0,0.0,0.0]; append(s,node(6,final,final,2500,int(s.targetId)),p)
	else: p.unsupported.call("projectile.path-builder",path)
static func next_node(s: Dictionary,p: Dictionary) -> int:
	if s.node!=null: p.destroyNode.call(s.node); s.node=null
	while not s.nodes.is_empty():
		s.node=s.nodes.pop_front(); var n: Variant=s.node
		if n==null: return 0
		if int(n.kind)==11:
			if s.model!=null and p.setStage.call(s,0)!=0: s.stage=0
			p.animateExternal.call(p.model.call(s),1)
			if int(n.targetId)==INVALID: p.setPosition.call(s,M.values(n.point))
			else:
				var found: Dictionary=p.getObject.call(int(n.targetId))
				if int(found.status)==0: p.setPosition.call(s,M.add(M.values(found.object.position),n.point))
			p.animateExternal.call(p.model.call(s),1)
			if s.model!=null and p.setStage.call(s,1)!=0: s.stage=1
		if (int(n.spawnCount)&255)!=0: p.spawnNodeChildren.call(s,n)
		s.remaining=int(n.duration)&0xffffffff; s.totalTime=s.remaining; s.endpoint=M.values(n.point); p.initializeNode.call(s,M.values(s.orientation))
		if int(n.kind)!=11 and (int(s.elapsed)&0xffffffff)<int(s.remaining): return 1
	return 0
static func endpoint(s: Dictionary,p: Dictionary,first: bool,resolved: Array) -> void:
	var n: Dictionary=s.node
	if int(n.targetId)==INVALID: s.endpoint=M.values(n.point); return
	var found: Dictionary=p.getObject.call(int(n.targetId))
	if int(found.status)!=0:
		if first: s.endpoint=M.values(n.point)
		return
	var object: Dictionary=found.object; var model=p.model.call(object)
	if model==null: resolved.assign(M.values(s.endpoint))
	else:
		var pose: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
		if not p.nodePose.call(p.model.call(object),str(s.get("impactNode","")),pose,q):
			resolved.assign([M.f(object.position[0]),M.f(object.position[1]),M.f(M.f(object.position[2])+1.25)])
			if (((int(s.result)&255)-2)&255)<2: resolved.assign(M.add(resolved,M.values(s.orientation).map(func(v):return M.f(v*M.f(-0.5)))))
		else: resolved.assign(M.values(pose))
	n.attachment=M.values(resolved); s.endpoint=M.add(resolved,n.point)
static func update_path(s: Dictionary,p: Dictionary) -> void:
	if s.node==null: return
	var resolved: Array=[0.0,0.0,0.0]; endpoint(s,p,true,resolved)
	var expired: bool=(int(s.remaining)&0xffffffff)<=(int(s.elapsed)&0xffffffff)
	if expired: s.elapsed=(int(s.elapsed)-int(s.remaining))&0xffffffff; s.remaining=0; p.setPosition.call(s,M.values(s.endpoint))
	if (((int(s.remaining)-int(s.elapsed))&0xffffffff)<=(int(s.node.threshold)&0xffffffff) or expired) and p.nextNode.call(s)==0: return
	s.remaining=(int(s.remaining)-int(s.elapsed))&0xffffffff
	if s.node==null: return
	endpoint(s,p,false,resolved)
	var delta:=M.subtract(M.values(s.endpoint),M.values(s.position))
	if square(delta)>M.f(1e-10):
		var n: Dictionary=s.node
		if not (n.radius>=0 and int(n.targetId)!=INVALID and square(M.subtract(M.values(s.position),resolved))<=M.f(M.f(n.radius)*M.f(n.radius))):
			s.previousPosition=M.values(s.position)
			if int(n.kind) in [1,2,4,5,9,10,12]: p.basicMotion.call(s)
			elif int(n.kind)==6: p.spiralMotion.call(s)
			return
	else:
		p.setPosition.call(s,M.values(s.endpoint))
		if s.node.radius<0: return
	var saved:=int(s.remaining); p.nextNode.call(s); s.remaining=(int(s.remaining)+saved)&0xffffffff
static func stage(s: Dictionary,value: int,p: Dictionary) -> int:
	if s.model==null: return 0
	var code:=value&65535; var clip: String={0:"default",1:"travel01",2:"impact01"}.get(code,"")
	p.playAnimation.call(s.model,clip,1.0,1 if code==2 else 0,0.0); s.stage=code; return 1
static func update(s: Dictionary,now: Dictionary,p: Dictionary) -> void:
	s.elapsed=int(p.difference.call(now,s.lastTime).time)&0xffffffff
	if int(s.phase)==1:
		var saved: int=s.remaining; s.remaining=0; p.updatePath.call(s); s.remaining=saved
	else: p.updatePath.call(s)
	if int(s.tracked)==1:
		if s.sound!=null: p.updateSound.call(s.sound,M.values(s.position),1.5)
		if int(s.phase)==1:
			var camera=p.camera.call()
			if int(s.faceCamera)!=0: p.faceCamera.call(s,camera)
			s.remaining=(int(s.remaining)-int(s.elapsed))&0xffffffff if (int(s.elapsed)&0xffffffff)<(int(s.remaining)&0xffffffff) else 0
			if int(s.remaining)==0:
				p.setScene.call(s,0)
				if s.sound!=null: p.destroySound.call(s.sound)
				p.destroy.call(s); return
		elif p.getStage.call(s)==1 or p.getStage.call(s)==0:
			if int(s.loopStarted)==0:
				if s.sound!=null: p.destroySound.call(s.sound); s.sound=null
				if s.loopSound:
					s.sound=p.createSound.call(s.loopSound)
					if s.sound!=null:
						p.soundPriority.call(s.sound,12); p.sound3d.call(s.sound,1); p.soundLooping.call(s.sound,1); p.updateSound.call(s.sound,M.values(s.position),1.5); p.playSound.call(s.sound)
			s.loopStarted=1
			if int(s.remaining)==0:
				p.setStage.call(s,2); s.phase=1
				if s.sound!=null: p.stopSound.call(s.sound); p.destroySound.call(s.sound); s.sound=null
				if s.impactSound: p.oneShot.call(s.impactSound,M.values(s.position),12,0)
				if int(s.attachOnImpact)==1: p.attachImpact.call(s); s.remaining=int(s.impactDuration)&0xffffffff
				else: s.remaining=0
	s.lastTime=now.duplicate()
