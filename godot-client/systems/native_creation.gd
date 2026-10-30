extends Node
# Native connection-owned creator; JavaScript receives only a finished BIC.
signal request(message: Dictionary)
signal closed
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Builder=preload("res://systems/native_data/creation_bic.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const STEPS=["Gender","Race","Portrait","Class","Alignment","Package","Abilities","Domains & school","Skills","Feats","Spells","Appearance","Voice","Name","Review"]
var rules:=Rules.new()
var ui
var view
var assets
var connection:=-1
var phase:="closed"
var step:=0
var serial:=0
var controls: Dictionary={}
var resource_queue: Array=[]
var jobs: Dictionary={}
var requested: Dictionary={}
var resource_errors: Array=[]
var dependencies:=false
var status:=""
var feat_kind:="bonus"
var filter:=""
var show_unavailable:=false
var portrait_page:=0
var build_task:=-1
var build_result: Dictionary={}
var draft_scope:=0
var dead:=false
var preview
var voice
func configure(owner) -> void:
	ui=owner; rules.tables=ui.text.tables; rules.catalog=ui.catalog
	view=preload("res://systems/server_creation.gd").new(); add_child(view); view.request.connect(input)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(ui.catalog); assets.cache_directory=ui.assets.cache_directory; assets.completed.connect(prepared)
	preview=preload("res://systems/native_creation_preview.gd").new(); add_child(preview); preview.configure(ui,view.appearance_preview,assets)
	voice=preload("res://systems/native_creation_voice.gd").new(); add_child(voice); voice.configure(ui.catalog,view.voice_audio)
func open(scope: int) -> void:
	if dead or phase!="closed": return
	draft_scope+=1; connection=scope; phase="loading"; step=0; dependencies=false; status="Reading character choices…"; view.open()
	request.emit({"kind":"native-creation-begin","connection":connection})
	for name in ["packages","appearance","gender","phenotype","soundset","chargenclothes","masterfeats"]: table(name)
	for pair in [["skin","pal_skin01"],["hair","pal_hair01"],["tattoo1","pal_tattoo01"],["tattoo2","pal_tattoo01"]]: enqueue(str(pair[1]),3,"palette",str(pair[0]))
	render()
func table(name: String) -> void:
	if rules.present(name) and not rules.tables.has(name.to_lower()): enqueue(name.to_lower(),2017,"table",name.to_lower())
func enqueue(name: String,type: int,kind: String,key: String) -> void:
	var identity:=kind+":"+key
	if requested.has(identity): return
	requested[identity]=true; resource_queue.append({"name":name,"type":type,"kind":kind,"key":key})
func prepared(id: int,result: Dictionary) -> void:
	if dead or not jobs.has(id): return
	var job: Dictionary=jobs[id]; jobs.erase(id)
	if not str(result.error).is_empty():
		resource_errors.append(str(job.name)+": "+str(result.error))
		if job.kind=="table": rules.tables[job.key]={}
		return
	if job.kind=="table": rules.tables[job.key]=result.value
	elif job.kind=="palette": rules.palette_sizes[job.key]=result.bytes.decode_u16(14) if result.bytes.size()>=18 else 0
func package_tables() -> void:
	var package:=rules.row("packages",int(rules.draft.packageId))
	for key in ["SkillPref2DA","FeatPref2DA","SpellPref2DA","Equip2DA"]: table(str(rules.cell(package,key,"")))
func _process(_delta: float) -> void:
	if dead: return
	for count in mini(4,resource_queue.size()):
		if assets.pending.size()+assets.running.size()>=32: break
		var job: Dictionary=resource_queue.pop_front(); var id: int=assets.request(job.name,int(job.type),"2da" if job.kind=="table" else "bytes")
		if id>=0: jobs[id]=job
	if build_task>=0 and WorkerThreadPool.is_task_completed(build_task):
		WorkerThreadPool.wait_for_task_completion(build_task); build_task=-1
		if phase=="preparing" and int(build_result.get("scope",-1))==draft_scope:
			if not str(build_result.error).is_empty(): phase="editing"; status=str(build_result.error); render()
			else:
				phase="waiting"; status="Waiting for the server to admit your character…"; render()
				request.emit({"kind":"native-creation-submit","connection":connection,"data":Marshalls.raw_to_base64(build_result.bytes)})
		build_result.clear()
	if phase not in ["loading","recommending"] or not ui.tables_ready or not jobs.is_empty() or not resource_queue.is_empty(): return
	if phase=="loading" and not dependencies:
		dependencies=true
		for data in rules.rows("racialtypes"): table(str(rules.cell(data,"FeatsTable","")))
		for data in rules.rows("classes"):
			if rules.num(data,"PlayerClass")==0: continue
			for field in ["PreReqTable","StatGainTable","SkillsTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable"]: table(str(rules.cell(data,field,"")))
		return
	if phase=="loading":
		rules.model_names=ui.catalog.resource_names(2002); rules.initialize(); phase="editing"; status=""; render()
	else: phase="editing"; status=rules.recommend(); render()
func title(table_name: String,id: int,column: String="Name") -> String:
	var data:=rules.row(table_name,id); var ref:=rules.num(data,column,-1); var label: String=ui.text.raw({"strRef":ref&0xffffffff}) if ref>=0 else ""
	return label if not label.is_empty() else str(rules.cell(data,"Label",rules.cell(data,"NAME",table_name+" "+str(id))))
func add(items: Array,type: String,label: String,operation: String="",value: Variant=null,extra: Dictionary={}) -> void:
	var id:=controls.size(); controls[id]={"operation":operation,"value":value,"type":type}; var entry:={"controlId":id,"type":type,"label":label,"disabled":phase!="editing"}; entry.merge(extra); controls[id].merge(entry); items.append(entry)
func text(items: Array,label: String) -> void: items.append({"type":"text","label":label})
func choices(items: Array,label: String,table_name: String,ids: Array,selected: int,operation: String,column: String="Name") -> void:
	var labels: Array=[]
	for id in ids: labels.append(title(table_name,int(id),column))
	add(items,"select",label,operation,ids,{"options":labels,"value":ids.find(selected),"disabled":ids.is_empty(),"tag":operation})
func input_field(items: Array,label: String,key: String,max_length: int=32,multiline: bool=false) -> void:
	add(items,"input",label,"field",key,{"value":str(rules.draft[key]),"maxLength":max_length,"multiline":multiline,"tag":key})
func render() -> void:
	if phase=="closed" or dead: return
	controls.clear(); serial+=1; var items: Array=[]; var d: Dictionary=rules.draft
	if phase=="editing":
		if rules.num(rules.cls(),"LearnScroll")!=0: d.known[0]=rules.spell_options(0)
		match step:
			0:
				for id in mini(2,rules.rows("gender").size()): add(items,"button",title("gender",id,"NAME"),"gender",id,{"selected":int(d.gender)==id,"tag":"gender","value":id})
			1:
				for id in rules.rows("racialtypes").size():
					if rules.num(rules.row("racialtypes",id),"PlayerRace")!=0: add(items,"button",title("racialtypes",id),"race",id,{"selected":int(d.raceId)==id,"tag":"race","value":id})
				input_field(items,"Subrace","subrace")
			2:
				var images:=rules.portraits(); var pages:=maxi(1,ceili(images.size()/48.0)); portrait_page=mini(portrait_page,pages-1); text(items,"Portraits · "+str(portrait_page+1)+" / "+str(pages))
				add(items,"button","Previous portraits","portrait-page",-1,{"disabled":portrait_page==0}); add(items,"button","Next portraits","portrait-page",1,{"disabled":portrait_page>=pages-1})
				for name in images.slice(portrait_page*48,(portrait_page+1)*48): add(items,"portrait",name,"portrait",name,{"selected":d.portrait==name,"resource":name,"tag":"portrait"})
			3:
				for id in rules.rows("classes").size():
					if rules.num(rules.row("classes",id),"PlayerClass")==0: continue
					var reason:=rules.class_requirement(id); add(items,"button",title("classes",id),"class",id,{"selected":int(d.classId)==id,"disabled":not reason.is_empty(),"reason":reason,"tag":"class","value":id})
			4:
				for id in 9:
					var a:=rules.alignment(id); add(items,"button",Rules.ALIGNMENTS[id],"alignment",id,{"selected":int(d.goodEvil)==int(a.goodEvil) and int(d.lawChaos)==int(a.lawChaos),"disabled":not rules.alignment_allowed(rules.cls(),int(a.goodEvil),int(a.lawChaos)),"tag":"alignment"})
			5:
				for id in rules.packages(): add(items,"button",title("packages",id),"package",id,{"selected":int(d.packageId)==id,"tag":"package"})
				text(items,"Packages supply starting equipment and recommendations. Every choice can be customized.")
			6:
				text(items,"Ability points remaining: "+str(rules.point_balance())); var scores:=rules.abilities()
				for key in Rules.ABILITIES:
					text(items,key+": "+str(d.abilities[key])+" · total "+str(scores[key]))
					for delta in [-1,1]: add(items,"button","−" if delta<0 else "+","ability",[key,delta],{"disabled":not rules.can_decrease(key) if delta<0 else rules.point_cost(int(d.abilities[key])+1)-rules.point_cost(int(d.abilities[key]))>rules.point_balance(),"tag":"ability","delta":delta})
			7:
				if rules.num(rules.cls(),"PickDomains")!=0:
					for index in 2: choices(items,"Domain "+str(index+1),"domains",range(rules.rows("domains").size()),int(d.domains[index]) if d.domains.size()>index else -1,"domain-"+str(index))
				if rules.num(rules.cls(),"PickSchool")!=0: choices(items,"Spell school","spellschools",range(rules.rows("spellschools").size()),int(d.school),"school","StringRef")
			8:
				text(items,"Skill points remaining: "+str(rules.skill_balance()))
				for id in rules.rows("skills").size():
					var rule:=rules.skill_rule(id)
					if not rule.allowed or rules.num(rules.row("skills",id),"HideFromLevelUp")!=0: continue
					text(items,title("skills",id)+": "+str(d.skills.get(id,0))+" / "+str(rule.max)+" · "+str(rule.cost)+" points/rank")
					for delta in [-1,1]: add(items,"button","−" if delta<0 else "+","skill",[id,delta],{"disabled":int(d.skills.get(id,0))<=0 if delta<0 else int(d.skills.get(id,0))>=int(rule.max) or rules.skill_balance()<int(rule.cost),"tag":"skill","delta":delta})
			9: render_feats(items)
			10:
				for level in 10:
					var count:=rules.spell_count(level)
					if count>0:
						text(items,"Level "+str(level)+" · "+str(d.known.get(level,[]).size())+" / "+str(count)+" known")
						if level!=0 or rules.num(rules.cls(),"LearnScroll")==0:
							for id in rules.spell_options(level):
								var selected: bool=d.known.get(level,[]).has(id); add(items,"button",title("spells",id),"spell",[level,id],{"selected":selected,"disabled":not selected and d.known.get(level,[]).size()>=count,"tag":"spell"})
					if rules.num(rules.cls(),"MemorizesSpells")==0: continue
					for slot in rules.spell_slots(level):
						var domain:=rules.num(rules.cls(),"PickDomains")!=0 and level>0 and slot==rules.spell_slots(level)-1; var ids: Array=[-1]+rules.prepared_options(level,domain); var labels: Array=["Unprepared"]
						for id in ids.slice(1): labels.append(title("spells",id))
						var prepared: Array=d.memorized.get(level,[]); var selected:=int(prepared[slot]) if slot<prepared.size() and prepared[slot]!=null else -1
						add(items,"select","Level "+str(level)+" · "+("Domain" if domain else "Slot "+str(slot+1)),"prepared",[level,slot,ids],{"options":labels,"value":ids.find(selected),"tag":"prepared"})
			11:
				choices(items,"Body type","phenotype",rules.phenotypes(),int(d.phenotype),"phenotype")
				var heads:=rules.heads(); var labels: Array=[]
				for id in heads: labels.append("Head "+str(id))
				add(items,"select","Head","head",heads,{"options":labels,"value":heads.find(int(d.head)),"disabled":heads.is_empty(),"tag":"head"})
				var clothing:=rules.clothes(); labels=[]
				for id in clothing: labels.append("Clothing "+str(id+1))
				add(items,"select","Clothing","clothing",clothing,{"options":labels,"value":clothing.find(int(d.clothes)),"disabled":clothing.is_empty(),"tag":"clothing"})
				for key in ["skin","hair","tattoo1","tattoo2"]:
					labels=[]; var ids: Array=[]
					for id in mini(256,int(rules.palette_sizes.get(key,176))): ids.append(id); labels.append("Colour "+str(id))
					add(items,"select",key.capitalize(),"palette",[key,ids],{"options":labels,"value":int(d[key]),"tag":"palette"})
			12:
				choices(items,"Voice","soundset",rules.voices(),int(d.soundset),"voice","STRREF")
				add(items,"voice-sample","Play sample","voice-sample")
			13:
				for pair in [["First name","firstName"],["Last name","lastName"],["Age","age"],["Deity","deity"],["Biography","biography"]]: input_field(items,pair[0],pair[1],32768 if pair[1]=="biography" else 10 if pair[1]=="age" else 32,pair[1]=="biography")
				for spec in [[303,"hen_familiar","familiar"],[199,"hen_companion","companion"]]:
					if rules.granted_feats().has(spec[0]): choices(items,str(spec[2]).capitalize(),spec[1],range(rules.rows(spec[1]).size()),int(d[spec[2]]),spec[2],"STRREF"); input_field(items,str(spec[2]).capitalize()+" name",spec[2]+"Name")
			14:
				text(items,(str(d.firstName)+" "+str(d.lastName)).strip_edges()); text(items,title("racialtypes",int(d.raceId))+" · "+title("classes",int(d.classId))+" 1"); text(items,str(rules.abilities())); text(items,"Play submits this character to the connected server.")
	var problems: Array=rules.errors() if not d.is_empty() and phase=="editing" else []
	view.receive({"kind":"creation-begin","viewId":serial,"step":step,"steps":STEPS,"phase":phase,"status":status,"errors":problems if step==14 else [],"canEdit":phase=="editing","canFinish":phase=="editing" and problems.is_empty(),"canRecommend":phase=="editing" and rules.default_package()>=0,"canCancel":phase!="waiting","count":items.size()})
	view.receive({"kind":"creation-items","viewId":serial,"items":items}); view.receive({"kind":"creation-commit","viewId":serial})
	view.panel.theme=ui.skin_owner.theme()
	if step==11 and phase=="editing": preview.refresh(rules)
	else: preview.stop()
	if step!=12 or phase!="editing": voice.reset()
	else: view.voice_caption=title("soundset",int(d.soundset),"STRREF")
	for id in controls:
		if controls[id].type=="portrait" and view.controls.has(id):
			var button: Button=view.controls[id]; ui.desktop.art.bind_portrait(button.get_meta("portrait"),str(controls[id].resource)+"m"); button.text=""
func render_feats(items: Array) -> void:
	var d: Dictionary=rules.draft; var slots:=rules.feat_slots(); var owned:=rules.granted_feats(); var counts:={"normal":0,"bonus":0}
	for index in d.feats.size():
		var choice: Dictionary=d.feats[index]; owned.append(int(choice.id)); counts[choice.kind]+=1; add(items,"button",title("feat",int(choice.id),"FEAT")+" · Remove","feat-remove",index)
	var kinds: Array=[]
	for kind in ["bonus","normal"]:
		if int(counts[kind])<int(slots[kind]): kinds.append(kind)
	if kinds.is_empty(): text(items,"All feat choices complete."); return
	if not kinds.has(feat_kind): feat_kind=str(kinds[0])
	add(items,"select","Feat slot","feat-kind",kinds,{"options":kinds,"value":kinds.find(feat_kind)})
	add(items,"toggle","Show unavailable feats","feat-unavailable",null,{"value":show_unavailable})
	add(items,"input","Filter feats","feat-filter",null,{"value":filter,"maxLength":128})
	for id in rules.rows("feat").size():
		if not rules.feat_allowed(id,feat_kind): continue
		var reason:=rules.feat_requirement(id,owned); var label:=title("feat",id,"FEAT")
		if not filter.is_empty() and not label.to_lower().contains(filter.to_lower()) or not show_unavailable and not reason.is_empty(): continue
		add(items,"button",label+(" · "+reason if not reason.is_empty() else ""),"feat",id,{"disabled":not reason.is_empty(),"tag":"feat"})
func apply_texts(values: Array) -> void:
	for entry in values:
		var control: Dictionary=controls.get(int(entry.get("controlId",-1)),{})
		if control.get("operation")=="field": rules.draft[str(control.value)]=int(str(entry.value)) if control.value=="age" else str(entry.value)
		elif control.get("operation")=="feat-filter": filter=str(entry.value).left(128)
func input(message: Dictionary) -> void:
	var operation:=str(message.get("operation",""))
	if operation=="cancel" and phase!="waiting": cancel(); return
	if phase!="editing" or int(message.get("viewId",-1))!=serial: return
	if operation=="voice":
		var control: Dictionary=controls.get(int(message.get("controlId",-1)),{})
		if step==12 and control.get("operation")=="voice-sample": voice.play(int(rules.draft.soundset),str(rules.cell(rules.row("soundset",int(rules.draft.soundset)),"RESREF","")))
		return
	apply_texts(message.get("texts",[])); var d: Dictionary=rules.draft; status=""
	if operation=="page": step=clampi(int(message.step),0,14)
	elif operation=="preview": preview.stop()
	elif operation=="recommend": phase="recommending"; status="Reading package recommendations…"; package_tables()
	elif operation=="submit":
		var problems:=rules.errors()
		if not problems.is_empty(): step=14
		else: phase="preparing"; status="Preparing your character…"; package_tables(); begin_build()
	elif operation=="control":
		var c: Dictionary=controls.get(int(message.get("controlId",-1)),{})
		if c.is_empty() or c.disabled: render(); return
		var value: Variant=message.get("value"); var id:=int(c.value) if c.value is int else -1
		if c.type=="select":
			if not (value is int or value is float) or float(value)!=floor(float(value)) or int(value)<0 or int(value)>=c.options.size(): render(); return
		match str(c.operation):
			"gender": d.gender=id; d.portrait=""
			"race": d.raceId=id; d.age=rules.num(rules.race(),"AGE",18); rules.initialize_abilities(); rules.reset_choices()
			"class": rules.select_class(id)
			"alignment": d.merge(rules.alignment(id),true)
			"package": d.packageId=id
			"portrait": d.portrait=c.value
			"portrait-page": portrait_page+=id
			"ability": d.abilities[c.value[0]]=int(d.abilities[c.value[0]])+int(c.value[1]); rules.reset_choices()
			"skill": d.skills[c.value[0]]=int(d.skills.get(c.value[0],0))+int(c.value[1]); d.feats=[]
			"feat-kind": feat_kind=str(c.value[int(value)])
			"feat-unavailable": show_unavailable=bool(value)
			"feat-filter": filter=str(value).left(128)
			"feat": d.feats.append({"id":id,"kind":feat_kind})
			"feat-remove": d.feats.remove_at(id)
			"spell":
				var selected: Array=d.known.get(c.value[0],[]).duplicate(); var spell: int=int(c.value[1])
				if selected.has(spell): selected.erase(spell)
				else: selected.append(spell)
				d.known[c.value[0]]=selected; d.memorized={}
			"prepared":
				var prepared: Array=d.memorized.get(c.value[0],[]).duplicate()
				while prepared.size()<=int(c.value[1]): prepared.append(null)
				var spell: int=int(c.value[2][int(value)]); prepared[int(c.value[1])]=null if spell<0 else spell; d.memorized[c.value[0]]=prepared
			"school": d.school=c.value[int(value)]; d.known={}
			"domain-0","domain-1":
				while d.domains.size()<2: d.domains.append(-1)
				d.domains[int(str(c.operation).right(1))]=c.value[int(value)]; d.feats=[]
			"head": d.head=c.value[int(value)]
			"phenotype": d.phenotype=c.value[int(value)]
			"clothing": d.clothes=c.value[int(value)]
			"voice": d.soundset=c.value[int(value)]; voice.reset()
			"familiar","companion": d[c.operation]=c.value[int(value)]
			"palette": d[c.value[0]]=c.value[1][int(value)]
			"field": d[c.value]=int(str(value)) if c.value=="age" else str(value)
	render()
func begin_build() -> void:
	var scope:=draft_scope
	while not dead and phase=="preparing" and scope==draft_scope and (build_task>=0 or not jobs.is_empty() or not resource_queue.is_empty()): await get_tree().process_frame
	if dead or phase!="preparing" or scope!=draft_scope: return
	var source:=Rules.new(); source.tables=rules.tables; source.catalog=rules.catalog.fork(); source.model_names=rules.model_names; source.palette_sizes=rules.palette_sizes; source.portrait_cache=rules.portrait_cache; source.draft=rules.draft.duplicate(true)
	build_task=WorkerThreadPool.add_task(func():
		var builder:=Builder.new(); var bytes:=builder.build(source); build_result={"bytes":bytes,"error":builder.failure,"scope":scope},false,"Native character BIC")
func observe(state: Dictionary) -> void:
	if phase=="waiting" and str(state.get("phase",""))=="character-rejected": phase="editing"; step=14; status="The server rejected the character. Review your choices."; render()
	elif phase=="waiting" and str(state.get("phase","")) in ["area-loading","playing"]: finish_view()
func finish_view() -> void: draft_scope+=1; phase="closed"; preview.stop(); voice.reset(); view.reset(); closed.emit()
func cancel() -> void:
	request.emit({"kind":"native-creation-cancel","connection":connection}); finish_view()
func result(message: Dictionary) -> void:
	if not message.get("accepted",false) and phase!="closed": phase="editing" if not rules.draft.is_empty() else "loading"; status=str(message.get("text","Character creation failed.")); render()
func close() -> void:
	if dead: return
	dead=true; preview.close(); voice.close(); assets.close()
	if build_task>=0: WorkerThreadPool.wait_for_task_completion(build_task); build_task=-1
	build_result.clear(); resource_queue.clear(); jobs.clear(); view.reset()
func _exit_tree() -> void: close()
