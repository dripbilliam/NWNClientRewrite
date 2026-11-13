extends "res://tests/native_particle_resident_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available(),"Native particle radius diagnostic loads")
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-emitter-admission-observations-v2.json").simplify_path()
	var bytes:=FileAccess.get_file_as_bytes(path); var corpus: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	check(corpus.binarySha256==BINARY_SHA and corpus.radii.size()==105,"Original radius instruction corpus identity")
	var rows:=0
	for row in corpus.radii:
		var input: Dictionary=row.input
		if input.has("target") or input.has("chunks"): continue
		var source:=make_owner(false,"fountain",4,false,false)
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":source.state,"parameters":input,"update":"fountain"},{})
		check(not configured.has("error"),"Native original radius configures "+str(rows))
		var actual: Dictionary=owner.call("dispatch",5,{"source_flags":int(input.get("source_flags",0)),"wind":input.get("wind",[0.0,0.0,0.0])},{})
		check(not actual.has("error") and PackedFloat32Array([float(actual.get("radius",NAN))]).to_byte_array().hex_encode()==row.radius_word,"Exact original radius with ambient wind "+str(rows)+" "+str(actual))
		var effect: Dictionary=owner.call("dispatch",5,{"source_flags":1,"wind":[1000.0,-2000.0,3000.0]},{})
		check(effect.get("radius")==1000.0,"Original effect classification retains1000-unit radius "+str(rows))
		source.providers.clear(); owner=null; rows+=1
	check(rows==96,"Every supported ordinary original radius case was compared")
	var empty: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(empty.call("dispatch",5,{"source_flags":0,"wind":[0,0,0]},{}).has("error"),"Radius rejects unconfigured owner")
	empty=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_rows":rows,"network_connections":0,"scope":"Resident C++ radius matches exact f32 results of unchanged original CalculateRadius61710 for96 ordinary cases with ambient wind. Original target/chunk-specific bounds are not accepted here."},"\t")); file.close()
	print("NATIVE_PARTICLE_WIND_RADIUS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
