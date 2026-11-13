extends SceneTree
# Deferred graphical correctness fixture. Full actual Gameplay/desktop window
# stack, original resources and real Window UI scaling. No network or input.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Settings=preload("res://systems/native_window_settings.gd")
const Text=preload("res://systems/server_text.gd")
var checks:=0
var failures: Array=[]
var states: Array=[]
var output:=""
var ui
var reference_layer: CanvasLayer
var reference_pose: Node2D
var reference: RichTextLabel
var rich: Dictionary={}
var retained_extension: Resource
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func wait_until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+45000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func settled() -> bool:
	var skin=ui.conversation_skin
	return skin.layout_ready and skin.failure.is_empty() and skin.background!=null and skin.background.visible and ui.inventory.frame_skin.fonts.fonts.has(skin.Plan.FONT) and ui.inventory.frame_skin.fonts.fonts.has("fnt_galahad14") and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active
func grab() -> Image:
	for at in 5:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func make_reference() -> void:
	if is_instance_valid(reference_layer):reference_layer.free()
	reference_layer=CanvasLayer.new();reference_layer.layer=100;root.add_child(reference_layer)
	reference_pose=Node2D.new();reference_layer.add_child(reference_pose)
	reference=RichTextLabel.new();reference_pose.add_child(reference);Text.style(reference);reference.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var body: RichTextLabel=ui.conversation.body
	reference.theme=body.theme
	for key in ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]:reference.add_theme_font_override(key,body.get_theme_font(key))
	for key in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]:reference.add_theme_font_size_override(key,body.get_theme_font_size(key))
	for key in ["outline_size","shadow_offset_x","shadow_offset_y","line_separation"]:reference.add_theme_constant_override(key,body.get_theme_constant(key))
	for key in ["default_color","font_outline_color","font_shadow_color"]:reference.add_theme_color_override(key,body.get_theme_color(key))
	if body.has_meta("native_text_color"):reference.set_meta("native_text_color",body.get_meta("native_text_color"))
	reference.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;reference.fit_content=true;reference.scroll_active=false
	reference.custom_minimum_size=Vector2(ui.conversation_skin.entry_scroll.size.x,0);reference.size=Vector2(ui.conversation_skin.entry_scroll.size.x,body.get_content_height())
	reference_pose.transform=body.get_global_transform_with_canvas()
	Text.set_text(reference,rich);reference_layer.hide()
func difference(a: Color,b: Color) -> float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func comparison(actual: Image,baseline: Image,expected: Image,rect: Rect2i,transform: Transform2D) -> Dictionary:
	var mask: Array=[];var line_expected: Dictionary={};var line_found: Dictionary={};var count:=0;var found:=0
	var inverse:=transform.affine_inverse()
	var line_height:=float(reference.get_content_height())/maxi(1,reference.get_line_count())
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if difference(expected.get_pixel(x,y),baseline.get_pixel(x,y))<0.18:continue
			count+=1;var local: Vector2=inverse*Vector2(x+0.5,y+0.5);var line:=clampi(floori(local.y/maxf(1,line_height)),0,reference.get_line_count()-1)
			line_expected[line]=int(line_expected.get(line,0))+1
			var present:=false
			for dy in range(-1,2):
				for dx in range(-1,2):
					var at:=Vector2i(x+dx,y+dy)
					if Rect2i(Vector2i.ZERO,actual.get_size()).has_point(at) and difference(actual.get_pixelv(at),baseline.get_pixelv(at))>=0.09:present=true
			if present:found+=1;line_found[line]=int(line_found.get(line,0))+1
			mask.append({"point":local,"present":present})
	var words: Array=[];var expression:=RegEx.new();expression.compile("[A-Za-z0-9]+")
	var text:=reference.get_parsed_text();var font: Font=reference.get_theme_font("normal_font");var font_size:=reference.get_theme_font_size("normal_font_size")
	for word_match in expression.search_all(text):
		var start: int=word_match.get_start();var line:=reference.get_character_line(start);var line_start:=start
		while line_start>0 and reference.get_character_line(line_start-1)==line:line_start-=1
		var x0:=font.get_string_size(text.substr(line_start,start-line_start),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var x1:=font.get_string_size(text.substr(line_start,word_match.get_end()-line_start),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var bounds:=Rect2(x0-1,line*line_height-1,maxf(1,x1-x0)+2,line_height+2);var total:=0;var seen:=0
		for pixel in mask:
			if bounds.has_point(pixel.point):total+=1;seen+=int(pixel.present)
		words.append({"word":word_match.get_string(),"line":line,"expected_pixels":total,"covered_pixels":seen,"ratio":float(seen)/maxi(1,total)})
	var lines: Array=[]
	for line in line_expected:lines.append({"line":line,"expected_pixels":line_expected[line],"covered_pixels":line_found.get(line,0),"ratio":float(line_found.get(line,0))/maxi(1,int(line_expected[line]))})
	return {"expected_pixels":count,"covered_pixels":found,"ratio":float(found)/maxi(1,count),"lines":lines,"words":words}
func inspect(tag: String,visible_only: bool=false) -> void:
	print("DIALOGUE_PIXEL_PHASE ",tag," begin")
	var skin=ui.conversation_skin;var dialog=ui.conversation;var body: RichTextLabel=dialog.body
	check(await wait_until(settled),"Actual original conversation art/font owners settle for"+tag)
	for at in 5:await process_frame
	rich=dialog.entry_rich.duplicate(true)
	skin.set_process(false);make_reference()
	var actual:=await grab()
	var previous:=body.self_modulate;body.self_modulate=Color(previous.r,previous.g,previous.b,0)
	var baseline:=await grab()
	reference_layer.show();var expected:=await grab()
	reference_layer.hide();body.self_modulate=previous
	check(actual!=null and baseline!=null and expected!=null and not actual.is_empty() and actual.get_size()==expected.get_size(),"Actual and reference screen readbacks are valid for"+tag)
	if actual==null or baseline==null or expected==null:return
	var transform: Transform2D=root.get_final_transform()*body.get_global_transform_with_canvas()
	var raw: Rect2=transform*Rect2(Vector2.ZERO,Vector2(skin.entry_scroll.size.x,reference.get_content_height()))
	var rect:=Rect2i(Vector2i(floori(raw.position.x)-4,floori(raw.position.y)-4),Vector2i(ceili(raw.size.x)+8,ceili(raw.size.y)+8)).intersection(Rect2i(Vector2i.ZERO,actual.get_size()))
	# Overflow is intentionally clipped by the actual ScrollContainer. Compare
	# its visible, interior glyph pixels at BOTH scroll endpoints, rather than
	# treating the hidden off-screen lines as a lost-text regression.
	if visible_only:
		var viewport_transform: Transform2D=root.get_final_transform()*skin.entry_scroll.get_global_transform_with_canvas()
		var visible: Rect2=viewport_transform*Rect2(Vector2.ZERO,skin.entry_scroll.size)
		var interior:=Rect2i(Vector2i(ceili(visible.position.x)+1,ceili(visible.position.y)+1),Vector2i(floori(visible.end.x)-ceili(visible.position.x)-2,floori(visible.end.y)-ceili(visible.position.y)-2))
		rect=rect.intersection(interior)
	var coverage:=comparison(actual,baseline,expected,rect,transform)
	check(int(coverage.expected_pixels)>100,"Reference contains actual original-font glyph pixels for"+tag)
	check(float(coverage.ratio)>=0.97,"NPC glyph pixels survive actual desktop/clipping stack for"+tag)
	for line in coverage.lines:check(float(line.ratio)>=0.95,"NPC line"+str(line.line)+" retains glyph pixel coverage for"+tag)
	for word in coverage.words:
		if int(word.expected_pixels)>=4:check(float(word.ratio)>=0.90,"NPC word '"+str(word.word)+"' is actually visible for"+tag)
	var layer_state: Dictionary=ui.window_layers.roots.get(dialog.get_instance_id(),{})
	states.append({"tag":tag,"body":str(body.get_global_rect()),"entry":str(skin.entry_scroll.get_global_rect()),"body_canvas":str(body.get_global_transform_with_canvas()),"window_transform":str(root.get_final_transform()),"body_actual_size":str(body.size),"entry_size":str(skin.entry_scroll.size),"body_font":body.get_meta("native_font_applied",""),"line_count":body.get_line_count(),"body_content_height":body.get_content_height(),"scroll_y":skin.entry_scroll.scroll_vertical,"visible_only":visible_only,"portrait_resource":skin.speaker_signature[2],"coverage_rect":str(rect),"coverage":coverage,"window_mask_signature":str(layer_state.get("signature",[])),"window_layers":ui.window_layers.snapshot(),"skin":skin.snapshot()})
	actual.save_png(output.trim_suffix(".json")+"-"+tag+"-actual.png");baseline.save_png(output.trim_suffix(".json")+"-"+tag+"-baseline.png");expected.save_png(output.trim_suffix(".json")+"-"+tag+"-reference.png")
	skin.set_process(true)
	print("DIALOGUE_PIXEL_PHASE ",tag," complete")
func run() -> void:
	var install:="";var cache_path:="";var override_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
		elif arg.begins_with("--override="):override_path=arg.substr(11)
	if output.is_empty() or install.is_empty() or cache_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(DisplayServer.get_name()!="headless","This deferred pixel fixture requires a real graphics renderer")
	check(root.current_screen==2 and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Graphical test starts on secondary2 without activation or pointer capture")
	if not failures.is_empty():quit(1);return
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Matched existing native library is actually loaded")
	root.size=Vector2i(3440,1369)
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Original installed resources mount read-only")
	if not override_path.is_empty():check(catalog.mount_directory(override_path,10000000),"Actual native-session profile override precedence is mounted")
	print("DIALOGUE_PIXEL_PHASE configure")
	ui=Gameplay.new();root.add_child(ui);ui.configure(catalog,install,cache_path,output+".layout.cfg")
	check(await wait_until(func():return ui.tables_ready),"Actual Gameplay desktop rules/font owner prepares")
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Listener"},"portrait":0,"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]}},"playerState":{}}
	var speaker:=actor.duplicate(true);speaker.id=43;speaker.replicated.name={"text":"Gondolier"};ui.set_world(1,55,42,[actor,speaker],{},{"area":{"id":55}})
	ui.conversation.position=Vector2(20,35)
	rich={"text":"Save you a walk? For 5 gold I can get you to the docks in no time."}
	ui.receive({"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":rich},1)
	ui.receive({"kind":"dialog-replies","entryId":51,"end":false,"firstCount":2,"secondCount":0,"tokenObjectId":43,"replies":[{"id":91,"text":{"text":"Yes, take me there."}},{"id":92,"text":{"text":"No, thank you."}}]},1)
	rich=ui.conversation.entry_rich.duplicate(true)
	var window_settings:=Settings.new();root.add_child(window_settings);window_settings.window=root;window_settings.unconstrained=true
	# Use the production deferred resize seam. The earlier scale-only fixture
	# assigned its Window but did not connect size_changed, so its first physical
	# resize retained the old3440x1369 content base and a letterboxed render target.
	root.size_changed.connect(window_settings.window_resized)
	for scale_value in [1.0,1.25,2.0]:
		check(window_settings.apply_scale(scale_value,false),"Actual Window UI scale applies")
		await inspect("window-"+str(int(scale_value*100)))
	window_settings.apply_scale(1.25,false)
	rich={"spans":[{"text":"A colored replacement ","color":"#66B3FF"},{"text":"retains every middle word after the speaker changes this entry.","color":"#FFFFFF"}]}
	# Same actual conversation ownership method after host rich-text projection.
	ui.conversation.present({"kind":"dialog-entry","speakerId":43,"rich":rich})
	ui.conversation.present({"kind":"dialog-replies","entryId":52,"replies":[{"id":93,"available":true,"rich":{"text":"A fresh offered reply"}}]})
	await inspect("replacement-125")
	# An unknown speaker supplies neither an object nor portrait. The production
	# frame must choose its original fallback; this is not a fake portrait port.
	rich={"spans":[{"text":"First explicit line is blue.\n","color":"#66B3FF"},{"text":"Second explicit line preserves the middle words.\nThird line ends here.","color":"#FFFFFF"}]}
	ui.conversation.present({"kind":"dialog-entry","speakerId":999,"rich":rich})
	ui.conversation.present({"kind":"dialog-replies","entryId":53,"replies":[{"id":94,"available":true,"rich":{"text":"Continue after the multiline entry."}}]})
	await inspect("multiline-no-portrait-125")
	check(ui.conversation_skin.speaker_signature[2]=="po_hu_m_99_m","Absent speaker/portrait uses the production fallback resource")
	check(ui.conversation.body.get_parsed_text().count("\n")==2 and ui.conversation.body.get_line_count()>=3,"Explicit newlines survive received-style rich spans")
	# Actual Window resize exercises the containing desktop and NativeWindowLayers,
	# rather than manually setting the RichTextLabel width.
	root.size=Vector2i(640,480)
	await inspect("resized-640x480-125")
	check(window_settings.resize_updates>0 and root.content_scale_size==root.size,"Physical resize settles through the production deferred Window settings callback")
	var visible_dialog: Rect2=root.get_final_transform()*ui.conversation.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,ui.conversation.size)
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(visible_dialog),"Authored wide override panel fits the resized physical viewport")
	root.size=Vector2i(3440,1369)
	window_settings.apply_scale(1.0,false)
	rich={"text":""}
	for line in 36:rich.text+=("First" if line==0 else "Last" if line==35 else "Middle")+" scrolling line "+str(line+1)+" keeps every requested word.\n"
	ui.conversation.present({"kind":"dialog-entry","speakerId":43,"rich":rich})
	ui.conversation.present({"kind":"dialog-replies","entryId":54,"replies":[{"id":95,"available":true,"rich":{"text":"The reply remains reachable after this long entry."}}]})
	check(await wait_until(settled),"Long entry actual art/font owners settle")
	for at in 8:await process_frame
	var entry: ScrollContainer=ui.conversation_skin.entry_scroll
	check(ui.conversation.body.get_content_height()>entry.size.y and ui.conversation_skin.entry_bar_host.visible,"Long NPC text uses the native overflow rail")
	entry.scroll_vertical=0
	await inspect("overflow-first-100",true)
	check(ui.conversation.body.get_character_line(0)==0 and entry.scroll_vertical==0,"The first long-entry line is reachable at the top")
	entry.scroll_vertical=int(entry.get_v_scroll_bar().max_value)
	await inspect("overflow-last-100",true)
	check(entry.scroll_vertical>0 and entry.scroll_vertical+entry.size.y>=ui.conversation.body.get_content_height()-1,"The last long-entry line is reachable at the bottom")
	print("DIALOGUE_PIXEL_PHASE teardown")
	window_settings.close();window_settings.free();reference_layer.free();ui.close();ui.free();await process_frame;await process_frame
	print("DIALOGUE_PIXEL_PHASE teardown-complete")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"states":states,"serverConnections":0,"nativeBuilds":0,"physicalInput":false,"fpsClaim":false,"fixtureTextAuthored":true,"scope":"Actual full native Gameplay desktop, original models/fonts, NativeWindowLayers and Window canvas-items scales; pixel-difference glyph/word coverage against unconstrained same-font reference, no original-client/server dialogue provenance claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("NATIVE_PARITY_CONVERSATION_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
