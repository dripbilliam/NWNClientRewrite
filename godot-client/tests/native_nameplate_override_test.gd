extends "res://tests/native_nameplate_anchor_test.gd"
func data_checks(text) -> void:
	super.data_checks(text)
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="): path=arg.trim_prefix("--oracle=")
	var observed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var table: Array=[]
	for index in 6: table.append({"STRING_REF":6409+index}); text.overrides[6409+index]="D"+str(6409+index)
	text.publish_table("damagelevels",{"orderedRows":table})
	for row in observed.rows:
		if int(row.damage)>5: continue
		var object:=creature(); object.replicated.name={"text":"Native Creature"}; object.replicated.reaction=int(row.reaction); object.replicated.damageLevel=int(row.damage)
		object.replicated.light={"field270":row.override,"field278":"<c"+String.chr(255)+String.chr(1)+String.chr(1)+">Override</c>"}
		check(PlateState.project(object,42,text).caption==Rich.parse(str(row.output.raw)),"One native caption matches original mode/reaction/damage "+str([row.override,row.reaction,row.damage]))
	var object:=creature(); object.replicated.light={"field270":1,"field278":"Plain replacement"}; var prior:=PlateState.signature(object,42,text.revision)
	var value:=PlateState.project(object,42,text)
	check(value.caption.text=="Plain replacement" and value.caption_color==Color.WHITE and value.available,"Original replacement removes normal identity/injury text and uses the original white default")
	object.replicated.light.field278=""; check(not PlateState.project(object,42,text).available,"An empty replacement hides the caption without restoring undisclosed/default text")
	check(prior!=PlateState.signature(object,42,text.revision),"In-place custom caption text changes invalidate the actual HUD signature")
	prior=PlateState.signature(object,42,text.revision); object.replicated.light.field270=2
	check(prior!=PlateState.signature(object,42,text.revision),"Changing only the custom caption mode invalidates the HUD signature")
	object.replicated.light={"field270":1,"field278":"[b]literal[/b]\nSecond line"}; var before:=object.duplicate(true); value=PlateState.project(object,42,text)
	check(value.caption.text=="[b]literal[/b]\nSecond line" and object==before,"Server BBCode stays literal and received state is never rewritten while composing a caption")
	object.replicationRemoved=true; check(not PlateState.project(object,42,text).available,"Custom caption cannot revive a removed creature")
	for index in 6: text.overrides.erase(6409+index)
	text.publish_table("damagelevels",{"orderedRows":[{"STRING_REF":700001}]})
func source_checks(plate,catalog) -> void:
	super.source_checks(plate,catalog)
	var saved: Dictionary=plate.data.duplicate(true); var identity: int=plate.caption.get_instance_id(); var value:=saved.duplicate(true)
	value.caption=Rich.parse("[b]literal[/b]\nNative replacement"); value.caption_color=Color.WHITE; plate.set_content(value)
	check(plate.caption.get_instance_id()==identity and not plate.caption.bbcode_enabled and plate.caption.get_parsed_text()==value.caption.text,"Actual original-style label displays one literal multiline replacement without rebuilding its text control")
	var old: String=plate.backdrop.resource; value.caption=Rich.parse("Long native caption line\n".repeat(20)); plate.set_content(value)
	check(plate.bubble_resource!=old and plate.placeholder.visible and not plate.backdrop.visible,"A larger caption cannot show an old ready backdrop while the matching source model is pending")
	plate.set_content(saved)
	check(plate.caption.get_instance_id()==identity and plate.caption.get_parsed_text()==saved.caption.text and not plate.placeholder.visible and plate.backdrop.visible,"Restoring normal caption reuses the cached matching source mesh and existing label immediately")
