import {createHash} from 'node:crypto';
import {decodeImaWav} from '../../src/ima_adpcm.js';
import {nativeBmuWave} from '../../src/native_bmu_wave.js';
import {isNativeAudioResourceRef} from '../../src/native_audio.js';
import {RESOURCE_TYPE} from '../../src/resource_archive.js';

export const MAX_AUDIO_BYTES=64*1024*1024, AUDIO_CHUNK_BYTES=128*1024;
const tag=(b,at,n=4)=>b.toString('ascii',at,at+n);
const pcm=(data,channels,sampleRate,frames)=>({codec:'pcm16',channels,sampleRate,frames,data});
export function prepareNativeAudio(input){
 const b=input instanceof ArrayBuffer?Buffer.from(input):Buffer.from(input.buffer,input.byteOffset,input.byteLength);
 if(b.length<4||b.length>MAX_AUDIO_BYTES)throw Error('Audio resource size is unsupported');
 const bmu=nativeBmuWave(b);
 if(bmu)return{codec:'mp3',data:Buffer.from(bmu.payload),sourceTiming:bmu.timing};
 if(tag(b,0)==='OggS')return{codec:'ogg',data:Buffer.from(b)};
 if(tag(b,0,3)==='ID3'||b[0]===255&&(b[1]&224)===224)return{codec:'mp3',data:Buffer.from(b)};
 if(b.length<12||tag(b,0)!=='RIFF'||tag(b,8)!=='WAVE')throw Error('Audio resource is not a supported WAVE, BMU, MP3 or Ogg stream');
 const end=b.readUInt32LE(4)+8;if(end<12||end>b.length)throw Error('Truncated WAVE resource');
 let fmt,data;
 for(let at=12;at<end;){if(at+8>end)throw Error('Truncated WAVE chunk');const size=b.readUInt32LE(at+4),start=at+8;if(start+size>end)throw Error('Truncated WAVE chunk');const name=tag(b,at);if(name==='fmt '){if(fmt)throw Error('Duplicate WAVE format');fmt=b.subarray(start,start+size);}if(name==='data'){if(data)throw Error('Duplicate WAVE data');data=b.subarray(start,start+size);}at=start+size+(size&1);}
 if(!fmt||fmt.length<16||!data)throw Error('WAVE format/data is missing');
 const format=fmt.readUInt16LE(0),channels=fmt.readUInt16LE(2),sampleRate=fmt.readUInt32LE(4),align=fmt.readUInt16LE(12),bits=fmt.readUInt16LE(14);
 if(![1,2].includes(channels)||sampleRate<1||sampleRate>384000)throw Error('Unsupported WAVE channels or sample rate');
 if(format===85)return{codec:'mp3',data:Buffer.from(data)};
 if(format===17){const decoded=decodeImaWav(b);if(decoded.frames*channels*2>MAX_AUDIO_BYTES)throw Error('Decoded audio exceeds capacity');const out=Buffer.alloc(decoded.frames*channels*2);for(let i=0;i<decoded.frames;i++)for(let c=0;c<channels;c++)out.writeInt16LE(Math.max(-32768,Math.min(32767,Math.round(decoded.samples[c][i]*32768))),(i*channels+c)*2);return pcm(out,channels,sampleRate,decoded.frames);}
 if(!(format===1&&[8,16,24,32].includes(bits)||format===3&&[32,64].includes(bits))||align!==channels*bits/8||data.length%align)throw Error('Unsupported WAVE sample format');
 const frames=data.length/align;if(!frames||frames>16000000||frames*channels*2>MAX_AUDIO_BYTES)throw Error('WAVE sample count exceeds capacity');
 if(format===1&&bits===16)return pcm(Buffer.from(data),channels,sampleRate,frames);
 const out=Buffer.alloc(frames*channels*2);
 for(let i=0;i<frames*channels;i++){const at=i*bits/8;let value;if(format===3){const f=bits===32?data.readFloatLE(at):data.readDoubleLE(at);if(!Number.isFinite(f))throw Error('Invalid floating-point audio sample');value=Math.round(f*32768);}else value=bits===8?(data[at]-128)*256:bits===24?data.readIntLE(at,3)>>8:data.readInt32LE(at)>>16;out.writeInt16LE(Math.max(-32768,Math.min(32767,value)),i*2);}
 return pcm(out,channels,sampleRate,frames);
}

// Bounded, connection-owned resource/decode work. No game audio bytes enter a
// report or the workspace; only the local native transport receives them.
export class NativeAudioAssets{
 constructor(getResource,{limit=32*1024*1024}={}){this.getResource=getResource;this.limit=limit;this.cache=new Map();this.bytes=0;this.queue=[];this.jobs=new Set();this.closed=false;}
 load(name,current=()=>true){
  if(this.closed||!current())return Promise.resolve(null);
  if(!isNativeAudioResourceRef(name))return Promise.reject(Error('Invalid sound resource reference'));
  name=name.toLowerCase();if(this.cache.has(name)){const audio=this.cache.get(name);this.cache.delete(name);this.cache.set(name,audio);return Promise.resolve(audio);}
  return new Promise((resolve,reject)=>{this.queue.push({name,current,resolve,reject});this.pump();});
 }
 pump(){while(!this.closed&&this.jobs.size<4&&this.queue.length){const row=this.queue.shift();if(!row.current()){row.resolve(null);continue;}const work=(async()=>{const bytes=await this.getResource(row.name,RESOURCE_TYPE.WAV);if(this.closed||!row.current())return null;const audio=prepareNativeAudio(bytes);audio.sha256=createHash('sha256').update(audio.data).digest('hex');if(audio.data.length<=this.limit){const previous=this.cache.get(row.name);if(previous)this.bytes-=previous.data.length;this.cache.delete(row.name);this.cache.set(row.name,audio);this.bytes+=audio.data.length;while(this.bytes>this.limit){const key=this.cache.keys().next().value;this.bytes-=this.cache.get(key).data.length;this.cache.delete(key);}}return audio;})().then(row.resolve,row.reject).finally(()=>{this.jobs.delete(work);this.pump();});this.jobs.add(work);}}
 async retire(){this.closed=true;for(const row of this.queue.splice(0))row.resolve(null);await Promise.allSettled([...this.jobs]);this.cache.clear();this.bytes=0;return{closed:true,pending:this.jobs.size,cachedBytes:this.bytes};}
}

export function* nativeAudioPackets(audio,scope){
 if(!audio?.data?.length||audio.data.length>MAX_AUDIO_BYTES)throw Error('Native audio payload size is unsupported');
 const sha256=audio.sha256??createHash('sha256').update(audio.data).digest('hex');
 yield{kind:'creation-audio-begin',...scope,codec:audio.codec,channels:audio.channels??0,sampleRate:audio.sampleRate??0,frames:audio.frames??0,bytes:audio.data.length,sha256};
 let index=0;for(let at=0;at<audio.data.length;at+=AUDIO_CHUNK_BYTES)yield{kind:'creation-audio-chunk',...scope,index:index++,data:audio.data.subarray(at,at+AUDIO_CHUNK_BYTES).toString('base64')};
 yield{kind:'creation-audio-commit',...scope,chunks:index};
}
