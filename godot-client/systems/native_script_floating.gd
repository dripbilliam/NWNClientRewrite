extends Node
# Native93/94 presentation only. Pending FIFO/cooldown and active GUI widgets
# have separate lifetimes. No world/actor mutation or fabricated actor context.
signal log_message(row: Dictionary)
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Frame=preload("res://systems/native_data/script_floating_frame.gd")
const Markup=preload("res://systems/native_data/script_floating_markup.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Resources=preload("res://systems/native_script_floating_resources.gd")
const View=preload("res://systems/native_script_floating_view.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const TextReceipt=preload("res://systems/native_data/script_floating_text_receipt.gd")
var text
var fonts
var art
var resources
var overlay: Control
var context_reader:=Callable()
var source_reader:=Callable()
var anchor_reader:=Callable()
var object_delta_ms_reader:=Callable()
var gui_delta_reader:=Callable()
var entries: Dictionary={}
var active_entries: Dictionary={}
var queues: Dictionary={}
var views: Dictionary={}
var pool: Array=[]
var last_serial:=-1
var scope: Array=[]
var closed:=false
var automatic:=true
var text_revision:=-1
var nominal_usec:=0.0
var nominal_ms:=0
var diagnostics: Array=[]
var pending_echo: Dictionary={}
var receipt_sequence:=0
var receipt_connection:=-1
func configure(parent_control: Control,text_owner,typefaces,images,catalog,current: Callable,sources: Callable,anchors: Callable,cache_path: String="") -> void:
	overlay=parent_control;text=text_owner;fonts=typefaces;art=images;context_reader=current;source_reader=sources;anchor_reader=anchors;process_priority=100
	resources=Resources.new();add_child(resources);resources.configure(catalog,cache_path);set_process(false)
func configure_processing(value: bool=true) -> void:automatic=value;update_processing()
static func slot(data: Dictionary,family: String,index: int) -> Variant:
	var values: Variant=data.get(family)
	if values is Array:return values[index] if index>=0 and index<values.size() else null
	return values.get(str(index),values.get(index)) if values is Dictionary else null
static func i32(value: int) -> int:return ((value+2147483648)&4294967295)-2147483648
func source(id: int) -> Dictionary:
	var value: Variant=source_reader.call(id) if source_reader.is_valid() else null
	return value if value is Dictionary else {}
func current_context() -> Dictionary:
	var value: Variant=context_reader.call() if context_reader.is_valid() else null
	if closed or not value is Dictionary:return {}
	var projected:=Scope.context(value.get("connection"),value.get("generation"),value.get("areaId"));projected.enabled=value.get("enabled",true)==true;return projected
func queue_key(witness: Array) -> String:return "%d:%d:%d"%[int(witness[0]),int(witness[1]),int(witness[2])]
func accepts_scope(entry: Dictionary,current: Dictionary) -> bool:return Scope.current_context(current) and entry.event.scope==[current.connection,current.generation,current.areaId]
func current_connection() -> Variant:
	var value: Variant=context_reader.call() if not closed and context_reader.is_valid() else null
	return int(value.connection) if value is Dictionary and Scope.integer(value.get("connection"),0,Scope.MAX_SAFE) else null
func synchronize_connection() -> void:
	var connection: Variant=current_connection()
	if connection==null:
		if receipt_connection>=0:reset()
		return
	if receipt_connection>=0 and receipt_connection!=int(connection):reset()
	receipt_connection=int(connection)
func synchronize_scope() -> Dictionary:
	synchronize_connection()
	var current:=current_context()
	if not Scope.current_context(current):return current
	var next: Array=[current.connection,current.generation,current.areaId]
	if next!=scope:
		if not scope.is_empty() and scope[0]!=next[0]:last_serial=-1
		for key in queues.keys():
			if queues[key].scope!=next:queues.erase(key)
		for serial in entries.keys():
			var item: Dictionary=entries[serial];var incoming: Array=item.event.scope
			if incoming[0]!=next[0] or incoming[1]<next[1] or incoming[1]==next[1] and incoming[2]!=next[2]:discard(int(serial))
		scope=next
	return current
func receive(message: Dictionary,transport_connection: Variant=null,transport_generation: Variant=null) -> Dictionary:
	if closed or message.get("kind")!="combat-feedback" or not Scope.integer(message.get("type"),93,94):return {"handled":false}
	var data: Variant=message.get("data")
	if not data is Dictionary:return {"handled":true,"ready":false}
	var target: Variant=slot(data,"objects",0);var type:=int(message.type)
	if not Scope.integer(target,0,Scope.MAX_ID):return {"handled":true,"ready":false}
	var current:=synchronize_scope();var connection: Variant=current_connection()
	var explicit_transport: bool=transport_connection!=null or transport_generation!=null
	var accepted_transport:=false
	if explicit_transport:
		if not Scope.integer(transport_connection,0,Scope.MAX_SAFE) or not Scope.integer(transport_generation,0,Scope.MAX_SAFE) or connection==null or int(transport_connection)!=int(connection):return {"handled":true,"ready":false,"accepted_transport":false,"reason":"Native script feedback transport is not current."}
		accepted_transport=true
	var show: Variant=slot(data,"integers",1 if type==93 else 0);var payload: Variant=slot(data,"integers",0) if type==93 else slot(data,"strings",0)
	if type==93 and not Scope.integer(payload,-2147483648,2147483647):return {"handled":true,"ready":false,"accepted_transport":false}
	if type==94 and not (payload is String or payload is Dictionary and payload.get("text") is String):return {"handled":true,"ready":false,"accepted_transport":false}
	if accepted_transport and (not Scope.integer(show,-2147483648,2147483647) or not message.get("color","") is String):return {"handled":true,"ready":false,"accepted_transport":false}
	var metadata: Variant=message.get("nativeTextEvent");var event: Dictionary={};var widget_allowed:=true
	if message.has("nativeTextEvent"):
		if not Scope.valid_header(metadata) or connection==null or metadata.connection!=connection or accepted_transport and int(metadata.generation)!=int(transport_generation):return {"handled":true,"ready":false,"accepted_transport":false,"reason":"Native script feedback metadata contradicts transport."}
		if metadata.source is Dictionary and (int(metadata.source.id)!=int(target) or metadata.areaId!=null and metadata.source.areaId!=null and int(metadata.areaId)!=int(metadata.source.areaId)):return {"handled":true,"ready":false,"accepted_transport":false,"reason":"Native script feedback source contradicts payload."}
		if int(metadata.serial)<=last_serial:return {"handled":true,"ready":false,"accepted_transport":accepted_transport}
		var possible:=Scope.context(metadata.connection,metadata.generation,metadata.areaId);event=Scope.event(message,possible)
		if not event.get("ready",false):
			if not accepted_transport or metadata.areaId!=null:return {"handled":true,"ready":false,"accepted_transport":false}
			widget_allowed=false
		elif Scope.current_context(current) and (event.scope[1]<current.generation or event.scope[1]==current.generation and event.scope[2]!=current.areaId):
			if not accepted_transport:return {"handled":true,"ready":false}
			widget_allowed=false
		last_serial=int(metadata.serial)
	elif not accepted_transport:return {"handled":true,"ready":false}
	else:widget_allowed=false
	# One receipt serves the connection-owned echo and the separately scoped
	# widget. A missing native event serial never acquires a synthetic one.
	var receipt:=TextReceipt.capture(type,payload,int(target),show==1,str(message.get("color","")),text,metadata if metadata is Dictionary else {})
	receipt_sequence+=1;receipt.receipt_id=receipt_sequence;receipt.echo_independent=accepted_transport;receipt.echo_connection=int(connection) if accepted_transport else -1
	if widget_allowed:
		receipt.merge({"event":event,"status":"pending","duration":1.5,"remaining":1.5,"sourceBound":false,"orphan":false},true)
		entries[int(event.serial)]=receipt
	if accepted_transport and receipt.showChat:pending_echo[receipt_sequence]=receipt;prepare_echo(receipt)
	if not closed and widget_allowed:prepare_entry(int(event.serial),current)
	update_processing()
	var result:={"handled":true,"ready":true,"accepted_transport":accepted_transport}
	if widget_allowed:result.serial=int(event.serial)
	return result
func snapshot_raw(entry: Dictionary) -> void:
	TextReceipt.snapshot_raw(entry,text)
func prepare_echo(receipt: Dictionary) -> void:
	if closed or current_connection()!=receipt.echo_connection:
		pending_echo.erase(receipt.receipt_id);return
	var prepared:=TextReceipt.prepare(receipt,text)
	if not prepared.get("ready",false):
		if not prepared.get("pending",false):receipt.text_failed=true;pending_echo.erase(receipt.receipt_id);warn_once(str(prepared.get("reason","Native script text is unavailable.")))
		return
	pending_echo.erase(receipt.receipt_id)
	var row:=TextReceipt.take_log(receipt)
	if not row.is_empty():log_message.emit(row)
func prepare_entry(serial: int,current: Dictionary) -> void:
	if not entries.has(serial):return
	var entry: Dictionary=entries[serial]
	if not accepts_scope(entry,current):return
	if entry.get("text_failed",false):discard(serial);return
	var prepared:=TextReceipt.prepare(entry,text)
	if not prepared.get("ready",false) and not prepared.get("pending",false):warn_once(str(prepared.get("reason","Native script text is unavailable.")));discard(serial);return
	if entry.bodyReady and not entry.echo_independent:
		var row:=TextReceipt.take_log(entry)
		if not row.is_empty():log_message.emit(row)
		if closed or not entries.has(serial):return
	if entry.status=="log-only":
		if entry.bodyReady or not entry.showChat:discard(serial)
		return
	if not entry.event.anchor:
		if entry.bodyReady or not entry.showChat:discard(serial)
		else:entry.status="log-only"
		return
	var metadata_type: Variant=entry.event.source.objectType
	if metadata_type!=null and int(metadata_type)!=5:
		if entry.bodyReady or not entry.showChat:discard(serial)
		else:entry.status="log-only"
		return
	if entry.status=="pending":
		var key:=queue_key(entry.event.witness)
		if not queues.has(key):queues[key]={"id":entry.target,"event":entry.event,"witness":entry.event.witness.duplicate(),"scope":entry.event.scope.duplicate(),"serials":[],"cooldown":0,"sourceBound":false}
		queues[key].serials.append(serial);entry.status="queued"
	if entry.status=="active" and entry.bodyReady:ensure_view(serial)
func data_changed() -> void:
	if closed:return
	var current:=synchronize_scope()
	for receipt in pending_echo.values():snapshot_raw(receipt);prepare_echo(receipt)
	for serial in entries.keys():snapshot_raw(entries[serial]);prepare_entry(int(serial),current)
	update_processing()
func observe_sources(changed_ids: Array=[],removed_ids: Array=[]) -> void:
	var current:=synchronize_scope()
	for id in removed_ids:
		for serial in entries.keys():
			if int(entries[serial].target)==int(id):
				if entries[serial].status=="active":entries[serial].orphan=true
				else:retire_pending(int(serial))
		for key in queues.keys():
			if int(queues[key].id)==int(id):queues.erase(key)
	for serial in entries.keys():
		var entry: Dictionary=entries[serial]
		if changed_ids.is_empty() or changed_ids.has(int(entry.target)):prepare_entry(int(serial),current)
	update_processing()
func queue_delta(queue: Dictionary,explicit_ms: Variant,nominal_delta: int) -> Variant:
	var value: Variant=explicit_ms
	if value==null:value=object_delta_ms_reader.call(int(queue.id),queue.witness,queue.scope) if object_delta_ms_reader.is_valid() else nominal_delta
	return int(value) if Scope.integer(value,0,4294967295) else null
func advance_queues(current: Dictionary,explicit_ms: Variant,nominal_delta: int) -> void:
	for key in queues.keys():
		var queue: Dictionary=queues[key]
		if queue.scope!=scope:continue
		var matched:=Scope.received_source(queue.event,source(int(queue.id)),current,true)
		if not matched.get("ready",false):
			if queue.sourceBound and (matched.get("mismatch",false) or matched.get("retired",false)):
				for serial in queue.serials.duplicate():retire_pending(int(serial))
				queues.erase(key)
			continue
		if int(matched.objectType)!=5:
			for serial in queue.serials.duplicate():retire_pending(int(serial))
			queues.erase(key);continue
		queue.sourceBound=true
		var elapsed: Variant=queue_delta(queue,explicit_ms,nominal_delta)
		if elapsed==null:continue
		if int(queue.cooldown)>=1:queue.cooldown=i32(int(queue.cooldown)-int(elapsed))
		elif not queue.serials.is_empty():
			var serial:=int(queue.serials.pop_front())
			if entries.has(serial):entries[serial].status="active";entries[serial].sourceBound=true;active_entries[serial]=true;queue.cooldown=400;ensure_view(serial)
		if int(queue.cooldown)<1 and queue.serials.is_empty():queues.erase(key)
func _make_view() -> Control:return View.new()
func ensure_view(serial: int) -> void:
	if views.has(serial) or not entries.has(serial) or not entries[serial].bodyReady or not is_instance_valid(overlay):return
	var view: Control=pool.pop_back() if not pool.is_empty() else _make_view()
	if view.get_parent()==null:overlay.add_child(view);view.configure(art,fonts,resources)
	views[serial]=view;view.move_to_front();view.set_content(entries[serial].model)
	var entry: Dictionary=entries[serial];var paint: Dictionary=entry.get("lastPaint",{})
	if paint.get("witness")==entry.event.witness and paint.get("scope")==entry.event.scope:view.apply_frame(paint.point,float(paint.alpha))
func frame_advance(gui_delta: float,object_delta_ms: Variant=null) -> void:
	if closed or not is_finite(gui_delta) or gui_delta<0:return
	var current:=synchronize_scope()
	nominal_usec+=gui_delta*1000000.0;var now:=int(nominal_usec/1000.0);var nominal_delta:=now-nominal_ms;nominal_ms=now
	var revision: int=int(text.revision) if is_instance_valid(text) else -1
	if Scope.current_context(current) and revision!=text_revision:text_revision=revision;data_changed()
	# Native object manager activates FIFO widgets before globalGUI frame tick.
	if Scope.current_context(current):advance_queues(current,object_delta_ms,nominal_delta)
	for serial in active_entries.keys():
		var entry: Dictionary=entries[serial]
		if entry.status!="active":continue
		var next:=Frame.frame(float(entry.remaining),gui_delta)
		if next.get("destroy",false):
			release_view(int(serial));active_entries.erase(serial)
			if not entry.bodyReady and entry.showChat:entry.status="log-only"
			else:entries.erase(serial)
			continue
		if not next.get("ready",false):continue
		var matched:=Scope.received_source(entry.event,source(int(entry.target)),current,true) if accepts_scope(entry,current) else {"ready":false}
		if matched.get("mismatch",false) or matched.get("retired",false):entry.orphan=true
		if not entry.orphan and matched.get("ready",false) and anchor_reader.is_valid():
			var anchor: Variant=anchor_reader.call(int(entry.target),entry.event.witness,entry.event.scope,float(next.height))
			if anchor is Dictionary and anchor.get("ready",false) and anchor.get("screen") is Vector2 and (anchor.get("viewportHeight") is int or anchor.get("viewportHeight") is float):
				var screen:=Frame.screen_down(anchor.screen,float(anchor.viewportHeight))
				if screen.get("ready",false) and current.get("enabled",true):
					entry.lastPaint={"point":screen.point,"alpha":float(next.alpha),"witness":entry.event.witness.duplicate(),"scope":entry.event.scope.duplicate()}
					if views.has(serial):views[serial].apply_frame(screen.point,float(next.alpha))
		entry.remaining=next.remaining
	for view in views.values():view.prepare_colors()
	update_processing()
func _process(delta: float) -> void:
	var began:=Timing.begin();var elapsed:=preload("res://systems/native_data/gui_clock_delta.gd").read(gui_delta_reader,delta)
	if elapsed.ready:frame_advance(elapsed.seconds)
	Timing.finish("callback_script_floating",began)
func release_view(serial: int) -> void:
	if not views.has(serial):return
	var view: Control=views[serial];views.erase(serial)
	if is_instance_valid(view):view.release();pool.append(view)
func discard(serial: int) -> void:
	release_view(serial);entries.erase(serial);active_entries.erase(serial)
	for queue in queues.values():queue.serials.erase(serial)
func retire_pending(serial: int) -> void:
	if not entries.has(serial):return
	if entries[serial].showChat and not entries[serial].bodyReady:
		entries[serial].status="log-only"
		for queue in queues.values():queue.serials.erase(serial)
	else:discard(serial)
func update_processing() -> void:
	var runnable:=not active_entries.is_empty();var current:=current_context()
	if not runnable and Scope.current_context(current):
		for queue in queues.values():
			if queue.scope==[current.connection,current.generation,current.areaId] and Scope.received_source(queue.event,source(int(queue.id)),current,true).get("ready",false):runnable=true;break
	set_process(not closed and automatic and runnable)
func reset() -> void:
	for serial in views.keys():release_view(int(serial))
	entries.clear();active_entries.clear();queues.clear();pending_echo.clear();receipt_sequence=0;receipt_connection=-1;scope=[];last_serial=-1;text_revision=-1;nominal_usec=0.0;nominal_ms=0;update_processing()
func warn_once(reason: String) -> void:
	if not diagnostics.has(reason) and diagnostics.size()<32:diagnostics.append(reason)
func close() -> void:
	if closed:return
	reset();closed=true;set_process(false)
	for view in pool:
		if is_instance_valid(view):view.close();view.queue_free()
	pool.clear()
	if is_instance_valid(resources):resources.close()
	context_reader=Callable();source_reader=Callable();anchor_reader=Callable();object_delta_ms_reader=Callable();gui_delta_reader=Callable();text=null;fonts=null;art=null;overlay=null
func _exit_tree() -> void:close()
