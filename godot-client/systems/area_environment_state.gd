extends RefCounted

# Original module-update1407d0197..1407d029b single-precision boundaries.
# The caller supplies the native camera behavior distance, not world depth.
static func f(v: float) -> float: return Vector3(v,0,0).x
static func fog_range(near_clip: float, clip: float, distance: float, amount: float, skybox: bool, show_sky: bool) -> Dictionary:
	var near := f(near_clip)
	var end := f(clip)
	if near >= end: end = f(near+f(.01))
	var begin := f(f(f(distance)-f(amount))+10.0)
	if begin >= end: begin = f(end-f(1.01))
	return {"start":begin,"end":end,"near":near,"far":f(maxf(end,45.0)+(90.0 if skybox and show_sky else 0.0))}

static func blend(a: Array,b: Array,t: float) -> Array:
	var out: Array = []
	for i in 3: out.append(f(f(f(a[i])*f(1.0-t))+f(f(b[i])*t)))
	return out

# Color phase of original1407e90b0. Native sky/tile animation and weather remain
# separate owners; this state supplies their period without synthesizing art.
static func phase_sample(colors: Dictionary,amounts: Dictionary,mode: String,elapsed: float,duration: float,shadow: float,is_night: bool) -> Dictionary:
	var active := mode in ["dawn","dusk"]
	var t := minf(1.0,f(f(elapsed)/f(duration))) if active and duration != 0 else 1.0
	var from := "moon" if mode == "dawn" or not active and is_night else "sun"
	var to := "sun" if mode == "dawn" else "moon" if mode == "dusk" else from
	var ambient: Array = blend(colors[from+"Ambient"],colors[to+"Ambient"],t)
	var diffuse: Array = blend(colors[from+"Diffuse"],colors[to+"Diffuse"],t)
	var fog: Array = blend(colors[from+"Fog"],colors[to+"Fog"],t)
	var amount := f(f(f(amounts[from])*f(1.0-t))+f(f(amounts[to])*t))
	var magnitude := absf(clampf(f(f(t+t)-1.0),-1.0,1.0)) if active else 1.0
	if magnitude < 1:
		for i in 3:
			ambient[i] = f(ambient[i]+f(f(diffuse[i]*f(1.0-magnitude))*.5))
			diffuse[i] = f(diffuse[i]*magnitude)
	var night := is_night if not active or t < .5 else mode == "dusk"
	return {"ambient":ambient,"diffuse":diffuse,"fog":fog,"amount":int(amount),"tile":diffuse.map(func(v):return f(v*.5)),"isNight":night,"shadow":f(f(f(shadow)*magnitude)/100.0),"complete":not active or t >= 1}
