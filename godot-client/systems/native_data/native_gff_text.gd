extends RefCounted
# Original NWN 8-bit Western text mapping, including undefined CP1252 slots.
const HIGH=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178]
static func encode(value: String)->Dictionary:
	var output:=PackedByteArray()
	for index in range(value.length()):
		var code:=value.unicode_at(index)
		if code>=128 and code<160:
			var mapped:=HIGH.find(code)
			if mapped<0:return {"error":"Unsupported NWN Western text character"}
			code=mapped+128
		elif code>=160:
			if code>255:
				var mapped:=HIGH.find(code)
				if mapped<0:return {"error":"Unsupported NWN Western text character"}
				code=mapped+128
		output.append(code)
	return {"bytes":output}

static func decode(bytes: PackedByteArray)->String:
	var output: Array[String]=[]
	for value in bytes:
		var code: int=HIGH[value-128] if value>=128 and value<160 else value
		output.append(char(code))
	return "".join(output)
