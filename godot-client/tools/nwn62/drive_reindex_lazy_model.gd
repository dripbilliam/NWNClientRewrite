extends "res://tools/nwn62/drive_reindex_component.gd"
const Candidate=preload("res://systems/native_render/drive_collision_indexed.gd")
func table_semantics()->Dictionary:
	var control:=ControlScript.new();var candidate:=Candidate.new()
	var edge_rows: Array=[{}, {"Model":"Fallback"},{"ModelName":"****","Model":"Fallback"},{"ModelName":"","Model":"Fallback"},{"modelname":"MiXeD","Model":"Fallback"},{"ModelName":null,"Model":"Fallback"},{"MODELNAME":"Upper","modelname":"Lower"},{"ModelName":"Direct","modelname":"Lower","Model":"Fallback"},{"model":"LowerFallback"},{"Model":null}]
	var matched:=0
	for row in edge_rows:
		control.tables={"placeables":{"orderedRows":[row]},"genericdoors":{"orderedRows":[row]},"doortypes":{"orderedRows":[row]}}
		candidate.tables=control.tables.duplicate(true)
		for object in [{"objectType":9,"staticState":{"appearance":0}},{"objectType":10,"replicated":{"doorType":0,"genericType":0,"doorOpenState":2}},{"objectType":10,"replicated":{"doorType":1,"doorOpenState":2}}]:
			check(control.descriptor(object)==candidate.descriptor(object),"missing/empty/****/mixed-case/null model cell semantics")
			matched+=1
	var door_data=JSON.parse_string(FileAccess.get_file_as_string("res://tools/native_parity/doors/asset-source-tables-v1.json"))
	var placeable_data=JSON.parse_string(FileAccess.get_file_as_string("res://tools/native_parity/visibility/blocker-asset-base-table-v1.json"))
	var generic_rows: Array=door_data.tables[0].rows;var door_rows: Array=door_data.tables[1].rows
	var placeable_rows: Array=placeable_data.table.candidates
	control.tables={"placeables":{"orderedRows":placeable_rows},"genericdoors":{"orderedRows":generic_rows},"doortypes":{"orderedRows":door_rows}}
	candidate.tables=control.tables.duplicate(true)
	for i in placeable_rows.size():
		check(control.descriptor({"objectType":9,"staticState":{"appearance":i}})==candidate.descriptor({"objectType":9,"staticState":{"appearance":i}}),"installed placeable metadata row")
		matched+=1
	for i in generic_rows.size():
		check(control.descriptor({"objectType":10,"replicated":{"doorType":0,"genericType":i,"doorOpenState":i%3}})==candidate.descriptor({"objectType":10,"replicated":{"doorType":0,"genericType":i,"doorOpenState":i%3}}),"installed generic door row")
		matched+=1
	for i in door_rows.size():
		check(control.descriptor({"objectType":10,"replicated":{"doorType":i,"doorOpenState":i%3}})==candidate.descriptor({"objectType":10,"replicated":{"doorType":i,"doorOpenState":i%3}}),"installed door type row")
		matched+=1
	control.free();candidate.free()
	return {"edge_rows":edge_rows.size(),"installed_placeables":placeable_rows.size(),"installed_genericdoors":generic_rows.size(),"installed_doortypes":door_rows.size(),"matched":matched}
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var legs: Array=[]
	for count in [1918,1919]:
		for source in [ControlScript,Candidate,Candidate,ControlScript]:
			var row:=leg(source,count,"none")
			legs.append({"count":count,"mode":"control" if source==ControlScript else "lazy-model","completion_us":row.completion_us,"signature":row.signature,"ready":row.ready,"sources":row.sources,"groups":row.group_count,"entries":row.entries})
			await process_frame
		for i in range(legs.size()-4,legs.size()):check(legs[i].ready and legs[i].signature==legs[legs.size()-4].signature,"lazy model ordered output parity")
	var semantics:=table_semantics()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":[],"semantics":semantics,"scope":"Production lazy fallback model lookup versus frozen pre-edit source; authored 1918/1919-source SceneTree plus installed base table metadata, no FPS or live asset result"}
	for row in legs:
		var copy: Dictionary=row.duplicate();copy.erase("signature");report.legs.append(copy)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
