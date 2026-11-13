extends "res://tests/native_skill_description_source_test.gd"
# Reuses only controlled art/fonts and pointer helpers from the sealed skill test.
func feat_requests() -> Array: return requests.filter(func(message):return message.get("kind")=="native-panel" and message.get("panel")=="feat")
func entry_for(feat: int) -> int:
	for id in sheet.entry_data:
		if int(sheet.entry_data[id].id)==feat: return int(id)
	return -1
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["report","install"]) or FileAccess.file_exists(options.report): quit(2); return
	var diagnostic:=await exercise_feats(options)
	if is_instance_valid(ui): ui.close(); ui.free()
	if is_instance_valid(sheet): sheet.free()
	if is_instance_valid(painter): painter.close()
	check(is_instance_valid(art) and art.closed and is_instance_valid(fonts) and fonts.closed,"Controlled raster/font owners close through actual native lifecycle")
	if is_instance_valid(surface): surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"headless":true,"gpu":false,"publicConnections":0,"gameServerConnections":0,"nativeBuilds":0,"scope":"Actual installed native sheet/frame geometry, pointer controls, current feat/TLK/token owners and native successor admission. Authored received memberships/table edits and controlled8px raster/fallback font. No original pixels, live game window or original-server acceptance; local GUI4 server outcome is separate."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("NATIVE_FEAT_DESCRIPTION_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
func exercise_feats(options: Dictionary) -> Dictionary:
	var catalog:=Catalog.new()
	if not check(catalog.mount_install(options.install),"Installed original GUI/model/table catalog mounts read-only"): return {}
	root.size=Vector2i(1440,960); surface=SubViewport.new(); surface.size=root.size; surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.handle_input_locally=true; surface.gui_disable_input=false; root.add_child(surface); surface.notify_mouse_entered()
	painter=Painter.new(); art=ControlledArt.new(); fonts=ControlledFonts.new(); painter.art=art; painter.fonts=fonts; painter.owns_art=true; painter.add_child(art); painter.add_child(fonts); art.loaded.connect(painter.art_loaded); surface.add_child(painter)
	ui=Gameplay.new(); root.add_child(ui); ui.set_process(false); ui.generation=1; ui.area_id=55; ui.controlled_id=42
	if not check(ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk")),"Original installed TLK is active in native text owner"): return {}
	for name in ["skills","feat","classes","racialtypes","exptable","ruleset"]: ui.text.publish_table(name,Table.new().parse(catalog.read_resource(name,2017).get_string_from_ascii()))
	var desktop:=Desktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.owner_ui=ui; desktop.rules.text=ui.text; ui.desktop=desktop
	sheet=Sheet.new(); sheet.setup(""); surface.add_child(sheet); desktop.sheet=sheet; sheet.request.connect(desktop.input_request); desktop.request.connect(func(message): requests.append(message.duplicate(true)))
	var skin:=Frame.new(); desktop.add_child(skin); desktop.sheet_frame=skin; skin.configure(sheet,catalog,str(options.report).get_base_dir().path_join("model-cache"),ui.text,painter)
	var original: Dictionary=ui.text.tables.feat.duplicate(true); var ids: Array=[]; var descriptions: Array=[]
	for id in original.orderedRows.size():
		var definition: Dictionary=desktop.rules.record_feat_definition(id)
		var reference:=desktop.rules.number(desktop.rules.cell(definition,"Description"))
		if definition.is_empty() or reference<0 or descriptions.has(reference) or ui.text.raw({"strRef":reference}).is_empty(): continue
		ids.append(id); descriptions.append(reference)
		if ids.size()==3: break
	if not check(ids.size()==3,"Three valid feat definitions/descriptions come from the installed active table"): return {}
	var predecessor: int=ids[0]; var customized: int=ids[1]; var unchanged: int=ids[2]; var description_ref: int=descriptions[1]
	var active: Dictionary=original.duplicate(true); active.orderedRows[predecessor].SUCCESSOR=str(customized); active.orderedRows[customized].SUCCESSOR="-1"; active.orderedRows[unchanged].SUCCESSOR="-1"; ui.text.publish_table("feat",active)
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Native feat help fixture"},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]},"hitPoints":{"current":10,"maximum":10}},"inventoryStats":{"fields118":[predecessor],"fields128":[customized,unchanged]},"playerState":{"feats":[unchanged],"abilities":{"current":[10,10,10,10,10,10]}}}
	desktop.objects={42:actor}; desktop.actor_id=42; desktop.area_id=55; desktop.generation=1; ui.text.objects=desktop.objects
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":description_ref,"text":"Owned feat help. <CUSTOM9002>"}]},1); ui.receive({"kind":"custom-token","id":9002,"text":"First server feat text"},1)
	sheet.wanted=true; sheet.page=2; sheet.show(); desktop.refresh_sheet()
	var deadline:=Time.get_ticks_msec()+20000
	while not skin.layout_ready and skin.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if not check(skin.layout_ready and skin.failure.is_empty(),"All installed character-sheet models decode without raster/render waits: "+skin.failure): return {"skin":skin.snapshot()}
	await frames(5)
	check(not sheet.window_column.visible and skin.models.size()==Plan.RESOURCES.size(),"Actual original frame uses all17 installed model components")
	var admitted: Array=sheet.entry_data.values().map(func(row):return int(row.id))
	check(not admitted.has(predecessor) and admitted.count(customized)==2 and admitted.count(unchanged)==1,"Canonical native primary-successor/bonus admission retains original duplicate semantics")
	var id:=entry_for(customized); var other_id:=entry_for(unchanged)
	if not check(id>=0 and other_id>=0,"Both customized and unchanged admitted feats have actual native controls"): return {}
	var row: Button=sheet.entry_nodes[id]; var other: Button=sheet.entry_nodes[other_id]
	check(row.size.distance_to(Vector2(331,34))<0.01 and row.image.size==Vector2(32,32) and row.toggle_mode and painter.button_geometry[row.get_instance_id()].resource=="ctl_chr_btn_feat","Source-sized native feat control keeps original checked model and icon geometry")
	var view: int=sheet.view_id; var frozen:=actor.duplicate(true)
	await click(row)
	check(row.button_pressed and feat_requests().size()==1 and sheet.description.get_parsed_text().contains("First server feat text"),"Real feat pointer press selects, fresh-resolves current help and emits exactly one GUI4 intent")
	check(feat_requests().back()=={"kind":"native-panel","panel":"feat","open":true,"featId":customized,"targetId":42,"actorId":42,"areaId":55,"generation":1},"GUI4 intent contains admitted successor ID and current displayed actor/scope")
	var binds:=art.calls; var geometry: int=painter.button_geometry.size()
	ui.receive({"kind":"custom-token","id":9002,"text":"Second server feat text"},1); await frames(); await click(row)
	check(feat_requests().size()==2 and sheet.description.get_parsed_text().contains("Second server feat text"),"Repeated already-selected feat radio refreshes later server custom text and emits another GUI4")
	check(sheet.entry_nodes[id]==row and sheet.view_id==view and art.calls==binds and painter.button_geometry.size()==geometry,"Dynamic feat inspection preserves row/view/artwork without rebuilding the record")
	await click(other); var plain: String=sheet.description.get_parsed_text(); var count:=feat_requests().size()
	ui.receive({"kind":"custom-token","id":9002,"text":"Third server feat text"},1); await click(other)
	check(not plain.is_empty() and sheet.description.get_parsed_text()==plain and feat_requests().size()==count+1,"Unchanged feat help remains stable across repeated clicks while another feat's server token changes")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":description_ref,"text":"Latest active feat override\n[b]literal[/b]\n<CUSTOM9002>"}]},1); await click(row)
	check(sheet.description.get_parsed_text().contains("Latest active feat override") and sheet.description.get_parsed_text().contains("[b]literal[/b]") and not sheet.description.bbcode_enabled,"Fresh active TLK text and literal markup reach the source-skinned feat description")
	var malformed: Dictionary=active.duplicate(true); malformed.orderedRows[customized].FEAT="****"; ui.text.publish_table("feat",malformed)
	desktop.rules.record_errors=["retained diagnostic"]; count=feat_requests().size(); await click(row)
	check(feat_requests().size()==count and desktop.rules.record_feat_definition(customized).is_empty(),"Invalid current GetFeat definition cannot send GUI4 from a still-present old control")
	check(desktop.rules.record_errors==["retained diagnostic"],"Single-row validation does not run another admission projection or overwrite its diagnostics")
	ui.text.publish_table("feat",active)
	var valid_zero: Dictionary=active.duplicate(true); valid_zero.orderedRows[customized].FEAT=0; ui.text.publish_table("feat",valid_zero)
	check(not desktop.rules.record_feat_definition(customized).is_empty(),"Canonical existing name-availability policy retains valid numeric FEAT zero")
	ui.text.publish_table("feat",active)
	var samples: Array=[]; count=feat_requests().size()
	for iteration in 200:
		var began:=Time.get_ticks_usec(); row.pressed.emit(); samples.append((Time.get_ticks_usec()-began)/1000.0)
	samples.sort()
	check(feat_requests().size()==count+200 and samples[189]<8.0 and sheet.entry_nodes[id]==row and art.calls==binds,"200 warm inspections each emit GUI4 below8ms p95 without whole-list reconstruction")
	check(actor==frozen and skill_requests().is_empty(),"Feat inspection neither mutates received memberships nor emits skill GUI3")
	var retired:={"kind":"sheet-select","viewId":view,"page":2,"entryId":id}; count=feat_requests().size(); actor.inventoryStats.fields128=[unchanged]; desktop.refresh_sheet(); await frames()
	admitted=sheet.entry_data.values().map(func(entry):return int(entry.id))
	check(admitted.has(predecessor) and not admitted.has(customized),"Removing bonus/temporary ownership retires its successor and restores the primary native row")
	desktop.input_request(retired); check(feat_requests().size()==count and (not is_instance_valid(row) or not row.current()),"Retired private row/view cannot issue an inspection after membership refresh")
	check(desktop.rules.record_entries({"inventoryStats":{"fields118":[],"fields128":[]},"playerState":{"feats":[customized],"bonusFeats":[unchanged]}},2).is_empty(),"Present-empty authoritative primary/bonus lists suppress stale fallback memberships")
	check(desktop.rules.record_entries({"inventoryStats":{"feats":[{"id":unchanged,"flag":false}]},"playerState":{"feats":[]}},2).is_empty(),"Present-empty player primary suppresses inventory-record fallback")
	var fallback: Array=desktop.rules.record_entries({"inventoryStats":{"feats":[{"id":unchanged,"flag":false}]}},2)
	check(fallback.size()==1 and fallback[0].id==unchanged,"Inventory fallback admits disclosed feat records without inventing a flag requirement")
	var temporary:={"playerState":{"feats":[],"bonusFeats":[customized]}}
	check(desktop.rules.record_entries(temporary,2).size()==1,"Temporary/bonus player fallback is admitted by the canonical native projection")
	temporary.playerState.bonusFeats=[]; check(desktop.rules.record_entries(temporary,2).is_empty() and desktop.rules.record_entries({},2).is_empty(),"Temporary removal and missing memberships never manufacture feat zero")
	var replacement:=actor.duplicate(true); replacement.id=43; replacement.inventoryStats.fields118=[customized]; replacement.inventoryStats.fields128=[]; desktop.objects={43:replacement}; ui.text.objects=desktop.objects; desktop.actor_id=43; desktop.refresh_sheet(); await frames()
	var replacement_id:=entry_for(customized); await click(sheet.entry_nodes[replacement_id])
	check(feat_requests().back().targetId==43 and feat_requests().back().actorId==43,"Replacement displayed actor receives its own GUI4 target rather than the previous actor")
	count=feat_requests().size(); sheet.close_sheet(); desktop.input_request({"kind":"sheet-select","viewId":sheet.view_id,"page":2,"entryId":replacement_id})
	check(feat_requests().size()==count,"Closing the native feat page retires inspection admission")
	var model_hashes: Dictionary={}
	for name in Plan.RESOURCES: model_hashes[name]=digest(catalog.read_resource(name,2002))
	return {"models":model_hashes,"customized_feat":customized,"unchanged_feat":unchanged,"predecessor":predecessor,"description_strref":description_ref,"selection_ms":{"p50":samples[99],"p95":samples[189],"max":samples.back(),"samples":samples.size()},"physical_input":true,"raster":"Controlled8x8RGBA8","font":"Godot fallback; original named bindings preserved","skin":skin.snapshot()}
