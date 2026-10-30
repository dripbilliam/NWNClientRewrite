extends RefCounted
# CKeyMappingPanel: load8be080/defaults8befa0/capture8bf920. Native key IDs
# are an input ABI; action names, pages, defaults and captions are server data.
# Data/transaction policy only. This does not install gameplay input bindings.
const FIRST:=37
const LAST:=108
const LABEL_CODES=[10,11,48,49,50,51,52,44,45,40,41,42,43,53,54,55,56,57,58,59,60,61,62,46,47,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104]
const SCAN_CODES=[80,79,82,81,75,78,86,87,70,73,76,74,77,98,89,90,91,92,93,94,95,96,97,99,85,84,88,52,43,42,47,48,49,51,53,54,55,56,44,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29]
static func remappable(code: int) -> bool:
	var low:=code&255
	return low>=40 and low<=105 and low not in [74,105]
static func captured_scan_code(scan: int,enabled: bool=true) -> int:
	if not enabled or scan==65535: return 0
	var index:=SCAN_CODES.find(scan)
	return index+40 if index>=0 else 0
static func label_ref(code: int) -> int:
	var index:=LABEL_CODES.find(code&255)
	return 10617+index if index>=0 else -1
static func key_label(binding: int,resolve: Callable) -> String:
	var ref:=label_ref(binding)
	if ref<0: return ""
	var label:=str(resolve.call(ref)); var modifier: int=binding>>8
	if modifier in [2,3]: return str(resolve.call(52919 if modifier==2 else 52917))+" + "+label
	return label
static func atoi(text: String) -> int:
	var value:=text.strip_edges(); var index:=0; var sign:=1; var result:=0
	if value.begins_with("-") or value.begins_with("+"):
		sign=-1 if value[0]=="-" else 1; index=1
	while index<value.length() and value.unicode_at(index)>=48 and value.unicode_at(index)<=57:
		result=result*10+value.unicode_at(index)-48
		if result>2147483648: return -2147483648 if sign<0 else 2147483647
		index+=1
	return clampi(sign*result,-2147483648,2147483647)
static func integer(table: Dictionary,action: int,column: String) -> Dictionary:
	# Original C2DA::GetRowIndex/GetINTEntry use first case-insensitive row and
	# column matches. Preserve raw physical cells; do not change generic rows.
	var row_index:=-1; var column_index:=-1
	var labels: Array=table.get("rowLabels",[]); var columns: Array=table.get("columns",[])
	for index in labels.size():
		if str(labels[index]).to_lower()==("Action"+str(action)).to_lower(): row_index=index; break
	for index in columns.size():
		if str(columns[index]).to_lower()==column.to_lower(): column_index=index; break
	var found: bool=row_index>=0 and column_index>=0 and row_index<table.get("orderedCells",[]).size()
	var value:=str(table.orderedCells[row_index][column_index]) if found else ""
	if not found or value.is_empty() or value=="****": return {"found":false,"value":0}
	if value.length()>2 and value.substr(0,2).to_lower()=="0x":
		var bits:=value.hex_to_int()&0xffffffff
		return {"found":true,"value":bits-4294967296 if bits>=2147483648 else bits}
	return {"found":true,"value":atoi(value)}
static func populate(table: Dictionary,language: int,profile: Dictionary={},defaults: bool=false) -> Dictionary:
	var column:="Language"+str(language); var selected:=column
	if not defaults:
		var eligible:=false
		for action in range(FIRST,LAST+1):
			var value:=integer(table,action,column)
			if value.found and int(value.value)>=0 and remappable(int(value.value)): eligible=true; break
		if not eligible: selected="Language0"
	var result:=population(table,selected,profile,not defaults)
	if defaults and result.rows.is_empty() and selected!="Language0":
		selected="Language0"; result=population(table,selected,{},false)
	result.language_column=selected; result.native_data_only=true; result.full_key_settings_parity=false
	return result
static func population(table: Dictionary,column: String,profile: Dictionary,deduplicate: bool) -> Dictionary:
	var rows: Array=[]; var values: Dictionary={}; var seen: Dictionary={}; var errors: Array=[]
	for action in range(FIRST,LAST+1):
		values[action]=-1
		var value:=integer(table,action,column); var page:=integer(table,action,"Page")
		var key:="Action"+str(action)
		if deduplicate and profile.has(key): value={"found":true,"value":atoi(str(profile[key]))}
		if not value.found or not page.found: continue
		var binding:=int(value.value); var page_number:=int(page.value)
		if page_number<0 or page_number>=4 or binding<0 or binding>1023:
			errors.append("Unsafe original keymapping row: "+key); continue
		if deduplicate:
			var slot: int=(binding>>8)+(binding&255)*4
			if seen.has(slot): binding=0
			else: seen[slot]=true
		var caption:=integer(table,action,"ActionStrRef")
		rows.append({"action":action,"page":page_number,"binding":binding,"strRef":int(caption.value)}); values[action]=binding
	return {"rows":rows,"values":values,"errors":errors}
static func assign(plan: Dictionary,action: int,binding: int) -> Dictionary:
	var result: Dictionary=plan.duplicate(true); var rows: Array=result.get("rows",[])
	var selected:=-1
	for index in rows.size():
		if int(rows[index].action)==action: selected=index; break
	if selected<0 or binding<40 or binding>104: return result
	# Capture scans40..105;105 has no initialized SDL mapping in this binary.
	# Native74 can be captured, although IsRemappableKey rejects it for the
	# language-default eligibility scan. These are distinct original policies.
	for row in rows:
		if int(row.binding)==binding: row.binding=0; result.values[int(row.action)]=0
	rows[selected].binding=binding; result.values[action]=binding
	return result
static func writes(plan: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for action in range(FIRST,LAST+1):
		var value:=int(plan.get("values",{}).get(action,-1))
		result["Action"+str(action)]=str(0 if value<0 else value)
	return result
