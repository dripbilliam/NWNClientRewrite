extends "res://tests/native_creation_appearance_view_test.gd"
const Attributes=preload("res://systems/native_level_up_attributes.gd")
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
const State=preload("res://systems/native_data/level_up_attributes_state.gd")
func packed(value:Variant)->Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Rect2:return {"position":packed(value.position),"size":packed(value.size)}
	if value is Color:return [value.r,value.g,value.b,value.a]
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[key]=packed(value[key])
		return result
	if value is Array:return value.map(packed)
	return value
func label_view(label:Label,entry:Dictionary)->Dictionary:
	var font:Font=label.get_theme_font("font");var height:=label.get_theme_font_size("font_size");var missing:Array=[]
	for at in label.text.length():
		if not font.has_char(label.text.unicode_at(at)):missing.append(label.text[at])
	return {"text":label.text,"rect":label.get_rect(),"minimum":label.get_combined_minimum_size(),"shapeSize":font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,height),"fontHeight":font.get_height(height),"fontSize":height,"fontApplied":str(label.get_meta("native_font_applied","")),"fontResource":str(label.get_meta("native_font_resource","")),"color":label.get_theme_color("font_color"),"modulate":label.modulate,"clip":label.clip_text,"missing":missing,"sourceRect":entry.rect,"sourceCaption":entry.get("caption",{}),"sourceHooks":entry.get("model",{}).get("hooks",{})}
func glyph_ink(label:Label)->Dictionary:
	var font:FontFile=label.get_theme_font("font");var height:=label.get_theme_font_size("font_size");var cache:=Vector2i(height,0);var advance:=0.0;var ink:=Rect2();var present:=false
	var extent:=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,height);var origin:=Vector2.ZERO
	if label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER:origin.x=(label.size.x-extent.x)*.5
	elif label.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT:origin.x=label.size.x-extent.x
	if label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER:origin.y=(label.size.y-font.get_height(height))*.5
	elif label.vertical_alignment==VERTICAL_ALIGNMENT_BOTTOM:origin.y=label.size.y-font.get_height(height)
	origin+=Vector2(0,font.get_ascent(height))
	for at in label.text.length():
		var glyph:=font.get_glyph_index(height,label.text.unicode_at(at),0);var index:=font.get_glyph_texture_idx(0,cache,glyph);var uv:=font.get_glyph_uv_rect(0,cache,glyph);var offset:=font.get_glyph_offset(0,cache,glyph)
		if index>=0:
			var image:Image=font.get_texture_image(0,cache,index)
			for y in int(uv.size.y):
				for x in int(uv.size.x):
					if image.get_pixel(int(uv.position.x)+x,int(uv.position.y)+y).a<=0:continue
					var pixel:=Rect2(label.position+origin+offset+Vector2(advance+x,y),Vector2.ONE);ink=ink.merge(pixel) if present else pixel;present=true
		advance+=font.get_glyph_advance(0,height,glyph).x
	return {"present":present,"rect":ink}
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions open")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var pane:=Attributes.new();surface.add_child(pane);pane.configure(painter,text,catalog,"");pane.set_context({"ready":true,"scores":[11,16,12,18,10,8],"modifiers":[0,3,1,4,0,-1],"raw":[13,14,12,16,10,8],"racial":[-2,2,0,2,0,0],"gains":[0,0,0,0,0,0],"costs":[2,2,1,3,1,1],"points":1,"selectedAbility":-1},true,text,["levelup-attributes",1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while (not pane.layout_ready or not fonts.pending.is_empty()) and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty() and fonts.pending.is_empty() and fonts.failed.is_empty(),"Actual source pane and installed bitmap/TTF fonts publish: "+pane.failure+str(fonts.failed))
	await frames(5)
	var diagnostic:Dictionary={"fontStats":fonts.snapshot(),"source":pane.source,"size":pane.size,"main":pane.plan.get("main"),"labels":{}}
	if pane.layout_ready:
		for index in 6:
			var key:String=Attributes.LevelLayout.KEYS[index];var label:Label=pane.values[index];var value:=label_view(label,pane.plan.entries[key+"edit"]);diagnostic.labels[key]=value
			var row:Button=pane.buttons[key+"label"];var name_label:Label=row.get_child(0);var ink:=glyph_ink(label);value.ink=ink;value.siblingIndex=label.get_index();value.rowIndex=row.get_index();value.name=label_view(name_label,pane.plan.entries[key+"label"])
			check(not label.text.is_empty() and value.missing.is_empty() and not value.fontApplied.is_empty(),"Actual numeric label has text and real installed glyph coverage: "+key)
			check(label.get_theme_color("font_color").a*label.modulate.a>0 and Rect2(Vector2.ZERO,pane.size).encloses(label.get_rect()),"Numeric text is visible and within its actual frame: "+key)
			check(label.get_index()>row.get_index() and label.get_parent()==row.get_parent(),"Numeric text paints above its opaque row/background: "+key)
			check(ink.present and pane.plan.entries[key+"edit"].rect.grow(1).encloses(ink.rect),"Actual installed atlas ink lies within the numeric source field: "+key)
			var anchor:Vector2=pane.plan.entries[key+"label"].caption_anchor;var name_rect:=Rect2(row.position+name_label.position,name_label.size)
			check(absf(name_rect.position.x-anchor.x)<.01 and absf(name_rect.get_center().y-anchor.y)<.01 and name_rect.end.x<label.position.x,"Actual ability name uses its left/center source text hook without crossing numeric text: "+key)
		diagnostic.labels.title=label_view(pane.title,pane.plan.entries.title);diagnostic.labels.points=label_view(pane.points,pane.plan.entries.pointsedit)
		check(Rect2(Vector2.ZERO,pane.size).encloses(pane.title.get_rect()),"Literal installed-font title rectangle is contained within the native panel")
		var state:=State.new();var edits:Array=[];var answers:Array=[];var initial:Dictionary=pane.model.duplicate(true)
		pane.action_requested.connect(func(operation,index,ticket):
			if operation not in ["up","down"]:return
			var changed:bool=state.move(index,1 if operation=="up" else -1);edits.append([operation,index,ticket.duplicate(),changed])
			if changed:
				var next:Dictionary=initial.duplicate(true);next.points=state.points();next.selectedAbility=state.selected
				if state.selected>=0:
					next.raw[state.selected]+=1;next.scores[state.selected]+=1;next.gains[state.selected]+=1;next.modifiers[state.selected]=floori((int(next.scores[state.selected])-10)/2.0)
				pane.update_model(next))
		pane.finished.connect(func(accepted,ticket):answers.append([accepted,ticket]))
		await click(pane.buttons.chalabel);check(pane.help_index==5,"Physical static row label still invokes mode1 help")
		await click(pane.values[0]);check(pane.help_index==0 and pane.help_prefix.contains("13") and pane.help_prefix.contains("-2") and pane.help_prefix.contains("11"),"Numeric text retains actual base/racial/final help")
		await click(pane.buttons.strupbutton);check(edits.size()==1 and state.selected==0 and pane.model.points==0 and pane.values[0].text=="12 (+1)","Physical mode1 arrow spends the one allocation and displays its actual score/modifier")
		await click(pane.buttons.dexupbutton);await click(pane.buttons.dexdownbutton);check(edits.size()==1 and state.selected==0,"Other ability arrows cannot spend a second point or refund the selected ability")
		await click(pane.buttons.strdownbutton);check(edits.size()==2 and state.selected==-1 and pane.model.points==1 and pane.values[0].text=="11 (+0)","Physical selected decrease refunds exactly the existing mode1 allocation")
		var button:Button=pane.buttons.dexupbutton;var point:Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
		await pointer(point,true);pane.set_process(false);var count:int=edits.size();pane.advance_repeat(500000)
		check(edits.size()==count and state.selected==1,"Held arrow retains the strict initial500ms threshold")
		pane.advance_repeat(1);check(edits.size()==count and state.selected==1 and pane.model.points==0,"Mode1 selection guard prevents held repeat from allocating twice")
		await pointer(point,false);check(not pane.repeat_clock.active,"Release retires held mode1 input")
		pane.capture("dexdownbutton");pane.dismiss();pane.invoke("dexdownbutton");check(state.selected==1 and edits.size()==count,"Retired mode1 label/arrow cannot mutate its private allocation")
		pane.open();await frames();await click(pane.buttons.cancelbutton);check(answers==[[false,["levelup-attributes",1]]] and state.selected==1,"Physical Cancel returns its exact scope without a duplicate arrow action")
		pane.set_context(pane.model,true,text,["levelup-attributes",2]);pane.open();await frames();await click(pane.buttons.okbutton);check(answers.size()==2 and answers[1]==[true,["levelup-attributes",2]],"Physical OK accepts the valid one-point selection at the current scope")

	pane.close();pane.free();painter.close();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"gpu":false,"serverConnections":0,"artworkDouble":true,"realInstalledFonts":true,"scope":"Literal actual mode1 Attributes labels/rectangles/real FontFile glyph coverage; no GPU pixel comparison or rules mutation."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
