extends RefCounted
# Direct byte decode of src/s3tc_decode.js::decodeS3tc for DDS/KTX base
# dimensions that the old WebGL compressed-texture path could not upload.
static func decode(input: PackedByteArray, width: int, height: int, format: String) -> PackedByteArray:
	if format not in ["dxt1_rgb", "dxt1_rgba", "dxt3", "dxt5"] or width<1 or height<1 or width>=32768 or height>=32768: return PackedByteArray()
	var dxt1:=format in ["dxt1_rgb", "dxt1_rgba"]; var block_bytes:=8 if dxt1 else 16
	var bw:=(width+3)/4; var bh:=(height+3)/4
	if input.size()!=bw*bh*block_bytes: return PackedByteArray()
	var output:=PackedByteArray(); output.resize(width*height*4)
	for by in bh:
		for bx in bw:
			var block:=(by*bw+bx)*block_bytes; var color:=block if dxt1 else block+8
			var c0:=input.decode_u16(color); var c1:=input.decode_u16(color+2); var selectors:=input.decode_u32(color+4)
			var first: Array=[float((c0>>11)&31)*255.0/31.0,float((c0>>5)&63)*255.0/63.0,float(c0&31)*255.0/31.0]
			var second: Array=[float((c1>>11)&31)*255.0/31.0,float((c1>>5)&63)*255.0/63.0,float(c1&31)*255.0/31.0]
			var colors: Array=[first,second,[],[]]; var four:=not dxt1 or c0>c1
			for channel in 3:
				colors[2].append((2.0*first[channel]+second[channel])/3.0 if four else (first[channel]+second[channel])/2.0)
				colors[3].append((first[channel]+2.0*second[channel])/3.0 if four else 0.0)
			for entry in colors:
				for channel in 3: entry[channel]=roundi(entry[channel])
			var alpha: Array=[input[block],input[block+1]]
			if format=="dxt5":
				var steps:=7 if alpha[0]>alpha[1] else 5
				for index in range(1,steps): alpha.append(roundi(float((steps-index)*alpha[0]+index*alpha[1])/float(steps)))
				if steps==5: alpha.append_array([0,255])
			for pixel in 16:
				var x:=bx*4+pixel%4; var y:=by*4+(pixel>>2)
				if x>=width or y>=height: continue
				var selected: int=(selectors>>(2*pixel))&3; var at:=(y*width+x)*4
				for channel in 3: output[at+channel]=int(colors[selected][channel])
				var opacity:=255
				if format=="dxt1_rgba" and not four and selected==3: opacity=0
				elif format=="dxt3": opacity=((input[block+(pixel>>1)]>>((pixel%2)*4))&15)*17
				elif format=="dxt5":
					var bit:=pixel*3; var byte:=block+2+(bit>>3)
					var next:=input[byte+1] if byte+1<input.size() else 0
					var code:=((input[byte]|(next<<8))>>(bit%8))&7
					opacity=int(alpha[code])
				output[at+3]=opacity
	return output
