extends RefCounted
# Original872770 selection for type11 area visuals. No dummy/loop effect list.
const Table=preload("res://systems/native_data/visual_definition.gd")
const Phases=preload("res://systems/visual_phases.gd")
var failure:=""
func prepare(message: Dictionary,table: Dictionary,quality: int=1) -> Dictionary:
	failure=""
	if not Table.identity(message.get("visualTransform")): failure="Native area visual controller-map presentation remains pending"; return {}
	var id:=int(message.visualId); var query:={"integer":{},"float":{},"string":{}}
	var read:=func(kind,column):
		var result:=Table.query(table,id,column,kind); query[kind][column]=result; return result
	var orient: Dictionary=read.call("integer","OrientWithGround"); var selected:={"found":false,"value":""}
	if quality==0: selected=read.call("string","LowQuality")
	if not selected.found:
		for column in ["Imp_HeadCon_Node","Imp_Impact_Node","Imp_Root_M_Node","Imp_Root_S_Node","Imp_Root_L_Node","Imp_Root_H_Node"]:
			selected=read.call("string",column)
			if selected.found: break
	var shake: Dictionary=read.call("integer","ShakeType"); var duration: Dictionary=read.call("float","ShakeDuration"); var delay: Dictionary=read.call("float","ShakeDelay")
	var warnings: Array=[]
	if shake.found and int(shake.value) in [1,2]: warnings.append({"code":"visual.area-camera-shake-pending","type":int(shake.value),"delay":int(Phases.f32(delay.value if delay.found else 0)*1000),"duration":0 if int(shake.value)==1 else int(Phases.f32(duration.value if duration.found else 0)*1000)})
	if id in [39,40]: warnings.append({"code":"visual.area-orientation-mode-pending"})
	if id in [253,219]: warnings.append({"code":"visual.area-default-animation-pending"})
	for column in ["SoundImpact","SoundDuration","SoundCessation"]: query.string[column]=Table.query(table,id,column,"string")
	var resources: Dictionary={}; var model: Variant=null
	if selected.found:
		var name:=str(selected.value).to_lower(); resources[name]=true; model={"id":1,"resource":name}
	return {"kind":"area-visual-definition","state":{"objectType":11,"position":message.position.map(func(value):return Phases.f32(float(value))),"since":{"day":0,"time":0},"elapsed58":0,"sound170":null,"retire178":0,"remaining17c":0,"visual180":id,"phase184":0,"retiring188":0,"suppressed18c":0,"instant190":1,"destroy194":1,"orient198":1 if orient.found and orient.value!=0 else 0,"detach19c":0,"skipRetirement1a0":0,"repeat1a4":0,"model":model,"destroyed":false},"resources":resources,"query":query,"warnings":warnings}
