import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {nativeStringEntry} from './spell_metadata.js';
import {intEntry} from './combat_stats.js';
import {parseSoundSet} from './sound_set.js';
import {effectSoundProviders} from './native_effect_sound.js';
import {playCreatureVoice,startCreatureVoiceSource} from './client_creature_voice.js';
import {nativeAudioResRef} from './native_audio.js';

// P/mask2000: server8a0 ->77fe10/80aea0 -> client SoundSetFile3b8.
const soundset=actor=>(actor.appearance?.field8A0??65535)&65535;
export class NetworkCreatureVoices{
 constructor({world,resolver,appearance,position,soundFactory=null,caption=()=>{},report=()=>{}}){
  Object.assign(this,{world,resolver,appearance,position,soundFactory,caption,report});this.areaId=world.areaId;this.actors=new Map();this.sets=new Map();this.tasks=new Set();this.events=[];this.disposed=false;this.sequence=0;
  this.sounds=effectSoundProviders(null,ref=>report('network.voice-output-unavailable','Native creature voice output is unavailable',{resRef:ref}));
 }
 actor(id){const o=this.world.registry.get(id);return !this.disposed&&this.areaId===this.world.areaId&&o?.objectType===5&&!o.replicationRemoved&&o.areaId===this.areaId?o:null;}
 event(value){this.events.push(value);if(this.events.length>64)this.events.shift();}
 state(actor){let state=this.actors.get(actor.id);if(state?.actor!==actor){if(state)this.remove(actor.id);state={actor,sound:null,delay:0,validSequence:-1};this.actors.set(actor.id,state);}return state;}
 async table(){
  if(!this.tables)this.tables=Promise.all(['soundset','soundsettype'].map(async name=>parse2da(decodeResourceText(await this.resolver.getResource(name,RESOURCE_TYPE.TWO_DA))))).then(([table])=>table).catch(e=>{this.tables=null;throw e;});
  return this.tables;
 }
 async entry(actor,code){
  const id=soundset(actor);if(id===65535)return null;const table=await this.table(),count=table.orderedRows.length&65535;
  if(id>=count){this.report('network.voice-soundset-invalid','Native soundset index exceeds the active table',{objectId:actor.id,soundsetId:id,count});return null;}
  const ref=nativeAudioResRef(nativeStringEntry(table,id,'RESREF').value).toLowerCase();if(!ref)return null;
  if(!this.sets.has(ref))this.sets.set(ref,this.resolver.getResource(ref,RESOURCE_TYPE.SSF).then(parseSoundSet).catch(e=>{this.sets.delete(ref);throw e;}));
  const set=await this.sets.get(ref),entry=set.get(code);
  if(entry===undefined)this.report('network.voice-index-invalid','Native SSF index exceeds its array',{objectId:actor.id,soundsetId:id,voiceCode:code,count:set.count});
  return{set,entry,id};
 }
 request(id,code,{quickChat=false,positional=1}={}){
  const task=this.process(id,code&65535,{quickChat,positional,sequence:this.sequence++}).catch(error=>{if(!this.disposed)this.report('network.voice-resource-failed',error.message,{objectId:id,voiceCode:code});return false;});
  this.tasks.add(task);void task.finally(()=>this.tasks.delete(task));return task;
 }
 bark(id,code){return this.request(id,code);}
 receive(message){if(message.kind==='quick-chat')return this.request(message.objectId,message.quickChat,{quickChat:true});if(message.kind==='voice-play')return this.request(message.objectId,message.voiceCode&255);return false;}
 async process(id,code,{quickChat,positional,sequence}){
  const actor=this.actor(id);if(!actor)return false;const state=this.state(actor),setId=soundset(actor),info=await this.entry(actor,code),current=()=>this.actor(id)===actor&&this.actors.get(id)===state;
  if(!info||!current()||setId!==soundset(actor))return false;
  if(quickChat&&info.entry?.strRef!==undefined&&info.entry.strRef!==0xffffffff){try{await this.caption({actorId:id,strRef:info.entry.strRef,voiceCode:code,current});}catch(error){if(current())this.report('network.voice-caption-failed',error.message,{objectId:id,voiceCode:code});}if(!current())return false;}
  const resRef=info.entry?.resRef;if(!resRef)return false;
  // Native Exists precedes replacement. Probe bytes without decoding so a
  // missing new resource leaves the existing voice intact, including pending IO.
  try{await this.resolver.getResource(resRef,RESOURCE_TYPE.WAV);}catch(error){if(current())this.report('network.voice-wave-unavailable',error.message,{objectId:id,resRef});return false;}
  if(!current()||setId!==soundset(actor)||sequence<state.validSequence)return false;state.validSequence=sequence;state.soundsetId=setId;
  const controlled=()=>this.world.localObjectId===id,player=()=>[...this.world.players.values()].some(p=>p.objectId===id),sounds=this.sounds;
  const p={demandSet:()=>info.set,entry:()=>info.entry,releaseSet(){},exists:()=>true,controlled,player,sizeCategory:()=>intEntry(this.appearance,actor.appearance.appearance,'SIZECATEGORY').value,
   createSound:ref=>this.soundFactory?this.soundFactory({resRef:ref,objectId:id,channel:'voice'}):sounds.createSound(ref),destroySound:s=>{this.event({kind:'replace',objectId:id,sound:s.snapshot?.()??null});sounds.destroySound(s);},
   sound3d:(s,v)=>sounds.soundSetting(s,'setting1401d9e90',v),soundPriority:(s,v)=>sounds.soundSetting(s,'setting1401da060',v),position:()=>this.position(actor),updateSound:sounds.updateSound,playSound:s=>sounds.playSound(s)};
  const started=quickChat?startCreatureVoiceSource(state,resRef,{positional:1,priority:controlled()?6:7,height:0},p):playCreatureVoice(state,code,positional,p);
  if(started)this.event({kind:'voice',objectId:id,voiceCode:code,soundsetId:setId,quickChat,resRef,priority:quickChat?controlled()?6:7:controlled()?6:player()?7:p.sizeCategory()<4?15:14});return started;
 }
 update(){for(const [id,state]of this.actors){if(this.actor(id)!==state.actor){this.remove(id);continue;}if(state.sound)this.sounds.updateSound(state.sound,this.position(state.actor),1.5);}}
 remove(id){const state=this.actors.get(id);if(!state)return;this.actors.delete(id);if(state.sound){this.event({kind:'destroy',objectId:id,sound:state.sound.snapshot?.()??null});this.sounds.destroySound(state.sound);state.sound=null;}}
 snapshot(){return{pending:this.tasks.size,sources:[...this.actors].filter(([,s])=>s.sound).map(([id,s])=>({id,sound:s.sound.snapshot?.()??null})),events:this.events.map(e=>({...e}))};}
 dispose(){this.disposed=true;for(const id of [...this.actors.keys()])this.remove(id);this.sets.clear();this.tables=null;}
}
