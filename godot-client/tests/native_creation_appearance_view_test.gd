extends SceneTree
const Pane=preload("res://systems/native_appearance_chooser.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Information=preload("res://systems/native_character_info_chooser.gd")
class Fonts extends Node:
	signal loaded(name:String)
	var metrics:Dictionary={}
	var fonts:Dictionary={}
	func bind(target:Control,_name:String)->void:target.set_meta("native_font_applied",true)
	func close()->void:pass
class Art extends Node:
	signal loaded(key:String,texture:Texture2D,bounds:Dictionary)
	const models=preload("res://systems/native_item_icons.gd")
	var bounds:Dictionary={}
	var textures:Dictionary={}
	var failed:Dictionary={}
	func bind(_target:Object,_resource:String,_property:String="texture",_model:bool=false,_clip:String="up",_portrait:bool=false,_overrides:Dictionary={},_region:Rect2=Rect2())->void:pass
	func unbind(_target:Object,_property:String="texture")->void:pass
	func request_model(resource:String,clip:String="up",overrides:Dictionary={},turn:int=0,layer:String="",poses:Array=[],region:Rect2=Rect2())->String:return models.model_key(resource,clip,overrides,turn,layer,poses,region)
var checks:=0
var failures:Array=[]
var surface:SubViewport
var timings:Array=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:run.call_deferred()
func frames(count:int=2)->void:
	for index in count:await process_frame
func pointer(position:Vector2,pressed:bool)->void:
	var motion:=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;surface.push_input(motion,true);await process_frame
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position;event.global_position=position;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await process_frame
func click(control:Control)->void:
	var point:Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	await pointer(point,true);await pointer(point,false);await frames()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original installed catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions are available")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=Fonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Pane.new();surface.add_child(pane);pane.configure(painter,text,catalog,"")
	var parts:Array=[];parts.resize(19);parts.fill(1);var skin:Dictionary=Pane.State.tattoo_parts(0,parts)
	var context:={"appearanceValid":true,"modelType":"P","customizeMode":0,"enabledPhenotypes":5,"headIndexComplete":true,"heads":{1:true,2:true,3:true},"paletteSizes":{"skin":176,"hair":176,"tattoo1":176,"tattoo2":176},"clothing":[{"id":3,"resRef":"first","bodyParts":parts.duplicate(),"colors":[1,2,3,4,5,6]},{"id":9,"resRef":"second","bodyParts":parts.duplicate(),"colors":[7,8,9,10,11,12]}],"value":{"phenotype":0,"head":1,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"tattooPattern":0,"bodyParts":parts.duplicate(),"skinParts":skin.skinParts,"clothes":3,"clothingIndex":0}}
	var results:Array=[];var previews:Array=[];var attachments:Array=[]
	pane.finished.connect(func(accepted,value,ticket):results.append([accepted,value,ticket]))
	pane.preview_changed.connect(func(value,ticket):previews.append([value,ticket]))
	pane.preview_attached.connect(func(slot,ticket):attachments.append([slot,ticket]))
	pane.set_context(context,["draft",1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Real installed CG_APPEARANCE and attachment MDLs prepare: "+pane.failure)
	if pane.layout_ready:
		await frames(4)
		check(pane.buttons.size()==14 and pane.size.distance_to(Vector2(742,526))<.01,"Original source frame and12 programmatic controls retain their dimensions")
		check(pane.preview_slot.size.distance_to(Vector2(347,406))<.01 and attachments.size()==1 and attachments[0][1]==["draft",1],"Native model hooks expose the actual private preview viewport without stretching surrounding artwork")
		check(pane.plan.controls.head_left.rect.size==Vector2(32,32) and pane.plan.boards.skin.rect.size==Vector2(256,176),"Original arrows and16-by11 color board bounds are retained")
		await click(pane.buttons.body_right);check(pane.state.value.phenotype==2 and context.value.phenotype==0,"Physical Body arrow changes the staged value with active mask, leaving owner draft untouched")
		await click(pane.buttons.head_left);check(pane.state.value.head==3,"Physical Head Previous uses original contiguous resource wrap")
		await click(pane.buttons.tattoo_right);check(pane.state.value.tattooPattern==1 and pane.state.value.bodyParts[7]==2,"Physical Tattoo arrow updates eligible skin parts")
		await click(pane.buttons.clothes_right);check(pane.state.value.clothes==9 and pane.state.value.materialColors==[7,8,9,10,11,12] and pane.state.value.bodyParts[7]==2,"Physical Clothing arrow copies actual variation colors while retaining current tattoo skin part")
		await click(pane.buttons.skin);check(pane.palette_kind=="skin" and is_instance_valid(pane.palette),"Physical color button opens source color board")
		if is_instance_valid(pane.palette):
			var point:Vector2=pane.palette.get_global_transform_with_canvas()*Vector2(40,24);await pointer(point,true);await pointer(point,false);await frames()
		check(pane.state.value.skin==18 and not is_instance_valid(pane.palette),"Physical color cell maps to row-major BYTE index and closes board")
		check(previews.size()==6 and previews[-1][0].skin==18 and previews[-1][1]==["draft",1],"Each staged input publishes one detached preview at its current ticket")
		previews[-1][0].head=400;check(pane.state.value.head==3,"Preview consumer cannot mutate live staged state")
		await click(pane.buttons.hair)
		if is_instance_valid(pane.palette):
			var begin:Vector2=pane.palette.get_global_transform_with_canvas()*Vector2(8,8);var end:Vector2=pane.palette.get_global_transform_with_canvas()*Vector2(88,40);await pointer(begin,true);await pointer(end,false);await frames()
		check(pane.state.value.hair==37 and not is_instance_valid(pane.palette),"Original mouse capture accepts a release in a different palette cell")
		await click(pane.buttons.hair)
		if is_instance_valid(pane.palette):
			var end:Vector2=pane.palette.get_global_transform_with_canvas()*Vector2(-40,-40);await pointer(end,true);await pointer(end,false);await frames()
		check(pane.state.value.hair==37 and not is_instance_valid(pane.palette),"Out-of-range captured release closes the board without editing a color")
		await click(pane.buttons.okbutton);check(results.size()==1 and results[0][0] and results[0][1].head==3 and results[0][2]==["draft",1] and not pane.wanted,"Physical OK returns one scoped transaction")
		pane.set_context(context,["draft",2]);pane.open();await frames();await click(pane.buttons.head_right);await click(pane.buttons.cancelbutton);check(results.size()==2 and not results[1][0] and context.value.head==1,"Physical Cancel cannot commit private choices")
		pane.set_context(context,["draft",3]);pane.open();await frames();var button:Button=pane.buttons.head_right;var point:Vector2=button.get_global_transform_with_canvas()*(button.size*.5);await pointer(point,true);pane.set_context(context,["draft",4]);await pointer(point,false);check(pane.state.value.head==1,"Held arrow cannot edit a replacement draft")
		context.customizeMode=1;pane.set_context(context,["draft",5]);check(pane.buttons.clothes_left.disabled and not pane.buttons.head_left.disabled,"Existing-character mode disables only Clothing controls")
		context.modelType="S";pane.set_context(context,["draft",6]);check(pane.plan.controls.keys().all(func(tag):return pane.buttons[tag].disabled),"Original non-P model disables every unsupported appearance control")
		context.modelType="P";context.customizeMode=0;pane.set_context(context,["draft",7]);pane.open();await frames()
		for index in 100:
			var began:=Time.get_ticks_usec();pane.capture("body_right");pane.invoke("body_right");timings.append(Time.get_ticks_usec()-began)
		check(previews[-1][1]==["draft",7] and context.value.phenotype==0,"Repeated current-owner input remains isolated and scoped")
		var before:=previews.size();pane.capture("head_right");pane.dismiss();pane.invoke("head_right");check(previews.size()==before,"Dismissal invalidates late button callbacks")
	var plan_summary:Dictionary={"size":[pane.size.x,pane.size.y],"previewSize":[pane.preview_slot.size.x,pane.preview_slot.size.y] if is_instance_valid(pane.preview_slot) else [],"buttons":pane.buttons.keys()}
	pane.close();pane.free();painter.free();surface.queue_free();await frames(4)
	timings.sort();var timing:Dictionary={} if timings.is_empty() else {"count":timings.size(),"medianUs":timings[timings.size()/2],"p95Us":timings[int(timings.size()*.95)],"maxUs":timings[-1]}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timing":timing,"layout":plan_summary,"gpu":false,"serverConnections":0,"sourceArtworkDouble":true,"scope":"Actual installed GUI/MDL source placement and Godot input into private Appearance transaction. Choices are authored detached provider data; no creator commit, rendered preview pixels, source generated swatches, BIC or server acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
