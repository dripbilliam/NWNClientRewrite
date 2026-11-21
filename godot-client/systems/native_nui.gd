extends Node
# Connection-owned native layout, binding, resource and input projection.
# The host transports decoded protocol values and encodes typed requests only.
signal request(message: Dictionary)
const State=preload("res://systems/native_data/nui_state.gd")
const Projector=preload("res://systems/native_data/nui_projector.gd")
var state:=State.new()
var projector:=Projector.new()
var ui
var view
var records: Dictionary={}
var image_ids: Dictionary={}
var image_jobs: Dictionary={}
var serial:=0
var installed:=false
var closed:=false
var text_revision:=-1
var diagnostics: Array=[]
var skin_started_us:=0
var skin_reported:=false
var skin_failure_reported:=false
var input_queues: Dictionary={}
var input_active: Dictionary={}
var input_request_keys: Dictionary={}
var input_request_serial:=0
func report_diagnostic(code: String,message: String,context: Dictionary={}) -> void:
	diagnostics.append({"code":code,"message":message,"context":context.duplicate(true)})
	if not is_instance_valid(ui):return
	var scene: SceneTree=ui.get_tree()
	if scene==null:return
	for property in scene.get_property_list():
		if str(property.get("name",""))!="direct_diagnostics":continue
		var journal: Variant=scene.get("direct_diagnostics")
		if journal is RefCounted and journal.has_method("record"):journal.record(code,message,context)
		return
func configure(owner) -> void:
	ui=owner; view=preload("res://systems/server_nui.gd").new(); add_child(view); view.setup(owner.layer); view.request.connect(input)
	projector.interaction_lookup=func(window_id,control_id):
		var current_window: Variant=view.windows.get(window_id) if is_instance_valid(view) else null
		if current_window==null:return {}
		var current_element: Variant=current_window.nodes.get(control_id)
		return {"hover":bool(current_element.hovered),"button":int(current_element.pointer_button)} if is_instance_valid(current_element) else {}
	projector.text_lookup=func(ref):
		var resolved: String=ui.text.resolve({"strRef":ref},ui.controlled_id)
		if not ui.text.network_last_error.is_empty():report_diagnostic("network.nui-text-failed",str(ui.text.network_last_error),{})
		return resolved
	projector.image_lookup=image_id; ui.desktop.art.loaded.connect(image_ready); ui.desktop.art.image_failed.connect(image_failed)
func receive(message: Dictionary) -> void:
	if closed: return
	if not state.receive(message) and not state.failure.is_empty(): diagnostics.append(state.failure)
func _process(_delta: float) -> void:
	if closed or not ui.tables_ready: return
	if text_revision!=int(ui.text.revision):
		text_revision=int(ui.text.revision)
		for record in records.values(): record.dirty=true
	if not installed and not skin_failure_reported:
		if skin_started_us==0:skin_started_us=Time.get_ticks_usec()
		installed=ui.skin_owner.install_nui(view)
		if not installed:
			if not skin_failure_reported and ui.skin_owner.done and not ui.skin_owner.stats.errors.is_empty():
				skin_failure_reported=true
				report_diagnostic("network.nui-skin-failed",str(ui.skin_owner.stats.errors[0].get("reason","NUI skin unavailable")),{})
			# Old NetworkNuiView.sync keeps its windows usable without a skin.
	if not skin_reported and view.skin_ready():
		skin_reported=true
		report_diagnostic("network.nui-skin-ready","Active native NUI skin prepared",{"durationMs":(Time.get_ticks_usec()-skin_started_us)/1000.0,"fonts":view.fonts.size(),"textures":view.images.size()})
	for token in records.keys():
		if not state.windows.has(token) or int(state.windows[token].serial)!=int(records[token].serial):
			view.receive({"kind":"nui-remove","windowId":records[token].id})
			retire_input_queue(str(token)+":"+str(records[token].serial))
			records.erase(token)
	for token in state.windows:
		var window: Dictionary=state.windows[token]
		if not window.ready: continue
		var created:=not records.has(token)
		if created: serial+=1; records[token]={"id":serial,"token":token,"serial":window.serial,"version":-1,"controls":{},"ranges":{},"acks":{},"opened":false,"dirty":true}
		var record: Dictionary=records[token]
		if int(record.version)==int(window.version) and not record.dirty: continue
		var started_us:=Time.get_ticks_usec()
		var result:=projector.project(window,record); record.dirty=false
		if result.is_empty():
			report_diagnostic("network.nui-render-failed",str(projector.failure),{"token":token})
			record.version=window.version; continue
		view.receive(result.frame)
		view.receive({"kind":"nui-nodes","windowId":record.id,"version":window.version,"nodes":result.nodes})
		view.receive({"kind":"nui-commit","windowId":record.id,"version":window.version})
		if record.get("closing",false) and view.windows.has(int(record.id)):view.windows[int(record.id)].hide()
		var duration_ms:=(Time.get_ticks_usec()-started_us)/1000.0
		if created:
			report_diagnostic("network.nui-window-built","NUI window DOM ready",{"token":token,"nodes":result.nodes.size(),"buildMs":duration_ms})
			call_deferred("report_paint_opportunity",int(token),int(record.serial),started_us)
		elif duration_ms>25.0:report_diagnostic("network.nui-update-slow","NUI binding/layout update exceeded25ms",{"token":token,"nodes":result.nodes.size(),"durationMs":duration_ms})
		if int(record.get("metadataVersion",-1))!=int(window.version):
			record.metadataVersion=int(window.version)
			var metadata:=layout_metadata(window,record,result.frame,result.nodes)
			var key:=JSON.stringify(metadata)
			if key!=str(record.get("metadataKey","")):
				record.metadataKey=key
				report_diagnostic("network.nui-layout-metadata","Bounded NUI geometry and image metadata",metadata)
func report_paint_opportunity(token: int,window_serial: int,started_us: int) -> void:
	await get_tree().process_frame
	if closed or not records.has(token) or not state.windows.has(token):return
	if int(records[token].serial)!=window_serial or int(state.windows[token].serial)!=window_serial:return
	report_diagnostic("network.nui-window-paint","NUI window reached a paint opportunity",{"token":token,"sinceBuildMs":(Time.get_ticks_usec()-started_us)/1000.0})
func metadata_type(value: Variant) -> String:
	if State.missing(value): return "undefined"
	if value==null: return "object"
	if value is bool: return "boolean"
	if value is int or value is float: return "number"
	if value is String: return "string"
	return "object"
func metadata_pixels(value: Variant) -> String:
	if State.missing(value): return ""
	var number:=State.number(value,NAN)
	if not is_finite(number) or number<0: return ""
	return str(int(number) if number==floor(number) else number)+"px"
func layout_metadata(window: Dictionary,record: Dictionary,frame: Dictionary,nodes: Array) -> Dictionary:
	var layout: Dictionary=window.layout
	var title: Variant=State.at(window,layout,"title")
	var metadata:={"token":int(record.token),"titleType":metadata_type(title),"titleEmpty":title is String and title.is_empty(),"headerHidden":not bool(frame.header),"closable":null,"collapsed":null,"transparent":null,"border":null,"nodes":nodes.size(),"images":[]}
	for key in ["closable","collapsed","transparent","border"]:
		var value: Variant=State.at(window,layout,key)
		metadata[key]=value if value is bool else null
	var incoming_geometry: Variant=State.at(window,layout,"geometry")
	var geometry: Variant=record.get("geometry")
	if geometry is Dictionary and (incoming_geometry is Dictionary or not geometry.is_empty()):
		metadata.geometry={}
		for key in ["x","y","w","h"]: metadata.geometry[key]=State.number(geometry.get(key,State.UNDEFINED))
	elif not State.missing(incoming_geometry): metadata.geometry=incoming_geometry
	var by_id: Dictionary={}
	for spec in nodes: by_id[int(spec.controlId)]=spec
	var stack: Array=[]
	if by_id.has(int(frame.rootId)): stack.append({"id":int(frame.rootId),"done":false})
	var valid_resref:=RegEx.create_from_string("^[A-Za-z0-9_]{1,32}$")
	while not stack.is_empty() and metadata.images.size()<32:
		var entry: Dictionary=stack.pop_back(); var spec: Dictionary=by_id.get(int(entry.id),{})
		if spec.is_empty(): continue
		if not entry.done:
			stack.append({"id":entry.id,"done":true})
			for child in range(spec.children.size()-1,-1,-1): stack.append({"id":int(spec.children[child]),"done":false})
			continue
		if str(spec.type) not in ["image","button_image"]: continue
		var control: Dictionary=record.controls.get(int(spec.controlId),{})
		if control.is_empty(): continue
		var element: Dictionary=control.element; var index:=int(control.index)
		var source: Variant=State.at(window,element,"value" if str(spec.type)=="image" else "label",index)
		var region: Variant=State.at(window,element,"image_region",index)
		var image:={"resref":source if source is String and valid_resref.search(source)!=null else null,"width":metadata_pixels(State.at(window,element,"width",index)),"height":metadata_pixels(State.at(window,element,"height",index))}
		if not State.missing(region):
			if State.truth(region):
				image.region={}
				for key in ["x","y","w","h"]: image.region[key]=State.number(region.get(key,State.UNDEFINED) if region is Dictionary else State.UNDEFINED)
			else: image.region=region
		metadata.images.append(image)
	return metadata
func image_id(name: Variant,region: Variant) -> int:
	if not name is String or name.is_empty() or name=="****": return -1
	var rectangle: Variant=null
	if region is Dictionary and State.number(region.get("w"))>0 and State.number(region.get("h"))>0:
		rectangle={}
		for key in ["x","y","w","h"]: rectangle[key]=int(State.number(region.get(key)))&65535
	var key:=str(name).to_lower()+":"+JSON.stringify(rectangle)
	if image_ids.has(key): return int(image_ids[key])
	var resource_id: int=view.reserve_resource_id()
	image_ids[key]=resource_id; image_jobs[key]={"id":resource_id,"name":str(name).to_lower(),"region":rectangle}
	if ui.desktop.art.textures.has(str(name).to_lower()): image_ready(str(name).to_lower(),ui.desktop.art.textures[str(name).to_lower()],{})
	else:
		# Start a native archive raster job. The temporary TextureRect is kept
		# until publication by the owner, never attached to the visible tree.
		var holder:=TextureRect.new(); add_child(holder); holder.hide(); image_jobs[key].holder=holder
		ui.desktop.art.retry_failed_raster(str(name)); ui.desktop.art.bind(holder,str(name))
	return resource_id
func image_failed(name: String,reason: String) -> void:
	if closed: return
	for key in image_jobs.keys():
		var job: Dictionary=image_jobs[key]
		if str(job.name)!=name: continue
		if job.has("holder"): job.holder.queue_free()
		image_jobs.erase(key); image_ids.erase(key)
		diagnostics.append({"code":"network.nui-image-failed","message":reason,"context":{"resref":name}})
func image_ready(name: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for key in image_jobs.keys():
		var job: Dictionary=image_jobs[key]
		if str(job.name)!=name: continue
		# NWN raster rows need the same Y flip used by the other native GUI.
		var image:=texture.get_image(); image.flip_y(); image.convert(Image.FORMAT_RGBA8)
		if job.region is Dictionary:
			# The old canvas kept the requested uint16-sized rectangle and left
			# source pixels outside the image transparent. AtlasTexture samples
			# outside its atlas instead, so copy only the intersecting source area.
			var requested:=Rect2i(int(job.region.x),int(job.region.y),maxi(1,int(job.region.w)),maxi(1,int(job.region.h)))
			var clipped:=requested.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			var cropped:=Image.create_empty(requested.size.x,requested.size.y,false,Image.FORMAT_RGBA8)
			cropped.fill(Color.TRANSPARENT)
			if clipped.has_area():cropped.blit_rect(image,clipped,clipped.position-requested.position)
			image=cropped
		var native: Texture2D=ImageTexture.create_from_image(image)
		view.resources[int(job.id)]=native; view.resources_dirty=true
		if job.has("holder"): job.holder.queue_free()
		image_jobs.erase(key)
func send_input(record: Dictionary,events: Array=[],binds: Array=[]) -> void:
	if closed:return
	var key:=str(record.token)+":"+str(record.serial)
	var queue: Array=input_queues.get(key,[])
	queue.append({"token":int(record.token),"serial":int(record.serial),"events":events.duplicate(true),"binds":binds.duplicate(true)})
	input_queues[key]=queue
	dispatch_input_queue(key)
func dispatch_input_queue(key: String) -> void:
	if closed or input_active.has(key):return
	var queue: Array=input_queues.get(key,[])
	if queue.is_empty():input_queues.erase(key);return
	var job: Dictionary=queue[0]
	var token:=int(job.token)
	if not records.has(token) or not state.windows.has(token) or int(records[token].serial)!=int(job.serial) or int(state.windows[token].serial)!=int(job.serial):
		retire_input_queue(key);return
	input_request_serial+=1
	var request_id:=input_request_serial
	input_active[key]=request_id;input_request_keys[request_id]=key
	request.emit({"kind":"native-nui-input","token":token,"serial":int(job.serial),"events":job.events,"binds":job.binds,"nuiRequestId":request_id})
func retire_input_queue(key: String) -> void:
	if input_active.has(key):input_request_keys.erase(int(input_active[key]))
	input_active.erase(key);input_queues.erase(key)
func complete_input(request_id: int,outcome: Dictionary) -> void:
	if not input_request_keys.has(request_id):return
	var key: String=input_request_keys[request_id]
	input_request_keys.erase(request_id);input_active.erase(key)
	var queue: Array=input_queues.get(key,[])
	if queue.is_empty():input_queues.erase(key);return
	var job: Dictionary=queue.pop_front()
	input_queues[key]=queue
	var token:=int(job.token)
	var current:=not closed and records.has(token) and state.windows.has(token) and int(records[token].serial)==int(job.serial) and int(state.windows[token].serial)==int(job.serial)
	if current and outcome.has("error"):report_diagnostic("network.nui-input-failed",str(outcome.error),{"token":token})
	if current and job.events is Array and not job.events.is_empty() and str(job.events[0].get("type",""))=="close" and not outcome.has("error"):
		state.receive({"kind":"nui-destroy","token":token})
	if current and state.windows.has(token):dispatch_input_queue(key)
	else:retire_input_queue(key)
func bind(record: Dictionary,window: Dictionary,source: Variant,value: Variant,index: int=-1) -> void:
	if not State.is_bind(source) or State.equal(State.value(window,source,index),value): return
	if state.local_bind(int(record.token),str(source.bind),value,index).is_empty():return
	send_input(record,[],[{"bind":source.bind,"value":value,"index":index}])
func input(message: Dictionary) -> void:
	if closed: return
	var record: Dictionary={}
	for candidate in records.values():
		if int(candidate.id)==int(message.get("windowId",-1)): record=candidate; break
	if record.is_empty() or not state.windows.has(int(record.token)): return
	var window: Dictionary=state.windows[int(record.token)]
	if int(window.serial)!=int(record.serial): return
	var operation:=str(message.get("operation","")); var accepts:=not State.strict_false(State.at(window,window.layout,"accepts_input"))
	if operation=="open":
		if not record.opened: record.opened=true; send_input(record,[{"type":"open","element":"_window_","index":-1,"payload":null}])
		return
	if not accepts: return
	if operation=="close":
		if not State.strict_false(State.at(window,window.layout,"closable")) and not record.get("closing",false):
			record.closing=true
			if view.windows.has(int(record.id)):view.windows[int(record.id)].hide()
			send_input(record,[{"type":"close","element":"_window_","index":-1,"payload":null}])
		return
	if operation=="geometry":
		if message.get("resize",false) and State.strict_false(State.at(window,window.layout,"resizable")) or not message.get("geometry") is Dictionary: return
		for key in ["x","y","w","h"]:
			if not message.geometry.has(key) or not is_finite(State.number(message.geometry[key],NAN)): return
		if State.number(message.geometry.w)<80 or State.number(message.geometry.h)<30: return
		record.geometry=message.geometry.duplicate(true); record.dirty=true; bind(record,window,window.layout.get("geometry"),record.geometry); return
	if operation=="collapse":
		if State.strict_false(window.layout.get("collapsed")) or not message.get("value") is bool: return
		record.collapsed=message.value; record.dirty=true; bind(record,window,window.layout.get("collapsed"),message.value); return
	if record.get("structure",[])!=[window.layout,window.layouts]: return
	var control: Dictionary=record.controls.get(int(message.get("controlId",-1)),{})
	if control.is_empty(): return
	for ancestor in control.ancestors+[control]:
		if State.strict_false(State.at(window,ancestor.element,"enabled",int(ancestor.index))) or State.strict_false(State.at(window,ancestor.element,"visible",int(ancestor.index))): return
	var element: Dictionary=control.element; var index:=int(control.index); var kind:=str(element.type)
	if operation=="range":
		if kind!="list" or int(message.start)<0 or int(message.count)<1 or int(message.count)>4096: return
		record.ranges[str(control.path)]={"start":int(message.start),"count":int(message.count)}; record.dirty=true
	elif operation=="change":
		var value: Variant=message.get("value")
		match kind:
			"button_select","check":
				if not value is bool: return
			"combo","options","tabbar":
				var entries: Variant=State.at(window,element,"elements",index)
				if not entries is Array or not value is int and not value is float or int(value)<0 or int(value)>=entries.size(): return
				value=entries[int(value)][1] if entries[int(value)] is Array else int(value)
			"slider","sliderf":
				if not value is int and not value is float or not is_finite(float(value)) or value<State.number(State.at(window,element,"min",index)) or value>State.number(State.at(window,element,"max",index),100) or kind=="slider" and value!=floor(float(value)): return
			"textedit":
				if not value is String or value.length()>int(State.number(State.at(window,element,"max",index),1024)): return
				var revision:=int(message.get("inputRevision",0))
				if revision<int(record.acks.get(int(control.id),0)): return
				record.acks[int(control.id)]=revision; record.dirty=true
			"color_picker":
				if not value is Dictionary: return
				for key in ["r","g","b","a"]:
					if not value.has(key) or State.number(value[key],-1)<0 or State.number(value[key],256)>255: return
			_: return
		bind(record,window,element.get("value"),value,index)
	elif operation=="event":
		var event:=str(message.get("event",""))
		if event not in ["click","focus","blur","mousedown","mouseup","mousescroll"]: return
		var ancestors: Array=control.ancestors+[control]; ancestors.reverse()
		for ancestor in ancestors:
			if not ancestor.element.get("id") is String or str(ancestor.element.id).is_empty(): continue
			var payload: Variant={"mouse_pos":message.get("position"),"mouse_scroll":message.get("scroll")} if event=="mousescroll" else {"mouse_btn":message.get("button"),"mouse_pos":message.get("position")} if event in ["mousedown","mouseup"] else null
			send_input(record,[{"type":event,"element":ancestor.element.id,"index":int(ancestor.index),"payload":payload}]); break
func blocks_pointer(point: Vector2) -> bool: return view.blocks_pointer(point)
func snapshot() -> Dictionary: return {"windows":records.size(),"native_only":true,"view":view.statistics.duplicate(true),"pending_images":image_jobs.size(),"diagnostics":diagnostics.duplicate()}
func close() -> void:
	if closed: return
	closed=true; state.clear(); records.clear(); image_jobs.clear(); image_ids.clear(); input_queues.clear(); input_active.clear(); input_request_keys.clear(); view.reset()
func _exit_tree() -> void: close()
