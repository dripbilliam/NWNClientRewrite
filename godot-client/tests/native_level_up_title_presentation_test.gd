extends "res://tests/native_creation_appearance_view_test.gd"
const Binding=preload("res://systems/native_data/level_up_title_presentation.gd")
const NativeFonts=preload("res://systems/native_bitmap_fonts.gd")
const Inspect=preload("res://tests/native_font_ink_probe.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const TitleContext=preload("res://systems/native_data/level_up_title_context.gd")
const PANES={"skills":preload("res://systems/native_level_up_skills.gd"),"feats":preload("res://systems/native_level_up_feats.gd"),"spells":preload("res://systems/native_spells_chooser.gd"),"domains":preload("res://systems/native_level_up_domains.gd"),"school":preload("res://systems/native_level_up_school.gd"),"associate":preload("res://systems/native_associate_chooser.gd")}
func wait_ready(predicate: Callable,seconds: int=20) -> bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func title_anchor(label: Label,entry: Dictionary) -> Vector2:
	var caption: Dictionary=entry.caption
	return label.position+label.size*Vector2(float(caption.get("AurString_AlignH",0)),float(caption.get("AurString_AlignV",0)))
func set_pane_context(pane,stage: String,text,art,scope: Array) -> void:
	if stage=="associate":pane.set_context({"ready":false},text,art,scope)
	elif stage=="school":pane.set_context({"ready":false},false,text,scope)
	else:pane.set_context({"ready":false},false,text,art,scope)
func finish_test(report: String,text,painter,diagnostics: Dictionary) -> void:
	painter.close();painter.free();text.close();surface.queue_free();await frames(5)
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(Inspect.packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostics,"realInstalledGuiModelsAndFonts":true,"artworkDouble":true,"privateNameContextAuthored":true,"runtimeIntegrated":false,"originalPixelsAccepted":false,"scope":"Six source-proven mode1 titles, actual native controls/GFF/MDL geometry and installed FontFile/atlas ink with scoped helper and physical Cancel. No Runtime/Frontend producer, live private-name publication, original raster, server or full level-up acceptance.","gpu":false,"serverConnections":0}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
func name_context_cases(text) -> void:
	check(TitleContext.name({"override":"  Override  "}).text=="  Override  ","Exact nonempty override does not require undisclosed split strings")
	check(TitleContext.name({"override":"Override","first":null,"last":7}).ready,"Unused split storage cannot invalidate original nonempty override branch")
	check(not TitleContext.name({"override":""}).ready and not TitleContext.name({"first":"A","last":"B"}).ready,"Unknown needed private name fields stay unavailable")
	var split: Dictionary={"firstName":{"text":"Shand"},"lastName":{"text":"Carna"}}
	var projected:=TitleContext.project(split,text)
	check(projected.ready and projected.parts=={"first":"Shand","last":"Carna","override":""},"Exact received split branch resolves without full-name formatting")
	var over:=TitleContext.project({"text":"Known override"},text)
	check(over.ready and over.parts=={"override":"Known override"} and not over.known.first and not over.known.last,"Override projection preserves unknown split strings explicitly")
	for value in [null,{}, {"text":""},{"firstName":{"text":"First"}}, {"text":"Override","firstName":{"text":"First"},"lastName":{"text":"Last"}},{"text":false}]:check(not TitleContext.project(value,text).ready,"Missing/ambiguous received branch is rejected: "+str(value))
	var reference:=TitleContext.project({"firstName":{"strRef":61920,"gender":0},"lastName":{"text":"Tail"}},text)
	check(reference.ready and reference.parts.first==text.raw({"strRef":61920}),"Actual active TLK resolver supplies exact received STRREF/gender name")
	check(not TitleContext.project({"firstName":{"strRef":4294967294,"gender":0},"lastName":{"text":"Tail"}},text).ready,"Unavailable TLK name never becomes an empty/default name")
	var actor: Dictionary={"id":9,"areaId":7,"objectType":5,"replicationRemoved":false,"nativeLifetime":11,"clientKnownLifetime":13,"replicated":{"name":split.duplicate(true)}}
	var before: Dictionary=actor.duplicate(true);var scope: Array=[1,7,9];var context:=TitleContext.new();var captured:=context.capture(actor,scope,99,text)
	check(captured.ready and actor==before,"Scoped capture does not add names to actor or canonical level-up snapshot")
	captured.parts.first="Consumer mutation";check(context.resolve(actor,scope,99,text).parts.first=="Shand","Returned private title strings are detached")
	actor.replicated.name.firstName.text="Later live name";check(context.resolve(actor,scope,99,text).parts.first=="Shand","Private clone retains captured names rather than following later display updates")
	actor.clientKnownLifetime=14;check(not context.resolve(actor,scope,99,text).ready,"Disclosure lifetime reuse retires old title context")
	actor=before.duplicate(true);check(context.capture(actor,scope,100,text).ready and not context.resolve(actor,scope,99,text).ready,"Old menu token cannot reuse current title context")
	var custom: int=0x01000042;actor.replicated.name={"firstName":{"strRef":custom,"gender":0},"lastName":{"text":"Tail"}}
	check(not context.capture(actor,scope,101,text).ready,"Captured unresolved active name remains explicitly pending")
	text.overrides[custom]="Resolved active name";check(context.resolve(actor,scope,101,text).parts.first=="Resolved active name","Late active text resolves captured raw branch in the same guarded lifetime")
	text.overrides[custom]="Changed later";check(context.resolve(actor,scope,101,text).parts.first=="Resolved active name","Resolved private clone string freezes independently of later active display text")
	text.overrides.erase(custom);context.close()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original GUI/MDL/font catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual original class/title TLK opens")
	name_context_cases(text)
	var table:=Table.new();var classes: Dictionary=table.parse(catalog.get_resource("classes",2017).get_string_from_utf8());check(table.failure.is_empty(),"Actual installed class names load without authored rule substitutions")
	var tables: Dictionary={"classes":classes};var private_classes: Array=[{"id":1,"level":2},{"id":10,"level":1}]
	var parts: Dictionary={"first":"Shand","last":"Carna","override":""};var diagnostics: Dictionary={};var outcomes: Array=[]
	surface=SubViewport.new();surface.size=Vector2i(1700,1100);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	for stage in PANES:
		print("NATIVE_TITLE_PHASE begin "+stage+" checks="+str(checks))
		var pane=PANES[stage].new();surface.add_child(pane);pane.position=Vector2(100,100);pane.configure(painter,text,catalog,"")
		var scope: Array=["level-up-title",stage,1]
		set_pane_context(pane,stage,text,art,scope)
		if stage in ["skills","feats","spells"]:pane.finished.connect(func(allow,_identity):outcomes.append({"stage":stage,"accepted":allow}))
		else:pane.finished.connect(func(allow,_value,_identity):outcomes.append({"stage":stage,"accepted":allow}))
		pane.open();pane.start()
		var prepared: bool=await wait_ready(func():return pane.layout_ready and fonts.pending.is_empty() or not pane.failure.is_empty() or not fonts.failed.is_empty())
		check(prepared and pane.layout_ready and pane.failure.is_empty() and fonts.failed.is_empty(),"Actual source "+stage+" controls and original FontFile/atlas prepare")
		if not pane.layout_ready or not pane.failure.is_empty():pane.close();pane.free();continue
		await frames(3)
		var caption: String=pane.caption(pane.plan.entries.title);var found:=Binding.locate(pane,stage,caption);check(found.ready,"Exact source title identity resolves: "+stage)
		if not found.ready:pane.close();pane.free();continue
		var label: Label=found.label;var entry: Dictionary=found.entry;var original_rect:=label.get_rect();var original_anchor:=title_anchor(label,entry)
		var binding:=Binding.new();var begun:=binding.begin(pane,stage,caption,scope);check(begun.ready,"Actual unwrapped rendered first caption line captured: "+stage)
		var value:=binding.present(parts,private_classes,tables,text,scope);await frames(2)
		check(value.ready and label.text.begins_with("Shand Carna   ") and label.text.ends_with("        "+caption),"Original mode1 name/class/separator/first-line text applied to real control: "+stage)
		check(label.text.count("Shand Carna")==1 and binding.present(parts,private_classes,tables,text,scope).ready and label.text.count("Shand Carna")==1,"Repeated publication never prefixes the title twice: "+stage)
		var ink:=Inspect.glyph_ink(label);var view:=Inspect.label_view(label,entry)
		var frame_resource: String=str(pane.plan.get("resource",""));var model: Dictionary={}
		if not frame_resource.is_empty() and pane.models.has(frame_resource):model=Geometry.model(pane.models[frame_resource])
		var frame_ready: bool=model.get("error","Missing frame metadata")=="" and model.get("drawn",false) and model.get("bounds") is Rect2
		check(frame_ready,"Actual installed main-frame metadata is separate from programmatic Title label: "+stage)
		diagnostics[stage]={"entry":entry,"label":view,"ink":ink,"originalRect":original_rect,"originalAnchor":original_anchor,"frameResource":frame_resource,"frameModelBounds":model.get("bounds"),"caller":Binding.CALLERS[stage],"scaleChecks":[]}
		if not frame_ready:
			binding.retire();pane.close();pane.free();await finish_test(args.report,text,painter,diagnostics);return
		check(view.fontApplied!="" and view.missing.is_empty() and ink.present,"Literal installed font atlas contains all displayed title glyphs: "+stage)
		check(Rect2(Vector2.ZERO,pane.size).grow(1).encloses(ink.rect),"Actual title ink stays within the native frame for supplied private context: "+stage)
		if stage=="associate":
			check(entry.get("floating",false) and not label.clip_text and title_anchor(label,entry).distance_to(original_anchor)<.01,"Unclaimed Associate title preserves exact original floating anchor")
		else:check(not entry.get("floating",false) and label.clip_text and label.get_rect().is_equal_approx(original_rect),"Claimed title keeps original bounded clipping geometry: "+stage)
		for scale_value in [1.0,1.25,1.5]:
			pane.scale=Vector2.ONE*scale_value;await frames()
			var expected: Vector2=label.get_global_transform_with_canvas()*Vector2.ZERO;var local: Vector2=label.get_global_transform_with_canvas().affine_inverse()*expected
			check(local.length()<.001 and label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Affine title scaling preserves its source origin and pointer transparency: "+stage+"/"+str(scale_value))
			diagnostics[stage].scaleChecks.append({"scale":scale_value,"globalOrigin":expected})
		pane.scale=Vector2.ONE
		var before: String=label.text;check(not binding.present(parts,private_classes,tables,text,["retired"]).ready and label.text==before,"Stale identity cannot alter current title: "+stage)
		check(not binding.present(null,private_classes,tables,text,scope).ready and label.text==caption,"Unavailable exact private names restore source caption without fake actor text: "+stage)
		check(binding.present(parts,private_classes,tables,text,scope).ready,"Known private title can publish after temporary unavailable context: "+stage)
		var newer: Array=scope+[2];var delayed: Callable=func():return binding.begin(pane,stage,caption,scope)
		binding.retire();set_pane_context(pane,stage,text,art,newer)
		check(binding.begin(pane,stage,caption,newer).ready and binding.present(parts,private_classes,tables,text,newer).ready,"New pane identity gets its own source title binding: "+stage)
		var new_text: String=label.text;check(not delayed.call().ready and label.text==new_text and binding.current(newer),"Stale pre-font callback cannot retire/relabel a newer pane: "+stage)
		label.text="Another title owner";binding.retire();check(label.text=="Another title owner","Retirement preserves another owner's replacement caption: "+stage)
		label.text=caption;set_pane_context(pane,stage,text,art,scope);check(binding.begin(pane,stage,caption,scope).ready and binding.present(parts,private_classes,tables,text,scope).ready,"Current pane can reacquire only its exact source caption: "+stage)
		var count: int=outcomes.size();await click(pane.buttons.cancelbutton);check(outcomes.size()==count+1 and not outcomes[-1].accepted and not pane.wanted,"Physical source Cancel remains reachable after title publication: "+stage)
		binding.retire();check(label.text==caption,"Scoped title retirement restores only its own current caption: "+stage)
		pane.close();pane.free();await frames(2)
		print("NATIVE_TITLE_PHASE complete "+stage+" checks="+str(checks))
	check(not Binding.CALLERS.has("class") and not Binding.CALLERS.has("attributes") and not Binding.CALLERS.has("summary"),"Unproved Class/Attributes/Summary prefixes are excluded")
	await finish_test(args.report,text,painter,diagnostics)
