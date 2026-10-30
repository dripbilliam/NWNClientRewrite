extends "res://tests/native_particle_schedule_test.gd"
const Impact=preload("res://systems/native_data/projectile_impact.gd")
const Orientation=preload("res://systems/native_data/projectile_orientation.gd")
static func bits(values: Array) -> Array: return values.map(func(v):return PackedFloat32Array([v]).to_byte_array().decode_u32(0))
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var index:=0
	for row in original("native-projectile-impact-observations",2472):
		var c: Dictionary=row.case; var calls: Array=[]; var target: Dictionary={}
		var s:={"targetId":0x80000063,"result":c.result,"impactNode":"authored_impact","impactDuration":c.duration,"remaining":0,"orientation":c.vector,"rangedEffect":0}
		var p:={"getObject":func(id):calls.append(["lookup",id]); return {"status":c.lookup,"object":target},"modelHandle":func(_o):return c.handle,"field28":func(_o):return c.field28,
			"model":func(o,part,flags):calls.append(["projectileModel" if is_same(o,s) else "targetModel",part,flags]); return {} if (c.model if is_same(o,s) else c.anchor) else null,
			"creature":func(_o):calls.append(["creature"]); return {} if c.creature else null,
			"equipped":func(_o,slot):calls.append(["equipped",slot]); return 0x80000077,"item":func(id):calls.append(["item",id]); return {} if c.item else null,
			# Retained corpus key weaponType is a historical label for the raw
			# byte8 fixture. Original loader proves that byte is WeaponWield.
			"weaponWield":func(_o):calls.append(["baseItem",42]); return c.weaponType,"itemModel":func(_o,part,flags):calls.append(["targetModel",part,flags]); return {} if c.anchor else null,
			"random":func():calls.append(["random"]); return c.random,
			"attach":func(_m,_a,name,flags):calls.append(["attach",name,flags]); return c.attach,
			"nodePose":func(_m,name,point,q):
				calls.append(["getPose",name])
				if c.pose: point.assign([7,8,9]); q.assign([0.5,0.5,0.5,0.5])
				return c.pose,
			"impactQuaternion":Orientation.impact,"setNodePose":func(_m,name,point,q):calls.append(["setPose",name,bits(point),bits(q)])}
		Impact.attach(s,p); var difference:=same({"calls":calls,"duration":s.impactDuration,"remaining":s.remaining},{"calls":row.calls,"duration":row.duration,"remaining":row.remaining})
		check(difference.is_empty(),"Original impact/body/shield/quaternion "+str(index)+" "+difference); index+=1
	index=0
	for row in original("native-client-projectile-orientation-observations",130):
		var q: Variant=Orientation.model(row.vector)
		check(q==null if int(row.result)==0 else q!=null and same(bits(q),row.quaternion).is_empty(),"Original model direction quaternion "+str(index)); index+=1
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalEvidence":evidence,"binarySha256":BINARY_SHA,"scope":"Actual native impact admission/equipment/attachment/call order/duration and original-derived finite CRT orientation against stored original cases; not complete scene/option/CRT exceptional-state parity"},"\t")); file.close()
	print("NATIVE_PROJECTILE_IMPACT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
