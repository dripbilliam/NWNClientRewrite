import {NativeAudioAssets,nativeAudioPackets} from './native-audio.mjs';
import {nativeBmuWave} from '../../src/native_bmu_wave.js';
import {isNativeAudioResourceRef,NetworkAudioPresentation} from '../../src/native_audio.js';

// Channel metadata is required before native positional playback. Godot may
// decode stereo, but the original positional source rejects it.
export function worldAudioChannels(audio){
 if([1,2].includes(audio.channels))return audio.channels;
 if([1,2].includes(audio.sourceTiming?.channels))return audio.sourceTiming.channels;
 if(audio.codec==='mp3')return nativeBmuWave(Buffer.concat([Buffer.from('BMU V1.0'),audio.data])).timing.channels;
 if(audio.codec==='ogg'){
  const b=audio.data;
  if(b.length<28||b.toString('ascii',0,4)!=='OggS'||b[4]!==0||!(b[5]&2)||b[26]<1)throw Error('Ogg identification page is unavailable');
  const at=27+b[26];if(at+16>b.length||b[at]!==1||b.toString('ascii',at+1,at+7)!=='vorbis'||b.readUInt32LE(at+7)!==0||![1,2].includes(b[at+11]))throw Error('Ogg channel identification is unsupported');
  return b[at+11];
 }
 throw Error('Native world audio channel metadata is unavailable');
}

export class WorldAudio {
 constructor({session,connection,active,ready,getResource,send,diagnose=()=>{},report={}}){
  Object.assign(this,{session,connection,active,ready,getResource,send,diagnose,report});this.context=null;this.closed=false;this.jobs=new Set();this.retiring=new Set();
  Object.assign(report,{resources:[],observed:[],scopes:[],scriptMessages:[],closed:false});
  this.script=new NetworkAudioPresentation({world:()=>session.world,ready:()=>!this.closed&&active()&&Boolean(ready()),report:diagnose,output:{play:cue=>{this.follow();const context=this.context;if(!this.valid(context)||cue.current&&!cue.current())return;const{current,...plain}=cue;send({...context.scope,kind:'world-audio-cue',cue:plain});}}});
 }
 follow(){
  const scope=this.ready(),world=this.session.world;
  if(this.context&&(this.context.world!==world||this.context.scope.areaId!==world.areaId||this.context.scope.generation!==this.session.areaGeneration||scope&&Object.keys(scope).some(k=>this.context.scope[k]!==scope[k]))){
   const context=this.context;this.context=null;this.script.areaChanged();const work=context.assets.retire().then(value=>Object.assign(context.stats,value)).finally(()=>this.retiring.delete(work));this.retiring.add(work);
  }
  if(!scope)return null;
  if(this.context?.world===world&&Object.keys(scope).every(k=>this.context.scope[k]===scope[k]))return this.context;
  if(this.context){const context=this.context;this.script.areaChanged();const work=context.assets.retire().then(value=>Object.assign(context.stats,value)).finally(()=>this.retiring.delete(work));this.retiring.add(work);}
  const stats={...scope,pending:0,cachedBytes:0,closed:false},context={scope:{...scope},world,assets:new NativeAudioAssets(this.getResource),ids:new Map(),stats};this.context=context;this.report.scopes.push(stats);return context;
 }
 valid(context){const scope=this.ready();return Boolean(!this.closed&&!this.session.closed&&this.active()&&context&&context===this.context&&context.world===this.session.world&&scope&&Object.keys(context.scope).every(k=>context.scope[k]===scope[k]));}
 request(message){const work=this.load(message);this.jobs.add(work);return work.finally(()=>this.jobs.delete(work));}
 async load(message){
  const context=this.follow();if(!this.valid(context)||Object.keys(context.scope).some(k=>message[k]!==context.scope[k]))return;
  if(!Number.isSafeInteger(message.resourceId)||message.resourceId<1||!isNativeAudioResourceRef(message.name))throw Error('Invalid private native audio resource request');
  const name=message.name.toLowerCase();
  if(context.ids.has(message.resourceId)){if(context.ids.get(message.resourceId)!==name)throw Error('Native audio identity changed its immutable resource');return;}
  context.ids.set(message.resourceId,name);
  try{
   const audio=await context.assets.load(name,()=>this.valid(context));if(!audio||!this.valid(context))return;
   const channels=worldAudioChannels(audio);
   let sent=0;for(const packet of nativeAudioPackets({...audio,channels},{...context.scope,resourceId:message.resourceId,name})){
    if(!this.valid(context))return;this.send({...packet,kind:packet.kind.replace('creation-audio-','world-audio-')});
    if(++sent%4===0)await new Promise(resolve=>setImmediate(resolve));
   }
   if(this.report.resources.length<256)this.report.resources.push({...context.scope,resourceId:message.resourceId,name,codec:audio.codec,channels,bytes:audio.data.length,sha256:audio.sha256});
  }catch(error){if(this.valid(context)){this.diagnose('audio.world-resource-failed',`${name}: ${error.message}`);this.send({...context.scope,kind:'world-audio-failed',resourceId:message.resourceId});}}
 }
 observe(message){const context=this.context;if(!this.valid(context)||message.transferId!==context.scope.transferId)return;if(this.report.observed.length<512)this.report.observed.push(structuredClone(message));}
 receive(message){const context=this.follow();if(message.kind==='script-sound'&&this.valid(context)&&this.report.scriptMessages.length<128)this.report.scriptMessages.push({...context.scope,kind:'server-script-sound',objectId:message.objectId,sound:message.sound});this.script.receive(message);}
 async close(){if(this.closed)return;this.closed=true;this.script.dispose();if(this.context){const result=await this.context.assets.retire();Object.assign(this.context.stats,result);}await Promise.allSettled([...this.jobs,...this.retiring]);this.context=null;this.report.closed=true;this.report.pending=this.jobs.size+this.retiring.size;}
}
