// Candidate only: backend ownership, no Host wiring, sockets, assets or UI work.
import {NativePortalAdoption} from './portal-adoption.mjs';

export class NativeDirectPortal {
 #options; #adoption; #binding=null; #pending=null; #work=null; #closed=false;
 #disposals=new WeakMap();
 #counts={bound:0,prepared:0,adopted:0,connected:0,cancelled:0,failed:0,stale:0,disposed:0,cleanupFailures:0};
 constructor({lobby,policy,isCurrent,configFor,prepare,retire=async()=>{},install,resetFailed=()=>{},onEvent=()=>{}}){
  for(const [name,value]of Object.entries({isCurrent,configFor,prepare,retire,install,resetFailed,onEvent}))if(typeof value!=='function')throw Error('Missing direct portal callback: '+name);
  this.#options={lobby,isCurrent,configFor,prepare,retire,install,resetFailed,onEvent};
  this.#adoption=new NativePortalAdoption({lobby,policy,config:configFor,
   owns:(session,connection)=>this.#bound(session,connection),
   prepare:async(args,connection,owned)=>{
    const job=this.#pending;
    if(!job||job.to!==connection||!this.#live(job)||!owned())throw Error('Retired direct portal preparation');
    const next=await prepare(args,connection,()=>this.#live(job)&&owned(),job.abort.signal);
    if(!next?.session||next.session===job.previous||typeof next.session.disconnect!=='function'||typeof next.session.connect!=='function'||isCurrent(next.session,lobby.connection))throw Error('Portal factory must return a fresh detached session');
    // NativePortalAdoption performs the late-result ownership check and disposal.
    // Keep the exact prepared object even if cancellation occurred during await.
    job.next=next;
    if(!this.#live(job)||!owned()){await this.#disconnect(next.session);throw Error('Cancelled direct portal preparation');}
    return next;
   },
   install:(next,connection,previous)=>this.#install(next,connection,previous),
   failed:(session,connection,previous)=>this.#resetFailure(session,connection,previous),
   onEvent:event=>{
    if(event.stage==='prepared'&&this.#pending&&event.from===this.#pending.from){this.#pending.endpoint={...event.endpoint};this.#counts.prepared++;}
    this.#event(event.stage,event.from,event.to);
   }});
 }
 #event(stage,from,to){try{this.#options.onEvent({stage,from,to});}catch{/* diagnostics cannot own the transfer */}}
 #bound(session,connection){const b=this.#binding;return !this.#closed&&b?.session===session&&b.connection===connection&&b.active&&this.#options.isCurrent(session,connection);}
 #live(job){return !this.#closed&&this.#pending===job&&!job.cancelled;}
 #detach(){
  const b=this.#binding;if(!b)return;this.#binding=null;b.active=false;
  b.session.off('portal-ready',b.ready);b.session.off('closed',b.closed);
  // Never restore the factory's generic portal hook after native retirement.
  // That could bypass native adoption while a cancelled origin is closing.
  if(b.session.portalTransfer.prepare===b.wrapper)b.session.portalTransfer.prepare=async()=>{throw Error('Retired direct portal origin');};
 }
 bind(session,connection){
  if(this.#closed||!Number.isSafeInteger(connection)||connection<1||!session?.portalTransfer||typeof session.on!=='function'||typeof session.off!=='function'||!this.#options.isCurrent(session,connection)||this.#options.lobby.session!==session)throw Error('Direct portal bind is not the current lobby owner');
  if(this.#bound(session,connection))return false;
  const job=this.#pending,installing=job&&job.phase==='installing'&&job.next?.session===session&&job.to===connection;
  if(job&&!installing)this.#cancelJob(job);
  this.#detach();
  const b={session,connection,active:true};this.#binding=b;
  this.#adoption.bind(session,connection);const prepare=session.portalTransfer.prepare;
  b.wrapper=async portal=>{
   if(this.#binding!==b||!this.#bound(session,connection)||this.#pending)throw Error('Retired or busy direct portal origin');
   const pending={previous:session,binding:b,from:connection,to:connection+1,next:null,endpoint:null,phase:'preparing',cancelled:false,abort:new AbortController(),work:null};
   if(!Number.isSafeInteger(pending.to))throw Error('Native connection serial exhausted');this.#pending=pending;
   try{const next=await prepare(portal);if(!this.#live(pending))throw Error('Cancelled direct portal preparation');pending.phase='prepared';return next;}
   catch(error){if(this.#pending===pending)this.#pending=null;throw error;}
  };
  session.portalTransfer.prepare=b.wrapper;
  b.ready=next=>{if(this.#binding!==b||!b.active){this.#counts.stale++;return;}void this.adopt(session,next).catch(()=>{});};
  b.closed=()=>{
   // A failed connect closes its Session before rejecting. Its active adoption
   // must retain the failure latch until #run recovers the exact lobby owner.
   if(this.#pending?.next?.session===session&&this.#pending.work)return;
   if(this.#binding===b&&!session.portalHandoffReady){
    // Trusted private Session closure is cleanup, not an old GUI command.
    const job=this.#pending;this.#detach();
    if(job&&(job.previous===session||job.next?.session===session))void this.#cancelJob(job);
   }
  };
  session.on('portal-ready',b.ready);session.on('closed',b.closed);this.#counts.bound++;return true;
 }
 #afterAdvance(job){return this.#live(job)&&this.#options.lobby.connection===job.to&&this.#options.lobby.session===null&&this.#binding===job.binding;}
 #destination(job){return this.#live(job)&&this.#bound(job.next?.session,job.to)&&this.#options.lobby.session===job.next.session;}
 #sync(callback,args){const value=callback(...args);if(value&&typeof value.then==='function'){void Promise.resolve(value).catch(()=>{});throw Error('Direct portal commit callbacks must be synchronous');}return value;}
 async #install(next,connection,previous){
  const job=this.#pending;
  if(!job||job.previous!==previous||job.next?.session!==next.session||job.to!==connection||!this.#afterAdvance(job))throw Error('Retired direct portal install');
  job.phase='retiring';
  const current=()=>this.#afterAdvance(job);
  await this.#options.retire({previous,next,from:job.from,to:connection,current,signal:job.abort.signal});
  if(!current()||next.session.closed)throw Error('Cancelled direct portal retirement');
  job.phase='installing';this.#sync(this.#options.install,[next,connection,previous]);
  // Host attach may bind during its synchronous commit. Otherwise bind here.
  if(!this.#bound(next.session,connection))this.bind(next.session,connection);
  if(!this.#destination(job))throw Error('Direct portal install did not publish its exact owner');
  job.phase='installed';this.#counts.adopted++;
 }
 adopt(previous,next){
  const job=this.#pending;
  if(!job||job.previous!==previous||job.next?.session!==next?.session||!this.#live(job)){this.#counts.stale++;return Promise.reject(Error('Unowned direct portal ready event'));}
  if(job.work)return job.work;
  if(job.phase!=='prepared'||!job.endpoint)return Promise.reject(Error('Direct portal destination is not prepared'));
  if(!this.#bound(previous,job.from)||this.#options.lobby.session!==previous||!previous.closed||!previous.portalHandoffReady)return Promise.reject(Error('Direct portal origin is not released'));
  const ownedNext={...job.next,host:job.endpoint.host,port:job.endpoint.port};
  job.work=this.#run(job,ownedNext);this.#work=job.work;
  void job.work.finally(()=>{if(this.#work===job.work)this.#work=null;}).catch(()=>{});return job.work;
 }
 async #run(job,next){
  try{
   job.phase='adopting';await this.#adoption.adopt({previous:job.previous,next});
   if(!this.#destination(job)||next.session.closed)throw Error('Cancelled direct portal destination');
   job.phase='connecting';
   await next.session.connect({host:job.endpoint.host,port:job.endpoint.port,metadata:next.metadata,...(next.expectedServerPublicKey?{expectedServerPublicKey:next.expectedServerPublicKey}:{})});
   if(!this.#destination(job)||next.session.closed)throw Error('Retired or closed direct portal connection');
   this.#adoption.connected({previous:job.previous,next});job.phase='connected';this.#counts.connected++;
   this.#event('connected',job.from,job.to);return {connected:true,connection:job.to};
  }catch(error){
   await this.#disconnect(job.next?.session);
   if(this.#live(job)){
    this.#counts.failed++;
    if(this.#options.lobby.connection===job.to)await this.#adoption.fail({previous:job.previous,next});
    else if(this.#bound(job.previous,job.from)&&this.#options.lobby.session===job.previous&&job.previous.closed&&job.previous.portalHandoffReady){
     this.#resetFailure(job.previous,job.from,job.previous);
     if(this.#live(job)&&this.#options.lobby.connection===job.from)this.#options.lobby.failPortal(job.from,'The destination server connection failed. Reconnect to try again.');
    }
    if(this.#binding?.session===job.previous||this.#binding?.session===job.next?.session)this.#detach();
   }
   throw error;
  }finally{if(this.#pending===job)this.#pending=null;}
 }
 #resetFailure(session,connection,previous){
  const job=this.#pending;
  if(!job||!this.#live(job)||job.previous!==previous||this.#options.lobby.connection!==connection)return;
  // A failure can occur in the null-lobby retirement interval or after install.
  if(this.#options.lobby.session!==null&&this.#options.lobby.session!==session&&this.#options.lobby.session!==previous)return;
  this.#sync(this.#options.resetFailed,[session,connection,previous]);
 }
 #disconnect(session){
  if(!session)return Promise.resolve();let work=this.#disposals.get(session);
  if(!work){work=Promise.resolve().then(()=>session.disconnect()).catch(()=>{this.#counts.cleanupFailures++;});this.#disposals.set(session,work);this.#counts.disposed++;}return work;
 }
 #cancelJob(job){
  if(job.cancelled)return Promise.resolve();job.cancelled=true;job.phase='cancelled';job.abort.abort(Error('Direct portal cancelled'));
  if(this.#pending===job)this.#pending=null;this.#counts.cancelled++;return this.#disconnect(job.next?.session);
 }
 async cancel(session,connection){
  const job=this.#pending,b=this.#binding;
  if(connection!==this.#options.lobby.connection)return false;
  const lobbyOwner=this.#options.lobby.session;
  const origin=job&&session===job.previous&&connection===job.from&&lobbyOwner===session&&this.#bound(session,connection);
  const destination=job&&connection===job.to&&(session===job.next?.session&&(lobbyOwner===null||lobbyOwner===session)||session===null&&lobbyOwner===null);
  const bound=b&&session===b.session&&connection===b.connection&&lobbyOwner===session&&this.#bound(session,connection);
  if(!origin&&!destination&&!bound)return false;
  this.#detach();if(job)await this.#cancelJob(job);return true;
 }
 async dispose(){if(this.#closed)return;this.#closed=true;this.#detach();if(this.#pending)await this.#cancelJob(this.#pending);}
 settled(){return this.#work??Promise.resolve();}
 snapshot(){return {...this.#counts,closed:this.#closed,boundConnection:this.#binding?.connection??null,pending:Boolean(this.#pending),phase:this.#pending?.phase??'idle'};}
}
