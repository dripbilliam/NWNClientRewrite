import {NativeMessageWriter} from './native_message.js';
import {journalWindowRequest} from './network_hud_input.js';

// CJournalPanel883610 subscribes before GUI10;883ce0/884100 emits GUI11
// before unsubscribing. Neither event carries a selection or an object.
export function journalGuiEventRequest({open,includePosition}){
 if(typeof open!=='boolean'||typeof includePosition!=='boolean')throw Error('Invalid native journal GUI event');
 const writer=new NativeMessageWriter(1);writer.create(20,0xffffffff,1);
 writer.writeWord(open?10:11);writer.writeWord(0);writer.writeObjectIdClient(0x7f000000);
 if(includePosition)for(const value of [0,0,0])writer.writeFloat(value,1,32);
 writer.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(writer.getWriteMessage().data);
}
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const MAX_PENDING=64;
const sameScope=(a,b)=>a&&a.world===b.world&&a.peer===b.peer&&a.actor===b.actor&&a.areaId===b.areaId&&a.areaGeneration===b.areaGeneration;
const stale=()=>Error('Native journal owner or scope has retired');

// Compact per-session transport bookkeeping, never a journal/world data store.
// Accepted pairs stay ordered through a rapid close/reopen. A superseding open
// without its predecessor's close retires that old logical owner (e.g. reset).
export class NativeJournalEvents{
 #state=null;
 #pending=0;
 async transition({open,journalLifetime,includePosition,scope},{assertCurrent,send}){
  if(typeof open!=='boolean'||typeof includePosition!=='boolean'||!Number.isSafeInteger(journalLifetime)||journalLifetime<=0)throw Error('Invalid native journal lifetime');
  if(!scope||!scope.world||!scope.peer||!scope.actor||!uint(scope.areaId)||!Number.isSafeInteger(scope.areaGeneration)||scope.areaGeneration<0||typeof assertCurrent!=='function'||typeof send!=='function')throw Error('Invalid native journal transport scope');
  assertCurrent();
  let state=this.#state;
  if(!state||!sameScope(state.scope,scope)){
   state={scope:{world:scope.world,peer:scope.peer,actor:scope.actor,areaId:scope.areaId,areaGeneration:scope.areaGeneration},latest:0,wanted:false,logical:null,tail:Promise.resolve()};this.#state=state;
  }
  if(journalLifetime<state.latest||(!open&&journalLifetime!==state.latest))throw stale();
  if(journalLifetime===state.latest){
   if(open&&!state.wanted)throw stale();
   if(open===state.wanted)return{sent:false,duplicate:true};
  }
  if(this.#pending>=MAX_PENDING)throw Error('Native journal transition queue is full');
  let logical=state.logical;
  if(open){
   if(logical&&!logical.closed)logical.cancelled=true;
   logical={lifetime:journalLifetime,closed:false,cancelled:false};state.logical=logical;state.latest=journalLifetime;
  }else{
   if(!logical||logical.closed)throw stale();
   logical.closed=true;
  }
  state.wanted=open;this.#pending++;
  const packets=open?[journalWindowRequest(true),journalGuiEventRequest({open:true,includePosition})]:[journalGuiEventRequest({open:false,includePosition}),journalWindowRequest(false)];
  const current=()=>{if(this.#state!==state||logical.cancelled)throw stale();assertCurrent();};
  const operation=state.tail.then(async()=>{
   try{for(const packet of packets){current();await send(packet);current();}return{sent:true};}
   finally{this.#pending--;}
  });
  state.tail=operation.catch(()=>{});return operation;
 }
}
