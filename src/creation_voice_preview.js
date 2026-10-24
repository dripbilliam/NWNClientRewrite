import {GameAudio} from './game_audio.js';
import {parseSoundSet} from './sound_set.js';
import {RESOURCE_TYPE} from './resource_archive.js';

// CharacterGen selection handler1408e7110: a new soundset starts at code0;
// repeated samples advance through0..48, including empty SSF entries.
export class CreationVoicePreview{
 constructor(resolver,{audioFactory=r=>new GameAudio(r,{getObject:()=>null,getPlayer:()=>({id:0})})}={}){
  this.resolver=resolver;this.audio=audioFactory(resolver);this.sets=new Map();this.index=0;this.selected=null;this.sequence=0;this.disposed=false;
 }
 async play(id,resref){
  if(this.disposed)return false;
  if(this.selected!==id){this.selected=id;this.index=0;}
  const code=this.index;this.index=code===48?0:code+1;const sequence=++this.sequence;
  if(!resref||resref==='****')return false;
  // Resume synchronously from the double-click gesture before awaiting IO.
  void this.audio.unlock();
  if(!this.sets.has(resref))this.sets.set(resref,this.resolver.getResource(resref,RESOURCE_TYPE.SSF).then(parseSoundSet).catch(e=>{this.sets.delete(resref);throw e;}));
  const entry=(await this.sets.get(resref)).get(code);if(this.disposed||sequence!==this.sequence||!entry?.resRef)return false;
  await this.audio.play({resRef:entry.resRef,objectId:0,channel:'creation-voice',replace:true,nativeSource:{positional:false,volume:127,priority:6},current:()=>!this.disposed&&sequence===this.sequence});return true;
 }
 dispose(){this.disposed=true;this.sequence++;this.audio.dispose();this.sets.clear();}
}
