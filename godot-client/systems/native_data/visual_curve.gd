extends RefCounted
# Native LerpFloat state. The network decoder keeps the ten source records;
# each model owns a copy because sampling mutates repeat clocks and endpoints.
const WorldTimer=preload("res://systems/native_data/world_timer.gd")
const U32:=4294967295
const TWO32:=4294967296
const HALF64:=9223372036854775808.0
const TWO64:=18446744073709551616.0
static func f(value: float)->float:return PackedFloat32Array([value])[0]
static func words(value: int)->Dictionary:return {"hi":(value>>32)&U32,"lo":value&U32}
static func add_words(a: Dictionary,b: Dictionary)->Dictionary:
	var low:=int(a.lo)+int(b.lo)
	return {"hi":(int(a.hi)+int(b.hi)+(1 if low>TWO32-1 else 0))&U32,"lo":low&U32}
static func subtract_words(a: Dictionary,b: Dictionary)->Dictionary:
	var low:=int(a.lo)-int(b.lo)
	return {"hi":(int(a.hi)-int(b.hi)-(1 if low<0 else 0))&U32,"lo":low&U32}
static func before_words(a: Dictionary,b: Dictionary)->bool:return int(a.hi)<int(b.hi) or int(a.hi)==int(b.hi) and int(a.lo)<int(b.lo)
static func difference_float(value: Dictionary)->float:
	var hi:=int(value.hi);var lo:=int(value.lo)
	var bits:=0;var top_part:=hi if hi!=0 else lo
	while top_part!=0:
		top_part>>=1
		bits+=1
	if hi!=0:bits+=32
	if bits<=24:return f(float(hi*TWO32+lo))
	var shift:=bits-24;var top:=0;var tail:=0
	if shift>=32:
		top=hi>>(shift-32)
		tail=(hi&((1<<(shift-32))-1))*TWO32+lo
	else:
		top=(hi<<(32-shift))+(lo>>shift)
		tail=lo&((1<<shift)-1)
	var half:=1<<(shift-1)
	if tail>half or tail==half and (top&1)!=0:top+=1
	return f(float(top)*pow(2.0,shift))
static func unsigned_difference_float(value: Dictionary)->float:
	if int(value.hi)<2147483648:return difference_float(value)
	var magnitude:=subtract_words({"hi":0,"lo":0},value)
	return f(-difference_float(magnitude)+TWO64)
static func duration_ticks(duration: float)->Dictionary:
	var value:=f(f(duration*1000.0)*1000.0);var bias:=false
	if value>=HALF64:
		value=f(value-HALF64)
		bias=value<HALF64
	var converted:=(-9223372036854775807-1)
	if is_finite(value) and value>=-HALF64 and value<HALF64:converted=int(value)
	var result:=words(converted)
	if bias:result.hi=(int(result.hi)+2147483648)&U32
	return result
static func identity(index: int)->Dictionary:
	return {"timer":0,"kind":0,"to":1.0 if index in [0,1,2,9] else 0.0,"from":1.0 if index in [0,1,2,9] else 0.0,"duration":0.0,"progress":0.0,"flags":0,"repeats":0,"start_us":0,"end_us":0,"world_start":{},"world_end":{}}
static func copy_channel(source: Dictionary,index: int,world_timer: Variant=null)->Dictionary:
	var result:=identity(index)
	result.timer=int(source.get("type",0));result.kind=int(source.get("duration",0))
	result.to=f(float(source.get("value",result.to)))
	result.from=f(float(source.get("target",result.to)))
	result.duration=f(float(source.get("parameter",0.0)))
	result.progress=f(float(source.get("progress",0.0)))
	result.flags=int(source.get("field18",0));result.repeats=int(source.get("field1c",0))
	# NetworkVisualTransformBytes creates and refreshes a temporary twice;
	# Gob's owned copy refreshes once more before presentation sampling.
	for _index in 3:restart(result,world_timer)
	return result
static func restart(curve: Dictionary,world_timer: Variant=null)->void:
	if int(curve.kind)==0 or float(curve.from)==float(curve.to):return
	if int(curve.timer)==0:
		var now:=words(Time.get_ticks_usec())
		curve.start_us=now
		curve.end_us=add_words(now,duration_ticks(float(curve.duration)))
	elif int(curve.timer)==1 and world_timer!=null:
		var now: Dictionary=world_timer.time()
		if not bool(now.get("ready",false)):return
		var delta: Dictionary=WorldTimer.seconds_to_world_delta(float(curve.duration),world_timer.seconds_per_day)
		if not bool(delta.get("ready",false)):return
		curve.world_start={"day":int(now.day),"time":int(now.time)}
		var end: Dictionary=WorldTimer.add_world_times(curve.world_start,{"day":0,"time":int(delta.time)},world_timer.day_length)
		if int(end.get("status",-1))==0:curve.world_end={"day":int(end.day),"time":int(end.time)}
static func progress(curve: Dictionary,world_timer: Variant=null)->float:
	if int(curve.kind)==0:return f(1.0)
	if float(curve.progress)<1.0:
		var fraction: Variant=null
		if int(curve.timer)==0:
			var now:=words(Time.get_ticks_usec());var end: Variant=curve.end_us
			if end is Dictionary and before_words(now,end):
				var total:=unsigned_difference_float(subtract_words(end,curve.start_us))
				if total>0.0:fraction=f(unsigned_difference_float(subtract_words(end,now))/total)
		elif int(curve.timer)==1:
			if world_timer==null:return f(1.0)
			var now: Dictionary=world_timer.time();var end: Dictionary=curve.world_end
			if bool(now.get("ready",false)) and end.has("day") and (int(now.day)<int(end.day) or int(now.day)==int(end.day) and int(now.time)<int(end.time)):
				var remaining: Dictionary=WorldTimer.subtract_world_times(end,now,world_timer.day_length)
				var total: Dictionary=WorldTimer.subtract_world_times(end,curve.world_start,world_timer.day_length)
				if int(total.get("time",0))!=0:fraction=f(float(int(remaining.get("time",0)))/float(int(total.time)))
		if fraction!=null:
			var result:=f(1.0-f(float(fraction)))
			if result!=1.0:return result
	var repeats:=int(curve.repeats)
	if repeats!=-1:
		if repeats<1:return f(1.0)
		curve.repeats=repeats-1
	if int(curve.flags)&1:
		var from: float=curve.from;curve.from=curve.to;curve.to=from
	restart(curve,world_timer)
	return f(1.0)
static func sample(curve: Dictionary,world_timer: Variant=null)->float:
	var kind:=int(curve.kind)
	if kind==0:return float(curve.to)
	var t:=progress(curve,world_timer)
	if t==0.0:return float(curve.from)
	var to:=float(curve.to)
	if t==1.0:return to
	var from:=float(curve.from);var span:=f(to-from)
	match kind:
		1,6:
			if kind==6:t=f(t*t)
			return f(f(span*t)+from)
		2:
			var s:=f(f(3.0-f(t*2.0))*t)
			s=f(s*t)
			return f(f(s*span)+from)
		3:
			var u:=clampf(f(1.0-f(t+t)),-1.0,1.0)
			t=f(0.5-f(sin(f(asin(u)/3.0))))
			return f(f(t*span)+from)
		4:
			t=f(cos(f(f(t*f(PI))*0.5)))
			return f(f(f(1.0-t)*span)+from)
		5:
			t=f(sin(f(f(t*f(PI))*0.5)))
			return f(f(t*span)+from)
		7:
			var s:=f(f(f(t*6.0)-15.0)*t)
			s=f(s+10.0);s=f(s*t);s=f(s*t);s=f(s*t)
			return f(f(s*span)+from)
		_:
			return to
