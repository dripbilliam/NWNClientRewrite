extends RefCounted
# Cast release and type-4 cue projection from network_cast_animation.js.
const OBJECT_INVALID:=0x7f000000
const RELEASE_BASE={17:250,18:251,19:252,20:253,61:261}
var failure:=""

static func _f(value: float) -> float:
	return Color(value,0,0,0).r

static func release_base(animation: int) -> Variant:
	return RELEASE_BASE.get(animation)

static func record(cast: Dictionary) -> Dictionary:
	var target_type: Variant=cast.get("targetType")
	return {"type":4,"targetType":target_type,"targetId":cast.get("target") if target_type==1 else OBJECT_INVALID,"position":cast.position.duplicate(true) if target_type==2 else [0,0,0],"spellId":int(cast.get("spell",0))&0xffffffff,"field38":int(cast.get("field220",0))&0xffffffff}

func client_cast_animation_cue(animation: int,length: float,cast_record: Dictionary) -> Dictionary:
	failure=""
	if release_base(animation)==null or int(cast_record.get("type",-1))!=4 or not is_finite(length):
		failure="Invalid native cast animation cue"
		return {}
	return {"animation":animation,"duration":500,"speed":_f(_f(length)/_f(500.0)),"record":cast_record,"delay":0}
