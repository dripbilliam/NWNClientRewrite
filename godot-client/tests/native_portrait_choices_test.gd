extends "res://tests/native_particle_schedule_test.gd"
const Resources=preload("res://systems/native_data/portrait_resources.gd")
const Choices=preload("res://systems/native_data/portrait_choices.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Recording=preload("res://systems/native_data/resource_recording.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Session=preload("res://systems/native_data/session_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
func oracle_provider(tga: int,dds: int,calls: Array) -> Callable:
	return func(name: String,type: int):
		calls.append([name.to_lower(),type]); var suffix:="tsmlh".find(name.right(1).to_lower())
		return suffix>=0 and ((tga if type==3 else dds)&(1<<suffix))!=0
func normalized(calls: Array) -> Array: return calls.map(func(value):return [str(value[0]).to_lower(),int(value[1])])
func image(directory: String,name: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join(name),FileAccess.WRITE); file.store_buffer(PackedByteArray()); file.close()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracles") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.oracles).path_join("native-portrait-candidates-v1.json")))
	var chooser: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.oracles).path_join("native-portrait-chooser-v1.json")))
	check(original.target==BINARY_SHA and chooser.target==BINARY_SHA,"Both original-instruction corpora identify the pinned binary")
	for row in original.cases:
		var calls: Array=[]; var result:=Resources.sized("portrait_",int(row.size),oracle_provider(int(row.tgaMask),int(row.ddsMask),calls))
		check(result==str(row.result).to_lower() and calls==normalized(row.calls),"Original size result and exact TGA/DDS Exists sequence "+str([row.size,row.tgaMask,row.ddsMask]))
	for row in chooser.admission:
		var calls: Array=[]; var admitted:=Resources.available("portrait_",oracle_provider(int(row.tgaMask),int(row.ddsMask),calls)) and not bool(row.duplicate)
		check(int(admitted)==int(row.added) and calls==normalized(row.calls),"Original add admission/dedup boundary "+str([row.tgaMask,row.ddsMask,row.duplicate]))
	for row in chooser.race:
		var result:=Choices.ordered([{"BaseResRef":"candidate_","Sex":0,"Race":int(row.value)},{"BaseResRef":"match_","Sex":0,"Race":int(row.selected)}],0,int(row.selected))
		check((result[0 if int(row.passIndex)==0 else 1]=="po_candidate_")==bool(row.admitted),"Original race-pass ordering "+str(row))
	for row in chooser.suffix:
		if int(row.byte)==0: continue # NUL is not a Windows filename or a Godot String character.
		var result:=Choices.ordered([],0,6,Callable(),["p"+String.chr(int(row.byte))+".tga"])
		check((not result.is_empty())==bool(row.admitted),"Original custom M/m suffix byte "+str(row.byte))
	var fixture:=str(args.report)+".files"; var catalog:=Catalog.new()
	for folder in ["install","profile","workshop","override"]: DirAccess.make_dir_recursive_absolute(fixture.path_join(folder))
	for name in ["installm.tga","po_human_m.tga","po_elf_s.tga","po_halff_m.dds","po_plot_m.tga","po_female_m.tga"]: image(fixture.path_join("install"),name)
	for name in ["userm.tga","userh.tga","po_plot_m.tga","po_female_m.tga"]: image(fixture.path_join("profile"),name)
	image(fixture.path_join("workshop"),"modm.dds"); image(fixture.path_join("override"),"not_a_portraitm.tga"); image(fixture.path_join("override"),"po_bare_.tga"); image(fixture.path_join("override"),"po_elf_m.ktx")
	check(catalog.mount_directory(fixture.path_join("install"),90000000,[3,2033],"portraitsinstall") and catalog.mount_directory(fixture.path_join("profile"),91000000,[3,2033],"portraits") and catalog.mount_directory(fixture.path_join("workshop"),90999999,[3,2033],"portraits") and catalog.mount_directory(fixture.path_join("override"),12000000),"Real native directory indexes retain selected portrait aliases separately from override textures")
	check(not catalog.portrait_files().has("not_a_portraitm.tga") and catalog.portrait_files().has("modm.dds"),"Unrelated textures stay out while selected Workshop portrait images remain discoverable")
	check(catalog.fork().portrait_files()==catalog.portrait_files(),"Worker fork retains portrait alias membership and order")
	var rows: Array=[{"BaseResRef":"elf_","Race":1,"Sex":0},{"BaseResRef":"human_","Race":6,"Sex":0},{"BaseResRef":"halff_","Race":4,"Sex":0},{"BaseResRef":"human_","Race":6,"Sex":0},{"BaseResRef":"plot_","Race":6,"Sex":0,"Plot":1},{"BaseResRef":"female_","Race":6,"Sex":1},{"BaseResRef":"bare_","Race":6,"Sex":0},{"BaseResRef":"absent_","Race":6,"Sex":0}]
	var before:=rows.duplicate(true); var selected:=Choices.ordered(rows,0,4,catalog.has_resource,catalog.portrait_files())
	check(selected==["po_human_","po_elf_","po_halff_","install","user","mod"],"Half-Elf uses Human first, then physical other-race order and unique permitted custom bases")
	check(rows==before,"Portrait admission never mutates the active table")
	check(Resources.sized("po_elf_",3,catalog.has_resource)=="po_elf_s" and not Resources.available("po_bare_",catalog.has_resource),"Size fallback admits an available neighbor; an unsuffixed texture alone is not a portrait")
	var art:=Art.new(); art.catalog=catalog
	check(art.portrait_resource("po_elf_M")=="po_elf_s","Actual menu artwork uses the same original Exists/size selection as admission, including uppercase size and a competing KTX-only neighbor")
	art.free()
	var rules:=Rules.new(); rules.catalog=catalog; rules.tables={"portraits":{"orderedRows":rows}}; rules.draft={"gender":0,"raceId":4}
	check(rules.portraits()==selected,"The actual native creator consumes the shared original chooser policy")
	var restricted:=Rules.new(); restricted.catalog=catalog; restricted.tables={"portraits":{"orderedRows":rows},"ruleset":{"orderedRows":[{"Label":"CHARGEN_ALLOW_CUSTOM_PORTRAITS","Value":"0"}]}}; restricted.draft={"gender":0,"raceId":4}
	check(restricted.portraits()==["po_human_","po_elf_","po_halff_"],"The current server's custom-portrait rule controls the actual creator")
	var recorder:=Recording.new(); var recorded_path:=fixture.path_join("recorded")
	check(recorder.start(recorded_path,catalog.layers),"Native resource recording starts with selected alias metadata")
	var recording:=recorder.close(); check(recording.complete,"Native alias metadata recording seals")
	var recorded:=Recorded.new(); check(recorded.mount(recorded_path) and recorded.portrait_files()==catalog.portrait_files(),"Sealed native replay preserves actual portrait-file membership without global-raster inference")
	check(Choices.ordered(rows,0,4,recorded.has_resource,recorded.portrait_files())==selected,"Recorded native creator admission agrees without installed/network fallback")
	var manifest_path:=recorded_path.path_join("manifest.json"); var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path)); manifest.erase("portraitFiles")
	var file:=FileAccess.open(manifest_path,FileAccess.WRITE); file.store_string(JSON.stringify(manifest)); file.close()
	var legacy:=Recorded.new(); check(legacy.mount(recorded_path) and legacy.portrait_files().is_empty(),"Older recordings remain readable but do not fabricate unrecorded portrait-directory membership")
	manifest.portraitFiles=["../elsewhere/m.tga"]; file=FileAccess.open(manifest_path,FileAccess.WRITE); file.store_string(JSON.stringify(manifest)); file.close()
	var invalid:=Recorded.new(); check(not invalid.mount(recorded_path),"Malformed recorded portrait filenames are rejected")
	if args.has("install"):
		var profile_path:=fixture.path_join("session-profile"); var mods_path:=fixture.path_join("session-mods")
		image(profile_path.path_join("portraits"),"sourcem.tga"); image(mods_path.path_join("417001/portraits"),"workshopm.dds"); image(profile_path.path_join("override"),"disguisem.tga")
		var descriptor:={"install":args.install,"profileDirectory":profile_path,"modsDirectory":mods_path}
		var live:=Session.prepare(descriptor)
		check(str(live.error).is_empty(),"Production native session setup mounts installed/profile/Workshop portrait sources")
		if str(live.error).is_empty():
			var files: Array=live.catalog.portrait_files()
			check(files.has("sourcem.tga") and files.has("workshopm.dds") and not files.has("disguisem.tga"),"Production setup publishes only selected portrait folders to the creator")
			live.catalog.close_sources()
		descriptor.disabledMods=["417001"]; var other:=Session.prepare(descriptor)
		check(str(other.error).is_empty() and not other.catalog.portrait_files().has("workshopm.dds") and other.catalog.portrait_files().has("sourcem.tga"),"A different session's disabled-mod selection owns its portrait membership")
		other.catalog.close_sources()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"size_cases":original.cases.size(),"admission_cases":chooser.admission.size(),"race_cases":chooser.race.size(),"suffix_cases":chooser.suffix.size()-1,"unrepresentable_suffix_bytes":[0],"selection":selected,"portrait_files":catalog.portrait_files(),"publicConnections":0,"scope":"Original-instruction size/Exists/admission/race/suffix corpora plus actual native creator, scoped native directory indexes, rule isolation, recording and legacy metadata. No GPU, file image decoding, whole Customize UI or original directory/Workshop ordering acceptance."}
	file=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
