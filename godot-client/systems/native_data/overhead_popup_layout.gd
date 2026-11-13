extends RefCounted
# Original1406e8880, ordered registered popup layout. NEW/unimported candidate.
# x/y are projected native center-bottom anchors. No viewport clamp or queue.
const F=preload("res://systems/native_render/particle_math.gd")
const MAX_I:=2147483647
static func i32(value: int) -> int:
	return ((value+2147483648)&4294967295)-2147483648
static func half(value: int) -> int:
	return int(float(i32(value))/2.0)
static func native_abs(value: int) -> int:
	return i32((value^(value>>31))-(value>>31))
static func cvtt(value: float) -> int:
	value=F.f(value)
	return -2147483648 if not is_finite(value) or value< -2147483648.0 or value>=2147483648.0 else int(value)
static func arrange(input: Array,mode: int,enabled: bool=true) -> Dictionary:
	var rows: Array=input.duplicate(true)
	var placed: Array=[]
	for row in rows:
		for field in ["x","y","width","height"]:
			if not row.has(field) or not (row[field] is int or row[field] is float):return {"ready":false,"reason":"Native popup layout field unavailable."}
			row[field]=F.f(float(row[field]))
		row.z=F.f(float(row.get("z",-5.0)))
	if mode==0 or not enabled:return {"ready":true,"rows":rows,"placed":placed}
	var padding: int=40 if mode==2 else 0
	for index in rows.size():
		var a: Dictionary=rows[index]
		if a.get("active",0)!=1:continue
		var neg_x:=MAX_I;var pos_x:=MAX_I;var neg_y:=MAX_I;var pos_y:=MAX_I
		var spent_x:=0;var spent_y:=0
		for earlier in index:
			var b: Dictionary=rows[earlier]
			if b.get("active",0)!=1:continue
			var dx: int=cvtt(F.f(float(a.x)-float(b.x)))
			var dy: int=i32(cvtt(F.f(float(a.y)-float(b.y)))+half(i32(cvtt(a.height)-cvtt(b.height))))
			var ox: int=i32(half(i32(cvtt(a.width)+cvtt(b.width)+padding))-native_abs(dx))
			var oy: int=i32(half(i32(cvtt(a.height)+cvtt(b.height)))-native_abs(dy))
			if ox>0 or oy>0:
				if dx<0:neg_x=mini(neg_x,i32(-ox))
				else:pos_x=mini(pos_x,i32(-ox))
				if dy<0:neg_y=mini(neg_y,i32(-oy))
				else:pos_y=mini(pos_y,i32(-oy))
				if ox>0 and oy>0:
					var moved:=false
					for attempt in 2:
						if moved:break
						var want_x: int=i32(ox+spent_x);var want_y: int=i32(oy+spent_y)
						if want_x<want_y:
							if (ox<=pos_x if dx<0 else ox<=neg_x):
								a.x=F.f(float(a.x)-F.f(float(ox)) if dx<0 else float(a.x)+F.f(float(ox)))
								spent_x=want_x;moved=true
							ox=MAX_I
						else:
							if (oy<=pos_y if dy<0 else oy<=neg_y):
								a.y=F.f(float(a.y)-F.f(float(oy)) if dy<0 else float(a.y)+F.f(float(oy)))
								spent_y=want_y;moved=true
							oy=MAX_I
		placed.append({"index":index,"x":a.x,"y":a.y,"z":a.z})
	return {"ready":true,"rows":rows,"placed":placed}
