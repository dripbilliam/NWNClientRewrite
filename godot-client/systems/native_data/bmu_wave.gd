extends RefCounted
# MPEG iterator6a4430/ProcessFrame6a3b00 layout/sample-count adapter. Codec PCM
# decoding remains Godot's MP3 provider, not emulated original codec internals.
var failure:=""
func parse(bytes: PackedByteArray) -> Dictionary:
	failure=""
	if bytes.size()<8 or bytes.slice(0,8).get_string_from_ascii()!="BMU V1.0": failure="Unsupported BMU header"; return {}
	var rates:=[44100,48000,32000,22050,24000,16000]
	var bitrates:=[[0,32000,40000,48000,56000,64000,80000,96000,112000,128000,160000,192000,224000,256000,320000],[0,8000,16000,24000,32000,40000,48000,56000,64000,80000,96000,112000,128000,144000,160000]]
	var at:=8; var first:=true; var mono:=true; var data_bytes:=0; var rate:=0; var frames: Array=[]
	while bytes.size()-at>4:
		while bytes.size()-at>4 and (bytes[at]!=255 or (bytes[at+1]&224)!=224): at+=1
		if bytes.size()-at<=4: break
		var header: int=(int(bytes[at])<<24)|(int(bytes[at+1])<<16)|(int(bytes[at+2])<<8)|int(bytes[at+3])
		var version:=(header>>19)&3; var bitrate:=(header>>12)&15; var frequency:=(header>>10)&3; var mode:=(header>>6)&3; var crc:=((header>>16)&1)==0
		at+=4
		if version not in [2,3] or bitrate<1 or bitrate>14 or frequency==3 or (header&0x60000)!=0x20000: break
		if crc:
			if bytes.size()-at<2: break
			at+=2
		var low:=version==2; var frame_rate:=int(rates[int(low)*3+frequency])
		var size:=int(int(bitrates[int(low)][bitrate])*(72 if low else 144)/frame_rate)+((header>>9)&1)
		if size-4>bytes.size()-at: break
		var payload_size:=size-(6 if crc else 4); var info: int=(9 if mode==3 else 17) if low else (17 if mode==3 else 32)
		var samples:=0 if first and bytes.slice(at+info,at+info+4).get_string_from_ascii()=="Info" else (576 if low else 1152)
		first=false; rate=frame_rate; frames.append({"offset":at,"payloadSize":payload_size,"low":low,"mode":mode,"sampleRate":rate,"samples":samples}); mono=mono and mode==3; data_bytes+=samples*(2 if mode==3 else 4); at+=payload_size
	if frames.is_empty(): failure="Native BMU has no supported MPEG frames"; return {}
	var channels:=1 if mono else 2
	return {"codec":"mp3","channels":channels,"sampleRate":rate,"frames":frames,"timing":{"channels":channels,"sampleRate":rate,"bits":16,"dataBytes":data_bytes,"duration":int((8.0/(16*rate))*floor(float(data_bytes)/channels)*1000.0)&0xffffffff}}
