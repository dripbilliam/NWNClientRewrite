extends Node
# Ordinary native speech: one replacement popup per disclosed visual lifetime.
# No actor/world scan, gameplay authority, wall-clock TTL, rise or fade.
signal expired(id: int,witness: Array,cached_caption: Dictionary)
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Rules=preload("res://systems/native_data/overhead_speech_rules.gd")
const State=preload("res://systems/native_data/overhead_speech_state.gd")
const Bubble=preload("res://systems/native_overhead_bubble.gd")
const UiRules=preload("res://systems/native_data/game_ui_rules.gd")
const F=preload("res://systems/native_render/particle_math.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const TextReceipt=preload("res://systems/native_data/ordinary_speech_text_receipt.gd")
var state:=State.new()
var text
var fonts
var art
var popup_source
var popup_registry
var overlay: Control
var context_reader:=Callable()
var source_reader:=Callable()
var anchor_reader:=Callable()
var settings_reader:=Callable()
var gui_delta_reader:=Callable()
var pending: Dictionary={}
var before_scope: Dictionary={}
var views: Dictionary={}
var pool: Array=[]
var last_received_serial:=-1
var deferred_connection:=-1
var text_revision:=-1
var late_processing:=true
var closed:=false
var diagnostics: Array=[]
var projection_pending:=false
var awaiting_visual: Dictionary={}
const MAX_AWAITING_VISUAL=512
func projection_eligible(record: Dictionary)->bool:
	return record.mode!=0 and not record.hidden and record.get("currentRawKnown",true) and (float(record.remaining)>0 or not record.cachedRaw.is_empty())
func await_visual(id: int,entry: Dictionary)->void:
	if not projection_eligible(entry.popup) or entry.popup.sceneActive:awaiting_visual.erase(id);return
	if not awaiting_visual.has(id) and awaiting_visual.size()>=MAX_AWAITING_VISUAL:warn_once("Native popup visual publication capacity is pending.");return
	awaiting_visual[id]={"witness":entry.witness.duplicate(),"scope":entry.scope.duplicate()}
func bind_popup_registry(value)->void:
	popup_registry=value
	if is_instance_valid(popup_registry) and popup_registry.has_signal("popup_changed"):
		popup_registry.popup_changed.connect(popup_changed);popup_registry.popup_expired.connect(popup_expired)
func popup_changed(id: int,witness: Array,_record: Dictionary,mode_changed: bool,font_changed: bool)->void:
	if closed or not state.speakers.has(id) or state.speakers[id].witness!=witness:return
	state.synchronize_record(id,mode_changed,font_changed)
	if mode_changed:
		await_visual(id,state.speakers[id])
		if awaiting_visual.has(id):projection_pending=true
		elif awaiting_visual.is_empty():projection_pending=false
	if views.has(id) and is_instance_valid(views[id]):views[id].set_meta("speech_revision",state.speakers[id].revision)
	update_processing()
func popup_expired(id: int,witness: Array,_record: Dictionary)->void:
	if closed or not state.speakers.has(id) or state.speakers[id].witness!=witness:return
	var caption: Dictionary=state.speakers[id].ownerCaption;state.speakers.erase(id);awaiting_visual.erase(id);release_view(id);expired.emit(id,witness,caption);update_processing()
func configure(parent_control: Control,text_owner,typefaces,images,resources,current: Callable,sources: Callable,anchors: Callable,settings: Callable=Callable()) -> void:
	# Reconfiguration retires old views and their font/resource connections.
	clear_views();state.close();pending.clear();before_scope.clear();last_received_serial=-1
	overlay=parent_control;text=text_owner;fonts=typefaces;art=images;popup_source=resources;context_reader=current;source_reader=sources;anchor_reader=anchors;settings_reader=settings;closed=false;text_revision=-1
	process_priority=100
	if is_instance_valid(overlay):overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.focus_mode=Control.FOCUS_NONE
	ensure_scope();update_processing()
func configure_processing(enabled: bool=true) -> void:
	late_processing=enabled;process_priority=100;update_processing()
func current_context() -> Dictionary:
	if closed or not context_reader.is_valid():return {}
	var value: Variant=context_reader.call()
	if not value is Dictionary:return {}
	var current:=Scope.context(value.get("connection"),value.get("generation"),value.get("areaId"))
	current.enabled=value.get("enabled",value.get("presentation_enabled",true))==true
	return current
func ensure_scope() -> Dictionary:
	var current:=current_context()
	if not Scope.current_context(current):
		if not state.scope.is_empty():reset()
		return {}
	if not state.current(current):
		var awaiting: Dictionary=before_scope;before_scope={}
		reset();state.begin(current)
		for id in awaiting:
			var request: Dictionary=awaiting[id];var event:=Scope.event(request.message,current)
			if event.get("ready",false) and event.get("anchor",false):
				request.event=event;pending[id]=request;last_received_serial=maxi(last_received_serial,int(event.serial));resolve_pending(int(id),current)
	return current
func defer_before_scope(message: Dictionary,receipt: Dictionary={}) -> Dictionary:
	if not context_reader.is_valid():return {"ready":false,"pending":true}
	var current: Variant=context_reader.call();var metadata: Variant=message.get("nativeTextEvent")
	if not current is Dictionary or not metadata is Dictionary or not Scope.integer(current.get("connection"),0,Scope.MAX_SAFE):return {"ready":false,"pending":true}
	# Only the explicit current owner supplies the accepted connection. Text
	# cannot adopt a connection/area or advance a known generation.
	if Scope.integer(current.get("generation"),0,Scope.MAX_SAFE):return {"ready":false,"retired":true}
	if not Scope.integer(metadata.get("connection"),0,Scope.MAX_SAFE) or int(metadata.connection)!=int(current.connection):return {"ready":false,"retired":true}
	if deferred_connection!=int(current.connection):before_scope.clear();last_received_serial=-1;deferred_connection=int(current.connection)
	var possible:=Scope.context(current.connection,metadata.get("generation"),metadata.get("areaId"));var event:=Scope.event(message,possible)
	if not event.get("ready",false) or not event.get("anchor",false):return event
	if int(event.serial)<=last_received_serial:return {"ready":false,"retired":true}
	last_received_serial=int(event.serial)
	var id:=int(event.source.id)
	if not before_scope.has(id) and before_scope.size()>=512:return {"ready":false,"reason":"Native speech publication capacity is pending."}
	before_scope[id]={"message":message.duplicate(true),"textReceipt":receipt if not receipt.is_empty() else TextReceipt.capture(message,text,current_context()),"elapsed":0.0};update_processing()
	return {"ready":false,"pending":true}
func receive(message: Dictionary,receipt: Dictionary={}) -> Dictionary:
	var current:=ensure_scope()
	if current.is_empty():return defer_before_scope(message,receipt)
	var event:=Scope.event(message,current)
	if not event.get("ready",false):return event
	if int(event.serial)<=last_received_serial:return {"ready":false,"retired":true}
	last_received_serial=int(event.serial)
	if not event.anchor:return {"ready":true,"eligible":false}
	var channel: Variant=message.get("channel")
	if not Scope.integer(channel,0,255) or not Rules.CHANNELS.has(int(channel)):return {"ready":true,"eligible":false}
	var id:=int(event.source.id)
	# One latest replacement waiting for publication, never a message queue.
	if not pending.has(id) and pending.size()>=512:return {"ready":false,"reason":"Native speech publication capacity is pending."}
	pending[id]={"event":event,"message":message.duplicate(true),"textReceipt":receipt if not receipt.is_empty() else TextReceipt.capture(message,text,current),"elapsed":0.0}
	var result:=resolve_pending(id,current);update_processing();return result
func source(id: int) -> Dictionary:
	if closed or not source_reader.is_valid():return {}
	var value: Variant=source_reader.call(id)
	return value if value is Dictionary else {}
func settings() -> Dictionary:
	if not settings_reader.is_valid():return {"mode":Rules.DEFAULT_MODE,"largeFont":Rules.DEFAULT_LARGE}
	var value: Variant=settings_reader.call()
	return value if value is Dictionary else {}
func resolved_body(message: Dictionary,current: Dictionary,receipt: Dictionary={}) -> Dictionary:
	if not is_instance_valid(text):return {"ready":false,"pending":true,"reason":"Native talk data is unavailable."}
	var channel:=int(message.channel);var value: Variant=message.get("text")
	if not (value is String or value is Dictionary):return {"ready":false,"reason":"Native speech text is malformed."}
	if channel in TextReceipt.CHANNELS:
		if receipt.is_empty():receipt=TextReceipt.capture(message,text,current)
		return TextReceipt.prepare(receipt,text,current)
	return {"ready":true,"body":text.raw(value,0),"forced":0.0}
func resolve_pending(id: int,current: Dictionary) -> Dictionary:
	if not pending.has(id):return {"ready":false}
	var request: Dictionary=pending[id];var event: Dictionary=request.event;var row:=source(id)
	var matched:=Scope.received_source(event,row,current)
	if matched.get("retired",false):pending.erase(id);return matched
	var type: Variant=event.source.objectType
	if matched.get("ready",false):type=matched.objectType
	# Native wrapper copies its raw name at the event boundary, independently
	# of text/resource delivery. Retain the first safely received name as well.
	if not request.has("rawName") and Scope.integer(type,1,4294967295) and int(type) in [7,9,10] and matched.get("ready",false) and is_instance_valid(text):
		var names: Variant=row.get("replicated",{}).get("name",row.get("appearance",{}).get("name",row.get("item",{}).get("name",row.get("staticState",{}).get("name"))))
		if names!=null:request.rawName=text.name(names,id)
	# Resolve once under its explicit received context, even if the speaker's
	# own raw name/model is still pending. Never retarget tokens after ID reuse.
	if not request.has("resolvedBody"):
		var resolved:=resolved_body(request.message,current,request.get("textReceipt",{}))
		if not resolved.get("ready",false):
			if not resolved.get("pending",false):pending.erase(id);warn_once(str(resolved.get("reason","Native speech could not be resolved.")))
			return resolved
		request.resolvedBody=resolved.duplicate(true)
	if not Scope.integer(type,1,4294967295):return {"ready":false,"pending":true,"reason":"Native speech speaker type is not yet disclosed."}
	var raw_name:=""
	if int(type) in [7,9,10]:
		if not request.has("rawName"):return {"ready":false,"pending":true,"reason":"Native speech raw speaker name is not yet disclosed."}
		raw_name=str(request.rawName)
	var body: Dictionary=request.resolvedBody
	var preference:=settings();var model:=Rules.compose(request.message.channel,type,str(body.body),raw_name,float(body.forced),preference.get("mode"),preference.get("largeFont"))
	if not model.get("ready",false):return model
	pending.erase(id)
	if not model.get("eligible",false):return model
	var record: Dictionary=popup_registry.caption_record(id,row) if is_instance_valid(popup_registry) and popup_registry.has_method("caption_record") and matched.get("ready",false) else {}
	var result:=state.replace(event,model,{},float(request.elapsed),record)
	if result.get("ready",false):
		if int(request.get("elapsedFrame",-1))==Engine.get_process_frames():state.speakers[id].popup.accountedGuiFrame=Engine.get_process_frames()
		if is_instance_valid(popup_registry) and popup_registry.has_method("adopt_speech") and not record.is_empty():popup_registry.adopt_speech(id,row,state.speakers[id].popup)
		state.observe_source(id,row,current);synchronize(id,current)
	return result
func popup_visual_ready(id: int,visual_source: Dictionary,visual_scope: Array)->void:
	if closed or not awaiting_visual.has(id) and not pending.has(id):return
	var current:=ensure_scope()
	if current.is_empty() or visual_scope!=[current.connection,current.generation,current.areaId]:return
	var event: Dictionary={}
	if pending.has(id):event=pending[id].event
	elif state.speakers.has(id):event={"ready":true,"anchor":true,"source":state.speakers[id].source,"scope":state.speakers[id].scope,"witness":state.speakers[id].witness}
	if event.is_empty() or not Scope.received_source(event,source(id),current).get("ready",false) or not Scope.received_source(event,visual_source,current).get("ready",false):return
	if awaiting_visual.has(id) and (awaiting_visual[id].witness!=event.witness or awaiting_visual[id].scope!=visual_scope):return
	if pending.has(id):resolve_pending(id,current)
	if state.speakers.has(id) and projection_eligible(state.speakers[id].popup):synchronize(id,current)
	elif state.speakers.has(id):awaiting_visual.erase(id)
	update_processing()
func observe_sources(changed_ids: Array=[],removed_ids: Array=[]) -> void:
	var current:=ensure_scope()
	if current.is_empty():update_processing();return
	for raw_id in removed_ids:
		if Scope.integer(raw_id,0,4294967295):retire(int(raw_id))
	var ids: Array=changed_ids.duplicate()
	if ids.is_empty():
		ids=state.speakers.keys()
		for id in pending:
			if not ids.has(id):ids.append(id)
	for raw_id in ids:
		if not Scope.integer(raw_id,0,4294967295):continue
		var id:=int(raw_id)
		if pending.has(id):resolve_pending(id,current)
		if state.speakers.has(id):synchronize(id,current)
	update_processing()
func _make_view() -> Control:return Bubble.new()
func acquire(id: int) -> Control:
	if views.has(id):return views[id]
	if not is_instance_valid(overlay):return null
	if is_instance_valid(popup_registry):popup_registry.register(id,source(id))
	var view: Control=pool.pop_back() if not pool.is_empty() else _make_view()
	if view.get_parent()==null:overlay.add_child(view);view.configure(art,fonts,popup_source)
	views[id]=view;return view
func popup_anchor(id: int,witness: Array) -> Dictionary:
	if not anchor_reader.is_valid():return {"ready":false}
	var value: Variant=anchor_reader.call(id,witness,[state.scope.connection,state.scope.generation,state.scope.areaId])
	return value if value is Dictionary else {"ready":false}
func synchronize(id: int,current: Dictionary) -> void:
	if not state.speakers.has(id):awaiting_visual.erase(id);release_view(id);return
	var matched:=state.observe_source(id,source(id),current)
	if not state.speakers.has(id):awaiting_visual.erase(id);release_view(id);return
	var entry: Dictionary=state.speakers[id]
	# The popup portrait is construction data even while Text-only/Off. A
	# later mode refit must use that same received portrait, not a new caption.
	if matched.get("ready",false) and is_instance_valid(text):
		var rule:=UiRules.new();rule.text=text;entry.popup.portrait=rule.portrait(source(id),1)
	if is_instance_valid(popup_registry) and popup_registry.has_method("adopt_speech") and matched.get("ready",false):
		if popup_registry.adopt_speech(id,source(id),entry.popup):entry.delegated=true
	var anchor:=popup_anchor(id,entry.witness)
	if is_instance_valid(popup_registry) and popup_registry.has_method("project_speech") and matched.get("ready",false) and anchor.get("ready",false):
		popup_registry.project_speech(id,source(id),true);state.synchronize_record(id)
	await_visual(id,entry)
	if not entry.popup.guiRegistered or entry.popup.hidden:
		# Mode0 skips activation, not native logical popup construction/order.
		if matched.get("ready",false) and is_instance_valid(popup_registry):popup_registry.register(id,source(id))
		release_view(id);return
	if anchor.get("retired",false):retire(id);return
	var view:=acquire(id)
	if not is_instance_valid(view):return
	var portrait:=""
	if int(entry.model.mode)==2 and matched.get("ready",false):portrait=str(entry.popup.portrait)
	if view.get_meta("speech_revision",-1)!=entry.revision or view.get_meta("speech_portrait","")!=portrait:
		view.set_content(entry.model,portrait,entry.witness);view.set_meta("speech_revision",entry.revision);view.set_meta("speech_portrait",portrait)
	if is_instance_valid(popup_registry) and popup_registry.has_method("bind_view"):popup_registry.bind_view(id,source(id),"speech",view)
	if current.get("enabled",true) and matched.get("ready",false) and anchor.get("ready",false) and anchor.get("screen") is Vector2:
		view.place(anchor.screen)
		if is_instance_valid(popup_registry):popup_registry.offer(id,source(id),view)
	else:view.hide()
func has_popup(id: int,row: Dictionary,current: Dictionary={}) -> bool:
	if current.is_empty():current=current_context()
	if not state.current(current) or not current.get("enabled",true) or not views.has(id) or not state.has_popup(id,row,current):return false
	var view: Control=views[id]
	if not is_instance_valid(view) or not view.layout_ready:return false
	return popup_anchor(id,state.speakers[id].witness).get("ready",false)
func update_owner_caption(id: int,witness: Array,caption: Dictionary) -> void:state.update_owner_caption(id,witness,caption)
func frame_advance(delta: float) -> void:
	if closed or not is_finite(delta) or delta<0:return
	var current:=ensure_scope()
	if current.is_empty():
		for id in before_scope.keys():
			var request: Dictionary=before_scope[id];request.elapsed=F.f(float(request.elapsed)+F.f(delta));request.elapsedFrame=Engine.get_process_frames()
			if int(request.message.get("channel",-1))!=11 and float(request.elapsed)>12.0:before_scope.erase(id)
		update_processing();return
	# Existing timers consume this GUI delta once. Deferred replacements below
	# already include it in elapsed and must not consume the same delta twice.
	for result in state.advance(delta):
		release_view(int(result.id));expired.emit(int(result.id),result.witness,result.ownerCaption)
	for id in pending.keys():
		var request: Dictionary=pending[id];request.elapsed=F.f(float(request.elapsed)+F.f(delta));request.elapsedFrame=Engine.get_process_frames()
		if int(request.message.get("channel",-1))!=11 and float(request.elapsed)>12.0:pending.erase(id)
	var revision: int=int(text.revision) if is_instance_valid(text) else -1
	if revision!=text_revision:
		text_revision=revision
		for id in pending.keys():resolve_pending(int(id),current)
	for result in state.advance(0.0):
		release_view(int(result.id));expired.emit(int(result.id),result.witness,result.ownerCaption)
	for id in state.speakers.keys():
		if state.speakers[id].popup.guiRegistered or projection_pending:synchronize(int(id),current)
	projection_pending=false
	update_processing()
func _process(delta: float) -> void:
	var began:=Timing.begin();var elapsed:=preload("res://systems/native_data/gui_clock_delta.gd").read(gui_delta_reader,delta)
	if elapsed.ready:frame_advance(elapsed.seconds)
	Timing.finish("callback_overhead_text",began)
func update_processing() -> void:set_process(not closed and late_processing and (projection_pending or not before_scope.is_empty() or not pending.is_empty() or state.active()))
func release_view(id: int) -> void:
	if not views.has(id):return
	var view: Control=views[id];views.erase(id)
	if is_instance_valid(popup_registry) and popup_registry.has_method("unbind_view"):popup_registry.unbind_view(id,"speech",view)
	if is_instance_valid(view):view.release();view.remove_meta("speech_revision");view.remove_meta("speech_portrait");pool.append(view)
func retire(id: int) -> void:pending.erase(id);awaiting_visual.erase(id);state.retire(id);release_view(id)
func reset() -> void:
	pending.clear();before_scope.clear();awaiting_visual.clear();state.close();last_received_serial=-1;deferred_connection=-1;text_revision=-1;projection_pending=false
	for id in views.keys():release_view(int(id))
	update_processing()
func clear_views() -> void:
	for view in views.values()+pool:
		if is_instance_valid(view):view.close();view.queue_free()
	views.clear();pool.clear()
func warn_once(reason: String) -> void:
	if not diagnostics.has(reason) and diagnostics.size()<32:diagnostics.append(reason)
func close() -> void:
	if closed:return
	if is_instance_valid(popup_registry) and popup_registry.has_signal("popup_changed"):
		if popup_registry.popup_changed.is_connected(popup_changed):popup_registry.popup_changed.disconnect(popup_changed)
		if popup_registry.popup_expired.is_connected(popup_expired):popup_registry.popup_expired.disconnect(popup_expired)
	reset();closed=true;set_process(false);clear_views();context_reader=Callable();source_reader=Callable();anchor_reader=Callable();settings_reader=Callable();gui_delta_reader=Callable();overlay=null;text=null;fonts=null;art=null;popup_source=null;popup_registry=null
func _exit_tree() -> void:close()
