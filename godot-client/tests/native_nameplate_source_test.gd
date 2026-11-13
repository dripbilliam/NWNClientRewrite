extends "res://tests/native_nameplate_test.gd"
const Rich=preload("res://systems/native_data/rich_text.gd")
func data_checks(text) -> void:
	super.data_checks(text)
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-nameplate-caption-v1.json").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="): path=arg.trim_prefix("--oracle=")
	var bytes:=FileAccess.get_file_as_bytes(path); var observed: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(observed is Dictionary and observed.target==BINARY_SHA and observed.rows.size()==200,"Pinned unchanged original caption instruction observations")
	if not observed is Dictionary: return
	var table: Array=[]
	for index in 6: table.append({"STRING_REF":6409+index}); text.overrides[6409+index]="D"+str(6409+index)
	text.publish_table("damagelevels",{"orderedRows":table})
	for row in observed.rows:
		# Override order is retained in the original evidence but not accepted by
		# this palette test; its wire/native presentation route remains open.
		if int(row.override)!=0: continue
		var original:=Rich.parse(str(row.output.raw)); var title: Dictionary=original.spans.filter(func(span):return span.text=="Native Creature")[0]; var injury: Dictionary=original.spans.filter(func(span):return str(span.text).begins_with("D"))[0]
		check(PlateState.name_color(int(row.reaction))==Color(str(title.color)) and PlateState.injury_color(int(row.damage))==Color(str(injury.color)),"Unchanged original caption palette "+str([row.reaction,row.damage]))
		if int(row.damage)>5: continue
		var object:=creature(); object.replicated.name={"firstName":{"text":"Native"},"lastName":{"text":"Creature"}}; object.replicated.reaction=int(row.reaction); object.replicated.damageLevel=int(row.damage)
		var value:=PlateState.project(object,42,text); var other:=PlateState.project(object,99,text)
		check(value.name.text==title.text and value.condition.text==injury.text and value.color==Color(str(title.color)) and value.condition_color==Color(str(injury.color)) and other.color==value.color,"Actual native projector preserves original name/injury colors even for the controlled character "+str([row.reaction,row.damage]))
	# Preserve the parent fixture's independent active-server metadata for its
	# actual control/font/input/retirement checks.
	for index in 6: text.overrides.erase(6409+index)
	text.publish_table("damagelevels",{"orderedRows":[{"STRING_REF":700001}]})
