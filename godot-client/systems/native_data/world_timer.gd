extends RefCounted
# Pure CWorldTimer arithmetic. No remote owner/lifecycle is inferred by new().
const U32:=4294967295
const TWO32:=4294967296
var initialized:=false
var microseconds:=Callable()
var mode: Variant=null
var fixed_rate: Variant=null
var counter: Dictionary={}
var previous_counter: Dictionary={}
var paused: Variant=null
var paused_day: Variant=null
var paused_time: Variant=null
var day_offset: Variant=null
var time_offset: Variant=null
var minutes_per_hour: Variant=null
var day_length: Variant=null
var seconds_per_day: Variant=null
static func unavailable(reason: String)->Dictionary:return {"ready":false,"reason":reason}
static func integer(value: Variant)->bool:
	if value is int:return true
	return value is float and is_finite(value) and floorf(value)==value and value>=-9223372036854775808.0 and value<9223372036854775808.0
static func u32(value: Variant)->int:return int(value)&U32
static func i32(value: Variant)->int:
	var word:=u32(value)
	return word-TWO32 if word>=2147483648 else word
static func words(value: Variant)->Dictionary:
	if not value is Dictionary or not integer(value.get("hi")) or not integer(value.get("lo")) or value.hi<0 or value.hi>U32 or value.lo<0 or value.lo>U32:return {}
	return {"hi":int(value.hi),"lo":int(value.lo)}
static func words_from_int(value: int)->Dictionary:return {"hi":(value>>32)&U32,"lo":value&U32}
static func provider_words(value: Variant)->Dictionary:
	# Preserve the old signed-integer provider domain; explicit DWORD limbs
	# additionally carry native values with bit63 set without any FLOAT cast.
	if value is int:return words_from_int(value) if value>=0 else {}
	return words(value) if value is Dictionary else {}
static func add_counter(value: Dictionary,delta: int)->Dictionary:
	var low: int=int(value.lo)+delta
	var carry:=1 if low>U32 else (-1 if low<0 else 0)
	return {"hi":(int(value.hi)+carry)&U32,"lo":low&U32}
static func subtract_counter(a: Dictionary,b: Dictionary)->Dictionary:
	var low: int=int(a.lo)-int(b.lo)
	return {"hi":(int(a.hi)-int(b.hi)-(1 if low<0 else 0))&U32,"lo":low&U32}
static func frame_seconds_from_difference(value: Dictionary)->Dictionary:
	var normalized:=words(value)
	if normalized.is_empty():return unavailable("Native frame counter difference is unknown.")
	# Caller6db800 narrows the getter result to signedDWORD before FLOAT.
	return {"ready":true,"seconds":f32(f32(float(i32(normalized.lo)))/1000000.0)}
static func counter_milliseconds(value: Dictionary)->int:
	# Unsigned64 /1000 without converting through DOUBLE or signed64.
	var high: int=value.hi;var low: int=value.lo
	@warning_ignore("integer_division")
	var quotient_hi: int=high/1000
	var lower: int=(high%1000)*TWO32+low
	@warning_ignore("integer_division")
	return quotient_hi*TWO32+lower/1000
static func add_world_times(now: Dictionary,delta: Dictionary,length_value: Variant)->Dictionary:
	if not integer(length_value) or not integer(now.get("day")) or not integer(now.get("time")) or not integer(delta.get("day")) or not integer(delta.get("time")):return unavailable("World-time operands are unknown.")
	var length:=u32(length_value);var a:=u32(now.time);var b:=u32(delta.time)
	if a>=length or b>=length:return {"ready":true,"status":-2,"outputsDefined":false}
	var day: int=(u32(now.day)+u32(delta.day))&U32;var time: int=(a+b)&U32
	if time>=length:day=(day+1)&U32;time=(time-length)&U32
	return {"ready":true,"status":0,"outputsDefined":true,"day":day,"time":time}
static func compare_world_times(a: Dictionary,b: Dictionary,length_value: Variant)->Dictionary:
	if not integer(length_value) or not integer(a.get("day")) or not integer(a.get("time")) or not integer(b.get("day")) or not integer(b.get("time")):return unavailable("World-time operands are unknown.")
	var length:=u32(length_value);var day:=u32(a.day);var other_day:=u32(b.day);var time:=u32(a.time);var other_time:=u32(b.time)
	if time>=length or other_time>=length:return {"ready":true,"status":-2}
	return {"ready":true,"status":(0 if time==other_time else (1 if time>other_time else -1)) if day==other_day else (1 if day>other_day else -1)}
static func subtract_world_times(a: Dictionary,b: Dictionary,length_value: Variant)->Dictionary:
	if not integer(length_value) or not integer(a.get("day")) or not integer(a.get("time")) or not integer(b.get("day")) or not integer(b.get("time")):return unavailable("World-time operands are unknown.")
	var length:=u32(length_value);var day:=u32(a.day);var other_day:=u32(b.day);var time:=u32(a.time);var other_time:=u32(b.time)
	if time<length and other_time<length and (day<other_day or day==other_day and time<other_time):return {"ready":true,"status":-2,"outputsDefined":false,"reason":"Native SubtractWorldTimes leaves both output operands unwritten."}
	var result_day: int=(day-other_day)&U32;var result_time: int=(time-other_time)&U32
	if result_time>=length:result_day=(result_day-1)&U32;result_time=(result_time+length)&U32
	return {"ready":true,"status":0,"outputsDefined":true,"day":result_day,"time":result_time}
static func f32(value: float)->float:return PackedFloat32Array([value])[0]
static func seconds_to_world_delta(value: float,length_value: Variant,iteration_bound: int=1000000)->Dictionary:
	if not integer(length_value):return unavailable("Native seconds-per-day is unknown.")
	var seconds:=f32(value);var length:=f32(float(u32(length_value)));var day:=0;var iterations:=0
	if length==0.0:return unavailable("Native FLOAT subtraction would not advance.")
	while seconds>=length:
		if iterations>=iteration_bound:return unavailable("Explicit finite component conversion bound reached; no native output is invented.")
		var next:=f32(seconds-length)
		if next==seconds:return unavailable("Native FLOAT subtraction would not advance.")
		seconds=next;day=(day+1)&U32;iterations+=1
	if seconds<0.0:return {"ready":true,"day":day,"time":0}
	var scaled:=f32(seconds*1000.0)
	# CVTTSS2SI indefinite INT64 has lowDWORD0, including unordered NaN.
	var time:=0
	if is_finite(scaled) and scaled>=-9223372036854775808.0 and scaled<9223372036854775808.0:time=int(scaled)&U32
	return {"ready":true,"day":day,"time":time}
func initialize(provider: Callable)->Dictionary:
	if not provider.is_valid():return unavailable("Native monotonic integer microsecond provider is unknown.")
	var sample: Variant=provider.call()
	var sampled_words:=provider_words(sample)
	if sampled_words.is_empty():return unavailable("Provider must supply known nonnegative integer microseconds or explicit unsigned64 DWORD limbs.")
	microseconds=provider;counter=sampled_words;previous_counter=counter.duplicate()
	mode=0;fixed_rate=null;paused=0;paused_day=null;paused_time=null;minutes_per_hour=5;day_length=7200000;seconds_per_day=7200
	initialized=true
	return set_time(0x6df4c,5*0x150ea0+0x36dee0)
func snapshot()->Dictionary:
	if not initialized:return unavailable("Native timer construction/owner state is unknown.")
	var next: Dictionary
	if mode==0:
		if not microseconds.is_valid():return unavailable("Native monotonic provider is unavailable.")
		var sample: Variant=microseconds.call()
		next=provider_words(sample)
		if next.is_empty():return unavailable("Native microsecond sample is unknown or malformed.")
	else:
		if not integer(fixed_rate) or i32(fixed_rate)==0:return unavailable("Native fixed-rate snapshot divisor is unknown or zero.")
		@warning_ignore("integer_division")
		var increment: int=1000000/i32(fixed_rate)
		next=add_counter(counter,increment)
	previous_counter=counter.duplicate();counter=next
	return {"ready":true}
func synchronize_previous()->Dictionary:
	if not initialized:return unavailable("Native timer state is unknown.")
	previous_counter=counter.duplicate();return {"ready":true}
func snapshot_difference()->Dictionary:
	if not initialized:return unavailable("Native snapshot counter state is unknown.")
	return {"ready":true,"microseconds":subtract_counter(counter,previous_counter)}
func set_minutes_per_hour(value: Variant)->Dictionary:
	if not initialized or not integer(value):return unavailable("Native timer/rate is unknown.")
	minutes_per_hour=u32(value)&255
	if minutes_per_hour==0:minutes_per_hour=1
	day_length=minutes_per_hour*1440000;seconds_per_day=minutes_per_hour*1440
	return {"ready":true}
func set_time(day_value: Variant,time_value: Variant,snapshot_value: Variant=0)->Dictionary:
	if not initialized or not integer(day_value) or not integer(time_value) or not integer(snapshot_value) or not integer(day_length) or day_length==0:return unavailable("Native timer/time operands are unknown.")
	if u32(snapshot_value)==1:
		var sampled:=snapshot()
		if not sampled.ready:return sampled
	var elapsed:=counter_milliseconds(counter)
	@warning_ignore("integer_division")
	day_offset=(u32(day_value)-(elapsed/int(day_length)))&U32
	time_offset=(u32(time_value)-(elapsed%int(day_length)))&U32
	return {"ready":true}
func time()->Dictionary:
	if not initialized:return unavailable("Native timer construction/owner state is unknown.")
	if paused==1:
		if not integer(paused_day) or not integer(paused_time):return unavailable("Native paused time is unknown.")
		return {"ready":true,"day":u32(paused_day),"time":u32(paused_time)}
	if not integer(day_length) or day_length==0 or not integer(day_offset) or not integer(time_offset):return unavailable("Native timer offsets/day length are unknown.")
	var elapsed:=counter_milliseconds(counter);var length:=u32(day_length)
	@warning_ignore("integer_division")
	var day: int=((elapsed/length)+int(day_offset))&U32
	var result_time: int=((elapsed%length)+int(time_offset))&U32
	# Native repeats while (~L)<t. With D=2^32-L, its DWORD addition
	# is exactly t-D whenever t>=D. Collapse all decrements, not just one.
	var negative_step: int=TWO32-length
	@warning_ignore("integer_division")
	var negative_count: int=result_time/negative_step
	day=(day-negative_count)&U32;result_time-=negative_count*negative_step
	# Algebraically identical to repeated unsigned carry; no per-day loop.
	@warning_ignore("integer_division")
	day=(day+result_time/length)&U32
	result_time%=length
	return {"ready":true,"day":day,"time":result_time}
func pause()->Dictionary:
	if not initialized:return unavailable("Native timer state is unknown.")
	if paused==0:
		var now:=time()
		if not now.ready:return now
		paused_day=now.day;paused_time=now.time;paused=1
	return {"ready":true}
func unpause()->Dictionary:
	if not initialized:return unavailable("Native timer state is unknown.")
	if paused==1:
		if not integer(paused_day) or not integer(paused_time):return unavailable("Native paused time is unknown.")
		paused=0;return set_time(paused_day,paused_time)
	return {"ready":true}
func state_view()->Dictionary:
	return {"ready":initialized,"mode":mode,"fixedRate":fixed_rate,"counter":counter.duplicate(),"previousCounter":previous_counter.duplicate(),"paused":paused,"pausedDay":paused_day,"pausedTime":paused_time,"dayOffset":day_offset,"timeOffset":time_offset,"minutesPerHour":minutes_per_hour,"dayLength":day_length,"secondsPerDay":seconds_per_day}
func restore_state(value: Dictionary)->Dictionary:
	var current_words:=words(value.get("counter"));var previous_words:=words(value.get("previousCounter"))
	if not value.get("ready",false) or current_words.is_empty() or previous_words.is_empty():return unavailable("Explicit timer state is unavailable.")
	for key in ["mode","paused","dayOffset","timeOffset","minutesPerHour","dayLength","secondsPerDay"]:
		if not integer(value.get(key)):return unavailable("Explicit timer scalar is unknown: "+key)
	for key in ["fixedRate","pausedDay","pausedTime"]:
		if value.get(key)!=null and not integer(value[key]):return unavailable("Explicit optional timer scalar is malformed: "+key)
	mode=u32(value.mode);fixed_rate=null if value.get("fixedRate")==null else i32(value.fixedRate);counter=current_words;previous_counter=previous_words
	paused=u32(value.paused);paused_day=null if value.get("pausedDay")==null else u32(value.pausedDay);paused_time=null if value.get("pausedTime")==null else u32(value.pausedTime)
	day_offset=u32(value.dayOffset);time_offset=u32(value.timeOffset);minutes_per_hour=u32(value.minutesPerHour)&255;day_length=u32(value.dayLength);seconds_per_day=u32(value.secondsPerDay);initialized=true
	return {"ready":true}
func reset_from(other)->Dictionary:
	if not is_instance_valid(other) or not other.has_method("state_view"):return unavailable("Native reset source is unavailable.")
	# restore copies all defined fields; this instance's host provider is kept.
	return restore_state(other.state_view())
func calendar(day_value: Variant=null)->Dictionary:
	if day_value==null:
		var now:=time()
		if not now.ready:return now
		day_value=now.day
	if not integer(day_value):return unavailable("Native calendar day is unknown.")
	var day:=u32(day_value)
	@warning_ignore("integer_division")
	var months: int=day/28
	@warning_ignore("integer_division")
	var year: int=months/12
	return {"ready":true,"year":1340 if year>32767 else year,"month":months%12+1,"day":day%28+1}
func time_parts(time_value: Variant=null)->Dictionary:
	if time_value==null:
		var now:=time()
		if not now.ready:return now
		time_value=now.time
	if not integer(time_value) or not integer(minutes_per_hour) or (int(minutes_per_hour)&255)==0:return unavailable("Native time/rate is unknown.")
	var raw:=u32(time_value);var rate: int=int(minutes_per_hour)&255
	@warning_ignore("integer_division")
	var seconds: int=raw/1000
	@warning_ignore("integer_division")
	var minutes: int=seconds/60
	@warning_ignore("integer_division")
	return {"ready":true,"hour":minutes/rate,"minute":minutes%rate,"second":seconds%60,"millisecond":raw%1000}
func set_calendar(year_value: Variant,month_value: Variant,day_value: Variant,hour_value: Variant,minute_value: Variant,second_value: Variant,millisecond_value: Variant,snapshot_value: Variant=0)->Dictionary:
	for value in [year_value,month_value,day_value,hour_value,minute_value,second_value,millisecond_value]:
		if not integer(value):return unavailable("Native calendar argument is unknown.")
	if not initialized or not integer(minutes_per_hour):return unavailable("Native calendar timer/rate is unknown.")
	var year:=u32(year_value);var month:=u32(month_value);var day:=u32(day_value);var hour:=u32(hour_value);var minute:=u32(minute_value);var second:=u32(second_value);var milliseconds:=u32(millisecond_value)
	var date: int=year*336 if year<32001 else 0x6dec0
	date=(date+(month*28-28 if ((month-1)&U32)<12 else 140))&U32
	if ((day-1)&U32)<28:date=(date+day-1)&U32
	var converted: int=(int(minutes_per_hour)*(hour*60000 if hour<24 else 1380000)+(minute*60000 if minute<60 else 3540000)+(second*1000 if second<60 else 56000)+milliseconds)&U32
	return set_time(date,converted,snapshot_value)
func close()->void:
	initialized=false;microseconds=Callable();counter.clear();previous_counter.clear()
	mode=null;fixed_rate=null;paused=null;paused_day=null;paused_time=null;day_offset=null;time_offset=null;minutes_per_hour=null;day_length=null;seconds_per_day=null

