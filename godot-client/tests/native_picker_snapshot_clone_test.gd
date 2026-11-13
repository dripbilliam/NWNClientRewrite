extends SceneTree
const Parser=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Candidate=preload("res://systems/native_data/picker_table_snapshot.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
func checked_flat(rows: Array) -> Array:
	var result: Array=[]
	for row in rows:result.append(row.duplicate(row.values().any(func(value):return value is Array or value is Dictionary)))
	return result
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","fixture"]) or FileAccess.file_exists(args.report):quit(2);return
	var bytes:=FileAccess.get_file_as_bytes(str(args.fixture).path_join("resources/spells.2da"));var parser:=Parser.new();var table:=parser.parse(Binary.new(bytes).text(0,bytes.size()));var rows: Array=table.orderedRows
	var class_bytes:=FileAccess.get_file_as_bytes(str(args.fixture).path_join("resources/classes.2da"));var classes:=parser.parse(Binary.new(class_bytes).text(0,class_bytes.size()));var columns:=Candidate.spell_columns(classes)
	var results: Array=[];var checks:=0;var failures: Array=[]
	for round_index in (0 if args.get("probe-mode","")=="policy" else 4):
		var order: Array=["deep","spell_columns","checked_flat","serialized"] if round_index%2==0 else ["serialized","checked_flat","spell_columns","deep"]
		for method in order:
			var began:=Time.get_ticks_usec();var copy: Array=[];var encode_us:=0;var decode_us:=0
			match method:
				"deep":copy=rows.duplicate(true)
				"checked_flat":copy=checked_flat(rows)
				"spell_columns":copy=Candidate.capture_spells(table,classes).orderedRows
				"serialized":
					var encoded:=var_to_bytes(rows);encode_us=Time.get_ticks_usec()-began;var decode_began:=Time.get_ticks_usec();copy=bytes_to_var(encoded);decode_us=Time.get_ticks_usec()-decode_began
			var elapsed:=Time.get_ticks_usec()-began
			checks+=1
			if method=="spell_columns":
				var valid: bool=copy.size()==rows.size()
				for index in rows.size():
					for key in copy[index]:valid=valid and copy[index][key]==rows[index][key] and columns.has(str(key).to_lower())
				if not valid:failures.append("Exact complete spell-column/physical-row snapshot failed")
			elif copy!=rows:failures.append("Exact physical row/value equality failed for "+method)
			results.append({"round":round_index,"method":method,"us":elapsed,"encode_us":encode_us,"decode_us":decode_us,"rows":copy.size()})
			copy=[]
	var nested: Array=[{"first":"unchanged","FIRST":"different-case","unused":{"array":[1,2,3]},"number":12},{}];var detached:=checked_flat(nested)
	nested[0].unused.array[0]=99;nested[0].first="mutated"
	checks+=1
	if detached[0].first!="unchanged" or detached[0].unused.array[0]!=1 or detached[0].keys()!=["first","FIRST","unused","number"]:failures.append("Container, scalar or physical key-order isolation failed")
	var active:={"orderedRows":[{"SpellTableColumn":"CaSt"},{"SpellTableColumn":"future"}]}
	var special:={"orderedRows":[{"cast":"1","CAST":"2","future":"9","Name":"unused"},{"CAST":"4","cast":"3","future":{"values":[7]}},{}]}
	var captured:=Candidate.capture_spells(special,active)
	checks+=1
	if captured.orderedRows.size()!=3 or captured.orderedRows[0].keys()!=["cast","CAST","future"] or captured.orderedRows[1].keys()!=["CAST","cast","future"]:failures.append("First case-insensitive physical key precedence changed")
	special.orderedRows[0].future="changed";special.orderedRows[1].future.values[0]=99
	checks+=1
	if captured.orderedRows[0].future!="9" or captured.orderedRows[1].future.values[0]!=7:failures.append("Future-class columns or nested input aliases were not detached")
	var all_rows:=Candidate.capture_spells(table,classes)
	for index in rows.size():
		for column in columns:
			checks+=1
			if Game.cell(rows[index],column,255)!=Game.cell(all_rows.orderedRows[index],column,255):failures.append("Canonical class-level getter differs at physical row "+str(index)+" column "+str(column))
	var packed:={"orderedRows":[{"cast":PackedInt32Array([1,2])}]};var private_pack:=Candidate.capture_spells(packed,active);packed.orderedRows[0].cast[0]=99
	checks+=1
	if private_pack.orderedRows[0].cast[0]!=1:failures.append("Authored packed cell storage aliases its source")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":results,"scope":"Staged full-physical-table clone strategy comparison on cached active2036-row Spells data; exact value equality and nested mutation isolation. No live picker import or GPU/FPS result."},"  "));file.close();quit(0 if failures.is_empty() else 1)
