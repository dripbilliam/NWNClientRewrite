extends RefCounted
# Ordered client6e1fc0/6d6770/6d7fe0 decisions, never a remote lifecycle owner.
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const INVALID:=0x7f000000
const TRANSITION_CALLBACKS=["pause","unpause","snapshot","syncPrevious","reset","time","object","asObject","scene","sceneVirtual","resetObjectTimes","pauseText","audio","disposeIncoming","guiActive","guiBlocked","guiSetFlags","guiClearFlags"]
var flags_known:=false
var flags:=0
var exclusions_known:=false
var exclusions: Variant=null
var timers: Dictionary={}
var providers: Dictionary={}
var gui_known:=false
var gui: Variant=null
var profile_mode: Variant=null
var controlled_id: Variant=null
var closed:=false
static func unavailable(reason: String)->Dictionary:return {"ready":false,"reason":reason}
static func owned_incoming(ids: Array)->Dictionary:
	var values: Array=[]
	for id in ids:
		if not NativeWorldTimer.integer(id):return unavailable("Incoming client exclusion ID is unknown.")
		values.append(NativeWorldTimer.u32(id))
	return {"ready":true,"ids":values,"capacity":0,"disposed":false}
func configure(initial: Dictionary,timer_handles: Dictionary,callbacks: Dictionary)->Dictionary:
	flags_known=false;exclusions_known=false;exclusions=null;gui_known=false;gui=null;profile_mode=null;controlled_id=null;closed=false
	timers=timer_handles.duplicate();providers=callbacks.duplicate()
	if initial.has("flags") and NativeWorldTimer.integer(initial.flags):flags=NativeWorldTimer.u32(initial.flags)&255;flags_known=true
	var list: Variant=initial.get("exclusions")
	if list is Dictionary and list.get("known")==true and list.has("ids"):
		if list.ids==null:exclusions_known=true;exclusions=null
		elif list.ids is Array:
			var copied:=owned_incoming(list.ids)
			if copied.get("ready",false):exclusions_known=true;exclusions=copied.ids
	var gui_state: Variant=initial.get("gui")
	if gui_state is Dictionary and gui_state.get("known")==true and gui_state.has("value"):gui_known=true;gui=gui_state.value
	if NativeWorldTimer.integer(initial.get("profileMode")):profile_mode=NativeWorldTimer.i32(initial.profileMode)
	if NativeWorldTimer.integer(initial.get("controlledId")):controlled_id=NativeWorldTimer.u32(initial.controlledId)
	return {"ready":flags_known and exclusions_known and gui_known and profile_mode!=null and controlled_id!=null and timer_known("world") and timer_known("timer1") and timer_known("timer2")}
func timer_known(key: String)->bool:return timers.has(key) and timers[key]!=null
func callbacks_known(names: Array)->bool:
	for key in names:
		var callback: Variant=providers.get(key)
		if not callback is Callable or not callback.is_valid():return false
	return true
func invoke(key: String,args: Array=[])->Variant:return providers[key].callv(args)
func excluded(id_value: Variant)->Dictionary:
	if closed or not exclusions_known or not NativeWorldTimer.integer(id_value):return unavailable("Client native exclusion storage/ID is unknown.")
	if exclusions==null:return {"ready":true,"value":1}
	if not exclusions is Array:return unavailable("Client native exclusion storage is malformed.")
	return {"ready":true,"value":1 if exclusions.has(NativeWorldTimer.u32(id_value)) else 0}
func active_timer(id_value: Variant)->Dictionary:
	if closed or not NativeWorldTimer.integer(id_value):return unavailable("Client timer selector/ID is unknown.")
	var id:=NativeWorldTimer.u32(id_value)
	# INVALID bypasses flag/list reads, exactly as the native getter.
	if id==INVALID:return {"ready":true,"timer":timers.world,"slot":"world"} if timer_known("world") else unavailable("World timer is unknown.")
	if not flags_known:return unavailable("Client native pause flags are unknown.")
	var chosen:="world"
	if flags&2:
		var admitted:=excluded(id)
		if not admitted.ready:return admitted
		if admitted.value==1:chosen="timer2"
	elif flags&1:
		var admitted:=excluded(id)
		if not admitted.ready:return admitted
		if admitted.value==1:chosen="timer1"
	return {"ready":true,"timer":timers[chosen],"slot":chosen} if timer_known(chosen) else unavailable("Selected native timer is unknown.")
func state_view()->Dictionary:
	return {"flagsKnown":flags_known,"flags":flags if flags_known else null,"exclusions":{"known":exclusions_known,"ids":exclusions.duplicate() if exclusions is Array else null},"guiKnown":gui_known,"profileMode":profile_mode,"controlledId":controlled_id,"closed":closed}
func snapshot_before_receive()->Dictionary:
	# Only the proven prefix of6db800, not dispatch/object/GUI execution.
	if closed or not flags_known or not callbacks_known(["snapshot"]):return unavailable("Native frame prefix flags/provider are unknown.")
	var selected: Array=[]
	if (flags&3)==0:selected.append("world")
	if (flags&2)==0:selected.append("timer1")
	selected.append("timer2")
	for key in selected:
		if not timer_known(key):return unavailable("Native frame-prefix timer is unknown: "+str(key))
	for key in selected:invoke("snapshot",[timers[key]])
	return {"ready":true,"slots":selected}
func scene_call(object: Variant,offset: int)->void:
	# Preserve repeated casts/lookups; native lower providers can have effects.
	if invoke("asObject",[object])!=null:
		var scene: Variant=invoke("scene",[invoke("asObject",[object])])
		if scene!=null:invoke("sceneVirtual",[invoke("scene",[invoke("asObject",[object])]),offset])
func clear_exclusions()->Dictionary:
	if closed or not flags_known or not exclusions_known:return unavailable("Client native old exclusion list/flags are unknown.")
	if exclusions==null:return {"ready":false,"nativeNullDereference":true,"reason":"Native clear6d6770 dereferences null list storage; no output or callback is invented."}
	if not exclusions is Array or not callbacks_known(["object","time","asObject","scene","sceneVirtual","resetObjectTimes"]):return unavailable("Client old-list providers/storage are unavailable.")
	for key in ["world","timer1","timer2"]:
		if not timer_known(key):return unavailable("Client timer is unknown: "+key)
	var at:=0
	# Live length is intentionally re-read after each lower callback.
	while at<exclusions.size():
		var object: Variant=invoke("object",[NativeWorldTimer.u32(exclusions[at])])
		if object!=null:
			var selected:=active_timer(object.id)
			if not selected.ready:return selected
			var now: Dictionary=invoke("time",[selected.timer])
			invoke("resetObjectTimes",[object,now.day,now.time]);scene_call(object,0x158)
		at+=1
	exclusions=[]
	return {"ready":true}
func apply(mask_value: Variant,value_value: Variant,incoming: Variant=null)->Dictionary:
	if closed or not NativeWorldTimer.integer(mask_value) or not NativeWorldTimer.integer(value_value):return unavailable("Client pause input/owner is unknown.")
	var mask:=NativeWorldTimer.u32(mask_value)&255;var value:=NativeWorldTimer.i32(value_value)
	# No callbacks, incoming consumption or later-state validation on native noop.
	if (flags_known and (flags&mask)==NativeWorldTimer.u32(value)) or mask==0 and value==0:return {"ready":true,"changed":false,"consumed":false}
	if not flags_known or not exclusions_known or not gui_known or profile_mode==null or controlled_id==null:return unavailable("Client native transition state is unknown.")
	if exclusions==null:return {"ready":false,"nativeNullDereference":true,"reason":"Transition would dereference known null native old-list storage."}
	if not exclusions is Array or not callbacks_known(TRANSITION_CALLBACKS):return unavailable("Client native transition provider table is unavailable.")
	for key in ["world","timer1","timer2"]:
		if not timer_known(key):return unavailable("Client transition timer is unknown: "+key)
	if incoming!=null:
		if not incoming is Dictionary or not incoming.get("ids") is Array or incoming.get("disposed",false):return unavailable("Owned incoming client list is unavailable.")
		for id in incoming.ids:
			if not NativeWorldTimer.integer(id):return unavailable("Incoming client ID is unknown.")
	var world: Variant=timers.world;var one: Variant=timers.timer1;var two: Variant=timers.timer2
	if value==1:
		flags=(flags|mask)&255;invoke("pause",[world]);invoke("snapshot",[world]);invoke("snapshot",[world])
		if flags&2:
			invoke("pause",[one]);invoke("snapshot",[one]);invoke("snapshot",[one]);invoke("pauseText",[205])
		invoke("audio",[true])
	else:
		flags=flags&(~mask&255)
		if mask==2:
			invoke("pause",[two]);invoke("reset",[two,one]);invoke("snapshot",[two]);invoke("snapshot",[one]);invoke("syncPrevious",[two]);invoke("syncPrevious",[one])
			if (flags&2)!=0 or (flags&1)==0:invoke("snapshot",[world]);invoke("syncPrevious",[world]);invoke("unpause",[world]);invoke("audio",[false])
			invoke("unpause",[one]);invoke("unpause",[two]);invoke("pauseText",[206])
		elif mask==1:
			invoke("pause",[one]);invoke("pause",[two]);invoke("reset",[one,world]);invoke("reset",[two,world]);invoke("snapshot",[world]);invoke("snapshot",[one]);invoke("snapshot",[two])
			invoke("syncPrevious",[two]);invoke("syncPrevious",[one]);invoke("syncPrevious",[world]);invoke("unpause",[world]);invoke("unpause",[one]);invoke("unpause",[two]);invoke("audio",[false])
	var cleared:=clear_exclusions()
	if not cleared.ready:return cleared
	if incoming!=null:
		var at:=0
		while at<incoming.ids.size():
			var id:=NativeWorldTimer.u32(incoming.ids[at])
			if exclusions!=null and not exclusions.has(id):exclusions.append(id)
			var object: Variant=invoke("object",[id])
			if object!=null:
				scene_call(object,0x150);var selected:=active_timer(object.id)
				if not selected.ready:return selected
				var now: Dictionary=invoke("time",[selected.timer]);invoke("resetObjectTimes",[object,now.day,now.time])
			at+=1
		invoke("disposeIncoming",[incoming]);incoming.ids=[];incoming.capacity=0;incoming.disposed=true
	if gui==null or invoke("guiActive",[gui])==0:return {"ready":true,"changed":true,"consumed":incoming!=null}
	var blocked:=0
	if flags&3 and profile_mode!=1:
		var admitted:=excluded(controlled_id)
		if not admitted.ready:return admitted
		if admitted.value==0:blocked=1
	invoke("guiBlocked",[gui,blocked])
	var bits: int=((mask&1)*2)|(4 if mask&2 else 0)
	invoke("guiSetFlags" if value!=0 else "guiClearFlags",[gui,bits])
	return {"ready":true,"changed":true,"consumed":incoming!=null}
static func write_creature_stamp(object: Dictionary,day: Variant,time: Variant)->Dictionary:
	if not NativeWorldTimer.integer(day) or not NativeWorldTimer.integer(time):return unavailable("Creature reset stamp is unknown.")
	object.day=NativeWorldTimer.u32(day);object.time=NativeWorldTimer.u32(time)
	return {"ready":true}
static func receive_message(reader: Dictionary)->Dictionary:
	for key in ["allocateIncoming","byte","bool","word","objectId","overflow","apply","gui","refreshGui","unconsumedIncoming"]:
		var callback: Variant=reader.get(key)
		if not callback is Callable or not callback.is_valid():return unavailable("Client pause scalar reader is unknown: "+key)
	var owned:={"ids":[],"capacity":0,"disposed":false}
	reader.allocateIncoming.call(owned)
	var mask: int=NativeWorldTimer.u32(reader["byte"].call(2,1))&255;var value: int=NativeWorldTimer.i32(reader["bool"].call());var count: int=NativeWorldTimer.u32(reader["word"].call(16))&65535
	for _index in count:
		var id:=NativeWorldTimer.u32(reader.objectId.call())
		if owned.ids.size()==owned.capacity:owned.capacity=16 if owned.capacity==0 else owned.capacity*2
		owned.ids.append(id)
	if reader.overflow.call()!=0:
		reader.unconsumedIncoming.call(owned,"overflow");return {"ready":true,"result":0,"owned":owned,"unconsumed":"overflow"}
	reader.apply.call(mask,value,owned);var current_gui: Variant=reader.gui.call()
	if current_gui!=null:
		var field: Variant=current_gui.get("fieldA8") if current_gui is Dictionary else current_gui.get("fieldA8")
		if field!=null and field!=0:reader.refreshGui.call()
	if not owned.disposed:reader.unconsumedIncoming.call(owned,"unchanged-state")
	return {"ready":true,"result":1,"owned":owned,"unconsumed":"" if owned.disposed else "unchanged-state"}
func close()->void:
	closed=true;flags_known=false;exclusions_known=false;exclusions=null;timers.clear();providers.clear();gui_known=false;gui=null;profile_mode=null;controlled_id=null

