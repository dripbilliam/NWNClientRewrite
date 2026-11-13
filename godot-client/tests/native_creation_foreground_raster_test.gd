extends "res://tests/native_creation_spells_raster_test.gd"
const FeatsPane=preload("res://systems/native_feats_chooser.gd")
const AssociatePane=preload("res://systems/native_associate_chooser.gd")
func changed_ink(a:Image,b:Image,rect:Rect2)->int:
	var area:=Rect2i(rect).intersection(Rect2i(Vector2i.ZERO,a.get_size()));var count:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var left:=a.get_pixel(x,y);var right:=b.get_pixel(x,y)
			if maxf(absf(left.r-right.r),maxf(absf(left.g-right.g),absf(left.b-right.b)))>.03:count+=1
	return count
func photograph(surface:SubViewport)->Image:
	await process_frame;RenderingServer.force_draw(false,0.0);await process_frame;RenderingServer.force_draw(false,0.0)
	return surface.get_texture().get_image()
func run()->void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.position=Vector2i(-32000,-32000);await process_frame
	var args:Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report","panel"]) or FileAccess.file_exists(args.report) or args.panel not in ["feats","associate"]:quit(2);return
	check(root.get_flag(Window.FLAG_NO_FOCUS) and root.position.x< -10000 and root.position.y< -10000,"Owned diagnostic stays offscreen and non-activating")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original source catalog mounts read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(850,650);surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,"")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original title/header fonts and captions retain source owner")
	var pane:Variant=FeatsPane.new() if args.panel=="feats" else AssociatePane.new();surface.add_child(pane);pane.position=Vector2(35,35);pane.configure(painter,text,catalog,"")
	if args.panel=="feats":pane.set_context({"ready":true,"available":[],"known":[],"remaining":3,"canAccept":false},false,text,painter.art,[1,1])
	else:pane.set_context({},text,painter.art,[1,1])
	pane.open();pane.start();var deadline:=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<deadline:
		await process_frame;RenderingServer.force_draw(false,0.0)
		if not pane.failure.is_empty() or pane.layout_ready and Builder.source_ready(pane,painter) and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.art.jobs.is_empty():break
	check(pane.layout_ready and pane.failure.is_empty(),"Actual source pane prepares: "+str(pane.failure))
	var observations:Dictionary={};var targets:Dictionary={};var content:Control=pane if args.panel=="feats" else pane.content
	if pane.layout_ready:
		check(Builder.source_ready(pane,painter) and painter.art.models.pending.is_empty() and not painter.art.models.active,"Actual fonts and original native model artwork finish before sampling")
		var tags:Array=["availtitle","knowntitle","tguilabel","remainlabel"] if args.panel=="feats" else ["tguilabel"]
		for tag in tags:
			if tag=="remainlabel":targets[tag]=pane.remaining;continue
			var caption:String=pane.caption(pane.plan.entries[tag])
			for child in content.get_children():
				if child is Label and child.text==caption:targets[tag]=child;break
		check(targets.size()==tags.size(),"Actual pane exposes every audited source label")
		for tag in targets:
			var label:Label=targets[tag];observations[tag]={"text":label.text,"siblingIndex":label.get_index(),"rect":str(label.get_global_rect()),"fontApplied":label.has_meta("native_font_applied")}
		var original:Image=await photograph(surface);original.save_png(str(args.report).trim_suffix(".json")+"-original.png")
		for label in targets.values():label.hide()
		var hidden:Image=await photograph(surface)
		for tag in targets:
			var label:Label=targets[tag];label.show();content.move_child(label,content.get_child_count()-1)
		var foreground:Image=await photograph(surface);foreground.save_png(str(args.report).trim_suffix(".json")+"-diagnostic-foreground.png")
		for tag in targets:
			var label:Label=targets[tag];var rect:Rect2=label.get_global_rect();var normal_delta:=changed_ink(original,hidden,rect);var front_delta:=changed_ink(foreground,hidden,rect)
			observations[tag].sourceInkDifference=normal_delta;observations[tag].diagnosticForegroundDifference=front_delta
			check(front_delta>=8,"Actual original font ink can appear over this exact rendered background: "+tag)
			check(normal_delta>=8,"Source label is visibly above its actual opaque native model background: "+tag)
	var artist:Dictionary=painter.art.models.snapshot();var fonts:Dictionary=painter.fonts.snapshot()
	pane.close();pane.free();painter.close();painter.free();text.close();surface.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"panel":args.panel,"observations":observations,"artist":artist,"fonts":fonts,"gpuRaster":true,"gpuBenchmark":false,"serverConnections":0,"scope":"Bounded offscreen/non-activating actual native pane/font/art pixel comparison: normal vs hidden source labels, with test-only foreground diagnostic. Detached model; no FPS benchmark, authoritative draft/server or original-client pixel acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
