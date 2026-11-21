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
var jui_jobs: Dictionary={}
var image_jobs: Dictionary={}
var resource_serial:=0
var serial:=0
var installed:=false
var closed:=false
var diagnostics: Array=[]
func configure(owner) -> void:
	ui=owner; view=preload("res://systems/server_nui.gd").new(); add_child(view); view.setup(owner.layer); view.request.connect(input)
	ui.assets.completed.connect(resource_prepared)
	projector.text_lookup=func(ref):return ui.text.resolve({"strRef":ref},ui.controlled_id)
	projector.image_lookup=image_id; ui.desktop.art.loaded.connect(image_ready)
func receive(message: Dictionary) -> void:
	if closed: return
	if not state.receive(message) and not state.failure.is_empty(): diagnostics.append(state.failure)
	if message.kind=="nui-create" and int(message.get("format",1))==0 and state.windows.has(int(message.token)):
		var id: int=ui.assets.request(str(message.resref),2083,"bytes"); jui_jobs[id]={"token":int(message.token),"serial":int(state.windows[int(message.token)].serial)}
func resource_prepared(id: int,result: Dictionary) -> void:
	if closed or not jui_jobs.has(id): return
	var job: Dictionary=jui_jobs[id]; jui_jobs.erase(id)
	if not state.windows.has(int(job.token)) or int(state.windows[int(job.token)].serial)!=int(job.serial): return
	if not str(result.error).is_empty(): diagnostics.append(str(result.error)); return
	var layout: Variant=JSON.parse_string(result.bytes.get_string_from_utf8())
	if not layout is Dictionary or not layout.has("root"): diagnostics.append("Invalid native JUI layout"); return
	state.version+=1; state.windows[int(job.token)].layout=layout; state.windows[int(job.token)].ready=true; state.windows[int(job.token)].version=state.version
func _process(_delta: float) -> void:
	if closed or not ui.tables_ready: return
	if not installed:
		installed=ui.skin_owner.install_nui(view)
		if not installed: return
	for token in records.keys():
		if not state.windows.has(token) or int(state.windows[token].serial)!=int(records[token].serial): view.receive({"kind":"nui-remove","windowId":records[token].id}); records.erase(token)
	for token in state.windows:
		var window: Dictionary=state.windows[token]
		if not window.ready: continue
		if not records.has(token): serial+=1; records[token]={"id":serial,"token":token,"serial":window.serial,"version":-1,"controls":{},"ranges":{},"acks":{},"opened":false,"dirty":true}
		var record: Dictionary=records[token]
		if int(record.version)==int(window.version) and not record.dirty: continue
		var result:=projector.project(window,record); record.dirty=false
		if result.is_empty(): diagnostics.append(projector.failure); record.version=window.version; continue
		view.receive(result.frame)
		view.receive({"kind":"nui-nodes","windowId":record.id,"version":window.version,"nodes":result.nodes})
		view.receive({"kind":"nui-commit","windowId":record.id,"version":window.version})
func image_id(name: Variant,region: Variant) -> int:
	if not name is String or name.is_empty() or name=="****": return -1
	var rectangle: Variant=null
	if region is Dictionary and State.number(region.get("w"))>0 and State.number(region.get("h"))>0:
		rectangle={}
		for key in ["x","y","w","h"]: rectangle[key]=int(State.number(region.get(key)))&65535
	var key:=str(name).to_lower()+":"+JSON.stringify(rectangle)
	if image_ids.has(key): return int(image_ids[key])
	for id in view.resources: resource_serial=maxi(resource_serial,int(id))
	resource_serial+=1; image_ids[key]=resource_serial; image_jobs[key]={"id":resource_serial,"name":str(name).to_lower(),"region":rectangle}
	if ui.desktop.art.textures.has(str(name).to_lower()): image_ready(str(name).to_lower(),ui.desktop.art.textures[str(name).to_lower()],{})
	else:
		# Start a native archive raster job. The temporary TextureRect is kept
		# until publication by the owner, never attached to the visible tree.
		var holder:=TextureRect.new(); add_child(holder); holder.hide(); image_jobs[key].holder=holder; ui.desktop.art.bind(holder,str(name))
	return resource_serial
func image_ready(name: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for key in image_jobs.keys():
		var job: Dictionary=image_jobs[key]
		if str(job.name)!=name: continue
		# NWN raster rows need the same Y flip used by the other native GUI.
		var image:=texture.get_image(); image.flip_y(); var native: Texture2D=ImageTexture.create_from_image(image)
		if job.region is Dictionary:
			var atlas:=AtlasTexture.new(); atlas.atlas=native; atlas.region=Rect2(job.region.x,job.region.y,job.region.w,job.region.h); native=atlas
		view.resources[int(job.id)]=native; view.resources_dirty=true
		if job.has("holder"): job.holder.queue_free()
		image_jobs.erase(key)
func send_input(record: Dictionary,events: Array=[],binds: Array=[]) -> void:
	request.emit({"kind":"native-nui-input","token":int(record.token),"serial":int(record.serial),"events":events,"binds":binds})
func bind(record: Dictionary,window: Dictionary,source: Variant,value: Variant,index: int=-1) -> void:
	if not State.is_bind(source) or State.equal(State.value(window,source,index),value): return
	var whole:=false
	if index>=0:
		var before: Variant=window.bindings.get(source.bind)
		if not before is Array or index>=before.size(): return
		var next: Array=before.duplicate(true); next[index]=value; value=next; whole=true
	state.local_bind(int(record.token),str(source.bind),value)
	send_input(record,[],[{"bind":source.bind,"value":value,"index":index,"wholeValue":whole}])
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
		if not State.strict_false(State.at(window,window.layout,"closable")): send_input(record,[{"type":"close","element":"_window_","index":-1,"payload":null}]); state.receive({"kind":"nui-destroy","token":record.token})
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
func snapshot() -> Dictionary: return {"windows":records.size(),"native_only":true,"view":view.statistics.duplicate(true),"pending_images":image_jobs.size(),"pending_jui":jui_jobs.size(),"diagnostics":diagnostics.duplicate()}
func close() -> void:
	if closed: return
	closed=true; jui_jobs.clear(); state.clear(); records.clear(); image_jobs.clear(); image_ids.clear(); view.reset()
func _exit_tree() -> void: close()
