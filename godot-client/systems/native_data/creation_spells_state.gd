extends RefCounted
# Original CG_SPELLS9ce190/9ce730/9c6e70. This class consumes explicit native
# getter results, not actor Nodes or a second rule/world store. The active-table
# draft adapter must supply those results before this policy can become ready.
const Order=preload("res://systems/native_data/character_record_entries.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
var ready:=false
var reason:=""
var source: Dictionary={}
var known: Array=[]
var baseline: Array=[]
var definitions: Dictionary={}
var name_keys: Dictionary={}
var eligible: Array=[]
var tabs: Array=[]
var finished: Array=[]
var remaining:=0
var selected_level:=0
var available_ids: Array=[]
var known_ids: Array=[]
static func scalar(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)
static func signed8(value: int) -> int:return (value&255)-256 if value&128 else value&255
static func unavailable(message: String) -> Dictionary:return {"ready":false,"reason":message}
func configure(value: Dictionary) -> Dictionary:
	ready=false;reason="";source={};definitions={};name_keys={};eligible=[];known=[];baseline=[];tabs=[];finished=[];remaining=0;selected_level=0;available_ids=[];known_ids=[]
	for key in ["memorizes","learnScroll","pickSchool","keepBudget"]:
		if not value.get(key) is bool:return reject("Native spell flag is unavailable: "+key)
	for key in ["classLevel","intModifier","baseInt","school","storedRemaining"]:
		if not scalar(value.get(key)):return reject("Native spell scalar is unavailable: "+key)
	if not value.has("opposition") or value.opposition!=null and not scalar(value.opposition):return reject("Native opposition lookup result is unavailable.")
	for key in ["capacity","gain","minimum","known"]:
		if not value.get(key) is Array or value[key].size()!=10:return reject("Native ten-level spell storage is unavailable: "+key)
	for level in 10:
		if not scalar(value.capacity[level]) or not scalar(value.gain[level]) or not value.minimum[level] is bool or not value.known[level] is Array:return reject("Native spell-level getter results are incomplete.")
		if value.known[level].size()>255 or value.known[level].any(func(id):return not scalar(id)):return reject("Known-spell indices exceed the verified native byte traversal.")
	if not value.get("spells") is Array:return reject("Active physical spell definitions are unavailable.")
	source=value.duplicate(true)
	var writer:=Writer.new()
	for spell in source.spells:
		if not spell is Dictionary or not scalar(spell.get("id")) or not scalar(spell.get("level")) or not spell.has("school") or spell.school!=null and not scalar(spell.school):return reject("A native spell definition is incomplete.")
		var id:=int(spell.id)
		if id<0 or definitions.has(id):return reject("Native physical spell identity is ambiguous.")
		definitions[id]=spell;name_keys[id]=writer.text(str(spell.get("name","")))
	for level in 10:
		var ids: Array=[]
		for id in source.known[level]:
			if not definitions.has(int(id)):return reject("Known spell metadata is unavailable.")
			ids.append(int(id))
		baseline.append(ids);eligible.append([])
	for spell in source.spells:
		var level:=int(spell.level)&255
		if level>=10:continue
		if source.pickSchool and (int(source.school)&255)!=0 and source.opposition!=null:
			if spell.school==null:return reject("An eligible spell's original school byte is unavailable.")
			if (int(spell.school)&255)==(int(source.opposition)&255):continue
		eligible[level].append(int(spell.id))
	known=baseline.duplicate(true);remaining=int(source.storedRemaining)&65535;ready=true
	initialize(source.keepBudget)
	return {"ready":ready,"reason":reason}
func reject(message: String) -> Dictionary:
	ready=false;reason=message;return unavailable(message)
func known_left(level: int) -> int:
	return maxi(0,(int(source.capacity[level])&255)-known[level].size()) if level>=0 and level<10 else 0
func initialize(keep_budget: bool=false) -> void:
	if not ready:return
	var first:=0 if source.learnScroll else 255
	if not keep_budget and source.learnScroll:
		if (int(source.classLevel)&255)==1:
			remaining=(3+maxi(0,signed8(int(source.intModifier))))&65535
			if known[0].is_empty() and (int(source.baseInt)&255)>9:
				for spell in source.spells:
					if (int(spell.level)&255)==0 and not known[0].has(int(spell.id)):known[0].append(int(spell.id))
				first=1
		else:remaining=2
	tabs=[];finished=[]
	for level in 10:
		var enabled: bool=source.learnScroll and (int(source.gain[level])&255)!=0 or (int(source.capacity[level])&255)!=0
		tabs.append(enabled);finished.append(true)
		if not enabled or not source.minimum[level]:continue
		# Initialization9ce190 branches on LearnScroll here. The level-display
		# callback9caae0 separately branches on MemorizesSpells; custom classes
		# can supply different combinations, so these gates are not aliases.
		if not source.learnScroll:remaining=known_left(level)
		var count:=0
		for id in eligible[level]:
			if not known[level].has(id):count=(count+1)&255
		if count!=0 and remaining!=0:
			finished[level]=false;first=maxi(first,level) if source.learnScroll else mini(first,level)
	show_level(first if first!=255 else 0)
func ordered(ids: Array) -> Array:
	var result: Array=[]
	for id in ids:insert_sorted(result,int(id))
	return result
func insert_sorted(ids: Array,id: int) -> void:
	# Original9ca3e0 inserts just the returned row at its lower bound. Sorting
	# the whole list here both wastes work and reverses existing equal-name
	# groups, which changes physical spell order after an unrelated removal.
	var first:=0;var last:=ids.size();var key: PackedByteArray=name_keys[id]
	while first<last:
		var middle: int=(first+last)/2
		if Order.compare(key,name_keys[int(ids[middle])])>0:first=middle+1
		else:last=middle
	ids.insert(first,id)
func show_level(level: int) -> void:
	selected_level=level
	if not source.memorizes:remaining=known_left(level)
	available_ids=[]
	for id in eligible[level]:
		if not known[level].has(id):available_ids.append(id)
	available_ids=ordered(available_ids)
	known_ids=ordered(known[level].slice(baseline[level].size()) if source.memorizes else known[level])
func select_level(level: int) -> bool:
	if not ready or level<0 or level>=10 or not tabs[level]:return false
	show_level(level);return true
func can_accept() -> bool:
	return ready and (source.memorizes and remaining==0 or not finished.has(false))
func update_current() -> void:
	finished[selected_level]=true
	if remaining!=0 and not available_ids.is_empty() and source.minimum[selected_level]:finished[selected_level]=false
func add(id: int) -> bool:
	if not ready or remaining==0 or not source.minimum[selected_level] or not available_ids.has(id):return false
	available_ids.erase(id);known[selected_level].append(id);known_ids.append(id);remaining=(remaining-1)&65535;update_current()
	if not source.memorizes and (available_ids.is_empty() or known_left(selected_level)==0) and selected_level<9 and known_left(selected_level+1)!=0:show_level(selected_level+1)
	return true
func remove(id: int) -> bool:
	if not ready or not known_ids.has(id) or source.learnScroll and selected_level==0:return false
	known[selected_level].erase(id);known_ids.erase(id);insert_sorted(available_ids,id);remaining=(remaining+1)&65535;update_current();return true
func reset_choices() -> bool:
	if not ready:return false
	known=baseline.duplicate(true);initialize(false);return true
func view() -> Dictionary:
	if not ready:return {"ready":false,"reason":reason,"available":[],"known":[]}
	var available: Array=[];var selected: Array=[]
	for id in available_ids:
		var row: Dictionary=definitions[id].duplicate(true);row.enabled=remaining!=0 and source.minimum[selected_level];available.append(row)
	for id in known_ids:
		var row: Dictionary=definitions[id].duplicate(true);row.enabled=not(source.learnScroll and selected_level==0);selected.append(row)
	return {"ready":true,"available":available,"known":selected,"level":selected_level,"remaining":remaining,"canAccept":can_accept(),"tabs":tabs.duplicate(),"finished":finished.duplicate(),"cannotLearn":not source.minimum[selected_level],"empty":available_ids.is_empty()}
