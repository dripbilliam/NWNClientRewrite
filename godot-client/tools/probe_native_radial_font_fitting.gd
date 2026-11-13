extends SceneTree
# Read-only follow-up evidence; no radial/menu production edits or GPU/world.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const PixelFont=preload("res://systems/native_data/ttf_pixel_height.gd")
const Native=preload("res://systems/native_data/nameplate_text.gd")
const Radial=preload("res://systems/native_data/radial_text.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(args.install): quit(2); return
	var text:=Talk.new()
	if not text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")): quit(2); return
	var parser:=Table.new(); var spells:=parser.parse(catalog.get_resource("spells",2017).get_string_from_utf8())
	if not parser.failure.is_empty(): text.close(); quit(2); return
	var strings: Array=[]; var seen: Dictionary={}
	for index in spells.orderedRows.size():
		var row: Dictionary=spells.orderedRows[index]; var cell:=str(row.get("Name",""))
		if not cell.is_valid_int() or int(cell)<0: continue
		var caption:=text.raw({"strRef":int(cell)})
		if caption.length()<6 or seen.has(caption): continue
		seen[caption]=true; strings.append({"source":"installed spells.2da/TLK","row":index,"strRef":int(cell),"text":caption})
		if strings.size()>=240: break
	for caption in ["An unusually long descriptive special ability caption","Long_unbroken_ability_caption_without_any_spaces_at_all","First line\nSecond line\nThird line","word  double spaces at a boundary end","AVAVAVAVAV AVAVAVAVAV AVAVAVAVAV"]: strings.append({"source":"synthetic fitting edge case","text":caption})
	var bytes:=catalog.get_resource("fnt_default",2074); var ordinary:=FontFile.new(); ordinary.data=bytes; ordinary.allow_system_fallback=false
	var adapted:=PixelFont.make(bytes,14)
	if not adapted.success: text.close(); quit(2); return
	var results: Array=[]
	for mode in ["ordinary default","explicit native pixel-height opt-in"]:
		var font: FontFile=ordinary if mode=="ordinary default" else adapted.font; var different: Array=[]; var elapsed_old:=0; var elapsed_native:=0
		for entry in strings:
			var begin:=Time.get_ticks_usec(); var current:=Radial.choose(font,14,str(entry.text)); elapsed_old+=Time.get_ticks_usec()-begin
			begin=Time.get_ticks_usec(); var metrics:=Native.font_metrics(font,14,str(entry.text)); var source:=Native.choose(str(entry.text),metrics,font.get_height(14),1,0.0); elapsed_native+=Time.get_ticks_usec()-begin
			if str(current[2])!=str(source.bubble[2]):
				var widths: Array=[]
				for line in source.layout.lines: widths.append(font.get_string_size(str(line),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)
				var row: Dictionary=entry.duplicate(true); row.current_bubble=current; row.original_policy_bubble=source.bubble; row.original_policy_lines=source.layout.lines; row.actual_shaped_line_widths=widths; different.append(row)
		results.append({"font_mode":mode,"logical_font_height":font.get_height(14),"captions":strings.size(),"bubble_mismatches":different.size(),"mismatches":different,"current_total_ms":elapsed_old/1000.0,"original_policy_total_ms":elapsed_native/1000.0})
	text.close()
	var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify({"results":results,"headless":true,"gpu":false,"serverConnections":0,"productionChanged":false,"radialFilesEdited":false,"ordinaryDefaultsChanged":false,"sourceAssetsExported":false,"scope":"Same actual installed font and source spell/TLK captions compare current Godot multiline bubble selection against the already verified original policy. No action/input/pixel/world acceptance or implementation."},"  ")+"\n"); output.close(); quit(0)
