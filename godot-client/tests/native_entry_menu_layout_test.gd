extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Plan=preload("res://systems/native_data/entry_menu_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original entry-menu resources mount read-only")
	var models: Dictionary={}; var hashes: Dictionary={}; var layouts: Dictionary={}; var metadata: Dictionary={}
	for kind in Plan.MENUS:
		var raw: PackedByteArray=catalog.get_resource(kind,2047); var parser:=Gff.new(); var document: Dictionary=parser.parse(raw,"GUI "); hashes[kind]=Cache.digest(raw)
		check(parser.failure.is_empty(),"Original GUI parses: "+kind)
		if not parser.failure.is_empty(): continue
		layouts[kind]=document.root
		var names: Array=[str(document.root.Obj_ResRef).to_lower()]
		for child in document.root.get("Obj_ChildList",[]):
			var name:=str(child.get("Obj_ResRef","")).to_lower()
			if not name.is_empty() and not names.has(name): names.append(name)
		for name in names:
			if models.has(name): continue
			var model_raw: PackedByteArray=catalog.get_resource(name,2002); var model_parser:=Actor.new(); models[name]=model_parser.parse(model_raw); hashes[name]=Cache.digest(model_raw)
			check(model_parser.failure.is_empty(),"Original menu model parses: "+name)
	for kind in layouts:
		var before: Dictionary=layouts[kind].duplicate(true); var plan:=Plan.parse(kind,layouts[kind],models)
		check(str(plan.error).is_empty(),"Source GUI/model attachments produce the complete menu data plan: "+kind)
		if not str(plan.error).is_empty(): continue
		check(plan.entries.size()==layouts[kind].Obj_ChildList.size() and layouts[kind]==before,"Source controls and captions are retained without mutating active resources: "+kind)
		var actions: Dictionary={}
		for tag in Plan.MENUS[kind].buttons:
			var entry: Dictionary=plan.entries[tag]
			check(entry.rect.size.x>0 and entry.rect.size.y>0 and entry.callback==Plan.MENUS[kind].buttons[tag],"Original model hit geometry and recovered callback remain paired: "+kind+"/"+tag)
			actions[tag]={"resource":entry.resource,"rect":entry.rect,"sourceRef":entry.source_caption.get("Obj_StrRef",-1),"runtimeRef":entry.caption.get("Obj_StrRef",-1),"callback":entry.callback}
		var clipping:=Rect2(Vector2.ZERO,plan.size).grow(0.001)
		check(plan.entries.values().all(func(entry):return clipping.has_point(entry.anchor) if entry.get("floating",false) else clipping.encloses(entry.rect)) and clipping.encloses(plan.main.rect),"Menu extent contains original controls and unbounded label anchors as well as its decorative model: "+kind)
		if kind=="pre_main": check(plan.size.y>plan.main.rect.size.y and plan.entries.exitbutton.rect.end.y<=plan.size.y+0.001,"Main-menu artwork bounds cannot clip the lower original button column")
		metadata[kind]={"size":plan.size,"origin":plan.origin,"rootPoint":plan.root_point,"actions":actions}
		var changed: Dictionary=layouts[kind].duplicate(true); var tag: String=Plan.MENUS[kind].buttons.keys()[0]
		for child in changed.Obj_ChildList:
			if str(child.Obj_Tag).to_lower()==tag: child.Obj_X+=0.25
		var moved:=Plan.parse(kind,changed,models)
		check(str(moved.error).is_empty() and moved.entries[tag].rect.position.distance_to(plan.entries[tag].rect.position+Vector2(25,0))<0.001,"Active GUI placement supersedes installed coordinates: "+kind)
		changed=layouts[kind].duplicate(true); var old: String=changed.Obj_ResRef; changed.Obj_ResRef="authored_entry_frame"; var supplied:=models.duplicate(); supplied.authored_entry_frame=models[old]; supplied.erase(old)
		check(str(Plan.parse(kind,changed,supplied).error).is_empty(),"An active catalog may replace the frame resource: "+kind)
		changed=layouts[kind].duplicate(true); changed.Obj_ChildList.pop_front()
		check(not str(Plan.parse(kind,changed,models).error).is_empty(),"A missing source control is reported before exposing a partial plan: "+kind)
		var missing:=models.duplicate(); missing.erase(str(layouts[kind].Obj_ResRef).to_lower())
		check(not str(Plan.parse(kind,layouts[kind],missing).error).is_empty(),"Missing frame art is explicit rather than a generic substitute: "+kind)
		check(plan.native_data_only and not plan.visible_menu_accepted and not plan.full_entry_menu_parity,"A data plan cannot claim visible or functional menu acceptance: "+kind)
	var game:=Plan.parse("options_main",layouts.get("options_main",{}),models); var pregame:=Plan.parse("options_pregame",layouts.get("options_pregame",{}),models)
	if str(game.error).is_empty() and str(pregame.error).is_empty():
		check(game.entries.savecharbutton.source_caption.Obj_StrRef==50 and game.entries.savecharbutton.caption.Obj_StrRef==0x19a0,"Save Character uses its original runtime caption rather than the stored GUI caption")
		check(game.entries.videooptionsbutton.caption.Obj_StrRef==0x1baf and pregame.entries.videooptsbutton.caption.Obj_StrRef==0x1baf and game.entries.controlsbutton.caption.Obj_StrRef==0x28ad and pregame.entries.controlbutton.caption.Obj_StrRef==0x28ad,"Both original Options initializers override resolution/control wording")
		check(pregame.entries.nwsyncbutton.runtime_text=="Storage" and game.entries.soundoptionsbutton.model_deleted_after_init and pregame.entries.soundbutton.model_deleted_after_init,"Storage caption and post-initialization sound-model removal are separate observed runtime facts")
		check(game.entries.buildnumber.runtime_text_kind=="build-version" and pregame.entries.buildnumber.runtime_color==Color(0.4,0.4,0.4,1),"Both build labels retain the original runtime replacement policy without inventing an original version")
	check(Plan.main_enabled(false,false,false).values().all(func(on):return not on),"NWSync initialization keeps every original main-menu action disabled")
	check(Plan.main_enabled(true,false,false).values().all(func(on):return on),"Completed initialization enables all seven normal original actions")
	for mode in [[true,false],[false,true],[true,true]]:
		var state:=Plan.main_enabled(true,mode[0],mode[1]); check(not state.newbutton and not state.loadbutton and state.multibutton and state.optionsbutton and state.exitbutton,"DM/client-server mode gates New/Load without disabling joining or Options: "+str(mode))
	check(not Plan.local_save_load_allowed(false,true,false,true,true) and not Plan.local_save_load_allowed(false,true,true,true,false) and Plan.local_save_load_allowed(false,true,true,true,true),"Loopback alone cannot enable host Save/Load; original server presence and client gate are both required")
	check(not Plan.local_save_load_allowed(true,true,true,true,true) and not Plan.local_save_load_allowed(false,false,true,true,true) and not Plan.local_save_load_allowed(false,true,true,false,true),"Original client-server, disconnected and remote branches never grant local Save/Load")
	var guest:=Plan.options_enabled("options_main",true,false); var host:=Plan.options_enabled("options_main",false,true)
	check(not guest.loadbutton and not guest.savebutton and not guest.soundoptionsbutton and guest.savecharbutton and guest.resumegamebutton and host.loadbutton and host.savebutton and host.soundoptionsbutton,"Original guest/host and sound-disable states preserve Export/Resume independently")
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-entry-menu-policy-observations-v1.json")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.main.size()==4 and oracle.localSaveLoad.size()==32,"Independent original-instruction oracle covers all binary DM/mode and local-host predicate combinations")
	for row in oracle.main:
		var state:=Plan.main_state(true,row.dm,row.clientServerMode)
		check(state.enabled==row.enabled and state.replacements==row.replacements,"Native main-menu availability and DM textures match unchanged original instructions: "+str([row.dm,row.clientServerMode]))
		for tag in row.colors:
			var color: Array=row.colors[tag]
			check(state.colors[tag].is_equal_approx(Color(color[0],color[1],color[2],color[3])),"Native menu caption color matches original instruction output: "+str([row.dm,row.clientServerMode])+"/"+tag)
	for row in oracle.localSaveLoad:
		check(Plan.local_save_load_allowed(row.clientServerMode,row.connected,row.appServerPresent,row.localhost,row.clientField5a4)==row.allowed,"Native local Save/Load gate matches unchanged original instructions: "+str([row.clientServerMode,row.connected,row.appServerPresent,row.localhost,row.clientField5a4]))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resourceSha256":hashes,"oracleSha256":FileAccess.get_sha256(oracle_path),"menus":metadata,"publicConnections":0,"fullEntryMenuParity":false,"visibleMenuAccepted":false,"scope":"Original installed main/pregame/in-game Options resource/callback data plan and unchanged original-instruction availability/color/host-predicate comparisons only. Native visible entry/options owner, authoritative Export/Save/Load, confirmations, config/NWSync manager, original-client comparison and full UI parity remain separate unfinished work."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
