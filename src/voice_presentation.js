import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {creatureRoot} from './creature_rules.js';
import {parseSoundSet,soundSetString} from './sound_set.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

// Local client adapter for quick-chat22 and voice-play26. It resolves the live
// soundset table/SSF, preserving its explicit WAV override of TLK audio. Browser
// output and HUD text are adapters, not native packet or audio-mixer emulation.
export class VoicePresentation{
  constructor(resolver,{getObject,getPlayer,getText,onCaption=()=>{},onSound=()=>{}}){
    Object.assign(this,{resolver,getObject,getPlayer,getText,onCaption,onSound});this.tables=null;this.sets=new Map();this.tail=Promise.resolve();this.disposed=false;
  }
  async soundSet(id){
    if(!this.tables)this.tables=(async()=>{
      const table=parse2da(decodeResourceText(await this.resolver.getResource('soundset',RESOURCE_TYPE.TWO_DA)));
      // Native manager1407d7280 admits no rows if its second table fails.
      parse2da(decodeResourceText(await this.resolver.getResource('soundsettype',RESOURCE_TYPE.TWO_DA)));return table;
    })().catch(e=>{this.tables=null;throw e;});
    const table=await this.tables;if(this.disposed)return null;const count=table.orderedRows.length&65535;
    if(id>=count){runtimeDiagnostics.record('voice.soundset-index-invalid','Native soundset index is beyond the active table',{soundsetId:id,count});return null;}
    const raw=table.orderedRows[id]?.RESREF,resRef=!raw||raw==='****'?'':String(raw).split('\0')[0].slice(0,16).toLowerCase();if(!resRef)return null;
    if(!this.sets.has(resRef))this.sets.set(resRef,this.resolver.getResource(resRef,RESOURCE_TYPE.SSF).then(parseSoundSet).catch(e=>{this.sets.delete(resRef);throw e;}));
    return this.sets.get(resRef);
  }
  receive(event){
    const task=this.tail.then(()=>this.process(event));this.tail=task.catch(error=>{
      runtimeDiagnostics.error(error,'voice.presentation-failed',{actorId:event.actorId,voiceCode:event.code,module:this.resolver.moduleName});});return this.tail;
  }
  async process(event){
    if(this.disposed)return;
    const actor=this.getObject(event.actorId);if(actor?.objectType!==5)return;
    const id=(creatureRoot(actor).SoundSetFile??65535)&65535;if(id===65535)return;
    const set=await this.soundSet(id);if(!set||this.disposed)return;
    const code=event.type==='voice-chat'?event.code&255:event.code&65535,entry=set.get(code),resolved=soundSetString(set,code,{
      text:ref=>this.getText()?.strRef(ref),warning:(_,count)=>runtimeDiagnostics.record('voice.sound-id-invalid','Native soundset sound ID is beyond its array',{actorId:actor.id,soundsetId:id,voiceCode:code,count})});
    if(!entry)return;const {text}=resolved;
    if(this.disposed||this.getObject(actor.id)!==actor)return;
    if(event.type==='quick-chat'&&text)await this.onCaption({actorId:actor.id,text,strRef:entry.strRef,voiceCode:code});
    if(this.disposed||this.getObject(actor.id)!==actor)return;
    // SSF's empty sound overrides any audio in the referenced TLK entry.
    if(resolved.resRef)await this.onSound({objectId:actor.id,resRef:resolved.resRef,position:actor.position.slice(),listenerId:this.getPlayer()?.id,channel:'voice',replace:true});
  }
  dispose(){this.disposed=true;this.tables=null;this.sets.clear();}
}
