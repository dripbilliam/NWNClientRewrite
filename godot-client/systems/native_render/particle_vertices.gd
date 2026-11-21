extends RefCounted
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const Trig=preload("res://systems/native_render/particle_trig.gd")
const BYTE_SCALE=255.99000549316406
const MAX_VERTICES=196608
static func draw_count(e: Dictionary) -> int:
	if e.source50!=null and e.source50.get("instance")!=null and 1>M.f(e.source50.instance.fade) or e.instance100!=null and 1>M.f(e.instance100.fade): return 0
	var count: int=e.active188.records.size()-(1 if int(e.renderMode1a8)==3 else 0)
	return 0 if count<1 or M.f(e.lifeExp)==0 else count
static func advance_frame(e: Dictionary,particle: Dictionary,age: float) -> void:
	var interval:=M.f(1/M.f(e.fps)) if M.f(e.fps)>0 else 0.0; var elapsed:=M.f(age-M.f(particle.field48))
	if interval!=0 and M.f(e.frameStart)!=M.f(e.frameEnd) and elapsed>=interval:
		var steps:=M.cvtt(M.f(elapsed/interval))
		if M.f(e.frameStart)>M.f(e.frameEnd):
			particle.frame44=int(particle.frame44)-steps
			if M.f(e.frameEnd)>M.f(particle.frame44): particle.frame44=M.cvtt(e.frameStart)
		else:
			particle.frame44=int(particle.frame44)+steps
			if M.f(particle.frame44)>M.f(e.frameEnd): particle.frame44=M.cvtt(e.frameStart)
		particle.field48=age
static func advance_atlas(e: Dictionary) -> void:
	if int(e.xGrid)<=1 and int(e.yGrid)<=1: return
	for index in draw_count(e): advance_frame(e,e.active188.records[index],M.f(e.active188.records[index].age))
static func mix_value(start: float,end: float,time: float) -> float:
	return M.f(M.f(time*end)+M.f(M.f(1-time)*start))
static func packed_color(color: Array,alpha: float) -> int:
	return ((int(alpha)&255)<<24)|((int(color[2])&255)<<16)|((int(color[1])&255)<<8)|(int(color[0])&255)
static func half_size(factor: float,value: float) -> float: return M.f(M.f(factor*M.f(value))*M.f(0.5))
static func write(bytes: PackedByteArray,index: int,color: int,position: Array,u: float,v: float) -> void:
	var offset:=index*24; bytes.encode_u32(offset,color)
	for axis in 3: bytes.encode_float(offset+4+axis*4,position[axis])
	bytes.encode_float(offset+16,u); bytes.encode_float(offset+20,v)
static func build(e: Dictionary,p: Dictionary,atlas_prepared: bool=false) -> Dictionary:
	var count:=draw_count(e)
	if count==0: return {}
	if count*6>MAX_VERTICES: return {"error":"Native particle vertex allocation exceeds explicit surface limit"}
	var mode:=int(e.renderMode1a8); var list: Array=e.active188.records; var life:=M.f(e.lifeExp)
	var factor:=M.f(Schedule.invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0; var camera:=M.values(Schedule.invoke(p,"cameraQuaternion")); var splat: bool=(int(e.flags)&512)!=0; var tinted: bool=(int(e.flags)&8)!=0
	var orientation: Array=M.values(e.quaternion1d0) if mode==1 else ([1.0,0.0,0.0,0.0] if mode==2 else camera)
	var axis: Array=[0.0,0.0,1.0] if mode==2 else M.axis_z(orientation); var camera_basis:=M.quaternion_basis(camera); var camera_x:=camera_basis.slice(0,3); var camera_y:=camera_basis.slice(3,6); var upright:=1.0
	if mode==4:
		var w:=float(camera[0]); var x:=float(camera[1]); var y:=float(camera[2]); var z:=float(camera[3]); var direction:=M.f(M.f(M.f(M.f(1-M.f(M.f(M.f(w*w)+M.f(x*x))*2))*0)+M.f(M.f(M.f(M.f(x*y)-M.f(z*w))*2)*0))+M.f(M.f(w*y)+M.f(x*z))*2)
		if direction<0: upright=-1.0
	var life_scale:=M.f(1/M.f(list.size())) if int(e.ageMode1cc)==0 else (M.f(1/life) if life>0 else M.f(0.01))
	var x_grid:=1 if int(e.xGrid)==0 else int(e.xGrid); var y_grid:=1 if int(e.yGrid)==0 else int(e.yGrid); var atlas: bool=x_grid>1 or y_grid>1
	if x_grid<1 or y_grid<1: return {"error":"Invalid original particle atlas dimensions"}
	var dx:=M.f(1/M.f(x_grid)); var dy:=M.f(1/M.f(y_grid)); var instance: Variant=e.instance100 if e.instance100!=null else (e.source50.get("instance") if e.source50!=null else null); var elevation:=1.0
	if instance!=null and M.f(M.f(e.position1e0[2])-M.f(instance.height50))>M.f(e.elevationThreshold): elevation=M.f(instance.opacity70)
	var opacity:=M.f(e.source50.opacity108) if e.source50!=null else 1.0; var tint: Array=M.values(Schedule.invoke(p,"lightColor",[e.position1e0.duplicate()])) if tinted else [1.0,1.0,1.0]
	var color_start: Array=[]; var color_end: Array=[]; var vary_color: bool=life>0 and range(3).any(func(index):return M.f(e.colorStart[index])!=M.f(e.colorEnd[index]))
	for index in 3:
		color_start.append(M.f(clampf(M.f(M.f(e.colorStart[index])*tint[index]),0,1)*BYTE_SCALE))
		color_end.append(M.f(clampf(M.f(M.f(e.colorEnd[index])*tint[index]),0,1)*BYTE_SCALE) if vary_color else color_start[index])
	var alpha_start:=M.f(clampf(M.f(M.f(elevation*M.f(e.alphaStart))*opacity),0,1)*BYTE_SCALE); var vary_alpha: bool=life>0 and M.f(e.alphaStart)!=M.f(e.alphaEnd)
	var alpha_end:=M.f(clampf(M.f(M.f(elevation*M.f(e.alphaEnd))*opacity),0,1)*BYTE_SCALE) if vary_alpha else alpha_start
	var start:=half_size(factor,e.sizeStart); var vary_size: bool=life>0 and M.f(e.sizeStart)!=M.f(e.sizeEnd) and not splat; var end:=half_size(factor,e.sizeEnd) if vary_size or splat else start
	var start_y:=half_size(factor,e.sizeStartY); var vary_y: bool=life>0 and M.f(e.sizeStartY)!=M.f(e.sizeEndY) and not splat; var end_y:=half_size(factor,e.sizeEndY) if vary_y or splat else start_y
	var maximum_size:=maxf(maxf(start,end),maxf(start_y,end_y)); var bytes:=PackedByteArray(); bytes.resize(count*6*24)
	for index in count:
		var particle: Dictionary=list[index]; var age:=M.f(particle.age); var t:=minf(1,M.f((M.f(index) if int(e.ageMode1cc)==0 else age)*life_scale)) if life>0 else 0.0
		var color: Array=[]
		for component in 3: color.append(mix_value(color_start[component],color_end[component],t) if vary_color else color_start[component])
		var alpha:=mix_value(alpha_start,alpha_end,t) if vary_alpha else alpha_start; var width:=mix_value(start,end,t) if vary_size else start
		var height:=mix_value(start_y,end_y,t) if vary_y else (start_y if M.f(e.sizeStartY)!=0 else width)
		if splat and int(particle.stopped70)!=0: width=end; height=end_y if M.f(e.sizeEndY)!=0 else end
		var head:=M.values(particle.position10); var tail:=head.duplicate(); var x: Array; var y: Array; var tail_color:=packed_color(color,alpha)
		if mode in [3,6]:
			if mode==6: tail=M.values(particle.trail64)
			else: head=M.values(list[index+1].position10)
			var travel:=M.subtract(head,tail); var dot_x:=M.f(M.f(M.f(camera_x[1]*travel[1])+M.f(camera_x[0]*travel[0]))+M.f(camera_x[2]*travel[2])); var dot_y:=M.f(M.f(M.f(camera_y[1]*travel[1])+M.f(camera_y[0]*travel[0]))+M.f(camera_y[2]*travel[2]))
			var inverse:=M.fast_rsqrt(M.f(M.f(dot_y*dot_y)+M.f(dot_x*dot_x))); var px:=M.f(dot_x*inverse); var py:=M.f(dot_y*inverse); x=[]; y=[]
			for component in 3: x.append(M.f(M.f(camera_x[component]*py)-M.f(camera_y[component]*px))); y.append(M.f(M.f(camera_y[component]*py)+M.f(camera_x[component]*px)))
			width=M.f(width*2); height=M.f(height*0.5)
			if mode==6: tail_color=packed_color(color,M.f(minf(1,M.f(inverse*width))*alpha))
		elif mode==5: x=M.axis_x(particle.quaternion34); y=M.axis_z(particle.quaternion34)
		else:
			var angle:=M.f(M.f(particle.rotation1c)*M.f(0.5)); var sine: float=p.sineFloat.call(angle) if p.has("sineFloat") else Trig.sine(angle); var cosine: float=p.cosineFloat.call(angle) if p.has("cosineFloat") else Trig.cosine(angle)
			var rotation_axis: Array=particle.direction4c if int(particle.stopped70)!=0 else axis; var q:=M.multiply([cosine,M.f(M.f(rotation_axis[0])*sine),M.f(M.f(rotation_axis[1])*sine),M.f(M.f(rotation_axis[2])*sine)],particle.quaternion34 if int(particle.stopped70)!=0 else orientation)
			x=M.axis_x(q); y=[0.0,0.0,upright] if mode==4 else M.cross(particle.direction4c if splat else axis,x)
		for component in 3: x[component]=M.f(width*x[component]); y[component]=M.f(height*y[component])
		var u0:=0.0; var u1:=1.0; var v0:=0.0; var v1:=1.0
		if atlas:
			if not atlas_prepared: advance_frame(e,particle,age)
			var frame:=M.f(particle.frame44); var row:=M.f(floor(M.f(frame*dx))); v1=M.f(1-M.f(row*dy)); u0=M.f(M.f(frame-M.f(M.f(x_grid)*row))*dx); v0=M.f(v1-dy); u1=M.f(u0+dx)
		var packed:=packed_color(color,alpha); var a: Array=[]; var b: Array=[]; var c: Array=[]; var d: Array=[]
		for component in 3:
			a.append(M.f(M.f(head[component]+x[component])+y[component])); b.append(M.f(M.f(head[component]-x[component])+y[component])); c.append(M.f(M.f(tail[component]+x[component])-y[component])); d.append(M.f(M.f(tail[component]-x[component])-y[component]))
		var base:=index*6
		write(bytes,base,packed,a,u1,v1); write(bytes,base+1,packed,b,u0,v1); write(bytes,base+2,tail_color,c,u1,v0); write(bytes,base+3,tail_color,c,u1,v0); write(bytes,base+4,packed,b,u0,v1); write(bytes,base+5,tail_color,d,u0,v0)
	var soft_inverse:=0.0 if splat or mode in [1,2] or not (maximum_size>0) else M.f(1/minf(M.f(0.2),M.f(maximum_size*M.f(0.2))))
	return {"buffer":bytes,"count":count*6,"softInverse":soft_inverse,"blendMode":e.blendMode68,"twoSided":bool(e.twoSided)}
