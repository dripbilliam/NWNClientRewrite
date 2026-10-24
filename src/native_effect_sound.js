import {BufferAudioSource} from './buffer_audio_source.js';
const f=Math.fround;

// CExoSoundSource owned by a visual phase, not a game object. The native
// constructor defaults to zero position, byte volume127, and max range20.
// Hardware reference distance remains OpenAL's default1 (1e0050).
export class NativeEffectSound{
 constructor(output,{resRef,objectId,channel='visual',onFailure=()=>{}}){
  Object.assign(this,{output,resRef,objectId,channel});this.destroyed=false;this.pending=false;this.playing=false;
  this.profile={positional:false,loop:false,priority:21,referenceDistance:1,maxDistance:20};
  this.source=new BufferAudioSource(output,{objectId,onFailure});this.source.configure(this.profile);this.source.setResRef(resRef);output.streams.add(this);
 }
 setting(key,value){
  const field={setting1401d9e90:'positional',setting1401da060:'priority',setting1401d9f90:'loop'}[key];
  if(!field)throw new Error('Native effect sound setting is unavailable');
  this.profile[field]=field==='priority'?value&255:Boolean(value);this.source.configure(this.profile);
 }
 play(){if(this.destroyed)return;this.playing=true;this.pending=this.source.play()===null;}
 flush(){if(this.pending&&!this.destroyed)this.pending=this.source.play()===null;}
 update(){this.flush();}
 setPosition(position,height=0){if(this.destroyed)return;const point=position.map(f);point[2]=f(point[2]+f(height));this.source.setPosition(point);}
 stop(){this.pending=false;this.playing=false;this.source.stop();}
 snapshot(){return{objectId:this.objectId,channel:this.channel,pending:this.pending,...this.source.snapshot()};}
 dispose(){if(this.destroyed)return;this.destroyed=true;this.stop();this.source.dispose();this.output.streams.delete(this);}
}

// Keep phase ordering in the existing original-code-derived owners. A missing
// platform factory retains explicit diagnostics for other users of the owner.
export function effectSoundProviders(factory,unavailable){return{
 createSound:resRef=>factory?factory(resRef):{resRef,settings:{},playing:false,destroyed:false},
 soundSetting:(sound,key,value)=>sound.setting?sound.setting(key,value):sound.settings[key]=value,
 playSound:sound=>{if(sound.play)sound.play();else{sound.playing=true;if(sound.resRef)unavailable(sound.resRef);}},
 stopSound:sound=>{if(sound.stop)sound.stop();else sound.playing=false;},
 destroySound:sound=>{if(sound.dispose)sound.dispose();else sound.destroyed=true;},
 updateSound:(sound,position,height=0)=>{if(sound.setPosition)sound.setPosition(position,height);else sound.position=position;}
};}
