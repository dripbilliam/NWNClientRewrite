extends RefCounted
# LoadVisualEffect14096cf10..14096ed64 selection, from the retained reviewed
# loader. Active native tables and original model-part descriptors only.
const Phases=preload("res://systems/visual_phases.gd")
const Numbers=preload("res://systems/native_data/combat_actor.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
var failure:=""
static func query(table: Dictionary,index: int,column: String,kind: String) -> Dictionary:
	var rows: Array=table.get("orderedRows",[]); var value: Variant=null
	if index>=0 and index<rows.size(): value=Rules.cell(rows[index],column)
	var valid:=value!=null; var text:=str(value) if valid else str(table.get("defaultValue","****"))
	var found:=valid and text not in ["","****"]
	if kind=="string": return {"found":found,"value":"" if text in ["","****"] else text}
	if kind=="integer": return {"found":found,"value":Numbers.integer(table,index,column)}
	var pattern:=RegEx.new(); pattern.compile("^\\s*[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][+-]?\\d+)?")
	var parsed:=pattern.search(text)
	return {"found":found,"value":Phases.f32(parsed.get_string().to_float() if parsed!=null else 0.0)}
static func identity(map: Variant) -> bool:
	if map==null: return true
	if not map is Dictionary or map.get("legacy",false): return false
	var entries: Array=map.get("entries",[]); var keys: Array=map.get("keys",[])
	if entries.is_empty(): return keys.is_empty()
	if entries.size()!=1 or int(entries[0].key)!=0 or keys.size()!=1 or int(keys[0])!=0: return false
	var leaf: Dictionary=entries[0].value
	if leaf.get("identity",false): return true
	var channels: Array=leaf.get("channels",[])
	if channels.size()!=10: return false
	for i in 10:
		if channels[i].value!=(1 if i in [0,1,2,9] else 0) or channels[i].duration!=0: return false
	return true
static func prefix(model: Dictionary,type: int) -> String:
	var name:=str(model.get("loadedName","")).to_lower()
	return name.substr(4) if type==9 else name if type==10 else ""
static func anchor(model: Dictionary,name: String) -> String:
	return name if name=="root" or model.get("parts",[]).any(func(part):return str(part).to_lower()==name.to_lower()) else "root"
func prepare(actor: Dictionary,record: Dictionary,tables: Dictionary,hosts: Dictionary,settings: Dictionary={"quality64":1,"violence40":2}) -> Dictionary:
	failure=""
	if not identity(record.get("networkTransform")): failure="Native nonidentity effect controller maps remain pending"; return {}
	if int(record.get("bodyPart",0))!=0: failure="Native nondefault looping effect body-part routing remains pending"; return {}
	var id:=int(actor.id); var type:=int(actor.objectType)
	if type not in [5,9,10] or not hosts.has(id): failure="Original visual target model is unavailable"; return {}
	var state:=Phases.constructor_state(); var visual:=int(record.visualId)&65535; var table: Dictionary=tables.get("visualeffects",{})
	state.visualF8=visual; state.target54=id; state.source58=int(record.get("sourceId",0x7f000000))
	var integer:=func(column):return query(table,visual,column,"integer")
	var string_value:=func(row,column):return str(query(table,row,column,"string").value)
	var orient: Dictionary=integer.call("OrientWithObject"); state.orient120=1 if orient.found and orient.value!=0 else 0
	var names:=["",string_value.call(visual,"Imp_Impact_Node"),string_value.call(visual,"Imp_HeadCon_Node")]
	for i in [1,2]:
		if str(names[i]).is_empty(): continue
		var low: Dictionary=query(table,visual,"LowQuality","string")
		if int(settings.quality64)==0 and low.found: names[i]=low.value
		if int(settings.violence40)<2:
			low=integer.call("LowViolence")
			if low.found:
				var alternate:=query(table,int(low.value),"Imp_Impact_Node" if i==1 else "Imp_HeadCon_Node","string")
				if i==1 or alternate.found: names[i]=alternate.value
	var size:=3
	if type==5:
		var category:=query(tables.get("appearance",{}),int(actor.get("appearance",{}).get("appearance",0))&65535,"SIZECATEGORY","integer")
		if category.found: size=int(category.value)
	var root_for:=func(row):
		if size>=5: names[0]=string_value.call(row,"Imp_Root_H_Node")
		if size>=4 and str(names[0]).is_empty(): names[0]=string_value.call(row,"Imp_Root_L_Node")
		if size>=1 and str(names[0]).is_empty(): names[0]=string_value.call(row,"Imp_Root_M_Node")
	root_for.call(visual)
	if not str(names[0]).is_empty():
		var low:=query(table,visual,"LowQuality","string")
		if int(settings.quality64)==0 and low.found: names[0]=low.value
		if int(settings.violence40)<2:
			low=integer.call("LowViolence")
			if low.found: root_for.call(int(low.value))
	var programs:=[{"found":false},{"found":false},{"found":false}]
	if str(names[0]).is_empty():
		for i in 3: programs[i]=integer.call(["ProgFX_Impact","ProgFX_Duration","ProgFX_Cessation"][i])
	if visual==999: programs[0]={"found":true,"value":1100}
	var delivery: Dictionary=record.get("delivery",{}); var source_part:=int(delivery.get("sourcePart",0))&255; var target_part:=int(delivery.get("targetPart",0))&255
	var source: Dictionary=hosts.get(int(state.source58),{}); var target: Dictionary=hosts[id]
	var from_type:=int(source.get("type",5)); var from_prefix:=prefix(source,from_type); var to_prefix:=prefix(target,type)
	state.sourceAnchor28=from_prefix+(["_hand","_impact"][source_part] if source_part<2 else "_ground") if from_type==9 else from_prefix+("impc" if source_part<2 else "grnd") if from_type==10 else "handconjure" if source_part==0 else "impact" if source_part==1 else "monster"+str(source_part-2) if source_part<=11 else "root"
	state.targetAnchor38=to_prefix+("_impact" if target_part<2 else "_ground") if type==9 else to_prefix+("impc" if target_part<2 else "grnd") if type==10 else "impact" if target_part<2 else "monster"+str(target_part-2) if target_part<=11 else "root"
	if not source.is_empty(): state.sourceAnchor28=anchor(source,state.sourceAnchor28)
	state.targetAnchor38=anchor(target,state.targetAnchor38)
	state.point48=delivery.get("point",[0,0,0]).map(func(value):return Phases.f32(float(value)))
	state.programsD0=[65535,65535,65535]; state.retiredDc=[1,1,1]; state.durationFc=1 if int(delivery.get("instant",0))==0 else 0
	var resources: Dictionary={}; var model_serial:=0
	for i in 3:
		if programs[i].found and (i==0 or state.durationFc!=0): state.programsD0[i]=int(programs[i].value)&65535
		var name:=str(names[i]).to_lower()
		if not name.is_empty():
			model_serial+=1; resources[name]=true; state.models88[i]={"id":model_serial,"resource":name}; state.retiredDc[i]=0
	state.programRemainingCc=1000 if state.programsD0[0]!=65535 else 0 if state.programsD0[1]!=65535 else 1000 if state.programsD0[2]!=65535 else 0
	state.closedEc=1; state.controllers128={"scale":1,"translate":[0,0,0],"rotate":[0,0,0]}
	var definition:={"state":state,"programs":{},"visual":{"integer":{},"float":{},"string":{}},"hosts":{},"resources":resources}
	for program in state.programsD0:
		if int(program)==65535 or definition.programs.has(str(program)): continue
		var data:={"id":program,"type":query(tables.get("progfx",{}),program,"Type","integer"),"integer":{},"float":{},"string":{}}
		for column in 7:
			for kind in ["integer","float","string"]: data[kind]["param"+str(column+1)]=query(tables.get("progfx",{}),program,"param"+str(column+1),kind)
		var resource_column: String={4:"param7",7:"param1",12:"param2"}.get(int(data.type.value)&255,"")
		if not resource_column.is_empty():
			data.resource=str(data.string[resource_column].value).to_lower()
			if not data.resource.is_empty(): resources[data.resource]=true
		definition.programs[str(program)]=data
	definition.visual.integer.ShakeType=integer.call("ShakeType")
	for column in ["ShakeDuration","ShakeDelay"]: definition.visual.float[column]=query(table,visual,column,"float")
	for column in ["SoundImpact","SoundDuration","SoundCessation","Type_FD"]: definition.visual.string[column]=query(table,visual,column,"string")
	for actor_id in [id,int(state.source58)]:
		if hosts.has(actor_id): definition.hosts[str(actor_id)]={"id":actor_id,"type":hosts[actor_id].type,"prefix":prefix(hosts[actor_id],int(hosts[actor_id].type)),"privateToken":int(hosts[actor_id].get("privateToken",0))}
	return definition
