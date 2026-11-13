extends RefCounted
# Connection/draft-owned CG_FEATS choices. The actor draft is committed only
# by its controller's accepted callback. No frame polling, Node or network I/O.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Snapshot=preload("res://systems/native_data/creation_feat_snapshot.gd")
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const Context=preload("res://systems/native_data/creation_feat_context.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var selected: Array=[]
var _table: Dictionary={}
var _decoded: Dictionary={}
var _text_revision:=-1
var _text_owner
var _master: Dictionary={}
var _entries: Array=[]
var _order: Array=[]
var builds:=0
var model_builds:=0
var _model_key: Array=[]
var _model_tables: Dictionary={}
var _model: Dictionary={}
func reset_selection() -> void:
	# The same draft may revisit Skills. Only choices and their derived model
	# expire; immutable active definitions/names retain their identity checks.
	selected.clear();_model_key.clear();_model_tables.clear();_model.clear()
func model_key(rules,text) -> Array:
	var d: Dictionary=rules.draft
	return [int(d.get("classId",-1)),int(d.get("raceId",-1)),d.get("abilities",{}).duplicate(),d.get("skills",{}).duplicate(),d.get("domains",[]).duplicate(),int(d.get("school",0)),selected.duplicate(),int(text.revision),text,rules.cls().duplicate(),rules.race().duplicate()]
func model_tables(rules) -> Dictionary:
	var result: Dictionary={}
	for name in ["feat","masterfeats","classes","racialtypes","skills","ruleset","domains"]:result[name]=rules.tables.get(name)
	for field in ["FeatsTable","SkillsTable","StatGainTable","AttackBonusTable","BonusFeatsTable","SpellGainTable","SpellKnownTable"]:
		var name:=Snapshot.Skills.table_name(rules.cls(),field)
		if not name.is_empty():result[name]=rules.tables.get(name)
	var race_feats:=Snapshot.Skills.table_name(rules.race(),"FeatsTable")
	if not race_feats.is_empty():result[race_feats]=rules.tables.get(race_feats)
	return result
func model_current(key: Array,tables: Dictionary) -> bool:
	if _model.is_empty() or key!=_model_key or tables.size()!=_model_tables.size():return false
	for name in tables:
		if not _model_tables.has(name) or not is_same(tables[name],_model_tables[name]):return false
	return true
static func compare(left: String,right: String) -> int:
	for at in mini(left.length(),right.length()):
		var a:=Rich.byte_value(left.unicode_at(at));var b:=Rich.byte_value(right.unicode_at(at))
		if a!=b:return -1 if a<b else 1
	return signi(left.length()-right.length())
func prepare(rules,text) -> Dictionary:
	var table: Dictionary=rules.tables.get("feat",{})
	var revision: int=int(text.revision)
	if not is_same(_table,table) or _decoded.is_empty():
		_table=table;_decoded=Tables.decode(table);_text_revision=-1;builds+=1
		if _decoded.get("ready",false):
			var definitions: Array=[]
			for feat in _decoded.definitions:definitions.append(Context.requirement_row(feat))
			_decoded.definitions=definitions
	if not _decoded.ready:return _decoded
	var master_table: Dictionary=rules.tables.get("masterfeats",{})
	if _text_revision!=revision or _text_owner!=text or not is_same(_master,master_table):
		var entries: Array=[];var order: Array=[]
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
		order.sort_custom(func(a,b):return compare(str(entries[a].key),str(entries[b].key))<0)
		_entries=entries;_order=order;_text_revision=revision;_text_owner=text;_master=master_table
	return _decoded
func snapshot(rules,text) -> Dictionary:
	var decoded:=prepare(rules,text)
	if not decoded.get("ready",false):return decoded
	var current:=Snapshot.resolve_spells(Snapshot.compose(rules,selected,decoded),rules)
	# All candidates in this action see the same class records. Build their
	# first-match lookup once instead of rescanning them for every physical feat.
	if current.get("ready",false):current.source=Context.prepare(current.source)
	return current
func candidate(source: Dictionary,id: int) -> Dictionary:
	if id<0 or id>=source.definitions.size():return {"ready":true,"allowed":false}
	var choice:=source.duplicate();choice.featId=id;choice.feat=source.definitions[id]
	return Choice.evaluate(choice)
func compose(rules,text) -> Dictionary:
	var key:=model_key(rules,text);var tables:=model_tables(rules)
	if model_current(key,tables):return _model.duplicate(true)
	var result:=build_model(rules,text)
	if result.get("ready",false):_model_key=key;_model_tables=tables;_model=result.duplicate(true)
	model_builds+=1
	return result
func build_model(rules,text) -> Dictionary:
	var current:=snapshot(rules,text)
	if not current.get("ready",false):return {"ready":false,"available":[],"known":[],"reason":str(current.get("reason","Active feat choices are unavailable."))}
	var source: Dictionary=current.source;var allowed: Dictionary={}
	for id in _order:
		var answer:=candidate(source,int(id))
		if not answer.ready:return {"ready":false,"available":[],"known":[],"reason":str(answer.get("reason","Active feat prerequisites are unresolved."))}
		if answer.allowed:allowed[int(id)]=true
	var available: Array=[];var names: Dictionary={};var group:=-1;var children: Array=[]
	for index in _order.size():
		var id: int=_order[index];var feat: Dictionary=source.definitions[id];var master:=int(feat.MASTERFEAT)
		if master==255:
			if allowed.has(id) and not names.has(_entries[id].name):
				var entry: Dictionary=_entries[id].duplicate();entry.enabled=true;available.append(entry);names[entry.name]=true
		else:
			if group<0:group=master
			if allowed.has(id):children.append(_entries[id].duplicate())
			var next_master:=int(source.definitions[int(_order[index+1])].MASTERFEAT) if index+1<_order.size() else -1
			if next_master!=group:
				if not children.is_empty():
					var table: Dictionary=rules.tables.get("masterfeats",{});var name_ref:=Tables.integer(table,group,"STRREF");var description:=Tables.integer(table,group,"DESCRIPTION");var icon:=Tables.cell(table,group,"ICON")
					if not name_ref.ready or not description.ready:return {"ready":false,"available":[],"known":[]}
					var name: String=text.raw({"strRef":int(name_ref.value)&0xffffffff})
					if not names.has(name):available.append({"id":group,"name":name,"infoName":name,"icon":str(icon.text).to_lower() if icon.found and str(icon.text)!="****" else "","description":int(description.value)&0xffffffff,"enabled":true,"children":children});names[name]=true
				group=-1;children=[]
	var granted: Array=[];var chosen: Array=[];names={}
	for id in source.owned:
		if id>=0 and id<_entries.size() and not names.has(_entries[id].name):
			var entry: Dictionary=_entries[id].duplicate();entry.enabled=false;granted.append(entry);names[entry.name]=true
	for id in selected:
		if id>=0 and id<_entries.size() and not names.has(_entries[id].name):
			var entry: Dictionary=_entries[id].duplicate();entry.enabled=true;chosen.append(entry);names[entry.name]=true
	granted.sort_custom(func(a,b):return compare(str(a.name),str(b.name))<0);chosen.sort_custom(func(a,b):return compare(str(a.name),str(b.name))<0)
	var remaining:=(int(source.normal)+int(source.bonus)-selected.size())&255
	return {"ready":true,"available":available,"known":granted+chosen,"remaining":Requirements.signed8(remaining),"canAccept":available.is_empty() or remaining==0,"selected":selected.duplicate(),"normal":int(source.normal),"bonus":int(source.bonus)}
func apply(operation: String,id: int,rules,text,preferences: String="") -> Dictionary:
	var current:=snapshot(rules,text)
	if not current.get("ready",false):return {"ready":false,"reason":str(current.get("reason","Active feat choices are unavailable."))}
	var source: Dictionary=current.source
	if operation=="add":
		var answer:=candidate(source,id)
		if answer.ready and answer.allowed:selected.append(id)
	elif operation=="remove":
		if not selected.has(id):return compose(rules,text)
		selected.erase(id)
		var changed:=true
		while changed:
			changed=false
			for chosen in selected.duplicate():
				var check:=source.duplicate();check.selected=selected.duplicate();check.selected.erase(chosen);check.featId=int(chosen)
				var answer:=Requirements.evaluate(check,source.definitions[int(chosen)])
				if not answer.ready:return {"ready":false,"reason":str(answer.reason)}
				if not answer.allowed:selected.erase(chosen);changed=true
	elif operation in ["reset","recommend"]:
		selected=[]
		if operation=="recommend" and not preferences.is_empty():
			if not rules.tables.has(preferences):return {"ready":false,"reason":"Active feat preferences have not arrived."}
			for at in rules.rows(preferences).size():
				var read:=Tables.integer(rules.tables[preferences],at,"FeatIndex")
				if not read.ready:return {"ready":false,"reason":str(read.reason)}
				if not read.ok:continue
				source.selected=selected.duplicate();var feat_id:=int(read.value)&65535;var answer:=candidate(source,feat_id)
				if not answer.ready:return {"ready":false,"reason":str(answer.reason)}
				if answer.allowed:selected.append(feat_id)
	else:return compose(rules,text)
	return compose(rules,text)
