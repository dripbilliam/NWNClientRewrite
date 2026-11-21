extends RefCounted
# Receiver1407acc9b..1407ae1b2. All state is client presentation; the packet
# supplies attack result/travel and active server tables supply ammunition art.
const M=preload("res://systems/native_render/particle_math.gd")
const State=preload("res://systems/native_data/projectile_state.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const VisualType10=preload("res://systems/native_data/visual_type10.gd")
static func hits(result: int) -> bool: return result<11 and result>=0 and ((0x4aa>>result)&1)!=0
static func metadata(tables: Dictionary,base_item: int,appearance: int) -> Dictionary:
	var base: Dictionary=tables.get("baseitems",{}); var ammo: Dictionary=tables.get("ammunitiontypes",{}); var index:=base_item&255
	# The old reader accepts physical ordered rows or Map insertion-order rows.
	# Query consumes orderedRows, so supply that view for the same fallback.
	var base_view: Dictionary=base.duplicate()
	if not base_view.get("orderedRows") is Array:
		base_view.orderedRows=base.get("rows",{}).values() if base.get("rows",null) is Dictionary else []
	var ammo_view: Dictionary=ammo.duplicate()
	if not ammo_view.get("orderedRows") is Array:
		ammo_view.orderedRows=ammo.get("rows",{}).values() if ammo.get("rows",null) is Dictionary else []
	if index==255 or index>=base_view.orderedRows.size(): return {}
	var ammunition:=int(Query.query(base_view,index,"AmmunitionType","integer").value)&255; var signed:=ammunition-256 if ammunition>=128 else ammunition
	var columns: Array=ammo.get("columns",[]).map(func(name):return str(name).to_lower()); var row:=-1
	if columns.has("ammunitiontype") and columns.has("damagerangedprojectile"):
		for i in ammo_view.orderedRows.size():
			var a:=Query.query(ammo_view,i,"AmmunitionType","integer"); var d:=Query.query(ammo_view,i,"DamageRangedProjectile","integer")
			if a.found and int(a.value)==signed and d.found and int(d.value)==(appearance&255): row=i; break
		if row==-1: return {}
	else: row=signed+int({0:-1,1:5,2:11,3:17,4:23,5:29}.get(appearance&255,-1))
	var model:=str(Query.query(ammo_view,row,"Model","string").value)
	if model.is_empty(): return {}
	var shot:=Query.query(ammo_view,row,"ShotSound","string")
	var model_ref:Dictionary=VisualType10.object_template_resref(model)
	var shot_ref:Dictionary=VisualType10.object_template_resref(str(shot.value))
	var impact_ref:Dictionary=VisualType10.object_template_resref(str(Query.query(ammo_view,row,"ImpactSound","string").value))
	if model_ref.has("error") or shot_ref.has("error") or impact_ref.has("error"):return {}
	return {"ammunition":ammunition,"row":row,"model":model_ref.value,"shotSound":shot_ref.value,"shotFound":bool(shot.found),"impactSound":impact_ref.value}
static func construct(p: Dictionary) -> Dictionary:
	var s:=State.constructor_state(p.worldTime.call()); p.register.call(s); p.registerAI.call(s); return s
static func begin(header: Dictionary,p: Dictionary,data: Dictionary) -> Dictionary:
	var source: Variant=p.object.call(int(header.sourceId)); var target: Variant=p.object.call(int(header.targetId)); var ammo:=int(data.ammunition)&255
	var delta:=M.subtract(M.values(header.to),M.values(header.from)); var length:=M.f(sqrt(State.square(delta)))
	var direction: Array=p.shortDirection.call(header) if length<=M.f(0.001) else M.normalize(delta)
	var launch: Array=[M.f(header.from[0]),M.f(header.from[1]),M.f(M.f(header.from[2])+1)]
	if source!=null:
		var model=p.model.call(source)
		if model!=null:
			var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
			var pose_result:=int(p.nodePose.call(model,"rhand",position,q))
			if pose_result<0:return {"error":str(p.partQueryFailure.call())}
			if pose_result==1:
				launch=M.values(position)
				if ammo in [1,2,3,6]:
					var distance:=M.f(float({1:0.6,2:0.3,3:0.4,6:0.4}[ammo]))
					for i in 3: launch[i]=M.f(launch[i]+M.f(direction[i]*distance))
				if ammo==2: launch[2]=M.f(launch[2]+M.f(0.1))
				elif ammo==3: launch[2]=M.f(launch[2]+M.f(0.4))
	if data.shotFound: p.oneShot.call(data.shotSound,M.values(launch),13,1.5)
	return {"data":data,"source":source,"target":target,"ammo":ammo,"direction":direction,"launch":launch}
static func receive(header: Dictionary,p: Dictionary,started: Dictionary={}) -> Array:
	var data: Dictionary=started.get("data",{}) if not started.is_empty() else p.rangedMetadata.call(int(header.baseItem),int(header.appearance))
	if data.is_empty(): return []
	var initial: Dictionary=started if not started.is_empty() else begin(header,p,data)
	var source: Variant=initial.source; var target: Variant=initial.target; var ammo:=int(initial.ammo)
	var direction: Array=initial.direction; var launch: Array=initial.launch
	var target_creature: Variant=target if target!=null and int(target.objectType)==5 else null; var source_creature: Variant=source if source!=null and int(source.objectType)==5 else null
	var appearance: int=(int(p.appearance.call(target_creature))&65535) if target_creature!=null else 65535
	if p.receiverFailed.call():return []
	var source_appearance: int=(int(p.appearance.call(source_creature))&65535) if source_creature!=null else 65535
	if p.receiverFailed.call():return []
	var special:=appearance in [103,116,298]; var model_type:=str(p.modelType.call(source_appearance)); var scale_value:=1.0
	if (model_type.contains("P") or model_type.contains("F")) and source_creature!=null:
		var entry: Dictionary=p.weaponScale.call(source_appearance)
		if entry.found: scale_value=M.f(1.2) if float(entry.value)>=M.f(1.2) else M.f(entry.value)
	var temporary:=false; var part:="impact"; var result:=int(header.result)&255
	if not special and p.hitPartsEnabled.call()==0: temporary=true
	elif hits(result):
		var type:=str(p.modelType.call(appearance))
		if target!=null and p.modelHandle.call(target):
			var generic: bool=(type.contains("P") or type.contains("F")) and int(p.random.call())%3==0
			if not generic:
				var model=p.model.call(target)
				if model!=null:
					var selected: Variant=p.randomImpactPart.call(model); part=str(selected) if selected!=null else ""
					if p.receiverFailed.call():return []
	if ammo not in [1,2,3,4,5,6]: return []
	var s:=construct(p)
	if not p.loadModel.call(s,str(data.model),int(header.path)): p.destroy.call(s); return [s]
	if s.destroyed: return [s]
	var model=p.model.call(s)
	if model!=null: p.modelScale.call(model,scale_value,0)
	p.defaultMaterial.call(s)
	if hits(result):
		p.setTarget.call(s,int(header.targetId),part)
		if s.destroyed:return [s]
		if ammo==3: s.result=1
		elif target_creature!=null: p.trackProjectile.call(target_creature,s); s.trackedByTarget=1
		s.rangedEffect=1; s.impactCritical=1 if result in [3,10] else 0; s.impactDamage=0
	elif result==2:
		p.setTarget.call(s,int(header.targetId),"")
		if s.destroyed:return [s]
		s.result=3 if ammo==3 else 2+int(int(header.path)==13)
	else:
		p.setTarget.call(s,State.INVALID,"")
		if s.destroyed:return [s]
		s.endpoint=M.values(header.to)
	p.setStage.call(s,1); p.setPosition.call(s,M.values(launch)); p.setOrientation.call(s,M.values(direction)); s.facing=2; s.remaining=int(header.duration)&0xffffffff; s.totalTime=s.remaining
	s.impactSound=data.impactSound; s.impactDuration=0 if temporary else 8000
	var path:=13 if int(header.path)==13 else 2
	if ammo==3 and path!=13: path=11 if hits(result) or result==2 or float(header.to[2])==M.f(launch[2]+1) else 12
	p.configurePath.call(s,path)
	if s.destroyed:return [s]
	var scene_result:Variant=p.setScene.call(s,1)
	if scene_result is bool and not scene_result:
		if p.has("sceneFailed") and p.sceneFailed is Callable:p.sceneFailed.call(s)
		else:p.destroy.call(s)
		return [s]
	p.ready.call(s); return [s]
