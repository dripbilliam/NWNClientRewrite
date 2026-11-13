extends SceneTree
# Actual frozen DLL calls compared with retained original-instruction outputs.
# No Win32 sample(), original process, timer worker or clock lifecycle runs.
var checks:=0
var failures: Array=[]
var compared_configurations:=0
var compared_defined:=0
var compared_unavailable:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func finish(report: String) -> void:
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:quit(2);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"configurations":compared_configurations,"defined_rows":compared_defined,"unavailable_rows":compared_unavailable,"scope":"Actual private DLL ctor+direct-Real conversion versus original16dd60 prefix/16e110 instruction oracle under controlled inputs. No cached-thread phase, live game, gameplay, GPU, pixels or performance acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
func words(hex: String) -> Dictionary:
	return {"hi":hex.substr(0,8).hex_to_int(),"lo":hex.substr(8,8).hex_to_int()}
func equal_words(actual: Variant,expected: Dictionary) -> bool:
	return actual is Dictionary and actual.get("hi")==int(expected.hi) and actual.get("lo")==int(expected.lo)
func integer_divisor(raw: String) -> Dictionary:
	# These original configs use positive frequency<=INT64_MAX. Its /1e6
	# stored divisor fits signed64; parsing the decimal string remains exact.
	var value: int=raw.to_int()
	return {"hi":(value>>32)&0xffffffff,"lo":value&0xffffffff}
func branch(config: Dictionary) -> String:
	return str({"double":"qpc-f64","integer":"qpc-integer","fallback":"tick32"}.get(str(config.native.branch),"unsupported"))
func input(config: Dictionary,row: Dictionary={}) -> Dictionary:
	# JSON-safe source descriptors become strict INT32/DWORD/uint64 limbs.
	# Unused fallback placeholders are authored inputs, never measurements.
	var received: Dictionary=row.get("input",{})
	var qpc_branch: bool=int(config.control.qpfResult)==1
	var qpc_hex: Variant=received.get("qpcBitsHex")
	return {"qpf_result":int(config.control.qpfResult),"frequency":words(str(config.control.frequencyBitsHex)),"qpc":words(qpc_hex if qpc_hex is String else "0000000000000000"),"qpc_ok":bool(received.get("qpcSucceeds",true)) if qpc_branch else false,"tick_ms":int(received.get("tickDword",0))}
func configuration_matches(actual: Dictionary,config: Dictionary,label: String) -> void:
	var native: Dictionary=config.native
	check(int(actual.get("qpf_result",-99))==int(native.qpfResult),label+" raw native QPF result remains exact")
	check(str(actual.get("configuration_branch",""))==branch(config),label+" original constructor selected branch")
	check(actual.get("frequency_known")==native.frequencyKnown,label+" original known-frequency distinction")
	if native.frequencyKnown:check(equal_words(actual.get("frequency"),words(str(native.frequencyBitsHex))),label+" exact native stored frequency bits")
	else:check(actual.get("frequency")==null,label+" unknown frequency remains null")
	if str(native.branch)=="double":
		check(actual.get("divisor_known")==true and actual.get("divisor_kind")=="binary64-bits" and equal_words(actual.get("divisor"),words(str(native.divisorBitsHex))),label+" exact original binary64 divisor bytes")
	elif str(native.branch)=="integer":
		check(actual.get("divisor_known")==true and actual.get("divisor_kind")=="uint64" and equal_words(actual.get("divisor"),integer_divisor(str(native.integerDivisorDecimal))),label+" exact original integer divisor")
	else:check(actual.get("divisor_known")==false and actual.get("divisor_kind")=="none" and actual.get("divisor")==null,label+" fallback has no constructed divisor")
	# Unicorn does not reproduce physical FP exception-status flags for every
	# CVTT-indefinite case. Compare control bits only; never seeded scratch/RAX.
	check(int(actual.get("configuration_mxcsr_control",-1))==(int(config.mxcsrBefore)&0xffc0),label+" original configured MXCSR control")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	check(ClassDB.class_exists("NwnClockSourceCandidate"),"Frozen private clock candidate is registered")
	if not ClassDB.class_exists("NwnClockSourceCandidate"):finish(args.report);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or not oracle.get("configurations") is Array or not oracle.get("rows") is Array:check(false,"Complete original oracle is readable");finish(args.report);return
	check(oracle.get("success")==true and oracle.get("method")=="original-instructions-unicorn" and oracle.configurations.size()==11 and oracle.rows.size()==117,"Accepted original matrix and method")
	var configurations: Dictionary={}
	for config in oracle.configurations:
		var id: String=str(config.id)
		if configurations.has(id) or branch(config)=="unsupported":check(false,"Unique supported original configuration: "+id);finish(args.report);return
		configurations[id]=config
		var authored: Dictionary=input(config)
		var before: String=JSON.stringify(authored)
		var actual: Dictionary=ClassDB.class_call_static("NwnClockSourceCandidate","convert_for_test",authored)
		configuration_matches(actual,config,id)
		check(JSON.stringify(authored)==before,id+" constructor test input remains unchanged")
		compared_configurations+=1
	for row in oracle.rows:
		var id: String=str(row.id);var config: Dictionary=configurations.get(str(row.configurationId),{})
		if config.is_empty():check(false,"Original row has its observed constructor: "+id);finish(args.report);return
		var authored: Dictionary=input(config,row)
		var before: String=JSON.stringify(authored)
		var actual: Dictionary=ClassDB.class_call_static("NwnClockSourceCandidate","convert_for_test",authored)
		configuration_matches(actual,config,id)
		check(actual.get("source")=="native-direct-real-candidate-v1" and actual.get("phase")=="direct-real-only" and actual.get("input_origin")=="authored-constructor-real-pair",id+" scoped pure conversion entry")
		check(JSON.stringify(authored)==before,id+" source input remains immutable")
		check(int(actual.get("mxcsr_control",-1))==(int(row.mxcsrBefore)&0xffc0),id+" original Real control state")
		if row.defined:
			check(actual.get("ready")==true and actual.get("branch")==branch(config),id+" native defined branch is available")
			check(equal_words(actual.get("microseconds"),row.result),id+" exact original RAX unsigned hi/lo")
			if str(config.native.branch)=="fallback":check(actual.get("qpc_attempted")==false and actual.get("qpc_known")==false and actual.get("qpc")==null and actual.get("tick_ms_known")==true and actual.get("tick_ms")==int(row.input.tickDword),id+" fallback never invents a QPC read")
			else:check(actual.get("qpc_known")==true and equal_words(actual.get("qpc"),words(str(row.input.qpcBitsHex))) and actual.get("tick_ms_known")==false and actual.get("tick_ms")==null,id+" exact controlled QPC with no TickCount substitution")
			compared_defined+=1
		else:
			check(row.result==null and row.get("diagnosticOnly")==true,id+" oracle explicitly has no defined return value")
			check(actual.get("ready")==false and actual.get("branch")=="qpc-unavailable" and not actual.has("microseconds"),id+" failed QPC returns unavailable with no fabricated microseconds")
			check(actual.get("qpc_known")==false and actual.get("qpc")==null and actual.get("tick_ms_known")==false and actual.get("tick_ms")==null,id+" undefined QPC never borrows seeded scratch or fallback")
			compared_unavailable+=1
	check(compared_configurations==11 and compared_defined==113 and compared_unavailable==4,"Every observed configuration and row compared exactly")
	finish(args.report)
