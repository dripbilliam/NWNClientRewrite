extends "res://tests/native_creation_attributes_text_geometry_test.gd"
const Feats=preload("res://systems/native_feats_chooser.gd")
func run()->void:
	var args:Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://oracle.json"))
	check(oracle is Dictionary and oracle.cases==40,"Unchanged-original native bounds branch cases are present")
	if oracle is Dictionary:
		for row in oracle.rows:
			check(row.bounds==row.initial if (int(row.flags)&4)==0 else absf(float(row.bounds[0])-float(row.supplied[0]))<.000001 and absf(float(row.bounds[1])-float(row.supplied[1]))<.000001,"The native width/height import follows only explicit owner flag4")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed creator assets mount read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original source labels load")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Feats.new();surface.add_child(pane);pane.configure(painter,text,catalog,"");pane.set_context({"ready":true,"available":[],"known":[],"remaining":3,"canAccept":false},false,text,art,["feat-label",1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while (not pane.layout_ready or not fonts.pending.is_empty()) and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty() and fonts.pending.is_empty() and fonts.failed.is_empty(),"Actual Feats source controls and installed bitmap fonts prepare")
	await frames(5)
	var diagnostic:Dictionary={"fontStats":fonts.snapshot(),"labels":{}}
	if pane.layout_ready:
		for tag in ["availtitle","knowntitle","remainlabel","title"]:
			var entry:Dictionary=pane.plan.entries[tag];var label:Label
			if tag=="remainlabel":label=pane.remaining
			else:
				for child in pane.get_children():
					if child is Label and child.text==pane.caption(entry):label=child;break
			check(is_instance_valid(label),"Actual source label exists: "+tag)
			if not is_instance_valid(label):continue
			var original_rect:Rect2=label.get_rect();var value:Dictionary=label_view(label,entry);value.ink=glyph_ink(label);diagnostic.labels[tag]=value
			check(value.missing.is_empty() and not value.fontApplied.is_empty() and value.ink.present,"Real installed glyphs cover the source caption: "+tag)
			if tag=="title":
				check(label.clip_text and not entry.get("floating",false) and label.get_rect().is_equal_approx(entry.rect),"Title's original flag4 still uses its bounded center-alignment region")
			else:
				check(not label.clip_text and entry.get("floating",false),"The original default-flag source label has no width limit: "+tag)
				check(label.get_rect().grow(1).encloses(value.ink.rect),"The entire actual source caption's atlas ink fits: "+tag)
				var anchor:Vector2=entry.rect.position;var align:=Vector2(float(entry.caption.get("AurString_AlignH",0)),float(entry.caption.get("AurString_AlignV",0)))
				check((label.position+label.size*align).is_equal_approx(anchor),"Natural text extent keeps the original source anchor: "+tag)
				label.text="Additional available feats" if tag=="availtitle" else "Selected feat choices" if tag=="knowntitle" else "127";await frames(3)
				var expanded:Dictionary=glyph_ink(label)
				check(not label.clip_text and expanded.present and label.get_rect().grow(1).encloses(expanded.rect),"Changed caption/count updates natural bounds without a stale width: "+tag)
			label.get_parent().scale=Vector2(1.25,1.25);await frames()
			check(label.get_rect().is_equal_approx(original_rect) if tag=="title" else label.size.x>0,"Parent scale does not alter the source label's local extent")
	pane.close();pane.free();painter.close();painter.free();text.close();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"gpu":false,"serverConnections":0,"scope":"Actual Feats controls and installed FontFile/atlas ink against the original native bounds branch. Copied-source candidate only; no original rendered pixels, live-client mutation, server or full creator acceptance."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
