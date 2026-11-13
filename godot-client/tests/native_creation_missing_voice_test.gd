extends "res://tests/native_creation_character_info_view_test.gd"
const VoiceProvider=preload("res://systems/native_data/creation_tail_provider.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original Information art catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original Information captions remain available")
	text.overrides={1000:"Unselectable",1001:"Active TYPE2 voice",1002:"Active second voice"}
	var tables: Dictionary={"packages":{"columns":["Soundset"],"orderedRows":[{"Soundset":"****"}],"orderedCells":[["****"]],"defaultValue":"****"},"soundset":{"columns":["RESREF","TYPE","GENDER","STRREF"],"orderedRows":[{"RESREF":"skip","TYPE":"1","GENDER":"1","STRREF":"1000"},{"RESREF":"first","TYPE":"2","GENDER":"1","STRREF":"1001"},{"RESREF":"second","TYPE":"0","GENDER":"1","STRREF":"1002"}],"orderedCells":[["skip","1","1","1000"],["first","2","1","1001"],["second","0","1","1002"]]}}
	var fields: Dictionary={"raceId":0,"gender":1,"packageId":0,"firstName":"Native","lastName":"Voice","age":18,"biography":"","deity":"","soundset":99}
	var before:=JSON.stringify(tables);var source:=VoiceProvider.character_info(tables,fields,text)
	check(source.ready and source.provenance.packageVoiceIndex==0 and source.context.value.soundset==1 and source.context.voices.map(func(row):return int(row.id))==[1,2],"Original failed-INT output0 maps through the filtered visible list to physical1, not physical0")
	if not source.ready:quit(1);return
	for cell in ["", "-1", "99", "0xzz"]:
		var changed: Dictionary=tables.duplicate(true);changed.packages.orderedCells[0][0]=cell;changed.packages.orderedRows[0].Soundset=cell
		var value:=VoiceProvider.character_info(changed,fields,text)
		if cell=="":check(value.ready and value.context.value.soundset==1,"Empty cell consumes the same known original0 output")
		elif cell=="-1":check(value.ready and value.provenance.selectedPhysicalSoundset==null and not value.context.value.has("soundset"),"Existing negative index remains unselected; no voice is invented")
		else:check(not value.ready,"Out-of-range and unresolved hexadecimal conversion stay unavailable: "+cell)
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=Fonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Information.new();surface.add_child(pane);pane.configure(painter,text,catalog,"")
	var voices: Array=[];var results: Array=[];var identity: Array=["empty-package",1]
	pane.voice_requested.connect(func(id,resref,sample,ticket):voices.append([id,resref,sample,ticket]))
	pane.finished.connect(func(accepted,value,ticket):results.append([accepted,value,ticket]))
	pane.set_context(source.context,identity);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+15000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Actual installed Information pane opens with the raw missing package Soundset")
	if pane.layout_ready:
		await frames(4)
		check(pane.state.selected==1 and voices==[[1,"first",0,identity]],"Actual initial source callback samples filtered physical1 exactly once")
		await click(pane.rows[1].button)
		check(pane.state.selected==2 and voices[-1]==[2,"second",0,identity],"Actual voice row can replace the initialized voice with physical2")
		await click(pane.buttons.okbutton)
		check(results.size()==1 and results[0][0] and results[0][1].soundset==2 and results[0][2]==identity,"Physical Info OK returns the explicit selected voice under the same source scope")
	check(JSON.stringify(tables)==before and fields.soundset==99,"Raw active package cells and the caller's prior soundset are unchanged")
	pane.close();pane.free();painter.free();surface.queue_free();await frames(4)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original8ecc60 ignored BOOL/known GetINTEntry output, actual native Information input, filtered physical IDs, malformed/negative/OOB guards and raw-row preservation. Authored active rows, installed art layout, controlled raster assets; no audio/server claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
