extends SceneTree
# Isolated producer attribution: engine font atlases only; no game/UI/assets.
var checks:=0
var failures: Array=[]
var report:=""
var scenario:="live"
var fonts: Array[FontFile]=[]
var atlases: Array=[]
var canvas:=RID()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func inspect(font: FontFile,size: Vector2i) -> void:
	for at in font.get_texture_count(0,size):
		var image:=font.get_texture_image(0,size,at)
		check(image!=null and not image.is_empty(),"Main-thread atlas is valid after glyph upload")
		if image!=null:
			atlases.append({"id":image.get_instance_id(),"font":font.get_instance_id(),"size":str(size),"atlas":at,"width":image.get_width(),"height":image.get_height(),"bytes":image.get_data_size(),"format":image.get_format()})
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--scenario="):scenario=arg.substr(11)
	check(DisplayServer.get_name()!="headless","Real Separate-thread renderer required")
	check(root.current_screen==1 and root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Nonprimary screen1, no activation or pointer capture")
	if report.is_empty() or not failures.is_empty():quit(2);return
	var bytes:=FileAccess.get_file_as_bytes("C:/Windows/Fonts/arial.ttf")
	check(bytes.size()>1000,"Original installed Arial bytes available")
	canvas=RenderingServer.canvas_item_create();RenderingServer.canvas_item_set_parent(canvas,root.get_world_2d().canvas)
	print("ATLAS_PHASE ",scenario," begin")
	var alphabet:="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,!?;:-_[]()"
	for cycle in 4:
		for index in 6:
			var size:=Vector2i(14+index*3,0)
			var font:=FontFile.new();font.data=bytes;font.generate_mipmaps=false;font.allow_system_fallback=false;font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
			fonts.append(font)
			if scenario=="precache":font.render_range(0,size,32,126)
			for character in alphabet.length():
				font.draw_char(canvas,Vector2(15+(character%30)*16,40+index*45),alphabet.unicode_at(character),size.x,Color.WHITE)
			inspect(font,size)
		await process_frame
	for at in 3:await process_frame
	await RenderingServer.frame_post_draw
	print("ATLAS_PHASE ",scenario," complete")
	RenderingServer.free_rid(canvas);fonts.clear()
	for at in 3:await process_frame
	var out:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scenario":scenario,"atlases":atlases,"font_source":"C:/Windows/Fonts/arial.ttf","game_ui_loaded":false,"network_connections":0,"native_builds":0,"performance_claim":false}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(out,"\t"));file.close()
	print("ATLAS_PROBE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
