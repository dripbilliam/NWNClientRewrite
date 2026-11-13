extends "res://tests/native_conversation_ui_test.gd"
# Keeps every existing asset-backed/input assertion. Adds cold ownership/resource
# readback and long-dialog scaled captures without physical pointer/focus calls.
var observed_ui
var asset_pins: Array=[]
func window_state() -> Dictionary:
	return {"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"screens":DisplayServer.get_screen_count(),"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse_mode":Input.get_mouse_mode()}
func run() -> void:
	var window:=window_state()
	check(window.screen==2 and window.screen!=window.primary and window.unfocusable and not window.focused and window.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Isolated visual window starts secondary/unfocusable without mouse capture")
	print("NATIVE_PARITY_CONVERSATION_ART_START ",JSON.stringify(window))
	if not failures.is_empty():quit(1);return
	await super.run()
func receive(ui,message: Dictionary) -> void:
	observed_ui=ui
	await super.receive(ui,message)
func hash_resource(catalog,name: String,type: int) -> void:
	var bytes: PackedByteArray=catalog.get_resource(name,type)
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
	asset_pins.append({"name":name,"type":type,"bytes":bytes.size(),"sha256":digest.finish().hex_encode(),"error":catalog.failure})
func collect_resources(ui) -> void:
	if not asset_pins.is_empty():return
	for name in DialogPlan.RESOURCES:hash_resource(ui.catalog,name,2002)
	hash_resource(ui.catalog,"fnt_default",2074)
	hash_resource(ui.catalog,"fnt_galahad14",2022)
	for name in ["fnt_galahad14","gui_boxes_dialog",str(ui.conversation_skin.speaker_signature[2])]:
		var raster: Dictionary=ui.catalog.raster_location(name)
		if not raster.is_empty():hash_resource(ui.catalog,name,int(raster.type))
	check(asset_pins.all(func(row):return row.error.is_empty() and row.bytes>0),"Actual original dialogue/font/portrait asset bytes are pinned read-only")
func capture_state(output: String,suffix: String) -> void:
	var ui=observed_ui;var skin=ui.conversation_skin;var dialog=ui.conversation
	collect_resources(ui)
	var rows: Array=[]
	for button in dialog.replies.get_children():
		var label: RichTextLabel=button.get_child(0)
		rows.append({"button":str(button.get_global_rect()),"label":str(label.get_global_rect()),"content_height":label.get_content_height(),"minimum_height":button.custom_minimum_size.y,"disabled":button.disabled})
	var snapshot:={"suffix":suffix,"window":window_state(),"dialog":str(dialog.get_global_rect()),"portrait":str(skin.portrait.get_global_rect()),"ui_scale":str(ui.controls.scale),"body":str(dialog.body.get_global_rect()),"body_content_height":dialog.body.get_content_height(),"rows":rows,"skin":skin.snapshot(),"resources":asset_pins,"performanceClaim":false,"physicalInputWarped":false,"serverConnections":0}
	var file:=FileAccess.open(output.trim_suffix(".json")+suffix+".state.json",FileAccess.WRITE);file.store_string(JSON.stringify(snapshot,"  ")+"\n");file.close()
func shot(output: String,suffix: String) -> void:
	await super.shot(output,suffix)
	capture_state(output,suffix)
	if suffix!="-long":return
	var ui=observed_ui;var skin=ui.conversation_skin;var dialog=ui.conversation
	var original_scale: Vector2=ui.controls.scale
	for scale_value in [1.25,2.0]:
		ui.controls.scale=Vector2.ONE*scale_value
		for index in 4:await process_frame
		check(await wait_until(func():return dialog_settled(ui)),"Long dialogue native fonts/art/scrollbars settle at"+str(scale_value))
		for index in 4:await process_frame
		check(Rect2(Vector2.ZERO,Vector2(surface.size)).grow(0.01).encloses(dialog.get_global_rect()),"Long dialogue stays inside actual viewport at"+str(scale_value))
		check(skin.portrait.texture!=null and skin.portrait.size==Vector2(64,100) and skin.entry_bar_host.visible and skin.reply_bar_host.visible,"Scaled long dialogue retains portrait and both original scroll owners")
		var scaled_suffix:="-long-"+str(int(scale_value*100))
		await super.shot(output,scaled_suffix)
		capture_state(output,scaled_suffix)
	ui.controls.scale=original_scale
	for index in 4:await process_frame
	check(await wait_until(func():return dialog_settled(ui)),"Native long-dialogue artwork settles after restoring the original scale")
