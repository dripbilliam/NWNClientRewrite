import {CreationVoicePreview} from '../../src/creation_voice_preview.js';
import {NativeAudioAssets,nativeAudioPackets} from './native-audio.mjs';

// Original SSF selection/cycling, with Godot owning playback instead of a hidden
// browser AudioContext. Every response retains its selected-voice owner.
export class NativeCreationVoice{
 constructor({getResource,active,send,onPrepared=()=>{}}){Object.assign(this,{getResource,active,send,onPrepared});this.assets=new NativeAudioAssets(getResource);this.owner=0;this.sequence=0;this.key=null;this.pending=new Set();}
 configure(key){
  if(key===this.key)return;
  this.preview?.dispose();this.preview=null;this.key=key;this.owner++;this.sequence++;
  this.send({kind:'creation-voice-stop',owner:this.owner});
  if(key===null)return;
  this.preview=new CreationVoicePreview({getResource:this.getResource},{audioFactory:()=>({unlock(){},dispose(){},play:async event=>{
   const preview=this.preview,owner=this.owner,sequence=this.sequence,code=this.code,voiceId=this.voiceId,current=()=>this.active()&&preview===this.preview&&owner===this.owner&&event.current();
   const audio=await this.assets.load(event.resRef,current);if(!audio||!current())return;
   for(const packet of nativeAudioPackets(audio,{owner,sequence,code,voiceId}))if(current())this.send(packet);
   this.onPrepared({owner,sequence,code,voiceId,resource:event.resRef,codec:audio.codec,bytes:audio.data.length,sha256:audio.sha256,channels:audio.channels,sampleRate:audio.sampleRate,frames:audio.frames});
  }})});
 }
 async play(id,resref){
  if(!this.preview||!this.active())throw Error('Voice preview is unavailable');
  const preview=this.preview,owner=this.owner,sequence=++this.sequence,code=preview.selected===id?preview.index:0;
  this.code=code;this.voiceId=id;this.send({kind:'creation-voice-state',owner,sequence,state:'loading',code,voiceId:id});
  const work=preview.play(id,resref);this.pending.add(work);
  try{const played=await work;if(this.active()&&preview===this.preview&&owner===this.owner&&sequence===this.sequence&&!played)this.send({kind:'creation-voice-state',owner,sequence,state:'empty',code,voiceId:id});}
  catch(error){if(this.active()&&preview===this.preview&&sequence===this.sequence)this.send({kind:'creation-voice-state',owner,sequence,state:'error',code,voiceId:id,text:error.message});}
  finally{this.pending.delete(work);}
 }
 async retire(){this.configure(null);await this.assets.retire();await Promise.allSettled([...this.pending]);return{closed:true,pending:this.pending.size,cachedBytes:this.assets.bytes};}
}
