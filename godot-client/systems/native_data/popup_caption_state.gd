extends RefCounted
# Presentation-only state for one existing popup construction slot. This owns
# its single clock and current raw C stream, never an actor/entity/world row.
const F=preload("res://systems/native_render/particle_math.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
static func font_name(large: bool)->String:return "ttf fnt_default_hr 16" if large else "ttf fnt_default 14"
static func encoded(value: Variant)->Dictionary:
	var bytes:=PackedByteArray()
	if value is PackedByteArray:bytes=value.duplicate()
	elif value is String:
		for at in value.length():
			var byte:=Rich.byte_value(value.unicode_at(at))
			if byte<0:return {"ready":false,"reason":"Current popup caption has no native byte encoding."}
			if byte==0:break
			bytes.append(byte)
	else:return {"ready":false,"reason":"Current raw popup caption is unavailable."}
	var zero:=bytes.find(0)
	if zero>=0:bytes=bytes.slice(0,zero)
	if bytes.size()>2147483647:return {"ready":false,"reason":"Current popup caption exceeds the certified native length domain."}
	return {"ready":true,"bytes":bytes}
static func decoded(bytes: PackedByteArray)->String:return Binary.new(bytes).text(0,bytes.size())
static func create(mode: int=2,large: bool=true)->Dictionary:
	return {"mode":mode,"font":font_name(large),"currentRaw":PackedByteArray(),"currentRawKnown":true,"currentRich":{"text":"","spans":[]},"cachedRaw":PackedByteArray(),"cachedRich":{"text":"","spans":[]},"cacheOwnerId":0x7f000000,"portrait":"","writer":"none","remaining":F.f(0.0001),"forceVisible":0,"timedFlag":0,"sceneActive":false,"guiRegistered":false,"hidden":false,"sizeChoice":-1,"minimumLines":2,"indent":F.f(0.0),"revision":0,"fontRevision":0,"accountedGuiFrame":-1}
static func write(record: Dictionary,raw: Variant,rich: Dictionary,writer: String,portrait: String,remaining: float,timed: int,activate: bool=true,force_visible: int=0)->Dictionary:
	var stream:=encoded(raw)
	if not stream.get("ready",false):return stream
	if not is_finite(remaining):return {"ready":false,"reason":"Native popup time is unavailable."}
	record.currentRaw=stream.bytes;record.currentRawKnown=true;record.currentRich=rich.duplicate(true);record.writer=writer;record.portrait=portrait;record.remaining=F.f(remaining);record.forceVisible=force_visible;record.timedFlag=timed
	record.minimumLines=2;record.indent=F.f(23.0 if record.mode==2 and not portrait.is_empty() else 0.0);record.sizeChoice=-1;record.revision+=1;record.accountedGuiFrame=-1
	if activate:
		record.sceneActive=record.mode!=0;record.guiRegistered=record.sceneActive
		if record.sceneActive and force_visible!=0:record.hidden=false # Explicit wrapper ForceVisible, not Off.
	return {"ready":true}
static func cache_name(record: Dictionary,raw: Variant,rich: Dictionary)->Dictionary:
	var stream:=encoded(raw)
	if not stream.get("ready",false):return stream
	record.cachedRaw=stream.bytes;record.cachedRich=rich.duplicate(true)
	return {"ready":true}
static func mode_changed(record: Dictionary,next: int)->Dictionary:
	if next<0 or next>2:return {"ready":false,"reason":"Native popup mode is unavailable."}
	if record.mode==next:return {"ready":true,"changed":false}
	var was_active: bool=record.sceneActive;var timed: int=record.timedFlag
	record.mode=next;record.sizeChoice=-1;record.minimumLines=2;record.indent=F.f(23.0 if next==2 and not str(record.portrait).is_empty() else 0.0);record.accountedGuiFrame=-1
	if not record.get("currentRawKnown",true):
		# Unsupported restoration must never revive the preceding speech. Off
		# still deactivates even when no certified raw stream can be refitted.
		if next==0:record.sceneActive=false;record.guiRegistered=false
		return {"ready":false,"changed":true,"pending":true,"reason":"Current native relation-decorated popup caption is unavailable."}
	record.remaining=maxf(F.f(4.0),minf(F.f(12.0),F.f(F.f(float(record.currentRaw.size()))*F.f(0.15))))
	record.forceVisible=0;record.timedFlag=timed;record.sceneActive=was_active and next!=0;record.guiRegistered=record.sceneActive;record.revision+=1
	return {"ready":true,"changed":true,"wasActive":was_active}
static func font_changed(record: Dictionary,large: bool)->Dictionary:
	var next:=font_name(large)
	if record.font==next:return {"ready":true,"changed":false}
	record.font=next;record.fontRevision+=1
	# SetFont -> RecalcDisplayData never calls SetText, invalidates choice,
	# rewrites raw wrapped lines, or resets the clock/flags/bubble dimensions.
	return {"ready":true,"changed":true}
static func project_active(record: Dictionary,eligible_owner_projection: bool=false,toggle_off: Variant=null)->void:
	if not eligible_owner_projection or not record.get("currentRawKnown",true) or record.mode==0 or record.hidden or float(record.remaining)<=0 and record.cachedRaw.is_empty():return
	if not record.sceneActive:
		record.sceneActive=true;record.guiRegistered=true
		if toggle_off is bool and toggle_off:record.hidden=true
static func expire(record: Dictionary,toggle_off: Variant=null)->void:
	#6e9900 restores the latest cache;6e98a0 then forces remaining0. Never
	# recover an older speech packet or derive raw bytes from rendered glyphs.
	record.currentRaw=record.cachedRaw.duplicate();record.currentRawKnown=true;record.currentRich=record.cachedRich.duplicate(true);record.writer="cached-name";record.timedFlag=0;record.remaining=F.f(0.0);record.forceVisible=0;record.guiRegistered=false;record.revision+=1
	if toggle_off is bool and toggle_off:record.hidden=true
static func advance(record: Dictionary,delta: float,toggle_off: Variant=null)->bool:
	if not record.guiRegistered or not is_finite(delta) or delta<0:return false
	if float(record.remaining)<0:record.guiRegistered=false;return false
	record.remaining=F.f(float(record.remaining)-F.f(delta))
	if float(record.remaining)<0:expire(record,toggle_off);return true
	return false
