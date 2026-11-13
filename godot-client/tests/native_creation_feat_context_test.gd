extends SceneTree
const Context=preload("res://systems/native_data/creation_feat_context.gd")
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const CHOICE_SHA="1d19d1b1f16106583689b28e44f2fbff01043ca4adaa715ebf69d126c42111b6"
const REQUIREMENTS_SHA="c1d83c3a2a1bbfd6dffc607dec6ab86bc09052c7908eff069497669f8b45285c"
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","choice","requirements"]) or FileAccess.file_exists(args.report):quit(2);return
	for kind in ["choice","requirements"]:
		var oracle: String=args[kind];check(FileAccess.get_sha256(oracle)==(CHOICE_SHA if kind=="choice" else REQUIREMENTS_SHA),"Immutable original "+kind+" instruction corpus")
		var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle));check(evidence.target==ORIGINAL and evidence.rows.size()==(480 if kind=="choice" else 360),"Complete original "+kind+" cases and executable identity")
		for at in evidence.rows.size():
			var row: Dictionary=evidence.rows[at];var source: Dictionary=row.case;var before:=JSON.stringify(source);var prepared:=Context.prepare(source)
			var direct:=Choice.evaluate(source) if kind=="choice" else Requirements.evaluate(source,source.feat)
			prepared.feat=Context.requirement_row(prepared.feat)
			if prepared.get("definitions") is Array:prepared.definitions=prepared.definitions.map(func(feat):return Context.requirement_row(feat))
			var indexed:=Choice.evaluate(prepared) if kind=="choice" else Requirements.evaluate(prepared,prepared.feat)
			check(indexed==direct and indexed.ready and indexed.allowed==row.accepted,"Indexed "+kind+" preserves original result and diagnostic order",{"case":at,"indexed":indexed,"direct":direct,"expected":row.accepted})
			check(JSON.stringify(source)==before and not source.has(Context.KEY),"Preparing and evaluating a choice cannot mutate its detached input")
	# The first matching WORD ID owns both independently read native fields.
	# Include case-insensitive access, wrapped IDs/BYTEs and duplicate records.
	var source:={"current":0,"classes":[{"id":4,"level":1,"feats":[{"ID":65538,"LEVEL":258,"LIST":257},{"id":2,"level":1,"List":2}]}],"definitions":[{"valid":false},{"valid":false},{"AllClassesCanUse":0}]}
	var prepared:=Context.prepare(source)
	check(prepared[Context.KEY]=={2:{"List":1,"level":2}},"Index retains first native match and WORD/BYTE conversion")
	check(Choice.flags(prepared,2)==Choice.flags(source,2),"Duplicate class-record classification is unchanged")
	prepared[Context.KEY][2].level=9
	check(source.classes[0].feats[0].LEVEL==258,"Index storage is detached from class records")
	var later:=Context.prepare(source)
	check(later[Context.KEY][2].level==2,"A later operation rebuilds from the current snapshot")
	for current in [-1,1,8]:
		var invalid: Dictionary=source.duplicate();invalid.current=current;var index:=Context.prepare(invalid)
		check(index[Context.KEY].is_empty() and Choice.flags(index,2)==Choice.flags(invalid,2),"Invalid current class does not acquire another class's records")
	var switched: Dictionary=source.duplicate(true);switched.classes.append({"feats":[{"id":2,"List":2,"level":7}]});switched.current=1
	check(Context.prepare(switched)[Context.KEY][2]=={"List":2,"level":7},"Changed class context builds an independent operation index")
	var mixed:={"minstr":13,"MinStr":17,"MINDEX":11,"MinDEX":19};var original:=mixed.duplicate();var compiled:=Context.requirement_row(mixed)
	check(compiled.MINSTR==13 and compiled.MINDEX==11 and compiled.MinStr==17 and compiled.MinDEX==19,"Private aliases retain exact-key priority and first case-insensitive match")
	check(mixed==original and not mixed.has("MINSTR"),"Private field aliases leave raw row keys and values intact")
	check(Context.requirement_row({}).is_empty(),"Unavailable prerequisite fields are not materialized as zero")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"840 complete original CanChooseFeat/prerequisite executions through indexed and fallback paths, exact diagnostic equality, first duplicate/physical conversion/current-class isolation. No server, GPU, native build or live-client claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
