import {NativeMessageWriter} from './native_message.js';
import {satisfiesNativeBuild} from './network_build.js';
import {OBJECT_INVALID} from './game_object_array.js';
const BUILD={number:8193,revision:35,postfix:0};
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const panel=value=>Number.isInteger(value)&&value>=0&&value<=22;
const serial=value=>Number.isSafeInteger(value)&&value>=0;
export const GUI_PANEL_EVENT_LIMIT=32;
export function readGuiPanelDisabled(reader,build){
 const panelId=reader.readInt(),disabled=Boolean(reader.readBool()),targetReceived=satisfiesNativeBuild(build,BUILD);
 return{kind:'gui-panel-disabled',panelId,disabled,targetId:targetReceived?reader.readObjectIdClient():OBJECT_INVALID,targetSource:targetReceived?'received':'legacy_protocol_default'};
}
export const readGuiPanelPopup=reader=>({kind:'gui-panel-popup',panelId:reader.readInt()});
export function guiPanelAttemptRequest({panelId,targetId,includePosition}){
 if(!panel(panelId)||[0,1,3].includes(panelId)||!uint(targetId)||typeof includePosition!=='boolean')throw Error('Invalid native blocked-panel attempt');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(14);w.writeWord(panelId);w.writeObjectIdClient(targetId);
 if(includePosition)for(const value of [0,0,0])w.writeFloat(value,1,32);
 w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Canonical compact connection state. No renderer references, world mirror or
// per-frame scan. The bounded effect journal is replayed only by unseen serials.
export class GuiPanelAccess{
 #disabled=new Map();#events=[];#sequence=0;#lastInput=null;#lastEvent=null;#cache=null;
 #actor=null;#actorId=null;#controlLifetime=0;
 observe(message){
  this.#lastInput=null;
  if(!panel(message.panelId))return false; // Original helpers ignore unsupported INTs.
  let event;
  if(message.kind==='gui-panel-disabled'){
   if(typeof message.disabled!=='boolean'||!uint(message.targetId)||!['received','legacy_protocol_default'].includes(message.targetSource)||message.targetSource==='legacy_protocol_default'&&message.targetId!==OBJECT_INVALID)throw Error('Invalid received GUI access fields');
   let targets=this.#disabled.get(message.panelId);
   if(message.disabled){if(!targets)this.#disabled.set(message.panelId,targets=new Map());targets.set(message.targetId,message.targetSource);}
   else if(targets){targets.delete(message.targetId);if(!targets.size)this.#disabled.delete(message.panelId);}
   event={kind:'disabled',panelId:message.panelId,disabled:message.disabled,targetId:message.targetId,targetSource:message.targetSource};
  }else if(message.kind==='gui-panel-popup')event={kind:'popup',panelId:message.panelId,scope:null};
  else return false;
  if(this.#sequence===Number.MAX_SAFE_INTEGER)throw Error('GUI access serial exhausted');
  event.sequence=++this.#sequence;this.#events.push(event);if(this.#events.length>GUI_PANEL_EVENT_LIMIT)this.#events.shift();
  this.#lastInput=message;this.#lastEvent=event;this.#cache=null;return true;
 }
 #context({actor,actorId,areaId,areaGeneration}){
  const known=actor&&actor.objectType===5&&actor.id===actorId&&uint(actorId)&&actorId!==OBJECT_INVALID;
  if((known?actor:null)!==this.#actor||(known?actorId:null)!==this.#actorId){this.#actor=known?actor:null;this.#actorId=known?actorId:null;this.#controlLifetime++;}
  return{actorId:known?actorId:null,areaId:uint(areaId)&&areaId!==OBJECT_INVALID?areaId:null,areaGeneration:serial(areaGeneration)?areaGeneration:null,controlLifetime:known?this.#controlLifetime:null,source:'client_receive_context'};
 }
 bindEvent(message,context){
  if(message!==this.#lastInput||!this.#lastEvent)return null;
  if(this.#lastEvent.kind==='popup'&&this.#lastEvent.scope===null){this.#lastEvent.scope=this.#context(context);this.#cache=null;}
  return structuredClone({...this.#lastEvent,retiredThrough:this.#events[0].sequence-1});
 }
 matches(panelId,targetId){if(!panel(panelId)||!uint(targetId))return false;const targets=this.#disabled.get(panelId);return Boolean(targets&&(targets.has(targetId)||targets.has(OBJECT_INVALID)));}
 get sequence(){return this.#sequence;}
 snapshot(context){
  const control=this.#context(context);
  if(!this.#cache)this.#cache={revision:this.#sequence,retiredThrough:this.#events.length?this.#events[0].sequence-1:0,disabled:[...this.#disabled].flatMap(([panelId,targets])=>[...targets].map(([targetId,targetSource])=>({panelId,targetId,targetSource}))),events:this.#events};
  return structuredClone({...this.#cache,control});
 }
}
// Host publisher binds authoritative Session context at its existing accepted
// message boundary. No Session.receive or canonical application/ACK edits.
const context=(world,areaGeneration)=>({actor:world.registry.get(world.localObjectId),actorId:world.localObjectId,areaId:world.areaId,areaGeneration});
export const guiPanelEventForHost=(world,message,areaGeneration)=>world.guiPanelAccess.bindEvent(message,context(world,areaGeneration));
export const guiPanelHeaderForHost=(world,areaGeneration)=>world.guiPanelAccess.snapshot(context(world,areaGeneration));
