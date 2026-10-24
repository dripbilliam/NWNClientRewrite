// CResWave::OnResourceServiced1a5ab0 decodes BMU stored as WAV4 into
// 16-bit PCM before GetWaveInfo. Iterator6a4430 accepts MPEG1/2 layer III,
// stops at the first invalid sync header and suppresses the first Info frame.
// Browser PCM decoding is a platform adapter; encoded frame metadata keeps
// native sample rates/duration independent of AudioContext resampling.
export function nativeBmuWave(input){
 const bytes=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength),tag=(at,n)=>String.fromCharCode(...bytes.subarray(at,at+n));
 if(bytes.length<8||tag(0,8)!=='BMU V1.0')return null;
 const rates=[44100,48000,32000,22050,24000,16000],bitrates=[[0,32000,40000,48000,56000,64000,80000,96000,112000,128000,160000,192000,224000,256000,320000],[0,8000,16000,24000,32000,40000,48000,56000,64000,80000,96000,112000,128000,144000,160000]],view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),frames=[];
 let at=8,first=true,mono=true,dataBytes=0,sampleRate=0;
 while(bytes.length-at>4){
  while(bytes.length-at>4&&(bytes[at]!==255||(bytes[at+1]&224)!==224))at++;
  if(bytes.length-at<=4)break;
  const header=view.getUint32(at,false),version=(header>>>19)&3,bitrate=(header>>>12)&15,frequency=(header>>>10)&3,mode=(header>>>6)&3,crc=(header>>>16&1)===0;
  at+=4;if(![2,3].includes(version)||bitrate<1||bitrate>14||frequency===3||(header&0x60000)!==0x20000)break;
  if(crc){if(bytes.length-at<2)break;at+=2;}
  const low=version===2,rate=rates[Number(low)*3+frequency],size=Math.trunc(bitrates[Number(low)][bitrate]*(low?72:144)/rate)+(header>>>9&1);
  if(size-4>bytes.length-at)break;
  const payloadSize=size-(crc?6:4),infoOffset=low?(mode===3?9:17):(mode===3?17:32),samples=first&&tag(at+infoOffset,4)==='Info'?0:low?576:1152;
  first=false;frames.push({offset:at,payloadSize,low,mode,sampleRate:rate,samples});mono=mono&&mode===3;sampleRate=rate;dataBytes+=samples*(mode===3?2:4);at+=payloadSize;
 }
 if(!frames.length)throw new Error('Native BMU has no supported MPEG frames');
 const channels=mono?1:2;return{payload:bytes.slice(8).buffer,frames,timing:{channels,sampleRate,bits:16,dataBytes,duration:Math.trunc((8/(16*sampleRate))*Math.floor(dataBytes/channels)*1000)>>>0}};
}
