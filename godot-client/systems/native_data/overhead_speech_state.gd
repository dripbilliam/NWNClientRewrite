extends RefCounted
# One ordinary popup state per actual speaker witness. Replacement never queues
# an earlier speech. Timers advance in GUI frame delta, independent of assets,
# camera/viewport/model readiness. Shared integration supplies current scopes.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const F=preload("res://systems/native_render/particle_math.gd")
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
var scope: Dictionary={}
var speakers: Dictionary={}
var last_serial:=-1
var revision:=0
func begin(current: Dictionary) -> bool:
	close()
	if not Scope.current_context(current):return false
	scope=current.duplicate();return true
func current(value: Dictionary) -> bool:
	return Scope.current_context(value) and Scope.current_context(scope) and value.connection==scope.connection and value.generation==scope.generation and value.areaId==scope.areaId
func replace(event: Dictionary,model: Dictionary,owner_caption: Dictionary={},elapsed: float=0.0,popup: Dictionary={}) -> Dictionary:
	if not Scope.current_context(scope) or not event.get("ready",false) or not event.get("anchor",false) or event.get("scope")!=[scope.connection,scope.generation,scope.areaId] or not is_finite(elapsed) or elapsed<0:return {"ready":false,"retired":true}
	if not model.get("ready",false) or not model.get("eligible",false):return {"ready":true,"replaced":false}
	var id:=int(event.source.id);var previous: Dictionary=speakers.get(id,{})
	# Ingestion deduplication belongs to the owner. A newer event from ANOTHER
	# speaker must not suppress this speaker's delayed raw/TLK publication.
	if not previous.is_empty() and int(previous.serial)>=int(event.serial):return {"ready":false,"retired":true}
	last_serial=maxi(last_serial,int(event.serial))
	var same: bool=not previous.is_empty() and previous.witness==event.witness
	var caption: Dictionary=previous.ownerCaption if same and owner_caption.is_empty() else owner_caption.duplicate(true)
	var delegated:=not popup.is_empty();var record: Dictionary=popup if delegated else CaptionState.create(int(model.mode),str(model.font)=="ttf fnt_default_hr 16")
	record.mode=int(model.mode);record.font=str(model.font)
	if not CaptionState.write(record,str(model.text),model.rich,"speech",str(record.portrait),F.f(float(model.seconds)-F.f(elapsed)),1,true,1).get("ready",false):return {"ready":false}
	revision+=1;speakers[id]={"id":id,"serial":int(event.serial),"scope":event.scope.duplicate(),"source":event.source.duplicate(),"witness":event.witness.duplicate(),"model":model.duplicate(true),"popup":record,"delegated":delegated,"remaining":record.remaining,"registered":record.guiRegistered,"sourceBound":bool(previous.get("sourceBound",false)) if same else false,"ownerCaption":caption,"revision":revision}
	return {"ready":true,"replaced":same,"id":id,"revision":revision}
func synchronize_record(id: int,refit: bool=false,_font_only: bool=false)->void:
	if not speakers.has(id):return
	var entry: Dictionary=speakers[id];var record: Dictionary=entry.popup
	entry.remaining=record.remaining;entry.registered=record.guiRegistered;entry.model.mode=record.mode;entry.model.font=record.font
	if refit and record.get("currentRawKnown",true):
		entry.model.text=CaptionState.decoded(record.currentRaw);entry.model.rich=record.currentRich.duplicate(true);entry.model.seconds=record.remaining;entry.model.registered=record.guiRegistered;revision+=1;entry.revision=revision
func observe_source(id: int,row: Dictionary,current_scope: Dictionary) -> Dictionary:
	if not speakers.has(id):return {"ready":false}
	if not current(current_scope):return retire(id,"scope")
	var entry: Dictionary=speakers[id];var event:={"ready":true,"anchor":true,"scope":entry.scope,"source":entry.source,"witness":entry.witness}
	var matched:=Scope.received_source(event,row,current_scope,bool(entry.sourceBound))
	if matched.get("ready",false):entry.sourceBound=true;return matched
	# Before first publication a newer event may legitimately precede its row.
	# A popup already bound to one disclosure must never revive after D/A.
	if matched.get("retired",false) or entry.sourceBound and (matched.get("mismatch",false) or row.is_empty()):return retire(id,"speaker")
	return matched
func update_owner_caption(id: int,witness: Array,value: Dictionary) -> void:
	if speakers.has(id) and speakers[id].witness==witness:speakers[id].ownerCaption=value.duplicate(true)
func advance(delta: float) -> Array:
	var expired: Array=[]
	if not is_finite(delta) or delta<0:return expired
	delta=F.f(delta)
	for id in speakers.keys():
		var entry: Dictionary=speakers[id]
		if entry.delegated:synchronize_record(int(id));continue # The same registry record owns/ticks this clock.
		var did_expire:=CaptionState.advance(entry.popup,delta,true)
		synchronize_record(int(id))
		if did_expire:
			expired.append({"id":int(id),"witness":entry.witness.duplicate(),"scope":entry.scope.duplicate(),"ownerCaption":entry.ownerCaption.duplicate(true),"serial":entry.serial});speakers.erase(id);revision+=1
	return expired
func retire(id: int,reason: String="removed") -> Dictionary:
	if not speakers.has(id):return {"ready":false,"retired":true}
	speakers.erase(id);revision+=1;return {"ready":false,"retired":true,"reason":reason}
func has_popup(id: int,row: Dictionary,current_scope: Dictionary) -> bool:
	if not speakers.has(id) or not speakers[id].popup.guiRegistered or speakers[id].popup.hidden:return false
	return observe_source(id,row,current_scope).get("ready",false) and speakers.has(id)
func active() -> bool:
	for entry in speakers.values():
		if entry.popup.guiRegistered:return true
	return false
func close() -> void:
	scope={};speakers={};last_serial=-1;revision+=1
