extends "res://tests/native_particle_schedule_test.gd"
const Controller=preload("res://systems/native_data/cast_visual_controller.gd")
func name(model: Variant) -> Variant: return model.name if model!=null else null
func fixture(c: Dictionary) -> Dictionary:
	var old: Array=[]
	for i in 7: old.append({"name":"old"+str(i)})
	var s:=Controller.create(); var calls: Array=[]; var serial: Array=[0]
	for i in 3:
		s.conjure[i]=(old[0] if c.get("alias",false) else old[i]) if (int(c.get("slots",0))&(1<<i))!=0 else null
		s.cast[i]=old[i+3] if (int(c.get("slots",0))&(1<<(i+3)))!=0 else null
	var timers: Array=c.get("timers",[0,0,0]); s.conjureTime=int(timers[0]); s.castTime=int(timers[1]); s.released=int(timers[2]); s.done=c.get("done",[0,0,0]).map(func(value):return int(value))
	var source:={"name":"actor","position":[1,2,3]}
	var actor:={"source":source,"visuals":s,"animation":int(c.get("animation",15)),"spellId":42,"previousCasting":int(c.get("previous",0)),"suppressSound":int(c.get("suppress",0)),"race":int(c.get("soundSet",0)),"gender":int(c.get("female",0))}
	var p:={"create":func(resource,category):
		var index: int=serial[0]; serial[0]+=1; calls.append(["create",resource,category]); return null if (int(c.get("fail",0))&(1<<index))!=0 else {"name":"new"+str(index)},
		"attach":func(model,parent,part,flags):
			calls.append(["attach",name(model),name(parent),part,flags])
			if c.get("detachNull",false) and parent==null:
				for group in [s.conjure,s.cast]:
					for i in 3:
						if is_same(group[i],model): group[i]=null,
		"destroy":func(model):calls.append(["destroy",name(model),1]),
		"play":func(model,clip,_speed,flags,time):calls.append(["play",name(model),clip,0x3f800000,flags,time]),
		"listen":func(model,event,callback,context):
			check(callback==Controller.done_fade and is_same(context,s),"Original callback/context identity"); calls.append(["listen",name(model),event,"controller"]),
		"sourceModel":func(_source,part,flags):calls.append(["source",part,flags]); return {"name":"source"} if c.get("model",1) else null,
		"nodePose":func(model,part,position,_q):
			calls.append(["pose",name(model),part])
			if c.get("pose",1): position.assign([7,8,9])
			return c.get("pose",1),
		"oneShot":func(sound,position,priority,_gain):calls.append(["sound",sound,position,0x3fc00000,priority,0,0]),
		"spell":func(id):
			calls.append(["spell",int(id)&0xffffffff]); return {"conjure":["head","hand","ground"],"conjureSoundMale":"male","conjureSoundFemale":"female","conjureSound":"generic"} if c.get("spell",1) else null}
	return {"old":old,"s":s,"calls":calls,"actor":actor,"source":source,"p":p}
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-cast-visual-controller-observations.json"; var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.binarySha256==BINARY_SHA and oracle.rows.size()==3644,"Original cast controller target/count")
	var modes: Dictionary={}
	for row in oracle.rows:
		var c: Dictionary=row.case; var f:=fixture(c); var s: Dictionary=f.s; var p: Dictionary=f.p; var op:=str(c.op)
		match op:
			"ctor": s.merge(Controller.create(),true)
			"release": Controller.release(s,c.refs,f.source,p)
			"start": Controller.start(s,c.refs,c.sounds,f.source,p)
			"clear": Controller.clear(s,c.group,p)
			"callback": Controller.done_fade(f.old[int(c.which)],s if c.get("context",1) else null)
			"tick": Controller.update(s,int(c.elapsed),p)
			"driver": Controller.drive(f.actor,int(c.elapsed),p)
			_: check(false,"Unknown original operation "+op)
		var actual: Dictionary=s.duplicate(); actual.conjure=s.conjure.map(name); actual.cast=s.cast.map(name)
		var wanted:={"state":row.state,"calls":row.calls,"previous":row.previous,"spellId":row.spellId,"suppress":row.suppress}
		var got:={"state":actual,"calls":f.calls,"previous":f.actor.previousCasting,"spellId":f.actor.spellId,"suppress":f.actor.suppressSound}
		var difference:=same(got,wanted)
		check(difference.is_empty(),"Original ordered fields/providers "+JSON.stringify(c)+" "+difference); modes[op]=int(modes.get(op,0))+1
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"modes":modes,"binarySha256":BINARY_SHA,"oracleSha256":FileAccess.get_sha256(path),"scope":"Stored original cast controller instructions/driver fields and ordered lower boundaries; renderer model/audio/lifetime and real casting require separate evidence"},"\t")); file.close()
	print("NATIVE_CAST_VISUAL_CONTROLLER ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
