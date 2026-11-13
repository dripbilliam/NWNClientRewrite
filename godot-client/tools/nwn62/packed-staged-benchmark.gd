extends "res://tests/nwn62_publication_benchmark.gd"
func run() -> void:
	Engine.max_fps=60
	var file:=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ)
	if file==null:print("Sealed original tile unavailable");quit(2);return
	var original: Dictionary=file.get_var(false);file.close()
	var authored:=bundle("d");authored.value.nodes=authored.value.nodes.slice(0,2)
	for index in 256:
		var row: Dictionary=authored.value.nodes[1].duplicate(true);row.name="copy_"+str(index);row.parent=0;row.position=[index*0.001,0.0,0.0];authored.value.nodes.append(row)
	var cases:=[{"name":"original-tile","bundle":original,"placements":24},{"name":"authored-257-mesh","bundle":authored,"placements":8}]
	for item in cases:observations.append(await measure(item.bundle,true,int(item.placements),str(item.name)))
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"mode":"packed-staged" if Template.configured_packed_staged() else "restored-recipe","scope":"Same source/engine control-vs-explicit-packed-staged original tile and authored graph; 3ms shared ledger, 60Hz, full retained placement output. Callback/unit active CPU plus first/full latency; no whole-client FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var output:=FileAccess.open(argument.substr(9),FileAccess.WRITE);output.store_string(JSON.stringify(result,"  "));output.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
