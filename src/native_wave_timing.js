// CResWave::GetWaveInfo1a5940 and CExoSoundSourceInternal::Play1df2e0.
// Native scheduling uses fmt/data lengths, including compressed-bit depth;
// fact sample counts and the decoder's resampled duration do not replace it.
export function nativeWaveTiming(input){
 const b=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength),tag=at=>String.fromCharCode(...b.subarray(at,at+4));
 if(b.length<12||tag(0)!=='RIFF'||tag(8)!=='WAVE')return null;const v=new DataView(b.buffer,b.byteOffset,b.byteLength),end=v.getUint32(4,true)+8;if(end>b.length||end<12)throw new Error('Truncated native WAV timing container');
 let channels,sampleRate,bits,dataBytes;
 for(let at=12;at<end;){if(at+8>end)throw new Error('Truncated native WAV timing chunk');const size=v.getUint32(at+4,true),start=at+8;if(start+size>end)throw new Error('Truncated native WAV timing data');
  if(tag(at)==='fmt '){if(size<16)throw new Error('Native WAV timing format is unavailable');channels=v.getUint16(start+2,true);sampleRate=v.getUint32(start+4,true);bits=v.getUint16(start+14,true);}
  else if(tag(at)==='data')dataBytes=size;at=start+size+(size&1);
 }
 if(!channels||!sampleRate||!bits||dataBytes===undefined)throw new Error('Native WAV timing fields are unavailable');const divisor=Math.imul(bits,sampleRate)>>>0;if(!divisor)throw new Error('Native WAV timing divides by zero');
 return{channels,sampleRate,bits,dataBytes,duration:Math.trunc((8/divisor)*Math.floor(dataBytes/channels)*1000)>>>0};
}
