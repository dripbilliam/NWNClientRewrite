extends "res://tests/native_nameplate_override_test.gd"
func data_checks(text) -> void:
	super.data_checks(text)
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--object-oracle="): path=arg.trim_prefix("--object-oracle=")
	var observed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(observed.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.rows.size()==92 and observed.identities.size()==4,"Object-caption corpus pins the original binary and all four RTTI/vtable owners")
	for row in observed.rows:
		var object:={"id":43,"objectType":row.objectType,"replicated":{"name":{"text":row.name},"reaction":1,"interactionFlags":[1,row.redFlag,0,0,0]}}
		if int(row.objectType)==6: object.item={"name":{"text":row.name},"field2b8":row.mode,"field2c0":row.custom}
		else: object.replicated.light={"field270":row.mode,"field278":row.custom}
		var before:=object.duplicate(true); var value:=PlateState.project(object,42,text)
		var expected: Dictionary=Rich.parse(str(row.output.raw)) if row.output!=null else {"text":""}
		check((not value.available if row.output==null else value.caption==expected and value.available==not str(expected.text).is_empty() and value.caption_color==Color.WHITE) and object==before,"Original object caption "+str([row.kind,row.redFlag,row.mode,row.name,row.custom]))
	var prop:={"id":43,"objectType":9,"replicated":{"name":{"text":"Chest"},"reaction":1}}
	check(PlateState.project(prop,42,text).color==Color("#8080ff"),"Creation's legacy reaction is not mistaken for placeable client+1a0")
	var signature:=PlateState.signature(prop,42,text.revision); prop.replicated.interactionFlags=[0,1,0,0,0]
	check(PlateState.project(prop,42,text).color==Color("#ff0101") and PlateState.signature(prop,42,text.revision)!=signature,"Second received interaction BOOL changes caption color and invalidates the live signature")
	var item:={"id":44,"objectType":6,"item":{"name":{"text":"Item"},"field2b8":1,"field2c0":"Initial"},"replicated":{}}
	signature=PlateState.signature(item,42,text.revision); item.item.field2c0="Changed"
	check(PlateState.project(item,42,text).caption.text=="Changed" and PlateState.signature(item,42,text.revision)!=signature,"Active item override metadata invalidates cached world caption content")
	item.replicated.light={"field270":1,"field278":"New generic update"}
	check(PlateState.project(item,42,text).caption.text=="Changed","Canonical received item storage takes precedence over a stale generic-world alias")
	item.replicationRemoved=true; check(not PlateState.project(item,42,text).available,"Item replacement cannot revive removed world identity")
	var rows:={42:{"type":5,"eligible":true},43:{"type":9,"eligible":true},44:{"type":6,"eligible":true},45:{"type":10,"eligible":true},46:{"type":7,"eligible":true}}
	check(PlateState.visible_ids(rows.keys(),rows)==[42] and PlateState.visible_ids(rows.keys(),rows,44)==[42,44] and PlateState.visible_ids(rows.keys(),rows,45)==[42] and PlateState.visible_ids(rows.keys(),rows,46)==[42],"Ground items retain hover captions while door/transition selection remains independent of original no-op caption slots")
func source_checks(plate,catalog) -> void:
	super.source_checks(plate,catalog)
	var saved: Dictionary=plate.data.duplicate(true); var text:=Talk.new(); var value:=PlateState.project({"id":43,"objectType":6,"item":{"name":{"text":"Gold item"},"field2b8":2,"field2c0":"Prefix\n"}},42,text)
	plate.set_content(value)
	check(plate.caption.get_parsed_text()=="Prefix\nGold item" and not plate.portrait_frame.visible and plate.caption.position.x==0,"Actual item label displays composed multiline text without a creature portrait or indent")
	plate.set_content(PlateState.project({"id":43,"objectType":9,"replicated":{"name":{"text":"Chest"},"light":{"field270":1,"field278":""}}},42,text))
	check(not plate.visible and plate.caption.get_parsed_text().is_empty(),"Actual empty placeable replacement hides the control and releases its previously displayed text")
	plate.set_content(saved); text.close()
