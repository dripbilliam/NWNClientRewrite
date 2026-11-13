extends "res://tools/nwn62/drive_reindex_component.gd"
const Candidate=preload("res://tools/nwn62/drive_collision_indexed_descriptor_cache.gd")
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var legs: Array=[]
	for count in [1918,1919]:
		for source in [ControlScript,Candidate,Candidate,ControlScript]:
			var row:=leg(source,count,"none")
			legs.append({"count":count,"mode":"control" if source==ControlScript else "descriptor-cache","completion_us":row.completion_us,"signature":row.signature,"ready":row.ready,"sources":row.sources,"groups":row.group_count,"entries":row.entries})
			await process_frame
		for i in range(legs.size()-4,legs.size()):check(legs[i].ready and legs[i].signature==legs[legs.size()-4].signature,"descriptor cache ordered output parity")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"legs":[],"scope":"Private within-reindex model name reuse; authored 1918/1919-source SceneTree, no original asset or FPS result"}
	for row in legs:
		var copy: Dictionary=row.duplicate();copy.erase("signature");report.legs.append(copy)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
