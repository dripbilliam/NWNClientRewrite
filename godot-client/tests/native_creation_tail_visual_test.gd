extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Appearance=preload("res://systems/native_appearance_chooser.gd")
const Information=preload("res://systems/native_character_info_chooser.gd")
const Builder=preload("res://systems/native_menu_builder.gd")
const Ink=preload("res://tests/native_font_ink_probe.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures:Array=[]
var surface:SubViewport
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.set_flag(Window.FLAG_BORDERLESS,true);root.position=Vector2i(-32000,-32000);run.call_deferred()
func outside_screens()->bool:
	var rectangle:=Rect2i(root.position,root.size)
	for index in DisplayServer.get_screen_count():
		if rectangle.intersects(Rect2i(DisplayServer.screen_get_position(index),DisplayServer.screen_get_size(index))):return false
	return true
func frames(count:int=2)->void:
	for index in count:await process_frame;RenderingServer.force_draw(false,0.0)
func capture()->Image:
	await frames(3);return surface.get_texture().get_image()
func pointer(point:Vector2,pressed:bool)->void:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await frames(1)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await frames(1)
func click(control:Control)->void:
	var point:Vector2=control.get_global_transform_with_canvas()*(control.size*.5);await pointer(point,true);await pointer(point,false);await frames()
func leave_pointer()->void:
	var event:=InputEventMouseMotion.new();event.position=Vector2(-20,-20);event.global_position=event.position;surface.push_input(event,true);await frames()
func ready(pane:Control,painter,limit:int=18000)->bool:
	var end:=Time.get_ticks_msec()+limit
	while Time.get_ticks_msec()<end:
		await frames(1)
		if not pane.failure.is_empty():return false
		if pane is Information and not pane.deity.layout_ready:continue
		if pane.layout_ready and Builder.source_ready(pane,painter) and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.art.jobs.is_empty():return true
	return false
func pixels_changed(a:Image,b:Image,rect:Rect2i)->int:
	var count:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var first:Color=a.get_pixel(x,y);var second:Color=b.get_pixel(x,y)
			if maxf(absf(first.r-second.r),maxf(absf(first.g-second.g),maxf(absf(first.b-second.b),absf(first.a-second.a))))>.02:count+=1
	return count
func run()->void:
	await process_frame;root.position=Vector2i(-32000,-32000);await process_frame
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.get_flag(Window.FLAG_BORDERLESS) and outside_screens(),"Owned actual-art window remains off every screen and cannot activate")
	if not failures.is_empty():
		var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":false,"checks":checks,"failures":failures,"gpuRaster":false}));file.close();quit(1);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed GUI resources mount read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual source captions load")
	surface=SubViewport.new();surface.size=Vector2i(850,650);surface.transparent_bg=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,"")
	var pane:=Appearance.new();surface.add_child(pane);pane.position=Vector2(35,35);pane.configure(painter,text,catalog,"")
	var parts:Array=[];parts.resize(19);parts.fill(1);var skin:Dictionary=Appearance.State.tattoo_parts(0,parts)
	var context:Dictionary={"appearanceValid":true,"modelType":"P","customizeMode":0,"enabledPhenotypes":5,"headIndexComplete":true,"heads":{1:true,2:true},"paletteSizes":{"skin":176,"hair":176,"tattoo1":176,"tattoo2":176},"clothing":[{"id":3,"resRef":"first","bodyParts":parts.duplicate(),"colors":[1,2,3,4,5,6]}],"value":{"phenotype":0,"head":1,"skin":1,"hair":40,"tattoo1":90,"tattoo2":110,"tattooPattern":0,"bodyParts":parts.duplicate(),"skinParts":skin.skinParts,"clothes":3,"clothingIndex":0}}
	pane.set_context(context,["raster",1]);pane.open();pane.start()
	check(await ready(pane,painter),"Appearance publishes original models/fonts and all selected palette swatch styles: "+pane.failure)
	var diagnostic:Dictionary={"swatches":{},"artist":{},"activeRowChangedPixels":0}
	if pane.layout_ready:
		for kind in ["skin","hair","tattoo1","tattoo2"]:
			var geometry:Dictionary=painter.button_geometry[pane.buttons[kind].get_instance_id()];var descriptor:Dictionary=geometry.overrides.get("gui_replace01",{})
			check(descriptor.resource=="gui_cg_color_tmp" and descriptor.palette==[int(context.value[kind])|((0 if kind=="skin" else 1 if kind=="hair" else 6)<<8)],"Actual rendered button uses exact original packed palette selector: "+kind)
			check(geometry.styles.normal[0].texture!=null and not painter.art.failed.has(painter.art.models.model_key(geometry.resource,"up",geometry.overrides)),"Actual color style renders without a missing placeholder: "+kind)
			diagnostic.swatches[kind]={"rect":pane.buttons[kind].get_rect(),"selector":descriptor.palette[0],"textureSha256":Cache.digest(geometry.styles.normal[0].texture.get_image().get_data()) if geometry.styles.normal[0].texture!=null else ""}
		await leave_pointer();var initial:Image=await capture();initial.save_png(str(args.report)+".appearance.png")
		await click(pane.buttons.skin);await frames(3)
		check(is_instance_valid(pane.palette) and await ready(pane,painter),"Physical source swatch opens a fully rendered native color board")
		if is_instance_valid(pane.palette):
			check(pane.palette.get_index()>pane.preview_slot.get_index(),"Native color board paints above the preview and parent controls")
			var board:Image=await capture();board.save_png(str(args.report)+".palette.png")
			var point:Vector2=pane.palette.get_global_transform_with_canvas()*Vector2(40,24);await pointer(point,true);await pointer(point,false)
		check(pane.state.value.skin==18 and not is_instance_valid(pane.palette) and await ready(pane,painter),"Captured physical board release updates selected native swatch and closes its child")
		await leave_pointer();var changed:Image=await capture();changed.save_png(str(args.report)+".selected.png")
		var swatch_rect:=Rect2i(pane.position+pane.buttons.skin.position,pane.buttons.skin.size)
		var changed_pixels:int=pixels_changed(initial,changed,swatch_rect);diagnostic.selectedChangedPixels=changed_pixels
		check(changed_pixels>32,"Actual installed button pixels change with the selected palette row")
		var row:=PackedByteArray();row.resize(1024)
		for pixel in 256:row[pixel*4]=15;row[pixel*4+1]=240;row[pixel*4+2]=30;row[pixel*4+3]=255
		var active:Dictionary=context.duplicate(true);active.value.skin=18;active.paletteRows={18:row};active.paletteSourceHashes={18:Cache.digest("authored-active-row".to_utf8_buffer())}
		# Supply every selected active row explicitly; no base fallback may fill
		# a declared but absent selector, even though those installed bytes exist.
		for pair in [["hair",0x100],["tattoo1",0x600],["tattoo2",0x600]]:
			var selector:int=int(active.value[pair[0]])|int(pair[1]);active.paletteRows[selector]=row;active.paletteSourceHashes[selector]=active.paletteSourceHashes[18]
		pane.set_context(active,["raster",2]);check(await ready(pane,painter),"Authored active-row fixture renders through the same original GUI model")
		await leave_pointer();var active_image:Image=await capture();active_image.save_png(str(args.report)+".active-row.png")
		diagnostic.activeRowChangedPixels=pixels_changed(changed,active_image,swatch_rect)
		check(diagnostic.activeRowChangedPixels>32,"Declared active palette row changes actual pixels instead of selecting the installed base palette")
		active.paletteRows.erase(18);pane.set_context(active,["raster",3]);await frames(3)
		var unavailable:Dictionary=painter.button_geometry[pane.buttons.skin.get_instance_id()]
		check(pane.snapshot().swatchesUnavailable.has("skin") and unavailable.styles.normal[0].texture==null,"Missing declared active row stays explicitly unavailable and retires old rendered pixels")
		check(context.value.skin==1 and not context.has("paletteRows"),"Swatch input and rendering cannot mutate the supplied draft/context")
	pane.dismiss()
	var info:=Information.new();surface.add_child(info);info.position=Vector2(35,35);info.configure(painter,text,catalog,"")
	info.set_context({"value":{"firstName":"Native","lastName":"Source","ageText":"25","description":"Biography from the current private draft.","deity":"Original deity","soundset":40},"voices":[{"id":40,"name":"Current active voice","resRef":"voice_source"}],"randomReady":false},["raster",4]);info.open();info.start()
	check(await ready(info,painter) and info.deity.layout_ready,"Information and Deity publish actual original artwork/fonts: "+info.failure)
	if info.layout_ready and info.deity.layout_ready:
		var voice:Dictionary=info.rows[0];var voice_label:Label=voice.label;var voice_source:=Rect2(info.plan.voice_row.hooks.text0-info.plan.voice_row.bounds.position,info.plan.voice_row.hooks.text1-info.plan.voice_row.hooks.text0).abs();var voice_ink:Dictionary=Ink.glyph_ink(voice_label)
		check(voice_source.encloses(voice_label.get_rect()),"Actual voice label uses native text0/text1 bounds instead of the full animated button")
		check(voice_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"Actual voice name retains original8ecc60 horizontal alignment0")
		check(voice_ink.present and voice_source.grow(1).encloses(voice_ink.rect) and absf(voice_ink.rect.position.x-voice_source.position.x)<=3,"Installed voice-name glyph ink starts at the native left attachment without covering the frame/scrollbar")
		diagnostic.voiceCaption={"id":voice.id,"rect":voice_label.get_rect(),"sourceRect":voice_source,"ink":voice_ink,"alignment":voice_label.horizontal_alignment,"font":str(voice_label.get_meta("native_font_resource",""))}
		await leave_pointer();var information:Image=await capture();information.save_png(str(args.report)+".information.png")
		await click(info.buttons.deitybutton);await frames();check(await ready(info,painter),"Actual GenericEdit child publishes above the Information screen")
		var deity:Image=await capture();deity.save_png(str(args.report)+".deity.png")
		var child_rect:=Rect2i(info.position+info.deity.position,info.deity.size);check(pixels_changed(information,deity,child_rect)>100,"Actual nested Deity modal visibly covers its parent content")
		var message:Label=info.deity.message;var message_ink:Dictionary=Ink.glyph_ink(message);var source_rect:Rect2=info.deity.plan.entries.messagelabel.rect
		check(Rect2(Vector2.ZERO,info.deity.size).encloses(message.get_rect()),"Actual GenericEdit message rectangle is fully inside its source popup")
		check(message.get_line_count()==1 and message_ink.present,"Installed Deity prompt shapes as one real-font line instead of vertical letters")
		check(source_rect.grow(1).encloses(message_ink.rect),"Actual installed prompt glyph ink remains within its original claimed MessageLabel rectangle")
		diagnostic.deityMessage={"text":message.text,"rect":message.get_rect(),"sourceRect":source_rect,"ink":message_ink,"lines":message.get_line_count()}
	diagnostic.artist=painter.art.models.snapshot();diagnostic.fonts=painter.fonts.snapshot();diagnostic.artFailures=painter.art.failed.keys()
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.get_flag(Window.FLAG_BORDERLESS) and outside_screens(),"Owned raster remains isolated through completion")
	pane.close();pane.free();info.close();info.free();painter.close();painter.free();text.close();surface.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(Ink.packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostic,"gpuRaster":true,"gpuBenchmark":false,"serverConnections":0,"scope":"Bounded offscreen/no-focus installed tail GUI/font/swatch and nested child raster. Authored active-row fixture verifies palette provenance; no 3D preview, audible output, original-client pixel or gameplay acceptance."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
