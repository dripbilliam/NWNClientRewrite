// Backend-only native presentation ownership around the proven portal protocol.
// No wire packets, credential readback, fabricated character or server query here.
export class NativePortalAdoption {
 constructor({lobby,policy,config,owns,prepare,install,failed=async()=>{},onEvent=()=>{}}){Object.assign(this,{lobby,policy,config,owns,prepare,install,failed,onEvent});this.jobs=new WeakMap();}
 bind(session,connection){
  session.portalTransfer.prepare=async portal=>{
   const owned=()=>this.owns(session,connection)&&!session.closed;
   if(!owned()||this.lobby.session!==session)throw Error('Retired native portal origin');
   // This must run before identity cloning or installed-session preparation,
   // whose server-info query can perform actual network work.
   const endpoint=this.policy.require(portal),config=this.config(session);
   if(!config)throw Error('Native portal resource configuration is absent');
   const identity=session.identity.forPortal(portal.password);let result;
   try{
    result=await this.prepare({...config,...endpoint,loginIdentity:identity,loginWaypoint:portal.waypoint||(portal.seamless?'*PAUL_WAS_HERE*':'')},connection+1,owned);
    if(!owned()){await result.session.disconnect();throw Error('Cancelled native portal preparation');}
    // A live destination must not keep every previous server world reachable.
    // The IPC adoption/failure call itself strongly owns its origin argument.
    this.jobs.set(result.session,{previous:new WeakRef(session),from:connection,to:connection+1,endpoint});
    this.onEvent({stage:'prepared',from:connection,to:connection+1,endpoint});return result;
   }catch(error){if(!result)identity.dispose();throw error;}
  };
 }
 async adopt({previous,next}){
  const job=this.jobs.get(next.session);
  if(!job||job.previous.deref()!==previous||!this.owns(previous,job.from)||this.lobby.session!==previous||!previous.closed||!previous.portalHandoffReady||next.session.closed)throw Error('Retired native portal adoption');
  const connection=this.lobby.advancePortal(previous,job.endpoint);
  if(connection!==job.to)throw Error('Native portal connection sequence changed');
  this.onEvent({stage:'adopting',from:job.from,to:connection,endpoint:job.endpoint});
  await this.install(next,connection,previous);
  if(!this.owns(next.session,connection)||this.lobby.session!==next.session||next.session.closed)throw Error('Cancelled native portal adoption');
  this.onEvent({stage:'installed',from:job.from,to:connection,endpoint:job.endpoint});
 }
 async fail({previous,next}){
  const job=this.jobs.get(next.session);
  if(!job||job.previous.deref()!==previous||this.lobby.connection!==job.to)return;
  let cleanupFailed=false;try{await this.failed(next.session,job.to,previous);}catch{cleanupFailed=true;}
  if(this.lobby.connection!==job.to)return;
  this.lobby.failPortal(job.to,'The destination server connection failed. Reconnect to try again.');
  this.onEvent({stage:'failed',from:job.from,to:job.to,endpoint:job.endpoint,cleanupFailed});
 }
 connected({previous,next}){
  const job=this.jobs.get(next.session);
  if(job&&job.previous.deref()===previous&&this.owns(next.session,job.to)&&!next.session.closed)this.lobby.portalConnected(next.session,job.to);
 }
}
