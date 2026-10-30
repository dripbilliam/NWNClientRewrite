extends RefCounted
# Original RIFF/IMA source decoding into private PCM, on asset workers.
# Listener and playback scheduling remain separate native owners.
const STEPS=[7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
const CHANGES=[-1,-1,-1,-1,2,4,6,8]
var failure:=""
func fail(reason: String) -> Dictionary: failure=reason; return {}
func parse(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()>=8 and bytes.slice(0,8).get_string_from_ascii()=="BMU V1.0":
		var parser:=preload("res://systems/native_data/bmu_wave.gd").new(); var data: Dictionary=parser.parse(bytes); failure=parser.failure; return data
	if bytes.size()<12 or bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WAVE": return fail("Native compressed non-RIFF audio decoding remains pending")
	var end:=int(bytes.decode_u32(4))+8
	if end<12 or end>bytes.size(): return fail("Truncated WAVE container")
	var chunks: Dictionary={}; var at:=12
	while at<end:
		if at+8>end: return fail("Truncated WAVE chunk header")
		var size:=int(bytes.decode_u32(at+4)); var start:=at+8; var name:=bytes.slice(at,at+4).get_string_from_ascii()
		if start+size>end: return fail("Truncated WAVE chunk")
		if name in ["fmt ","data","fact"]:
			if chunks.has(name): return fail("Duplicate WAVE chunk")
			chunks[name]={"start":start,"size":size}
		at=start+size+(size&1)
	if not chunks.has("fmt ") or not chunks.has("data") or chunks["fmt "].size<16: return fail("Missing WAVE format/data")
	var fmt: int=chunks["fmt "].start; var channels:=int(bytes.decode_u16(fmt+2)); var rate:=int(bytes.decode_u32(fmt+4)); var bits:=int(bytes.decode_u16(fmt+14)); var codec:=int(bytes.decode_u16(fmt)); var block:=int(bytes.decode_u16(fmt+12))
	if channels not in [1,2] or rate<1 or rate>384000 or bits<1 or bits>64: return fail("Unsupported WAVE channel/rate/bit depth")
	var timing:={"channels":channels,"sampleRate":rate,"bits":bits,"dataBytes":int(chunks.data.size),"duration":int((8.0/float((bits*rate)&0xffffffff))*floor(float(chunks.data.size)/channels)*1000.0)&0xffffffff}
	if codec in [1,3]: return {"codec":"wav","channels":channels,"sampleRate":rate,"timing":timing}
	if codec!=17: return fail("Unsupported original WAVE codec "+str(codec))
	if chunks["fmt "].size<20 or bytes.decode_u16(fmt+16)<2 or bits!=4 or block<channels*4: return fail("Invalid IMA WAVE format")
	if int(bytes.decode_u16(fmt+18))!=1+(block-channels*4)*2/channels or channels==2 and (block-8)%8!=0: return fail("Invalid IMA block size")
	var available:=0; var offset:=0
	while offset<int(chunks.data.size):
		var length:=mini(block,int(chunks.data.size)-offset)
		if length<channels*4 or channels==2 and (length-8)%8!=0: return fail("Truncated IMA block")
		available+=1+(length-channels*4)*2/channels; offset+=block
	var frames:=available
	if chunks.has("fact"):
		if chunks.fact.size<4: return fail("Truncated IMA fact")
		frames=int(bytes.decode_u32(int(chunks.fact.start)))
	if frames<1 or frames>available or frames>16000000: return fail("Invalid IMA sample count")
	var output:=PackedByteArray(); output.resize(frames*channels*2); var output_frame:=0
	var block_start: int=chunks.data.start; var data_end: int=chunks.data.start+chunks.data.size
	while block_start<data_end:
		var limit:=mini(block_start+block,data_end); var predictors: Array=[]; var indices: Array=[]; var offsets: Array=[]
		for channel in channels:
			var header:=block_start+channel*4; var predictor:=int(bytes.decode_s16(header)); var index:=int(bytes[header+2])
			if index>88 or bytes[header+3]!=0: return fail("Invalid IMA block header")
			predictors.append(predictor); indices.append(index); offsets.append(output_frame+1)
			if output_frame<frames: output.encode_s16((output_frame*channels+channel)*2,predictor)
		var p:=block_start+channels*4
		while p<limit:
			for channel in channels:
				var group_end:=mini(p+4,limit)
				while p<group_end:
					var byte:=int(bytes[p]); p+=1
					for nibble in [byte&15,byte>>4]:
						var step: int=STEPS[int(indices[channel])]; var delta:=step>>3
						if nibble&4: delta+=step
						if nibble&2: delta+=step>>1
						if nibble&1: delta+=step>>2
						predictors[channel]=clampi(int(predictors[channel])+(-delta if nibble&8 else delta),-32768,32767)
						indices[channel]=clampi(int(indices[channel])+int(CHANGES[nibble&7]),0,88)
						if int(offsets[channel])<frames: output.encode_s16((int(offsets[channel])*channels+channel)*2,int(predictors[channel]))
						offsets[channel]+=1
		output_frame=int(offsets[0]); block_start+=block
	return {"codec":"pcm16","channels":channels,"sampleRate":rate,"frames":frames,"pcm":output,"timing":timing}
