extends Node
# Original panel geometry and authoritative examination/merchant context only.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/examine_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var owner_ui
var view
var frame
var assets
var jobs: Dictionary={}
var layouts: Dictionary={}
var models: Dictionary={}
var plans: Dictionary={}
var stages: Dictionary={}
var scrollbars: Dictionary={}
var identify_button: Button
var fee_label: RichTextLabel
var mode:=""
var scope: Array=[]
var icon_key:=""
var icon_target:=-1
var icon_revision:=-1
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var waiting: Dictionary={}
var retired_store:=-1
var art_pending:=false
var last_art_cohort: Dictionary={}
func configure(ui,catalog,cache_path: String) -> void:
	owner_ui=ui; view=ui.examine; view.native_skin=self; frame=ui.inventory.frame_skin; ui.inventory.examine_owner=self
	ui.inventory.icons.completed.connect(icon_ready)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	for name in ["examine_basic","examine_item"]:
		var id: int=assets.request(name,2047,"gff")
		if id<0:failure="Original examine GUI "+name+": "+str(assets.failure);return
		jobs[id]={"kind":"gui","name":name}
func _process(_delta: float) -> void:
	if not art_pending or closed:set_process(false);return
	var cohort: Dictionary=art_snapshot()
	last_art_cohort=cohort
	if cohort.ready:
		art_pending=false;set_process(false)
		if stages.has(mode):stages[mode].show()
		view.admit_ready()
	elif not cohort.failures.is_empty():
		art_pending=false;set_process(false)
		if stages.has(mode):stages[mode].hide()
		view.admit_failure(str(cohort.failures[0]))
func collect(root: Dictionary) -> void:
	if root.has("Obj_ResRef"): models[str(root.Obj_ResRef).to_lower()]={}
	for child in root.get("Obj_ChildList",[]): collect(child)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=str(result.error); return
	if job.kind=="gui":
		if result.value.get("type","")!="GUI ": failure="Invalid original examine GUI signature"; return
		layouts[job.name]=result.value.root
	else: models[job.name]=result.value
	if layouts.size()==2 and not requested:
		requested=true
		for root in layouts.values(): collect(root)
		for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]: models[name]={}
		for name in models:
			var requested_id: int=assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")
			if requested_id<0:failure="Original examine model "+name+": "+str(assets.failure);return
			jobs[requested_id]={"kind":"model","name":name}
	if not jobs.is_empty() or layouts.size()!=2 or not failure.is_empty(): return
	for key in ["basic","item"]:
		plans[key]=Plan.parse(layouts["examine_"+key],models,key=="item")
		if not str(plans[key].error).is_empty(): failure=str(plans[key].error); return
	layout_ready=true; build()
	if not view.state.is_empty():present(view.state);view.render_details(view.state);request_art_admission()
func build() -> void:
	view.window_column.hide(); view.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for key in plans:
		var plan: Dictionary=plans[key]; var stage:=Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; view.add_child(stage); stage.size=plan.size; stages[key]=stage; stage.hide()
		frame.image(plan.resource,Rect2(Vector2.ZERO,plan.size),stage)
		for tag in ["xbutton","closebutton"]:
			var button: Button=frame.create_button(plan.entries[tag],stage,models); button.pressed.connect(view.hide)
			if tag=="closebutton": frame.button_caption(button,owner_ui.text.raw({"strRef":int(plan.entries[tag].caption.Obj_StrRef)}))
		if key=="item":
			identify_button=frame.create_button(plan.entries.identifybutton,stage,models)
			frame.button_caption(identify_button,owner_ui.text.raw({"strRef":int(plan.entries.identifybutton.caption.Obj_StrRef)})); identify_button.pressed.connect(identify)
		var scrollbar:=preload("res://systems/native_scrollbar.gd").new(); stage.add_child(scrollbar); scrollbars[key]=scrollbar
		scrollbar.configure(frame,models,plan.entries.description,view.scroll,14)
	view.title_text.mouse_filter=Control.MOUSE_FILTER_STOP; view.title_text.gui_input.connect(view._title_input)
func current_scope() -> Array: return [owner_ui.generation,owner_ui.area_id,owner_ui.controlled_id]
func present(message: Dictionary) -> void:
	if closed or not layout_ready or message.get("close",false): return
	mode="item" if message.get("type","")=="item" else "basic"; var plan: Dictionary=plans[mode]; var stage: Control=stages[mode]
	for key in stages: stages[key].visible=key==mode
	scope=current_scope(); waiting.clear(); view.custom_minimum_size=plan.size; view.size=plan.size
	var name_rect: Rect2=plan.entries.name.rect; name_rect.size.x=maxf(name_rect.size.x,plan.entries.xbutton.rect.position.x-name_rect.position.x-8)
	frame.relocate(view.title_text,stage,name_rect); view.title_text.fit_content=false; view.title_text.scroll_active=false; view.title_text.add_theme_font_size_override("normal_font_size",14)
	frame.font_style(view.title_text,plan.entries.name.caption); Text.set_text(view.title_text,message.get("name",{"text":"Examine"}))
	var rect: Rect2=plan.entries.description.rect
	var old_body_parent: Node=view.body.get_parent()
	frame.relocate(view.scroll,stage,rect); view.scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER if scrollbars[mode].art_ready else ScrollContainer.SCROLL_MODE_SHOW_ALWAYS; view.scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	if view.body.get_parent()!=view.scroll: view.body.reparent(view.scroll,false)
	view.detail_width=rect.size.x; view.detail_font=14
	frame.relocate(view.portrait,stage,Rect2(plan.icon-Vector2(32,50),Vector2(64,100)))
	if old_body_parent!=view.scroll and old_body_parent.get_child_count()==0:
		old_body_parent.get_parent().remove_child(old_body_parent); old_body_parent.queue_free()
	view.portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; view.scroll.scroll_vertical=0
	icon_key=""; icon_target=int(message.targetId); icon_revision=int(message.revision)
	if mode=="item":
		var item: Dictionary=owner_ui.text.objects.get(icon_target,{}).get("item",{})
		if not item.is_empty():
			icon_key=owner_ui.inventory.icons.request(item,owner_ui.text.tables,int(owner_ui.text.objects.get(owner_ui.controlled_id,{}).get("appearance",{}).get("gender",0)))
			if owner_ui.inventory.icons.textures.has(icon_key): icon_ready(icon_key,owner_ui.inventory.icons.textures[icon_key],"")
	view._clamp(); sync()
func request_art_admission() -> void:
	if closed or view.state.is_empty():return
	art_pending=true;last_art_cohort={}
	if stages.has(mode):stages[mode].hide()
	set_process(true)
func cancel_art_admission() -> void:
	art_pending=false;last_art_cohort={};set_process(false)
	if stages.has(mode):stages[mode].hide()
func art_snapshot() -> Dictionary:
	var result:={"ready":false,"mode":mode,"pending":[],"failures":[],"images_expected":0,"images_ready":0,"fonts_expected":0,"fonts_ready":0}
	if not failure.is_empty():result.failures.append(failure)
	if not layout_ready:
		if result.failures.is_empty():result.pending.append("Original examine layout")
		return result
	if mode.is_empty() or not stages.has(mode):result.pending.append("Examine presentation");return result
	var stage: Control=stages[mode]
	for picture in stage.find_children("*","TextureRect",true,false):
		var key:=str(picture.get_meta("native_gui_art_key",""))
		if key.is_empty():continue
		result.images_expected+=1
		if picture.texture!=null and frame.art.textures.get(key)==picture.texture:result.images_ready+=1
		elif frame.art.failed.has(key):result.failures.append("Examine artwork "+key+": "+str(frame.art.failed[key]))
		else:result.pending.append("image:"+key)
	for button in stage.find_children("*","Button",true,false):
		var data: Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		if data.is_empty():continue
		for pair in data.styles.values():
			var key: String=frame.art.models.model_key(str(data.resource),str(pair[1]),data.overrides)
			result.images_expected+=1
			if pair[0].texture!=null and frame.art.textures.get(key)==pair[0].texture:result.images_ready+=1
			elif frame.art.failed.has(key):result.failures.append("Examine button "+key+": "+str(frame.art.failed[key]))
			else:result.pending.append("image:"+key)
	for control in stage.find_children("*","Control",true,false):
		var font: String=str(control.get_meta("native_font_resource",""))
		if font.is_empty():continue
		result.fonts_expected+=1
		if str(control.get_meta("native_font_applied",""))==font:result.fonts_ready+=1
		elif frame.fonts.failed.has(font):result.failures.append("Examine font "+font+": "+str(frame.fonts.failed[font]))
		else:result.pending.append("font:"+font)
	var bar=scrollbars[mode]
	if not str(bar.failure).is_empty():result.failures.append("Examine scrollbar: "+str(bar.failure))
	elif not bar.art_ready or bar.snapshot().thumb_pending or bar.snapshot().layout_pending:result.pending.append("Examine scrollbar")
	if mode=="item":
		var icons=owner_ui.inventory.icons
		if icon_key.is_empty():result.failures.append("Received item icon is unavailable: "+str(icons.last_request_error))
		elif icons.failed.has(icon_key):result.failures.append("Item icon "+icon_key+": "+str(icons.failed[icon_key]))
		else:
			result.images_expected+=1
			var resident: Dictionary=icons.catalog.ui_asset_owner().lookup("item",icon_key)
			if icons.textures.has(icon_key) and view.portrait.texture==icons.textures[icon_key] and not resident.is_empty() and resident.texture==view.portrait.texture:result.images_ready+=1
			else:result.pending.append("item-icon:"+icon_key)
	result.ready=result.failures.is_empty() and result.pending.is_empty()
	return result
func details_changed() -> void:
	if not layout_ready or closed: return
	fee_label=Text.label({},view.detail_width); fee_label.add_theme_font_size_override("normal_font_size",14); style_detail(fee_label); view.body.add_child(fee_label); sync()
func style_detail(label: RichTextLabel) -> void:
	if layout_ready and not mode.is_empty(): frame.font_style(label,plans[mode].entries.description.caption)
func context() -> Dictionary:
	var inv=owner_ui.inventory; var store: Dictionary=inv.store; var id:=int(view.state.get("targetId",-1)); var object: Dictionary=inv.objects.get(id,{})
	var location: Variant=object.get("inventoryLocation"); var owned: bool=location is Dictionary and int(location.get("ownerId",-1))==owner_ui.controlled_id and location.get("channel","") in ["R","I"]
	var item: bool=view.state.get("type","")=="item"; var price:=int(store.get("identifyPrice",-1)); var balance: int=inv.gold.balance()
	var identified: bool=view.state.get("identified",true) or object.get("item",{}).get("identified",false)
	return {"id":id,"open":store.get("open",false) and int(store.get("generation",-1))!=retired_store,"generation":int(store.get("generation",-1)),"price":price,"balance":balance,"identified":identified,"item":item,"owned":owned,"valid":scope==current_scope() and inv.ui.wanted and not object.get("replicationRemoved",false),"pending":inv.pending.has(id) or not waiting.is_empty()}
func sync() -> void:
	if closed or not layout_ready or mode.is_empty(): return
	if scope!=current_scope(): waiting.clear()
	if not waiting.is_empty() and int(waiting.store)!=int(owner_ui.inventory.store.get("generation",-1)): waiting.clear()
	if not waiting.is_empty() and not owner_ui.inventory.pending.has(int(waiting.id)): waiting.clear()
	var state:=context(); identify_button.visible=state.item and state.open
	identify_button.disabled=not state.valid or not state.owned or state.identified or state.price<0 or state.balance<state.price or state.pending
	if is_instance_valid(fee_label) and not fee_label.is_queued_for_deletion():
		fee_label.visible=state.item and state.open and not state.identified and state.price>=0
		if fee_label.visible:
			var value: String=owner_ui.text.resolve({"strRef":0x10c3d},owner_ui.controlled_id,{"localCustomTokens":{0:str(state.price)}})
			if state.balance<state.price: value+="\n<c"+String.chr(255)+String.chr(1)+String.chr(1)+">"+owner_ui.text.raw({"strRef":0x14b3b})+"</c>"
			Text.set_text(fee_label,Rich.parse(value))
func identify() -> void:
	sync()
	if identify_button.disabled or not identify_button.visible: return
	var state:=context(); var inv=owner_ui.inventory
	if not inv.views.has(int(state.id)): return
	waiting={"id":int(state.id),"revision":int(view.state.revision),"store":int(state.generation)}
	inv.store_command({"viewId":inv.view_serial,"operation":"identify","entryId":int(state.id)})
	if not inv.pending.has(int(state.id)): waiting.clear()
	sync()
func receive(message: Dictionary) -> void:
	if message.kind=="native-action-result" and message.get("action","")=="native-store" and not message.get("accepted",false): waiting.clear()
	if message.kind=="store-close": waiting.clear(); retired_store=int(owner_ui.inventory.store.get("generation",-1))
	sync()
func icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed or not layout_ready or mode!="item" or key!=icon_key or not error.is_empty() or texture==null: return
	if not view.set_native_portrait(texture,icon_target,icon_revision): return
	view.portrait.flip_v=false
	var bounds: Dictionary=owner_ui.inventory.icons.image_bounds.get(key,{})
	if bounds.has("min") and bounds.has("max"):
		view.portrait.position=plans.item.icon+Vector2(bounds.min[0],-float(bounds.max[1]))*100.0
		view.portrait.size=Vector2(float(bounds.max[0])-float(bounds.min[0]),float(bounds.max[1])-float(bounds.min[1]))*100.0
func snapshot() -> Dictionary:
	var bars: Dictionary={}
	for key in scrollbars: bars[key]=scrollbars[key].snapshot()
	return {"ready":layout_ready,"mode":mode,"failure":failure,"waiting":not waiting.is_empty(),"scrollbars":bars,"art_pending":art_pending,"art_cohort":last_art_cohort,"native_only":true,"full_examine_parity":false}
func close() -> void:
	if closed: return
	closed=true;art_pending=false;set_process(false);assets.close(); view.native_skin=null; owner_ui.inventory.examine_owner=null
	for scrollbar in scrollbars.values(): scrollbar.close()
	if owner_ui.inventory.icons.completed.is_connected(icon_ready): owner_ui.inventory.icons.completed.disconnect(icon_ready)
	jobs.clear(); models.clear(); layouts.clear(); waiting.clear()
func _exit_tree() -> void: close()
