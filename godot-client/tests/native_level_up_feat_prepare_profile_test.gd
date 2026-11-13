extends "res://tests/native_level_up_feat_index_test.gd"
# Copied-only phase clocks and alternatives. No production State/cache hook.
const DefinitionWork=preload("res://systems/native_level_up_definitions_work.gd")
const NativeBytes=preload("res://systems/native_data/binary_data.gd")
class TimedState extends State:
	var injected: Dictionary={}
	var native_keys:=false
	var phases: Dictionary={}
	static func byte_key(value: String) -> String:
		var result:=""
		# +2 preserves [-1,255] order without introducing a NUL into Godot.
		for at in value.length():result+=String.chr(Rich.byte_value(value.unicode_at(at))+2)
		return result
	func prepare(rules,text) -> Dictionary:
		var began:=Time.get_ticks_usec();var table: Dictionary=rules.tables.get("feat",{});var revision: int=int(text.revision)
		if not is_same(_table,table) or _decoded.is_empty():
			var at:=Time.get_ticks_usec();_table=table;_decoded=injected.duplicate() if injected.get("ready",false) else Tables.decode(table);_text_revision=-1;builds+=1;phases.decodeUsec=Time.get_ticks_usec()-at
			if _decoded.get("ready",false):
				at=Time.get_ticks_usec();var definitions: Array=[]
				for feat in _decoded.definitions:definitions.append(Context.requirement_row(feat))
				_decoded.definitions=definitions;phases.aliasUsec=Time.get_ticks_usec()-at
		if not _decoded.ready:return _decoded
		var master_table: Dictionary=rules.tables.get("masterfeats",{})
		if _text_revision!=revision or _text_owner!=text or not is_same(_master,master_table):
			var at:=Time.get_ticks_usec();var entries: Array=[];var order: Array=[]
			for feat in _decoded.definitions:
				var entry:={"id":int(feat.id),"name":"","icon":"","description":4294967295,"key":""}
				if feat.valid:
					entry.name=text.raw({"strRef":int(feat.FEAT)&0xffffffff});entry.icon=str(feat.Icon);entry.description=int(feat.Description)&0xffffffff;entry.key=entry.name
					if int(feat.MASTERFEAT)!=255:
						if not rules.tables.has("masterfeats") or int(feat.MASTERFEAT)>=master_table.get("orderedRows",[]).size():return {"ready":false,"reason":"Active master feat storage is unavailable."}
						var master:=Tables.integer(master_table,int(feat.MASTERFEAT),"STRREF")
						if not master.ready:return master
						entry.key=text.raw({"strRef":int(master.value)&0xffffffff})+str(entry.name)
					order.append(int(feat.id))
				entries.append(entry)
			phases.namesAndMasterUsec=Time.get_ticks_usec()-at;var keys: Array=[]
			at=Time.get_ticks_usec()
			if native_keys:
				for entry in entries:keys.append(byte_key(str(entry.key)))
			phases.keyBuildUsec=Time.get_ticks_usec()-at;at=Time.get_ticks_usec()
			if native_keys:order.sort_custom(func(a,b):return str(keys[a])<str(keys[b]))
			else:order.sort_custom(func(a,b):return compare(str(entries[a].key),str(entries[b].key))<0)
			phases.sortUsec=Time.get_ticks_usec()-at;_entries=entries;_order=order;_text_revision=revision;_text_owner=text;_master=master_table
		phases.totalPrepareUsec=Time.get_ticks_usec()-began;return _decoded
func edge_keys() -> void:
	var values: Array=["","A","AA","A!","a","GroupChild","Group","OtherChild","same","same","ΩA","ΨA","ΩB"]
	for byte in range(1,256):
		var code: int=NativeBytes.CP1252_HIGH[byte-128] if byte>=128 and byte<160 else byte
		values.append(String.chr(code));values.append("Prefix"+String.chr(code)+"suffix")
	var keys: Array=values.map(func(value):return TimedState.byte_key(str(value)));var mismatch: Array=[]
	for left in values.size():
		for right in values.size():
			var reference: int=TimedState.compare(str(values[left]),str(values[right]));var mapped: int=-1 if str(keys[left])<str(keys[right]) else 1 if str(keys[right])<str(keys[left]) else 0
			if signi(reference)!=mapped and mismatch.size()<10:mismatch.append([left,right,reference,mapped])
	check(mismatch.is_empty(),"Every CP1252 byte/prefix/unknown-Unicode pair preserves current comparator sign",mismatch)
	var first: Array=range(values.size());var second: Array=first.duplicate()
	first.sort_custom(func(a,b):return TimedState.compare(str(values[a]),str(values[b]))<0);second.sort_custom(func(a,b):return str(keys[a])<str(keys[b]))
	check(first==second,"Identical false-on-tie comparison preserves actual current sort order including duplicate names")
	observations.append({"kind":"byte-edge-order","strings":values.size(),"pairComparisons":values.size()*values.size(),"includesUnknownUnicode":true,"embeddedNulExcluded":"Native TLK loader truncates at first NUL before decoding; this follows current State comparison, not a new string decoder.","originalTies":"Original CompareFeatName returns0 for equal byte keys; no new ID tie-breaker or qsort stability claim."})
func cold_text(source):
	var result:=Text.new()
	result.base.open_file(source.base.file.get_path_absolute())
	if source.custom.file!=null:result.custom.open_file(source.custom.file.get_path_absolute())
	result.overrides=source.overrides.duplicate();result.revision=int(source.revision);return result
func profile(catalog,text,kind: String,class_label: String,prior_class_label: String="",class_level: int=2) -> void:
	print("LEVEL_UP_COLD_PREPARE begin "+kind)
	var tables: Dictionary={};var reads: Array=[]
	for name in ["classes","racialtypes","ruleset","skills","feat","masterfeats","packages"]:read(catalog,name,tables,reads)
	var class_id:=find_label(tables.classes,class_label);var race_id:=find_label(tables.racialtypes,"human")
	if not check(class_id>=0 and race_id>=0,"Physical active mode1 class/race resolve "+kind):return
	var compiled:=Metadata.compile(tables.classes)
	if not check(compiled.ready,"Private original class projection is available "+kind):return
	var raw:=tables.duplicate(true);tables=tables.duplicate();tables.classes=compiled.table;var class_ids: Array=[]
	if not prior_class_label.is_empty():class_ids.append(find_label(tables.classes,prior_class_label))
	class_ids.append(class_id)
	for id in class_ids:
		for field in ["SkillsTable","FeatsTable","StatGainTable","AttackBonusTable","BonusFeatsTable","SpellGainTable","SpellKnownTable"]:read(catalog,SkillTables.table_name(tables.classes.orderedRows[id],field),tables,reads)
	var package:=Tables.integer(tables.classes,class_id,"Package");var ranks: Array=[];ranks.resize(tables.skills.orderedRows.size()&255);ranks.fill(0)
	var received:={"actorId":42,"race":race_id,"classes":class_ids.map(func(id):return {"id":id,"level":class_level,"school":0}),"baseAbilities":[14,14,14,14,14,14],"feats":[],"skills":ranks.duplicate(),"fieldD4":int(package.value)};var before:=received.duplicate(true)
	var worker:=DefinitionWork.new();root.add_child(worker);var scope: Array=[10,7,42,1];worker.warm(scope,catalog,-1,tables.feat)
	var until:=Time.get_ticks_msec()+10000
	while not worker.view(scope,catalog,-1,tables.feat).get("ready",false) and Time.get_ticks_msec()<until:await process_frame
	var plain: Dictionary=worker.view(scope,catalog,-1,tables.feat)
	if not check(plain.get("ready",false),"Actual accepted background plain definitions are supplied "+kind):worker.close();worker.queue_free();return
	var plain_before:=plain.duplicate(true);var context:={"baseFortitude":3};var states: Array=[];var outputs: Array=[];var variants: Array=[];var texts: Array=[]
	# Phase clocks are copied from prepare; a separate real production State
	# below proves the copied baseline's complete model/order/prerequisites.
	for variant in ["normal","plain_injected","plain_native_keys"]:
		var variant_text=cold_text(text);texts.append(variant_text)
		var state:=TimedState.new();state.configure(received,class_id,-1,ranks,context);state.injected=plain if variant!="normal" else {};state.native_keys=variant=="plain_native_keys";state.view.tables=tables
		var began:=Time.get_ticks_usec();var model: Dictionary=state.model(tables,variant_text);var model_usec:=Time.get_ticks_usec()-began;var phases:=state.phases.duplicate()
		var current: Dictionary=state.snapshot(state.view,variant_text);var verdict:=verdicts(state,current.source) if current.get("ready",false) else {"ready":false}
		check(model.get("ready",false) and current.get("ready",false) and verdict.get("ready",false),"Cold prepare/model/current candidates are ready "+kind+"/"+variant)
		states.append(state);outputs.append({"model":model,"snapshot":current,"verdict":verdict.get("ordered",[]),"entries":state._entries.duplicate(true),"order":state._order.duplicate()});variants.append({"variant":variant,"phases":phases,"wholeModelUsec":model_usec,"definitions":state._decoded.definitions.size(),"names":state._order.size(),"freshTlkRecordReads":variant_text.base.reads+variant_text.custom.reads})
	var actual_text=cold_text(text);texts.append(actual_text);var actual:=State.new();actual.configure(received,class_id,-1,ranks,context);actual.view.tables=tables;var actual_model: Dictionary=actual.model(tables,actual_text)
	check(actual_model==outputs[0].model and actual._entries==outputs[0].entries and actual._order==outputs[0].order,"Copied phase-clock baseline equals actual untouched production State "+kind)
	for at in range(1,outputs.size()):
		check(outputs[at]==outputs[0],"Plain cache injection/native keys preserve full model, physical order and every prerequisite "+kind+"/"+str(at))
	var plan:=Plan.feats(received,class_id,tables)
	if plan.get("pending",false):
		for name in plan.get("dependencies",[]):read(catalog,str(name),tables,reads)
		plan=Plan.feats(received,class_id,tables)
	if check(plan.get("ready",false),"Actual native recommendation plan resolves "+kind):
		var first: Dictionary={}
		for at in states.size():
			var answer:=Loop.apply(outputs[at].snapshot.source,tables.get(str(plan.get("name","")),{}),bool(plan.get("loaded",false)),states[at].candidate)
			if at==0:first=answer
			else:check(answer==first,"Preference read order/selected IDs/remainder stay exact "+kind+"/"+str(at))
	check(plain==plain_before and received==before and raw.classes!=tables.classes,"Private injected aliases/keys do not mutate the accepted plain cache, received state or raw classes "+kind)
	observations.append({"kind":kind,"classId":class_id,"received":received,"variants":variants,"worker":worker.snapshot(),"masterNames":states[0]._entries.filter(func(row):return str(row.key)!=str(row.name)).size(),"tieGroups":tie_groups(states[0]._entries,states[0]._order),"reads":reads})
	for owner in texts:owner.close()
	worker.close();worker.queue_free();await process_frame
	print("LEVEL_UP_COLD_PREPARE complete "+kind)
func tie_groups(entries: Array,order: Array) -> Array:
	var groups: Dictionary={}
	for id in order:
		var key:=TimedState.byte_key(str(entries[id].key))
		if not groups.has(key):groups[key]=[]
		groups[key].append(id)
	return groups.values().filter(func(ids):return ids.size()>1)
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","fixture","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var custom:=Catalog.new();var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture).path_join("fixture.json")))
	check(base.mount_install(args.install) and custom.mount_install(args.install) and custom.mount_nwsync(str(fixture.manifest),str(args.fixture).path_join("nwsync"),"","",100000001),"Actual base and captured custom namespaces mount read-only")
	var base_text:=Text.new();var custom_text:=Text.new();check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and custom_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and custom_text.custom.open_file(str(args.fixture).path_join("resources/arelith.tlk")),"Exact installed/captured active TLK names are available")
	edge_keys()
	await profile(base,base_text,"installed_fighter","fighter");await profile(custom,custom_text,"captured_warlock","warlock");await profile(custom,custom_text,"captured_multiclass_warlock","warlock","fighter");await profile(base,base_text,"installed_wizard_level16","wizard","",15)
	base_text.close();custom_text.close();base=null;custom=null;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"productionChanged":false,"gpu":false,"serverConnections":0,"scope":"Copied-only cold State.prepare phase clocks, real accepted private plain definitions injected, precomputed byte-order String key alternative, exact actual production whole-model/order/prerequisite/preference equality using installed/captured active tables and TLK with authored advanced mode1 contexts. Not current live-input, pixel/FPS or original qsort tie-order acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
