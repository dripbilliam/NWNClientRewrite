extends RefCounted
# Independent fixed-origin one-shots. Canonical/proxy existence is captured at
# wire receipt; sounds do not require a visible/selectable physical model.
const Selection=preload("res://systems/native_data/script_sound.gd")
var manager
var last_serial:=-1
var closed:=false
var history: Array=[]
var stats:={"received":0,"started":0,"stale":0,"suppressed":0,"failed":0}
func configure(owner) -> void: manager=owner
func receive_raw(message: Dictionary) -> void:
	if closed or manager.closed or manager.world.get("retiring")==true: return
	if int(message.get("serial",-1))<=last_serial: stats.stale+=1; return
	last_serial=int(message.serial)
	for event in message.get("events",[]):
		stats.received+=1
		var source: Dictionary=event.source; var id:=int(source.id)
		var object: Variant=manager.object(id)
		if object!=null and int(object.get("nativeLifetime",0))>int(source.lifetime): stats.stale+=1; continue
		var positional: Variant=Selection.positional_type(int(source.objectType))
		if positional==null: diagnose("Original positional cast is not established for source type "+str(source.objectType),id); continue
		var point: Variant=Selection.raw_position(source)
		if positional and object!=null and int(object.get("nativeLifetime",0))==int(source.lifetime):
			var host=manager.host(id)
			if is_instance_valid(host):
				var p: Vector3=host.global_position; point=[p.x,-p.z,p.y]
		var cue: Dictionary=Selection.cue_bytes(PackedByteArray(event.soundBytes),positional,point) if event.has("soundBytes") else Selection.cue(str(event.sound),positional,point)
		if not str(cue.error).is_empty(): diagnose(str(cue.error),id); continue
		if str(cue.resRef).is_empty(): stats.suppressed+=1; continue
		var sound: int=manager.world_audio.one_shot(cue.resRef,cue.position,cue.height,cue.priority,cue.delay,cue.volume)
		if sound<0: stats.failed+=1; continue
		stats.started+=1
		if history.size()>=128: history.pop_front()
		history.append({"objectId":id,"lifetime":source.lifetime,"soundId":sound,"resource":cue.resRef,"position":cue.position,"priority":cue.priority})
func diagnose(reason: String,id: int) -> void:
	stats.failed+=1; manager.diagnose("script-sound.native-source-unavailable",reason,id)
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"events":history.duplicate(true),"scope":"Original9/7 fixed-position source/profile selection; actual server/device/mixed-client acceptance separate."}
func close() -> void:
	closed=true; history.clear(); manager=null
