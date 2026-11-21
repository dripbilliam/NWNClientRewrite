extends RefCounted
# Original AI983e2e..9841d2. Ready model, handle78 and client flag28 are
# distinct providers. Keep shield/equipment reads, random draw and call order.
static func attach(s: Dictionary,p: Dictionary) -> bool:
	var found: Dictionary=p.getObject.call(int(s.targetId)&0xffffffff)
	if int(found.status)==0:
		var target: Dictionary=found.object; var result:=int(s.result)&255; var anchor: Variant=null
		if result==0:
			if p.modelHandle.call(target):
				if p.field28.call(target)==0: anchor=p.model.call(target,255,1)
				else: s.impactDuration=0
		elif result==2:
			# The normal network adapter omitted impactEquipment. Its equipped()
			# provider throws here; the presentation catches and retires this shot.
			return false
		var model: Variant=p.model.call(s,255,1)
		if anchor!=null and model!=null and result not in [1,3]:
			if result in [0,2]:
				var part: String=s.impactNode if result==0 else "imp_shield_"+str((int(p.random.call())%2)+1)
				p.attach.call(model,anchor,part,0)
				var query_error:=str(p.partQueryFailure.call())
				if not query_error.is_empty():s.partQueryFailure=query_error;return false
				var position: Array=[0.0,0.0,0.0]; var q: Array=[1.0,0.0,0.0,0.0]
				p.nodePose.call(model,"root",position,q)
				query_error=str(p.partQueryFailure.call())
				if not query_error.is_empty():s.partQueryFailure=query_error;return false
				p.setNodePose.call(model,"root",position,p.impactQuaternion.call(s.orientation))
				query_error=str(p.partQueryFailure.call())
				if not query_error.is_empty():s.partQueryFailure=query_error;return false
		if p.creature.call(target)!=null and (int(s.rangedEffect)&255)!=0: p.rangedImpact.call(target,s)
	s.remaining=int(s.impactDuration)&0xffffffff
	return true
