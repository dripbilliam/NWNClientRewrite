import {nativeAudioResRef} from './native_audio.js';
import {nativeSoundPitchRate} from './native_placed_sound.js';
const f=Math.fround;
// Stateful CExoSoundSource adapter sharing GameAudio's decoded WAV cache and
// listener. Metadata IO yields null to its owner; it never blocks networking.
export class BufferAudioSource{
 constructor(output,{objectId,random=()=>Math.floor(Math.random()*0x8000),onFailure=()=>{}}){Object.assign(this,{output,objectId,random,onFailure});this.buffers=new Map();this.position=[0,0,0];this.volume=127;this.pitchVariance=0;this.resource='';this.rate=null;this.requested=false;this.disposed=false;this.loaded=0;this.played=0;this.status='idle';output.streams.add(this);}
 configure(profile){Object.assign(this,profile);if(![profile.referenceDistance,profile.maxDistance].every(Number.isFinite)||profile.referenceDistance<0||profile.maxDistance<=0||profile.maxDistance<profile.referenceDistance)throw new Error('Native sound source distance is unavailable');}
 setResRef(ref){this.stop();this.resource=nativeAudioResRef(ref).toLowerCase();this.rate=null;}
 setVolume(value){this.volume=value&255;if(this.record)this.record.gain.gain.value=f(this.volume/(this.positional?255:127));}
 setPitchVariance(value){const upper=value<=1?value:1;this.pitchVariance=f(upper>=0?upper:0);}
 setPosition(point){this.position=point.map(f);if(this.record?.panner)this.writePosition(this.record.panner,[this.position[0],this.position[1],f(-this.position[2])]);}
 hardwarePlaying(){return Boolean(this.record);}
 writePosition(node,point){for(let i=0;i<3;i++)node['position'+'XYZ'[i]].value=point[i];}
 withinRange(){if(!this.positional)return true;const listener=this.output.listenerState;if(!listener)return false;const d=this.position.map((v,i)=>f(listener.position[i]-v));return f(Math.sqrt(f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]))))<=this.maxDistance;}
 play(){
  if(this.disposed||!this.resource)return 0;
  let entry=this.buffers.get(this.resource);
  if(!entry){const resource=this.resource;entry={ready:false,buffer:null};this.buffers.set(resource,entry);this.status='loading';void this.output.loadBuffer(resource).then(buffer=>{if(this.disposed)return;entry.ready=true;entry.buffer=buffer;this.loaded++;},error=>{if(this.disposed)return;entry.ready=true;this.onFailure(error,{objectId:this.objectId,resRef:resource});});}
  if(!entry.ready)return null;if(!entry.buffer){this.status='failed';return 0;}
  this.buffer=entry.buffer;this.timing=this.output.bufferTiming?this.output.bufferTiming(this.buffer):{sampleRate:this.buffer.sampleRate,channels:this.buffer.numberOfChannels,duration:Math.trunc(this.buffer.duration*1000)>>>0};
  if(!this.timing){entry.buffer=null;this.status='failed';this.onFailure(new Error('Native WAV duration metadata is unavailable'),{objectId:this.objectId,resRef:this.resource});return 0;}
  if(this.rate===null)this.rate=this.positional&&this.timing.channels!==1?1:nativeSoundPitchRate(this.timing.sampleRate,this.pitchVariance,this.random);
  this.stopPhysical();this.requested=true;this.flush();return this.timing.duration;
 }
 flush(){
  if(this.disposed||!this.requested||this.record||!this.buffer||this.output.context?.state!=='running')return;
  if(this.positional&&this.timing.channels!==1){this.status='stereo-3d-rejected';return;}
  if(!this.withinRange()){this.status=this.loop?'parked':'out-of-range';if(!this.loop)this.requested=false;return;}
  const context=this.output.context,source=context.createBufferSource(),gain=context.createGain(),record={source,gain,panner:null};source.buffer=this.buffer;source.loop=this.loop;source.playbackRate.value=this.rate;gain.gain.value=f(this.volume/(this.positional?255:127));source.connect(gain);
  if(this.positional){record.panner=context.createPanner();Object.assign(record.panner,{panningModel:'equalpower',distanceModel:'linear',refDistance:this.referenceDistance,maxDistance:this.maxDistance,rolloffFactor:1});gain.connect(record.panner);record.panner.connect(context.destination);this.writePosition(record.panner,this.position);}else gain.connect(context.destination);
  this.record=record;source.addEventListener('ended',()=>{source.disconnect();gain.disconnect();record.panner?.disconnect();if(this.record===record){this.record=null;this.requested=false;this.status='idle';}});source.start();this.status='playing';this.played++;
 }
 update(){if(this.loop&&this.record&&!this.withinRange()){this.stopPhysical();this.status='parked';}this.flush();}
 stopPhysical(){const record=this.record;this.record=null;if(record){record.source.stop();record.source.disconnect();record.gain.disconnect();record.panner?.disconnect();}}
 stop(){this.requested=false;this.stopPhysical();this.status='idle';}
 snapshot(){return{objectId:this.objectId,resource:this.resource,status:this.status,hardwarePlaying:this.hardwarePlaying(),loop:this.loop,positional:this.positional,priority:this.priority,volume:this.volume,rate:this.rate,duration:this.timing?.duration??null,sampleRate:this.timing?.sampleRate??null,position:[...this.position],loaded:this.loaded,played:this.played};}
 dispose(){if(this.disposed)return;this.disposed=true;this.stop();this.buffers.clear();this.output.streams.delete(this);}
}
