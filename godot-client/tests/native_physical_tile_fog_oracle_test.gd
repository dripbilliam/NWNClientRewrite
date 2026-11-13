extends SceneTree
# Expected states come from actual original0dc140/setter instructions. The
# fixture seeds native POD fields, including diagnostic states not reachable
# from ordinary constructors, instead of adding a public mutable-state API.
const Fog=preload("res://tools/native_parity/visibility/physical_tile_fog.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func value(word_value: Variant) -> float:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_u32(0,int(word_value));return bytes.decode_float(0)
func word(value_float: float) -> int:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value_float);return bytes.decode_u32(0)
func _initialize() -> void:run.call_deferred()
func run_case(input: Dictionary,label: String) -> void:
	var fog:=Fog.new();fog.configure([1,2,3],func(scope):return scope==[1,2,3])
	for row in input.initial:
		var id:=int(row.token);fog.register_tile(id,[100,id])
		# Test-only seed of the exact original memory fixture. Production still
		# constructs factor1 and has only native setters/ordered advancement.
		fog._tiles[id].fogged=int(row.fogged)!=0
		fog._tiles[id].factor=value(row.factor_word)
	for index in input.trace.size():
		var step: Dictionary=input.trace[index];var accepted: Dictionary
		if step.kind=="collect":accepted=fog.advance_collected(PackedInt64Array([int(step.token)]),value(step.renderer_delta_t_word))
		else:
			# The independently recovered BSPSearch target is an explicit input
			# here. Its actual resolver has separate equality/far-fallback tests.
			var id:=int(step.target_token)
			accepted=fog.receive_fog(id,[100,id],step.flag)
		check(accepted.available,label+" operation "+str(index)+" accepted")
		for expected in step.expected:
			var id:=int(expected.token);var state: Dictionary=fog.tile_view(id,[100,id])
			check(state.available and word(state.factor)==int(expected.factor_word),label+" exact original C8 word "+str(index)+"/"+str(id))
			check(state.fogged==(int(expected.fogged)!=0),label+" exact original C4 flag "+str(index)+"/"+str(id))
	fog.close()
func run() -> void:
	var corpus: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/native_tile_fog_callback_oracle.json"))
	check(corpus is Dictionary and corpus.get("binary_sha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original instruction corpus identity")
	if not corpus is Dictionary:quit(1);return
	check(corpus.callback_cases.size()==96 and corpus.setter_cases.size()==6,"Full retained callback/setter corpus is present")
	for index in corpus.callback_cases.size():run_case(corpus.callback_cases[index],"callback "+str(index))
	for index in corpus.setter_cases.size():run_case(corpus.setter_cases[index],"setter "+str(index))
	print("NATIVE_PHYSICAL_TILE_FOG_ORACLE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
