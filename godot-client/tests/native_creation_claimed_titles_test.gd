extends "res://tests/native_creation_attributes_text_geometry_test.gd"
const TitleCases={
	"cg_main":preload("res://systems/native_data/creation_main_layout.gd"),
	"cg_sex":preload("res://systems/native_data/creation_gender_layout.gd"),
	"cg_race":preload("res://systems/native_data/creation_race_layout.gd"),
	"cg_class":preload("res://systems/native_data/creation_class_layout.gd"),
	"cg_package":preload("res://systems/native_data/creation_package_layout.gd"),
	"cg_alignment":preload("res://systems/native_data/creation_alignment_layout.gd"),
	"cg_skills":preload("res://systems/native_data/creation_skills_layout.gd"),
	"cg_portrait":preload("res://systems/native_data/portrait_chooser_layout.gd"),
	"cg_school":preload("res://systems/native_data/creation_school_layout.gd"),
	"cg_domain":preload("res://systems/native_data/creation_domains_layout.gd")
}
const ExtraModels=["ctl_cg_btn_class","ctl_cg_btn_skill","ctl_cg_btn_skup","ctl_cg_btn_skdn","ctl_cg_numbox3","ctl_cg_portraits","ctl_cg_mportrait","ctl_cg_btn_dom","ctl_cg_btn_left","ctl_cg_btn_right","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func collect_title_models(node:Dictionary,names:Dictionary)->void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty():names[name]=true
	for child in node.get("Obj_ChildList",[]):collect_title_models(child,names)
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original title source catalog mounts read-only")
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original source title captions open")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var painter:=Painter.new();var art:=Art.new();var fonts:=NativeFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);fonts.configure(catalog,"");art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var sources:Dictionary={};var models:Dictionary={};var names:Dictionary={};var captions:Dictionary={};var containers:Array=[]
	for name in ExtraModels:names[name]=true
	for resource in TitleCases:
		var decoder:=preload("res://systems/native_data/gff_document.gd").new();var bytes:PackedByteArray=catalog.get_resource(resource,2047);sources[resource]=decoder.parse(bytes).root
		check(decoder.failure.is_empty(),"Actual claimed Title GUI decodes: "+resource);collect_title_models(sources[resource],names)
	for name in names:
		var decoder:=preload("res://systems/native_data/actor_model.gd").new();models[name]=decoder.parse(catalog.get_resource(name,2002));check(decoder.failure.is_empty(),"Actual source title model decodes: "+str(name))
	var plans:Dictionary={}
	for resource in TitleCases:
		var plan:Dictionary=TitleCases[resource].parse(sources[resource],models);check(str(plan.get("error","")).is_empty(),"Actual title layout hooks remain intact: "+resource)
		if not str(plan.get("error","")).is_empty():continue
		plans[resource]=plan;var parent:=Control.new();surface.add_child(parent);parent.size=plan.size;parent.position=Vector2(100,80);containers.append(parent)
		var entry:Dictionary=plan.entries["titlelabel" if resource=="cg_main" else "title"];var caption:Dictionary=entry.caption;var label:Label=painter.create_label(entry,parent,text.raw({"strRef":int(caption.get("Obj_StrRef",4294967295))}));captions[resource]=label
	var deadline:=Time.get_ticks_msec()+20000
	while not fonts.pending.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(fonts.pending.is_empty() and fonts.failed.is_empty(),"Actual installed bitmap fonts publish without fallback or GPU wait")
	await frames(5);var diagnostic:Dictionary={"fontStats":fonts.snapshot(),"menus":{}}
	for resource in captions:
		var label:Label=captions[resource];var plan:Dictionary=plans[resource];var entry:Dictionary=plan.entries["titlelabel" if resource=="cg_main" else "title"];var value:=label_view(label,entry);value.ink=glyph_ink(label);diagnostic.menus[resource]=value
		check(not entry.get("floating",false) and not entry.has("anchor"),"Original flag4 claimed Title is kept bounded: "+resource)
		check(label.clip_text and label.get_rect().is_equal_approx(entry.rect),"Actual native Title uses its GFF rectangle as the alignment region: "+resource)
		check(label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"Original source center/center alignment applies inside the Title region: "+resource)
		check(not label.text.is_empty() and value.missing.is_empty() and not value.fontApplied.is_empty(),"Actual native Title has installed font glyphs/text: "+resource)
		check(Rect2(Vector2.ZERO,plan.size).encloses(label.get_rect()) and value.ink.present and entry.rect.grow(1).encloses(value.ink.rect),"Literal native Title bounds/atlas ink remain within the source frame: "+resource)
		var old:Rect2=label.get_rect();label.get_parent().scale=Vector2(1.25,1.25);await frames();check(label.get_rect().is_equal_approx(old),"Viewport scaling does not reinterpret a claimed Title as an anchor: "+resource)
	for parent in containers:parent.free()
	painter.close();painter.free();text.close();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(packed({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"gpu":false,"serverConnections":0,"scope":"Original per-menu Title flag4 mappings plus real installed FontFile/atlas text bounds and scaling through actual native Painter labels. No full menu/server or GPU pixel acceptance."}),"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
