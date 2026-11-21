'use strict';
// Accepted Session/World event boundary only. No socket, resources, world
// mirror, clock construction, native simulation or scene preparation here.
const {NativeClockIngress}=require('./native-clock-ingress.cjs');
const MAX=Number.MAX_SAFE_INTEGER;
const own=(value,key)=>{if(!value||typeof value!=='object')return undefined;const d=Object.getOwnPropertyDescriptor(value,key);return d&&Object.hasOwn(d,'value')?d.value:undefined;};
const method=(value,key)=>{for(let at=value;at&&typeof at==='object';at=Object.getPrototypeOf(at)){const d=Object.getOwnPropertyDescriptor(at,key);if(d)return Object.hasOwn(d,'value')&&typeof d.value==='function'?d.value:null;}return null;};
const safe=value=>Number.isSafeInteger(value)&&value>=0;
const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
const GAPS=new Map([['network.game-message-invalid','decoder-rejected'],['network.object-import-failed','lifecycle-gap'],['network.object-record-unhandled','incomplete-records'],['network.game-session-failed','transport-gap'],['network.area-import-failed','lifecycle-gap']]);

class NativeClockBridge {
 #isCurrent; #ingress; #active=null; #lastConnection=-1; #counts={};
 constructor({send,isCurrent}={}){
  if(typeof send!=='function'||typeof isCurrent!=='function')throw TypeError('Invalid native clock bridge callbacks');
  this.#isCurrent=isCurrent;
  this.#ingress=new NativeClockIngress({send,
   beginHistory:session=>{const active=this.#active;return active?.session===session&&active.early&&active.initialCoverage;},
   acceptedLifecycle:(session,boundary)=>{const active=this.#active;if(!active||!this.#current(session,active.connection)||active.epochInvalid)return null;return active.readBoundary.call(active.world,boundary);}
  });
 }
 #note(key){this.#counts[key]=Math.min(MAX,(this.#counts[key]??0)+1);}
 #admitted(session,connection){try{return this.#isCurrent(session,connection)===true;}catch{return false;}}
 #current(session,connection){const active=this.#active;if(!active||active.session!==session||active.connection!==connection||own(session,'closed')===true||!this.#admitted(session,connection)){this.#note('stale');return false;}return true;}
 #gap(active,reason){
  if(this.#active!==active)return;
  active.coverageLost=true;this.#note('gaps');
  try{this.#ingress.gap(active.session,active.connection,reason);}catch{this.#note('observerErrors');}
 }
 #epochCurrent(active){
  if(active.epochInvalid)return false;
  const history=active.readHistory.call(active.world);
  if(own(active.session,'world')!==active.world||own(history,'epoch')!==active.epoch||own(history,'connection')!==active.connection){
   active.epochInvalid=true;this.#note('epochChanges');this.#gap(active,'reset-unverified');return false;
  }
  if(own(history,'recordHistoryComplete')!==true&&!active.coverageLost)this.#gap(active,'lifecycle-gap');
  return true;
 }
 #receive(active,event){
  if(!this.#current(active.session,active.connection)||this.#active!==active)return;
  this.#note('messages');
  try{
   const message=own(event,'message'),kind=own(message,'kind');
   if(typeof kind!=='string'){this.#gap(active,'source-unknown');return;}
   if(kind==='object-updates'&&own(message,'complete')!==true&&!active.coverageLost)this.#gap(active,'incomplete-records');
   if(!this.#epochCurrent(active))return;
   const generation=own(event,'areaGeneration'),areaId=own(active.world,'areaId');
   if(!safe(generation)||!uint(areaId)){this.#gap(active,'source-unknown');return;}
   const scope={generation,areaId};
   const observed=this.#ingress.observe(active.session,active.connection,message,scope);
   if(observed.reason==='invalid-clock-event')this.#note('invalidClockEvents');
   if(kind!=='object-updates')return;
   const boundaries=active.readBoundaries.call(active.world,own(message,'records'));
   if(!Array.isArray(boundaries)){this.#gap(active,'lifecycle-gap');return;}
   for(const boundary of boundaries){
    const result=this.#ingress.lifecycle(active.session,active.connection,boundary,scope);
    if(result.reason==='not-lifecycle-event'||result.reason==='invalid-lifecycle-fact')this.#gap(active,'lifecycle-gap');
    else this.#note('lifecycleFacts');
   }
  }catch{this.#note('observerErrors');this.#gap(active,'source-unknown');}
 }
 attach(session,connection){
  if(!safe(connection)||!session||typeof session!=='object'||own(session,'closed')===true||!this.#admitted(session,connection)){this.#note('attachRejected');return {attached:false,reason:'stale-session'};}
  if(this.#active?.session===session&&this.#active.connection===connection)return {attached:true,reused:true};
  if(connection<=this.#lastConnection){this.#note('attachRejected');return {attached:false,reason:'old-or-duplicate-connection'};}
  const world=own(session,'world'),on=method(session,'on'),off=method(session,'removeListener');
  const bind=method(world,'bindNativeClockConnection'),readHistory=method(world,'nativeClockLifecycleHistory'),readBoundary=method(world,'nativeClockLifecycleBoundary'),readBoundaries=method(world,'nativeClockLifecycleBoundaries');
  if(!on||!off||!bind||!readHistory||!readBoundary||!readBoundaries){this.#note('attachRejected');return {attached:false,reason:'missing-owner-api'};}
  if(this.#active)this.retire(this.#active.session,this.#active.connection);
  let history;
  try{
   bind.call(world,connection);history=readHistory.call(world);
   if(own(history,'version')!==1||own(history,'source')!=='native_client_clock_lifecycle_v1'||!Number.isSafeInteger(own(history,'epoch'))||own(history,'epoch')<1||own(history,'connection')!==connection)throw Error('Invalid clock owner scope');
  }catch{this.#note('attachRejected');return {attached:false,reason:'world-clock-bind-failed'};}
  const active={session,connection,world,on,off,readHistory,readBoundary,readBoundaries,epoch:history.epoch,epochInvalid:false,coverageLost:false,early:own(session,'phase')==='new',initialCoverage:own(history,'recordHistoryComplete')===true};
  active.message=event=>this.#receive(active,event);
  active.diagnostic=value=>{if(!this.#current(session,connection)||this.#active!==active)return;const reason=GAPS.get(own(value,'code'));if(reason&&!active.coverageLost)this.#gap(active,reason);};
  active.closed=()=>this.retire(session,connection);
  this.#active=active;
  try{
   on.call(session,'message',active.message);on.call(session,'diagnostic',active.diagnostic);on.call(session,'closed',active.closed);
   const result=this.#ingress.begin(session,connection);
   if(!result.recorded)throw Error('Clock begin rejected');
   this.#lastConnection=connection;this.#note('attached');
   if(!active.early)this.#gap(active,'late-bind');
   return {attached:true,reused:false,connection,epoch:active.epoch};
  }catch{this.#note('attachRejected');this.retire(session,connection);return {attached:false,reason:'event-binding-failed'};}
 }
 flush(session,connection){if(!this.#current(session,connection))return {recorded:false,reason:'stale-session'};return this.#ingress.flush(session,connection);}
 retire(session,connection){
  const active=this.#active;
  if(!active||active.session!==session||active.connection!==connection){this.#note('staleRetire');return {retired:false};}
  // Fence captured callbacks before removing listeners or draining anything.
  this.#active=null;
  for(const [event,handler] of [['message',active.message],['diagnostic',active.diagnostic],['closed',active.closed]]){
   try{active.off.call(session,event,handler);}catch{this.#note('listenerRemovalErrors');}
  }
  const result=this.#ingress.retire(session,connection);this.#note('retired');return result;
 }
 snapshot(){const active=this.#active;return {attached:active!==null,connection:active?.connection??null,epoch:active?.epoch??null,epochInvalid:active?.epochInvalid??false,counts:{...this.#counts},ingress:this.#ingress.snapshot()};}
}
module.exports={NativeClockBridge};
