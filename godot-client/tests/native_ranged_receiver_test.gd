extends "res://tests/native_particle_schedule_test.gd"
const Ranged=preload("res://systems/native_data/projectile_ranged.gd")
const Parts=preload("res://systems/native_data/model_random_part.gd")
func cases(name: String,count: int) -> Dictionary:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/"+name+"-observations.json"); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==BINARY_SHA and data.cases.size()==count,"Original observation identity/count "+name); evidence.append({"name":name,"sha256":FileAccess.get_sha256(path),"cases":count}); return data
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report) or not FileAccess.file_exists(args.oracle): quit(2); return
	var index:=0
	for row in cases("native-client-ranged-projectile",132).cases:
		var c: Dictionary=row.case; var source:={"id":0x80000011,"objectType":5}; var target:={"id":0x80000012,"objectType":c.targetType}; var commands: Array=[]; var created: Array=[]
		var header:={"sourceId":source.id if c.source else 0x7f000000,"targetId":target.id if c.target else 0x7f000000,"from":[1.25,-2,3.5],"to":[4,5,6],"duration":250,"appearance":c.appearance,"path":c.path,"baseItem":49,"result":c.result}
		var p:={"rangedMetadata":func(_base,_appearance):
			if not c.baseValid: return {}
			var signed: int=int(c.ammo)-256 if int(c.ammo)>=128 else int(c.ammo); var i:=((signed+int({0:-1,1:5,2:11,3:17,4:23,5:29}.get(int(c.appearance),-1)))&0xffffffff) if c.legacy else 0
			commands.append({"kind":"cell","column":"Model","row":i,"value":"fixture_"+str(i)}); return {"ammunition":c.ammo,"model":"fixture_"+str(i),"shotSound":"shot","shotFound":true,"impactSound":"impact","row":i},
			"object":func(id):return source if id==source.id and c.source else target if id==target.id and c.target else null,
			"model":func(o):return o if c.model else null,"modelHandle":func(_o):return c.model,"appearance":func(_o):return 0,
			"nodePose":func(_m,part,point,_q):commands.append({"kind":"pose","part":part}); point.assign([7,8,9]); return c.pose,
			"oneShot":func(resource,point,_priority,_height):commands.append({"kind":"sound","resource":resource,"position":point}),
			"modelType":func(i):commands.append({"kind":"cell","column":"modeltype","row":i,"value":c.sourceModelType}); return c.sourceModelType,
			"weaponScale":func(_i):return {"found":true,"value":M.f(c.scale)},"hitPartsEnabled":func():return c.config,"random":func():return c.random,"randomImpactPart":func(_m):return "fixture_impact",
			"worldTime":func():return {"day":0,"time":0},"register":func(s):commands.append({"kind":"construct"}); created.append(s),"registerAI":func(_s):pass,
			"loadModel":func(s,name,_path):
				commands.append({"kind":"load","model":name})
				if c.load: s.model={}
				return c.load,
			"destroy":func(s):commands.append({"kind":"destroy"}); s.destroyed=true,
			"modelScale":func(_m,value,_flags):commands.append({"kind":"scale","value":value}),"defaultMaterial":func(_s):commands.append({"kind":"material","name":"DEFAULT"}),
			"setTarget":func(s,id,part):commands.append({"kind":"target","id":id,"part":part}); s.targetId=id,"trackProjectile":func(_t,_s):commands.append({"kind":"track"}),
			"setStage":func(_s,value):commands.append({"kind":"stage","value":value}),"setPosition":func(_s,value):commands.append({"kind":"position","value":value}),"setOrientation":func(_s,value):commands.append({"kind":"orientation","value":value}),
			"configurePath":func(s,value):commands.append({"kind":"duration","value":s.totalTime}); commands.append({"kind":"path","value":value}),"setScene":func(_s,_v):commands.append({"kind":"scene"}),"ready":func(_s):pass}
		Ranged.receive(header,p)
		var expected: Array=row.commands.filter(func(command):return command.kind!="cell" or command.column not in ["ShotSound","ImpactSound"])
		var difference:=same(commands,expected); check(difference.is_empty(),"Original ranged receiver "+str(index)+" "+difference)
		if not created.is_empty() and not created[0].destroyed:
			var s: Dictionary=created[0]; var fields:={"result":s.result,"rangedEffect":s.rangedEffect,"impactCritical":s.get("impactCritical",0),"impactDuration":s.impactDuration,"facing":s.facing,"impactSound":s.impactSound}
			difference=same(fields,row.fields); check(difference.is_empty(),"Original ranged state fields "+str(index)+" "+difference)
		index+=1
	var source:=cases("native-model-random-part",84)
	for row in source.cases:
		var c: Dictionary=row.case; var parts: Array=[]
		for i in c.areas.size(): parts.append({"index":i,"parent":int(c.parents[i]),"name":"part"+str(i),"area":0.0 if c.areas[i]==null else M.f(c.areas[i])})
		var model:=Parts.graph(parts); model.partArea=float(c.cached); var draws: Array=[0]
		var name: Variant=Parts.choose(model,func():draws[0]+=1; return int(c.draw))
		var difference:=same({"name":name,"area":model.partArea,"draws":draws[0]},{"name":row.name,"area":row.area,"draws":row.draws}); check(difference.is_empty(),"Original weighted physical part "+str(c.draw)+" "+difference)
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	for row in oracle.cases:
		var actual:=Ranged.metadata(row.tables,int(row.baseItem),int(row.appearance)); var expected: Dictionary=row.expected if row.expected!=null else {}
		var difference:=same(actual,expected); check(difference.is_empty(),"Authored active ammunition table "+str(row.appearance)+" "+difference)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"Original ranged receiver/physical weighted-part replay and authored active-table metadata; rendering, impact quaternion and specialized paths require separate checks"},"\t")); file.close()
	print("NATIVE_RANGED_RECEIVER ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
