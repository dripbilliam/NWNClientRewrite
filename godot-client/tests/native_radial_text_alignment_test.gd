extends SceneTree
const Text=preload("res://systems/native_data/radial_text.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<24: failures.append(label)
func _initialize() -> void: call_deferred("run")
func word(values: Array) -> String: return PackedFloat32Array(values).to_byte_array().hex_encode()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-radial-text-alignment-v1.json"))
	check(corpus.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.rows.size()==7680,"Original complete alignment/root instruction corpus")
	for n in corpus.rows.size():
		var row: Dictionary=corpus.rows[n]; var c: Dictionary=row.input; var dimensions:=Vector2(c.size[0],c.size[1])
		var a:=Text.alignment(int(c.slot),Vector2(c.origin[0],c.origin[1]),Vector2(c.screen[0],c.screen[1]),dimensions,bool(c.hide),bool(c.center),int(c.mode),float(c.scale))
		check(word([a.x,a.y])==word(row.alignment),"Exact original edge alignment "+str(n)+" "+str(a)+" != "+str(row.alignment))
		var offset:=Text.root_offset(a,dimensions)
		check(word([offset.x,offset.y,0.0])==word(row.root),"Exact original bubble root "+str(n)+" "+str(offset)+" != "+str(row.root))
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_rows":corpus.rows.size(),"network_connections":0,"scope":"Exact f32 comparison against unchanged original FixAttachedText and FixAlignment instructions: all8 slots, corners/center, widths/heights, GUI scales, preview modes, hidden icons and centered text. Font wrapping and actual graphical binding require separate checks."},"\t")); file.close()
	print("NATIVE_RADIAL_TEXT_ALIGNMENT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
