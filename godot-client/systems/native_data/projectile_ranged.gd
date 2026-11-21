extends RefCounted
# Receiver1407acc9b..1407ae1b2. All state is client presentation; the packet
# supplies attack result/travel and active server tables supply ammunition art.
const M=preload("res://systems/native_render/particle_math.gd")
const State=preload("res://systems/native_data/projectile_state.gd")
const Query=preload("res://systems/native_data/visual_definition.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
static func hits(result: int) -> bool: return result<11 and result>=0 and ((0x4aa>>result)&1)!=0
static func metadata(tables: Dictionary,base_item: int,appearance: int) -> Dictionary:
	var base: Dictionary=tables.get("baseitems",{}); var ammo: Dictionary=tables.get("ammunitiontypes",{}); var index:=base_item&255
	if index==255 or index>=base.get("orderedRows",[]).size(): return {}
	var ammunition:=int(Query.query(base,index,"AmmunitionType","integer").value)&255; var signed:=ammunition-256 if ammunition>=128 else ammunition
	var columns: Array=ammo.get("columns",[]).map(func(name):return str(name).to_lower()); var row:=-1
	if columns.has("ammunitiontype") and columns.has("damagerangedprojectile"):
		for i in ammo.get("orderedRows",[]).size():
			var a:=Query.query(ammo,i,"AmmunitionType","integer"); var d:=Query.query(ammo,i,"DamageRangedProjectile","integer")
			if a.found and int(a.value)==signed and d.found and int(d.value)==(appearance&255): row=i; break
		if row==-1: return {}
	else: row=signed+int({0:-1,1:5,2:11,3:17,4:23,5:29}.get(appearance&255,-1))
	var model:=str(Query.query(ammo,row,"Model","string").value)
	if model.is_empty(): return {}
	var shot:=Query.query(ammo,row,"ShotSound","string")
	return {"ammunition":ammunition,"row":row,"model":Spell.ref_name(model),"shotSound":Spell.ref_name(str(shot.value)),"shotFound":bool(shot.found),"impactSound":Spell.ref_name(str(Query.query(ammo,row,"ImpactSound","string").value))}
static func construct(p: Dictionary) -> Dictionary:
	var s:=State.constructor_state(p.worldTime.call()); p.register.call(s); p.registerAI.call(s); return s
static func receive(header: Dictionary,p: Dictionary) -> Array:
	var data: Dictionary=p.rangedMetadata.call(int(header.baseItem),int(header.appearance))
	if data.is_empty(): return []
	var source: Variant=p.object.call(int(header.sourceId)); var target: Variant=p.object.call(int(header.targetId)); var ammo:=int(data.ammunition)&255
	var delta:=M.subtract(M.values(header.to),M.values(header.from)); var length:=M.f(sqrt(State.square(delta)))
	var direction: Array=p.shortDirection.call(header) if length<=M.f(0.001) else M.normalize(delta)
	var launch: Array=[M.f(header.from[0]),M.f(header.from[1]),M.f(M.f(header.from[2])+1)]
	if source!=null:
		var model=p.model.call(source)
		if model!=null:
			var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
			if p.nodePose.call(model,"rhand",position,q)==1:
				launch=M.values(position)
				if ammo in [1,2,3,6]:
					var distance:=M.f(float({1:0.6,2:0.3,3:0.4,6:0.4}[ammo]))
					for i in 3: launch[i]=M.f(launch[i]+M.f(direction[i]*distance))
				if ammo==2: launch[2]=M.f(launch[2]+M.f(0.1))
				elif ammo==3: launch[2]=M.f(launch[2]+M.f(0.4))
	if data.shotFound: p.oneShot.call(data.shotSound,M.values(launch),13,1.5)
	var target_creature: Variant=target if target!=null and int(target.objectType)==5 else null; var source_creature: Variant=source if source!=null and int(source.objectType)==5 else null
	var appearance: int=(int(p.appearance.call(target_creature))&65535) if target_creature!=null else 65535
	var source_appearance: int=(int(p.appearance.call(source_creature))&65535) if source_creature!=null else 65535
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
	if ammo not in [1,2,3,4,5,6]: return []
	var s:=construct(p)
	if not p.loadModel.call(s,str(data.model),int(header.path)): p.destroy.call(s); return [s]
	if s.destroyed: return [s]
	var model=p.model.call(s)
	if model!=null: p.modelScale.call(model,scale_value,0)
	p.defaultMaterial.call(s)
	if hits(result):
		p.setTarget.call(s,int(header.targetId),part)
		if ammo==3: s.result=1
		elif target_creature!=null: p.trackProjectile.call(target_creature,s); s.trackedByTarget=1
		s.rangedEffect=1; s.impactCritical=1 if result in [3,10] else 0; s.impactDamage=0
	elif result==2:
		p.setTarget.call(s,int(header.targetId),""); s.result=3 if ammo==3 else 2+int(int(header.path)==13)
	else: p.setTarget.call(s,State.INVALID,""); s.endpoint=M.values(header.to)
	p.setStage.call(s,1); p.setPosition.call(s,M.values(launch)); p.setOrientation.call(s,M.values(direction)); s.facing=2; s.remaining=int(header.duration)&0xffffffff; s.totalTime=s.remaining
	s.impactSound=data.impactSound; s.impactDuration=0 if temporary else 8000
	var path:=13 if int(header.path)==13 else 2
	if ammo==3 and path!=13: path=11 if hits(result) or result==2 or float(header.to[2])==M.f(launch[2]+1) else 12
	p.configurePath.call(s,path); p.setScene.call(s,1); p.ready.call(s); return [s]
