extends Node
# Small presentation registry only: one construction ordinal per exact popup
# lifetime, shared by speech and hover captions. No replicated entity data is
# stored here. Original6e8360/6e8530 retain ordinals across deactivate/reactivate.
const Layout=preload("res://systems/native_data/overhead_popup_layout.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Anchor=preload("res://systems/native_data/overhead_speech_anchor.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const F=preload("res://systems/native_render/particle_math.gd")
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
signal popup_changed(id: int,witness: Array,record: Dictionary,mode_changed: bool,font_changed: bool)
signal popup_expired(id: int,witness: Array,record: Dictionary)
const NATIVE_TOGGLE_OFF_DEFAULT=true # Pinned141296dec initializer; no guessed setting key.
var context_reader:=Callable()
var source_reader:=Callable()
var settings_reader:=Callable()
var name_cache_reader:=Callable()
var restoration_reader:=Callable()
var gui_delta_reader:=Callable()
var scope: Array=[]
var slots: Dictionary={}
var offers: Dictionary={}
var next_ordinal:=0
var closed:=false
var automatic:=true
var clocks: Dictionary={}
var preference:={"mode":2,"largeFont":true}
var diagnostics: Array=[]
func configure(current: Callable,sources: Callable,settings: Callable=Callable(),names: Callable=Callable(),restore: Callable=Callable()) -> void:
	context_reader=current;source_reader=sources;settings_reader=settings;name_cache_reader=names;restoration_reader=restore;process_priority=110
	if settings_reader.is_valid():
		var value: Variant=settings_reader.call()
		if value is Dictionary:preference={"mode":int(value.get("mode",2)),"largeFont":value.get("largeFont",true)==true}
	set_process(false)
func current_scope() -> Array:
	if closed or not context_reader.is_valid():return []
	var value: Variant=context_reader.call()
	if not value is Dictionary:return []
	var current:=Scope.context(value.get("connection"),value.get("generation"),value.get("areaId"))
	return [current.connection,current.generation,current.areaId] if Scope.current_context(current) else []
func synchronize_scope() -> bool:
	var current:=current_scope()
	if current!=scope:reset();scope=current
	return not scope.is_empty()
func register(id: int,row: Dictionary) -> bool:
	if not synchronize_scope() or int(row.get("id",-1))!=id or int(row.get("areaId",-1))!=int(scope[2]) or row.get("replicationRemoved",false) or row.get("destroyed",false):return false
	var identity:=Anchor.witness(row)
	if identity.is_empty():return false
	if slots.has(id) and slots[id].witness!=identity:retire(id)
	if not slots.has(id):
		slots[id]={"witness":identity,"ordinal":next_ordinal,"caption":CaptionState.create(int(preference.mode),bool(preference.largeFont)),"views":{}};next_ordinal+=1
		cache_name(id)
	return true
func cache_name(id: int)->void:
	if not slots.has(id) or not name_cache_reader.is_valid():return
	var value: Variant=name_cache_reader.call(id)
	if value is Dictionary and value.get("ready",false):
		var record: Dictionary=slots[id].caption
		if CaptionState.cache_name(record,value.get("rawBytes"),value.get("rich",{})).get("ready",false):record.cacheOwnerId=value.get("ownerId",record.cacheOwnerId)
func caption_record(id: int,row: Dictionary)->Dictionary:
	return slots[id].caption if register(id,row) else {}
func adopt_speech(id: int,row: Dictionary,record: Dictionary)->bool:
	if not register(id,row):return false
	var previous: Dictionary=slots[id].caption
	if not is_same(previous,record):
		record.cachedRaw=previous.cachedRaw.duplicate();record.cachedRich=previous.cachedRich.duplicate(true);record.cacheOwnerId=previous.cacheOwnerId;slots[id].caption=record
	track_clock(id);return true
func track_clock(id: int)->void:
	if slots.has(id) and slots[id].caption.guiRegistered:clocks[id]=true
	else:clocks.erase(id)
	update_processing()
func view_for(id: int,kind: String):
	if not slots.has(id):return null
	var ref: Variant=slots[id].views.get(kind);var view=ref.get_ref() if ref is WeakRef else null
	if not is_instance_valid(view) or view.get_meta("native_popup_witness",[])!=slots[id].witness or view.get_meta("native_popup_scope",[])!=scope:return null
	return view
func bind_view(id: int,row: Dictionary,kind: String,view: Control)->void:
	if not is_instance_valid(view) or not register(id,row):return
	view.set_meta("native_popup_witness",slots[id].witness.duplicate());view.set_meta("native_popup_scope",scope.duplicate());slots[id].views[kind]=weakref(view)
func unbind_view(id: int,kind: String,view: Control)->void:
	if not slots.has(id) or view_for(id,kind)!=view:return
	slots[id].views.erase(kind)
func notify_views(id: int,mode_changed: bool,font_changed: bool)->void:
	if not slots.has(id):return
	var slot: Dictionary=slots[id];var expected_scope:=scope.duplicate()
	for kind in slot.views.keys():
		if closed or scope!=expected_scope or not slots.has(id) or not is_same(slots[id],slot):return
		var view=view_for(id,str(kind))
		if is_instance_valid(view) and view.has_method("apply_popup_state"):view.apply_popup_state(slot.caption,mode_changed,font_changed)
	if not closed and scope==expected_scope and slots.has(id) and is_same(slots[id],slot):popup_changed.emit(id,slot.witness.duplicate(),slot.caption,mode_changed,font_changed)
func apply_preferences(value: Dictionary)->void:
	if closed:return
	var next:={"mode":int(value.get("mode",2)),"largeFont":value.get("largeFont",true)==true}
	var mode_changed: bool=next.mode!=preference.mode;var font_changed: bool=next.largeFont!=preference.largeFont
	if not mode_changed and not font_changed:return
	preference=next
	# A settings change can precede the first received area. Keep the preference
	# for later construction without adopting or inventing an area owner.
	if not synchronize_scope():return
	var ordered: Array=slots.keys();ordered.sort_custom(func(a,b):return int(slots[a].ordinal)<int(slots[b].ordinal))
	for raw_id in ordered:
		if closed or not slots.has(raw_id):continue
		var id:=int(raw_id);var record: Dictionary=slots[id].caption
		if font_changed:CaptionState.font_changed(record,bool(next.largeFont))
		if mode_changed:
			var result:=CaptionState.mode_changed(record,int(next.mode))
			if not result.get("ready",false) and not diagnostics.has(str(result.get("reason",""))):diagnostics.append(str(result.get("reason","")))
			if next.mode==0:offers.erase(id)
		track_clock(id);notify_views(id,mode_changed,font_changed)
	update_processing()
func hover_blocked(id: int,row: Dictionary)->bool:
	return register(id,row) and int(slots[id].caption.timedFlag)!=0
func write_hover(id: int,row: Dictionary,value: Dictionary)->bool:
	if not register(id,row) or int(slots[id].caption.timedFlag)!=0:return false
	var rich: Dictionary=value.get("caption",value.get("name",{}));var raw: Variant=rich.get("nativeRawBytes")
	var result:=CaptionState.write(slots[id].caption,raw,rich,"hover",str(value.get("portrait","")),4.0,0,true,1)
	if not result.get("ready",false):return false
	# Same native byte clamp as a direct SetText writer, including markup.
	var record: Dictionary=slots[id].caption;record.remaining=maxf(F.f(4.0),minf(F.f(12.0),F.f(F.f(float(record.currentRaw.size()))*F.f(0.15))))
	track_clock(id);notify_views(id,true,false);return true
func leave_hover(id: int)->void:
	if slots.has(id) and int(slots[id].caption.timedFlag)==0:slots[id].caption.remaining=0.0
func project_speech(id: int,row: Dictionary,eligible: bool)->void:
	if not register(id,row):return
	CaptionState.project_active(slots[id].caption,eligible,NATIVE_TOGGLE_OFF_DEFAULT);track_clock(id)
func advance_clocks(delta: float)->void:
	if not synchronize_scope():return
	for raw_id in clocks.keys():
		var id:=int(raw_id)
		if not slots.has(id):clocks.erase(id);continue
		var record: Dictionary=slots[id].caption
		# Delayed text can publish after Owner100 accounted this GUI frame in
		# request.elapsed. This is one clock, with that delta consumed once.
		if int(record.get("accountedGuiFrame",-1))==Engine.get_process_frames():record.accountedGuiFrame=-1;continue
		var witness: Array=slots[id].witness.duplicate()
		if CaptionState.advance(record,delta,NATIVE_TOGGLE_OFF_DEFAULT):
			if restoration_reader.is_valid():
				var restored: Variant=restoration_reader.call(id,record)
				if restored is Dictionary and restored.get("ready",false):record.currentRaw=restored.rawBytes.duplicate();record.currentRawKnown=true;record.currentRich=restored.rich.duplicate(true)
				else:
					record.currentRawKnown=false;record.currentRaw=PackedByteArray();record.currentRich={"text":"","spans":[]}
			notify_views(id,false,false)
			if not closed and slots.has(id) and slots[id].witness==witness:popup_expired.emit(id,witness,record)
		track_clock(id)
func update_processing()->void:set_process(automatic and not closed and (not clocks.is_empty() or not offers.is_empty()))
func offer(id: int,row: Dictionary,view: Control,mode: int=1) -> void:
	if not is_instance_valid(view) or not register(id,row):return
	# Position is already rounded by its native view. Never call place() again
	# after overlap: negative offscreen coordinates must not round twice.
	offers[id]={"view":weakref(view),"witness":slots[id].witness.duplicate(),"mode":mode,"position":view.position,"size":view.size,"frame":Engine.get_process_frames()}
	update_processing()
func observe(changed_ids: Array=[],removed_ids: Array=[]) -> void:
	if not synchronize_scope():return
	for raw_id in removed_ids:retire(int(raw_id))
	if not source_reader.is_valid():return
	for raw_id in changed_ids:
		var id:=int(raw_id)
		if not slots.has(id):continue
		var row: Variant=source_reader.call(id)
		if not row is Dictionary or Anchor.witness(row)!=slots[id].witness or int(row.get("areaId",-1))!=int(scope[2]):retire(id)
		else:cache_name(id)
func retire(id: int) -> void:
	if slots.has(id):
		for kind in slots[id].views:
			var view=view_for(id,str(kind))
			if is_instance_valid(view):view.hide();view.remove_meta("native_popup_witness");view.remove_meta("native_popup_scope")
	slots.erase(id);offers.erase(id);clocks.erase(id);update_processing()
func frame_layout() -> void:
	if not synchronize_scope():return
	var active: Array=[];var frame:=Engine.get_process_frames()
	for id in offers.keys():
		var entry: Dictionary=offers[id];var view=entry.view.get_ref()
		if not is_instance_valid(view) or not view.is_visible_in_tree() or int(entry.frame)!=frame or not slots.has(id) or slots[id].witness!=entry.witness:
			offers.erase(id);continue
		active.append({"id":id,"ordinal":slots[id].ordinal,"view":view,"entry":entry})
	active.sort_custom(func(a,b):return int(a.ordinal)<int(b.ordinal))
	var rows: Array=[];var mode:=1
	if settings_reader.is_valid():
		var settings: Variant=settings_reader.call()
		if settings is Dictionary and Scope.integer(settings.get("mode"),0,2):mode=int(settings.mode)
	for value in active:
		var entry: Dictionary=value.entry;var dimensions: Vector2=entry.size;var position: Vector2=entry.position
		rows.append({"active":1,"x":position.x+dimensions.x*0.5,"y":-(position.y+dimensions.y),"width":dimensions.x,"height":dimensions.y,"z":-5.0})
	var arranged:=Layout.arrange(rows,mode)
	if arranged.get("ready",false):
		for index in active.size():
			var result: Dictionary=arranged.rows[index];var view: Control=active[index].view
			view.position=Vector2(float(result.x)-view.size.x*0.5,-float(result.y)-view.size.y)
	update_processing()
func _process(delta: float) -> void:
	var began:=Timing.begin();var elapsed:=preload("res://systems/native_data/gui_clock_delta.gd").read(gui_delta_reader,delta)
	if elapsed.ready:advance_clocks(elapsed.seconds)
	frame_layout();Timing.finish("callback_overhead_layout",began)
func reset() -> void:
	for id in slots.keys():retire(int(id))
	slots.clear();offers.clear();clocks.clear();next_ordinal=0;scope=[];set_process(false)
func close() -> void:
	if closed:return
	reset();closed=true;context_reader=Callable();source_reader=Callable();settings_reader=Callable();name_cache_reader=Callable();restoration_reader=Callable();gui_delta_reader=Callable()
func _exit_tree() -> void:close()
