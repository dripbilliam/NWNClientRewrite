extends "res://tests/native_projectile_lifetime_test.gd"
const NativeEvents=preload("res://systems/model_native_animation.gd")
const OriginalActor=preload("res://systems/native_data/actor_model.gd")
func events_equal(actual: Array,expected: Array) -> bool:
	if actual.size()!=expected.size(): return false
	for i in actual.size():
		if float(actual[i].time)!=float(expected[i].time) or str(actual[i].name)!=str(expected[i].name): return false
	return true
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source_path:="res://reports/native-parry-source-events-v1.json"; var oracle_path:="res://reports/native-parry-original-repeated-events-v1.json"
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path)); var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==24,"Original event function target and 24 executions")
	check(oracle.inputSha256==FileAccess.get_sha256(source_path),"Native execution uses independently read active source event records")
	for row in oracle.rows:
		check(NativeEvents.event_names(row.events,float(row.start),float(row.end),int(row.flags))==row.calls,"Original physical callback count/order "+str(row.model)+"/"+str(row.clip)+"/"+str(row.flags))
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original event resources mount read-only")
	var selected: Dictionary={}
	for model in source.models:
		var bytes:=catalog.get_resource(str(model.name),2002); var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
		check(hash.finish().hex_encode()==str(model.sha256),"Independent original resource hash "+str(model.name))
		var parser:=OriginalActor.new(); var parsed:=parser.parse(bytes)
		check(parser.failure.is_empty(),"Native original resource parses "+str(model.name))
		for clip in model.clips:
			var actual: Array=parsed.animations.filter(func(row):return row.name==clip.name)
			check(actual.size()==1 and events_equal(actual[0].events,clip.events),"Native parser retains literal original event entries "+str(model.name)+"/"+str(clip.name))
			if not selected.has(clip.name): selected[clip.name]=clip.events
	var world:=World.new(); world.catalog=catalog; root.add_child(world); world.set_meta("native_particle_random",Random.new())
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world)
	check(await wait_for(func():return owner.ensure_models({"pmh0":true})),"Actual inherited primary-body asset prepares through native workers")
	for name in selected:
		var clips: Array=owner.bundles.pmh0.value.rig_asset.clips.filter(func(row):return row.name==name)
		check(clips.size()==1 and events_equal(clips[0].events,selected[name]),"Native prepared body preserves first original supermodel events "+str(name))
	owner.close(); await settle_retirement(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(oracle_path),"sourceSha256":FileAccess.get_sha256(source_path),"scope":"Independent source hashes/physical event records, native parser/inherited worker metadata and 24 original AnimateEvents executions. Full upper Hit listener mutation, native clock and paired-client effect counts remain separate."},"\t")); file.close()
	print("NATIVE_PARRY_EVENTS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
