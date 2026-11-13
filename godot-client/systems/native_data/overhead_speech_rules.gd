extends RefCounted
# Original77c140 ->766450 ->6e9590/6e98a0. This is ordinary speech,
# not ScriptFeedback93/94 or combat floaty text.
const F=preload("res://systems/native_render/particle_math.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const CHANNELS=[1,2,3,4,6,8,9,10,11,14,17,18,19,20,22,30]
const DEFAULT_MODE=2
const DEFAULT_LARGE=true
static func c_string(raw: String) -> Dictionary:
	for at in raw.length():
		var byte:=Rich.byte_value(raw.unicode_at(at))
		if byte==0:return {"ready":true,"text":raw.left(at),"byteLength":at}
		if byte<0:return {"ready":false,"reason":"Native speech contains an unresolved non-Western byte character."}
	return {"ready":true,"text":raw,"byteLength":raw.length()}
static func duration(byte_length: int,channel: int,forced: float=0.0) -> Dictionary:
	if byte_length<0 or byte_length>4294967295 or not is_finite(forced):return {"ready":false,"reason":"Native speech duration inputs are unavailable."}
	forced=F.f(forced)
	if forced>F.f(0.15):return {"ready":true,"seconds":forced,"forced":true}
	var seconds:=F.f(F.f(F.f(float(byte_length))*F.f(0.15))*F.f(0.75 if channel==11 else 1.0))
	return {"ready":true,"seconds":maxf(F.f(4.0),minf(F.f(12.0),seconds)),"forced":false}
static func compose(channel: Variant,object_type: Variant,body: String,raw_name: String,forced: float,mode: Variant,large_font: Variant) -> Dictionary:
	if not Scope.integer(channel,0,255) or not CHANNELS.has(int(channel)):return {"ready":true,"eligible":false}
	if not Scope.integer(object_type,1,4294967295) or not Scope.integer(mode,0,2) or not large_font is bool:return {"ready":false,"reason":"Native speech presentation context is unavailable."}
	# These native localized branches return before popup replacement if empty.
	if int(channel) in [8,9,10,11] and body.is_empty():return {"ready":true,"eligible":false}
	var raw: String="["+raw_name+"]: "+body if int(object_type) in [7,9,10] else body
	var text:=c_string(raw)
	if not text.ready:return text
	var timed:=duration(int(text.byteLength),int(channel),forced)
	if not timed.ready:return timed
	return {"ready":true,"eligible":true,"text":text.text,"rich":Rich.parse(text.text),"byteLength":int(text.byteLength),"seconds":timed.seconds,"mode":int(mode),"registered":int(mode)!=0,"font":"ttf fnt_default_hr 16" if large_font else "ttf fnt_default 14","minimumLines":2,"color":Color.WHITE,"depth":-5.0,"extraOutline":0,"extraShadow":Vector2.ZERO}
