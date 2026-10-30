extends RefCounted
# Original SpawnHitVisuals14080bb10 mode1 and its distinct three model slots.
# Native row numbers select categories; active tables supply all resource names.
const M=preload("res://systems/native_render/particle_math.gd")
const Trig=preload("res://systems/native_data/projectile_orientation.gd")
const ROWS={"R":[109,112,115],"G":[110,113,116],"Y":[111,114,117],"W":[237,238,239]}
static func signed16(value: int) -> int:
	value&=65535
	return value-65536 if value>=32768 else value
static func select(actor: Dictionary,record: Dictionary,p: Dictionary) -> Variant:
	if int(p.kind.call(actor))==1: return null
	var violence:=int(p.violence.call())
	var large:=int(record.result) in [3,10] or ((int(record.get("attackType",0))-867)&0xffffffff)<2 or int(record.get("killingBlow",0))==1
	var blood:=str(p.blood.call(actor))
	if blood=="N": return null
	if blood.is_empty(): p.warning.call("missing-blood"); return null
	if int(record.weaponAttackType)==7: violence=0
	var level: int
	if violence in [0,2]: level=2 if large else 0 if signed16(int(record.damage))<int(signed16(int(p.maximum.call(actor)))/10) else 1
	elif violence==1: level=1 if large else 0
	else: p.warning.call("unknown-violence"); return ""
	var color: String="W" if blood=="W" or bool(p.whiteOverride.call(actor)) else blood
	if not ROWS.has(color): return ""
	var row:=int(ROWS[color][level])
	if violence==0:
		var low: Dictionary=p.lowViolence.call(row)
		if low.found: row=int(low.value)
	return str(p.modelName.call(row))
static func slot(slots: Array,p: Dictionary) -> int:
	for i in 3:
		if slots[i]==null: return i
		if float(p.playInfo.call(slots[i],"impact"))==-1:
			p.destroy.call(slots[i]); slots[i]=null; return i
	return -1
static func play_info(runs: Array,name: String) -> float:
	var key:=name.to_lower()
	for run in runs:
		if str(run.clip0.name).to_lower()==key: return M.f(float(run.time14))
	return -1.0
static func normalize(vector: Array) -> Array:
	var v:=M.values(vector); var square:=M.f(M.f(M.f(v[0]*v[0])+M.f(v[1]*v[1]))+M.f(v[2]*v[2]))
	if square==1 or square>=M.f(0.99999) and square<=M.f(1.00001): return v
	if square==0: return [1.0,0.0,0.0]
	var reciprocal:=M.f(sqrt(M.f(1.0/square)))
	return v.map(func(value):return M.f(value*reciprocal))
static func bits(value: float) -> int: return PackedFloat32Array([value]).to_byte_array().decode_u32(0)
static func from_bits(word: int) -> float:
	var bytes:=PackedByteArray(); bytes.resize(4); bytes.encode_u32(0,word&0xffffffff); return bytes.decode_float(0)
static func acosf(value: float) -> float:
	var x:=M.f(value); var word:=bits(x); var exponent: int=(word>>23)&255
	if is_nan(x) or absf(x)>1: return NAN
	if exponent<0x65: return M.f(PI/2)
	if exponent>=0x7f: return 0.0 if x==1 else M.f(PI)
	var a:=absf(x); var r: float
	if exponent<0x7e: r=M.f(a*a)
	else: r=M.f(M.f(1-a)*M.f(0.5)); a=M.f(sqrt(r))
	var numerator:=M.f(M.f(-0.013381929)-M.f(r*M.f(0.0039613745)))
	numerator=M.f(numerator*r); numerator=M.f(numerator-M.f(0.05652987)); numerator=M.f(numerator*r); numerator=M.f(numerator+M.f(0.1841616))
	var p:=M.f(M.f(numerator*r)/M.f(M.f(1.1049696)-M.f(r*M.f(0.8364113))))
	if exponent>0x7d:
		if x<0:
			var z: float=M.f(p*a)-6.123233995736766e-17+a
			return M.f(PI-(z+z))
		var high:=from_bits(bits(a)&0xffff0000); var correction:=M.f(M.f(r-M.f(high*high))/M.f(high+a))
		return M.f(M.f(M.f(M.f(a+a)*p)+M.f(correction+correction))+M.f(high*2))
	return M.f(PI/2-(x-(6.123233995736766e-17-M.f(p*x))))
static func orientation(facing: Array,direction: Array,animation: int,weapon_type: Variant) -> Array:
	var face:=M.values(facing); var toward:=normalize(direction)
	var dot:=M.f(M.f(M.f(face[1]*toward[1])+M.f(face[0]*toward[0]))+M.f(face[2]*toward[2]))
	var angle:=acosf(1.0 if dot>=1 else dot); var norm_face:=normalize(face)
	var cross:=M.f(M.f(M.f(direction[0])*norm_face[1])-M.f(norm_face[0]*M.f(direction[1]))); var negative:=cross<0
	var slash:=weapon_type!=null and int(weapon_type) in [1,3,4]; var pierce:=weapon_type!=null and int(weapon_type) in [2,5]
	if (animation&65535) in [200,201]:
		var offset: int=(-1 if negative else 1) if slash else (1 if negative else -1) if pierce else 0
		if (animation&65535)==201: offset=-offset
		if offset!=0: angle=M.f(angle+M.f(offset*M.f(PI/4)))
	if not negative: angle=M.f(-angle)
	var half:=M.f(angle*M.f(0.5)); var cx:=Trig.trig(M.f(0.5),true); var sx:=Trig.trig(M.f(0.5),false); var cz:=Trig.trig(half,true); var sz:=Trig.trig(half,false)
	return [M.f(cz*cx),M.f(sx*cz),M.f(sz*sx),M.f(sz*cx)]
