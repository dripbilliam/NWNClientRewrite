import {encodeGffText,decodeGffText} from './gff_text.js';
const f=Math.fround,twice=n=>f(n+n);
// Client listener owner1406e67e0: five-sixths controlled eye position plus
// one-sixth camera position, with the actual camera quaternion (w,x,y,z).
// These are native Z-up coordinates, passed unchanged to the audio backend.
export function nativeAudioListener(player,camera,quaternion){
 if(!player||!camera||!quaternion)return null;
 if(player.length!==3||camera.length!==3||quaternion.length!==4||![...player,...camera,...quaternion].every(Number.isFinite))throw new Error('Native audio listener pose is invalid');
 const p=player.map(f),c=camera.map(f),[w,x,y,z]=quaternion.map(f);p[2]=f(p[2]+f(1.8));
 const position=p.map((v,i)=>f(v+f(f(c[i]-v)*f(1/6))));
 return{position,forward:[-twice(f(f(z*x)+f(y*w))),-twice(f(f(z*y)-f(x*w))),-f(1-twice(f(f(y*y)+f(x*x))))],up:[twice(f(f(y*x)-f(z*w))),f(1-twice(f(f(z*z)+f(x*x)))),twice(f(f(x*w)+f(z*y)))]};
}
// The original CResRef(CExoString) copies at most16 bytes, retaining case;
// resource lookup is separately case insensitive. Empty names play nothing.
export function nativeAudioResRef(text){if(typeof text!=='string')throw new Error('Native audio resource name is unavailable');const bytes=encodeGffText(text),end=bytes.indexOf(0);return decodeGffText(bytes.subarray(0,Math.min(16,end<0?bytes.length:end)));}
export function isNativeAudioResourceRef(value){try{return typeof value==='string'&&value.length>0&&!/[\\/:\0]/.test(value)&&nativeAudioResRef(value)===value;}catch{return false;}}
export function nativeOneShotSoundCue({resRef:sound,position=null,height=0,priority=8,volume=0,delay=0,channel='effect'}){
 const resRef=nativeAudioResRef(sound);if(!resRef)return null;
 if(position&&(position.length!==3||!position.every(Number.isFinite)))throw new Error('Native script sound source position is invalid');
 if(!Number.isFinite(height)||!Number.isInteger(priority)||!Number.isInteger(volume)||!Number.isInteger(delay)||delay<0||delay>0xffffffff)throw new Error('Native one-shot sound arguments are unavailable');
 // 77e330..77e3bb: priority8, delay0, optional volume0 retains ctor127.
 // The OpenAL source sets maxDistance20 and keeps default referenceDistance1;
 // Initialize1dc590 selects AL_LINEAR_DISTANCE_CLAMPED. Native Play rejects
 // stereo resources for positional sources instead of centering them.
 const point=position?.map(f);if(point)point[2]=f(point[2]+f(height));
 return{resRef,position:point,channel,nativeSource:{positional:Boolean(point),priority:priority&255,volume:(volume&255)||127,referenceDistance:1,maxDistance:20,rolloff:1,monoOnly:Boolean(point),fixedPosition:true,...(delay?{delay}:null)}};
}
export const nativeScriptSoundCue=(sound,position=null)=>nativeOneShotSoundCue({resRef:sound,position,channel:'script'});

// A received request can use an existing proxy but never creates one. The
// common77c140 source/readiness gates run before its 2D/3D one-shot branch.
export class NetworkAudioPresentation{
 constructor({world,output,ready=()=>true,report=()=>{}}){Object.assign(this,{world,output,ready,report});this.disposed=false;this.events=[];this.reportedMixer=false;this.generation=0;}
 areaChanged(){this.generation++;}
 receive(message){
  if(this.disposed||message.kind!=='script-sound'||!this.ready())return;
  const world=this.world(),source=world?.registry.get(message.objectId);
  if(!source||source.replicationRemoved||source.areaId!==world.areaId)return;
  const position=source.replicated?.position??source.staticState?.position??source.lightState?.position??source.state?.position;
  if(!position){this.report('network.sound-source-pose-unavailable','Native sound source proxy has no position',{objectId:source.id,objectType:source.objectType});return;}
  this.oneShot({resRef:message.sound,nativePosition:position,objectId:source.id,channel:'script'});
 }
 oneShot({resRef,nativePosition,height=0,priority=8,volume=0,delay=0,objectId=0x7f000000,channel='effect'}){
  if(this.disposed||!this.ready())return;
  const cue=nativeOneShotSoundCue({resRef,position:nativePosition,height,priority,volume,delay,channel});if(!cue)return;
  if(!this.reportedMixer){this.reportedMixer=true;this.report('network.audio-mixer-settings-unimplemented','Native priority-group voice limits and user mixer settings are not connected; source defaults are used',{});}
  const generation=this.generation;cue.current=()=>!this.disposed&&this.generation===generation;
  cue.objectId=objectId;this.events.push({objectId,resRef:cue.resRef,position:cue.position,priority:cue.nativeSource.priority,delay,channel});if(this.events.length>128)this.events.shift();
  void this.output.play(cue);
 }
 dispose(){this.disposed=true;this.events=[];}
 snapshot(){return{events:this.events.map(e=>({...e})),output:{...this.output.state},effectSounds:this.output.effectSounds?.()??[],delayedSounds:this.output.delayedSounds?.()??[]};}
}
