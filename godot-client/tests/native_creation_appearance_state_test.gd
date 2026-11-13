extends SceneTree
const State=preload("res://systems/native_data/creation_appearance_state.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<24:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.success and oracle.cases==480 and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original pinned instruction corpus is complete")
	var timings:Array=[]
	for row in oracle.rows:
		var input:Dictionary=row.input;var result:Dictionary={};var begin:=Time.get_ticks_usec()
		if str(input.operation).begins_with("body"):
			result=State.phenotype_step(int(input.phenotype),int(input.mask),1 if input.operation=="bodyNext" else -1)
		else:
			var exists:Dictionary={}
			for id in input.exists:exists[int(id)]=true
			begin=Time.get_ticks_usec();result=State.head_step(int(input.head),exists,1 if input.operation=="headNext" else -1)
		timings.append(Time.get_ticks_usec()-begin)
		check(result.get("available",false),"Native finite arrow case remains available")
		check(result.get("value")==row.get("phenotype" if str(input.operation).begins_with("body") else "head"),"Original branch/width/Exists matches "+str(input.operation))
	var context:={"appearanceValid":true,"modelType":"P","customizeMode":0,"enabledPhenotypes":-1,"headIndexComplete":true,"heads":{1:true,2:true},"paletteSizes":{"skin":32,"hair":64},"value":{"phenotype":31,"head":1,"skin":1,"tattooPattern":0,"bodyParts":[]}}
	var state:=State.new();state.reset(context)
	var admission:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.gate))
	check(admission.success and admission.cases==16 and admission.binarySha256==oracle.binarySha256,"Original CompareNoCase BOOL and exact Appearance enable branch are pinned")
	for row in admission.rows:
		var gate_context:=context.duplicate(true);gate_context.modelType=row.input.modelType;gate_context.appearanceValid=row.input.appearanceValid;state.reset(gate_context)
		check(state.editable("head")==row.enabled,"Original model-type/validity branch matches "+str(row.input))
	var palette:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.palette))
	check(palette.success and palette.cases==195 and palette.binarySha256==oracle.binarySha256,"Original color release binary32/range/callback corpus is pinned")
	for row in palette.rows:
		check(State.palette_index(Vector2(row.worldDelta[0],row.worldDelta[1]))==row.index,"Original palette release conversion matches "+str(row.pixel))
	state.reset(context)
	check(state.step("body",1) and state.value.phenotype==32,"Verified initial BYTE increment/bit alias is not incorrectly clamped to32 rows")
	check(context.value.phenotype==31,"Staged edits cannot mutate input draft")
	check(state.step("head",-1) and state.value.head==2,"Head Previous wraps at first missing resource")
	check(state.color("skin",31) and not state.color("skin",32),"Color uses actual active palette count")
	check(not state.color("tattoo1",0),"Missing palette is unavailable rather than invented zero")
	var detached:=state.snapshot();detached.head=99;check(state.value.head==2,"Returned snapshot is detached")
	context.customizeMode=1;state.reset(context);check(not state.editable("clothes") and state.editable("head"),"Existing-character mode disables clothing without disabling head")
	context.modelType="S";state.reset(context);check(not state.editable("head") and not state.color("skin",1),"Native non-P model disables appearance controls")
	context.modelType="P";context.appearanceValid=false;state.reset(context);check(not state.step("head",1),"Missing MODELTYPE validity never becomes editable")
	check(not State.phenotype_step(255,0,1).available,"Original nonterminating malformed mask remains explicit unavailable")
	var parts:Array=[]
	for index in 19:parts.append(1)
	var tattoo:=State.tattoo_parts(15,parts)
	check(tattoo.available and tattoo.parts[7]==2 and tattoo.parts[2]==2 and tattoo.parts[12]==2 and tattoo.parts[10]==2 and tattoo.parts[8]==1 and tattoo.skinParts[8]==0,"Tattoo mask changes only original unarmored/eligible slots")
	check(parts.all(func(part):return part==1),"Tattoo preview cannot mutate caller body parts")
	parts.fill(9);tattoo=State.tattoo_parts(15,parts);check(tattoo.parts==parts,"Protected clothing parts are retained")
	check(not State.tattoo_parts(0,[]).available,"Missing body parts do not receive a fabricated complete model")
	timings.sort();var perf:={"cases":timings.size(),"medianUs":timings[timings.size()/2],"p95Us":timings[int(timings.size()*.95)],"maxUs":timings[-1]}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timing":perf,"scope":"Detached appearance arrow/palette/ownership state versus480 unchanged-original cases. Tattoo source semantics are not yet emulator-compared; no active screen, preview, BIC or server acceptance."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
