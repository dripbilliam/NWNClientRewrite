'use strict';
// Opt-in test orchestration only. Production still owns cancel, connect and UI.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
class NativeDirectHandoffRecovery {
 constructor(driver,{io=fs,clock=Date.now,sleep=delay}={}){
  this.driver=driver;this.io=io;this.clock=clock;this.sleep=sleep;this.row=null;this.destination=null;this.wrappers=[];this.hold=null;this.cancelInput=null;this.cancelAck=null;this.retryAck=null;this.retryFrom=null;this.retryTo=null;this.retrySent=false;this.committed=false;this.closed=false;this.destinationStopped=false;
 }
 prepare(row,destination){
  if(this.row||this.closed||row.endpoint.host!=='127.0.0.1'||row.endpoint.port!==5130)throw Error('Recovery destination/order differs');
  this.row=row;this.destination=new WeakRef(destination);row.connectCalls=0;row.disconnectCalls=0;row.cleanup=null;
  for(const method of ['connect','disconnect'])if(typeof destination[method]!=='function')throw Error('Recovery destination lifecycle owner unavailable');
  const controller=this,connect=destination.connect,disconnect=destination.disconnect;
  const connectWrapper=async function(...args){row.connectCalls++;return connect.apply(this,args);};
  const disconnectWrapper=async function(...args){
   row.disconnectCalls++;const bytes=this.character;
   const result=await disconnect.apply(this,args);
   // Inspect only during the actual disconnect call; no character bytes survive
   // in controller state, captures or snapshots.
   row.cleanup={closed:this.closed===true,characterNull:this.character===null,releasedBufferWiped:row.cleanup?.releasedBufferWiped===true||ArrayBuffer.isView(bytes)&&bytes.byteLength>=1000&&bytes.every(byte=>byte===0),identityDisposed:this.identity?.toJSON?.().disposed===true,peerClosed:this.peer?.closed===true};
   return result;
  };
  destination.connect=connectWrapper;destination.disconnect=disconnectWrapper;
  this.wrappers.push({ref:this.destination,connect,disconnect,connectWrapper,disconnectWrapper});
 }
 async retire(context){
  const d=this.driver,row=this.row,state=d.getScope(),next=context.next?.session;
  if(this.closed||this.hold||!row||this.destination.deref()!==next||row.previous.deref()!==context.previous||row.from!==context.from||row.to!==context.to||!context.current()||context.signal.aborted||state.session!==null||state.lobby.session!==null||state.lobby.connection!==row.to||!context.previous.closed||context.previous.portalHandoffReady!==true||!row.character||next.closed)throw Error('Recovery hold is not the actual null-lobby retirement boundary');
  const canJoin=state.lobby.snapshot().canJoin;
  row.retireBoundary={stage:'retire',nullLobby:true,sourceClosed:true,sourceHandoffReady:true,canJoin,connection:row.to};
  if(canJoin!==false)throw Error('Recovery permits join before destination cleanup');
  this.hold={signal:context.signal,started:this.clock(),cancelRelease:null};
  if(d.scenario==='failure'){
   await this.stopDestination(context);
   if(!context.current()||context.signal.aborted)throw Error('Unavailable-destination barrier lost its actual owner');
   this.hold=null;return;
  }
  await new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>{context.signal.removeEventListener('abort',aborted);reject(Error('Actual native cancellation did not abort the retirement hold'));},45000);
   const aborted=()=>{clearTimeout(timer);context.signal.removeEventListener('abort',aborted);this.hold.cancelRelease=null;resolve();};
   this.hold.cancelRelease=()=>{clearTimeout(timer);context.signal.removeEventListener('abort',aborted);reject(Error('Recovery controller closed'));};
   context.signal.addEventListener('abort',aborted,{once:true});
   d.send({kind:'probe-direct-handoff',connection:row.to,mode:'cancel',requestId:1});
  });
 }
 async stopDestination(context){
  const d=this.driver,request={version:1,kind:'native-direct-handoff-stop',host:'127.0.0.1',port:5130,fixtureNonce:d.fixture.nonce,from:context.from,to:context.to};
  const text=JSON.stringify(request),requestPath=path.join(d.fixture.directory,'stop-destination.json');
  if(typeof request.fixtureNonce!=='string'||request.fixtureNonce.length>128)throw Error('Owned fixture nonce unavailable');
  await this.io.writeFile(requestPath,text,{flag:'wx'});const expected=sha(Buffer.from(text)),deadline=this.clock()+25000;
  while(!this.closed&&context.current()&&!context.signal.aborted&&this.clock()<deadline){
   try{
    const bytes=await this.io.readFile(path.join(d.fixture.directory,'destination-stopped.json'));
    if(bytes.byteLength>4096)throw Error('Destination stop acknowledgment exceeds bound');
    const ack=JSON.parse(bytes);
    if(ack.version!==1||ack.kind!=='native-direct-handoff-stopped'||ack.host!=='127.0.0.1'||ack.port!==5130||ack.fixtureNonce!==request.fixtureNonce||ack.requestSha256!==expected||ack.stopped!==true)throw Error('Destination stop acknowledgment differs');
    this.destinationStopped=true;return;
   }catch(error){if(error.code!=='ENOENT')throw error;}
   await this.sleep(25);
  }
  throw Error('Owned unavailable-destination barrier did not complete');
 }
 input(message,current,connection){
  const d=this.driver,row=this.row,state=d.getScope();
  if(message.kind==='lobby-cancel-join'&&row){
   if(d.scenario!=='cancel'||this.cancelInput||connection!==row.to||state.lobby.connection!==row.to||state.lobby.session!==null||state.session!==null||!this.hold)throw Error('Cancellation input is outside the retirement hold');
   this.cancelInput={connection,at:this.clock()};return false;
  }
  if(message.kind==='browser-input'&&message.operation==='join'&&row){
   if(!this.retrySent||this.retryTo!==null||connection!==this.retryFrom||message.direct!==true||message.values?.host!=='127.0.0.1'||Number(message.values?.port)!==5129||!state.lobby.snapshot().canJoin||state.lobby.busy||state.lobby.transferring)throw Error('Recovery retry is not the actual clean owned-A browser input');
   this.retryTo=connection+1;return false;
  }
  if(message.kind!=='direct-handoff-control')return false;
  if(!row)throw Error('Recovery control precedes original handoff');
  if(message.mode==='cancel'){
   if(d.scenario!=='cancel'||this.cancelAck||message.requestId!==1||message.connection!==row.to||message.pointerClick!==true||!this.cancelInput)throw Error('Actual native cancel pointer acknowledgment differs');
   this.cancelAck={pointerClick:true,sourceWorldRetired:message.sourceWorldRetired===true,retiredAlive:message.retiredAlive,phase:message.phase};return true;
  }
  if(message.mode==='recover'){
   if(!this.retrySent||this.retryAck||message.requestId!==2||message.connection!==this.retryFrom||this.retryTo===null||message.backPointer!==true||message.directPointer!==true||message.confirmPointer!==true||message.menuUsable!==true||message.sourceWorldRetired!==true||message.retiredAlive!==0)throw Error('Actual native Back/Direct/OK recovery acknowledgment differs');
   this.retryAck={backPointer:true,directPointer:true,confirmPointer:true,menuUsable:true,sourceWorldRetired:true,retiredAlive:0};return true;
  }
  throw Error('Unknown recovery control acknowledgment');
 }
 event(event){
  if(event.stage!=='failed')return false;
  if(this.driver.scenario!=='failure'||!this.destinationStopped||this.row?.connectCalls!==1)throw Error('Unexpected direct destination failure');
  return true;
 }
 tick(){
  const d=this.driver,row=this.row;if(this.closed||!row||this.committed)return;
  const state=d.getScope(),destination=this.destination.deref(),cleanup=row.cleanup;
  if(!cleanup||!cleanup.closed||!cleanup.characterNull||!cleanup.releasedBufferWiped||!cleanup.identityDisposed||!cleanup.peerClosed||destination&&!destination.closed)return;
  if(state.portalState?.pending!==false||state.portalState?.phase!=='idle'||state.session!==null||state.lobby.session!==null||state.lobby.phase!=='menu'||state.lobby.busy||state.lobby.transferring||state.lobby.cancelling||!state.lobby.snapshot().canJoin)return;
  if(d.scenario==='cancel'&&(!this.hold?.signal.aborted||!this.cancelAck||this.cancelAck.sourceWorldRetired!==true||this.cancelAck.retiredAlive!==0||row.connectCalls!==0||state.lobby.error!==''))return;
  if(d.scenario==='failure'&&(!this.destinationStopped||row.connectCalls!==1||!row.stages.includes('failed')||typeof state.lobby.error!=='string'||state.lobby.error.length===0))return;
  if(!this.retrySent){this.retrySent=true;this.retryFrom=state.lobby.connection;this.errorAtRecovery=String(state.lobby.error).slice(0,512);d.send({kind:'probe-direct-handoff',connection:this.retryFrom,mode:'recover',requestId:2});}
 }
 mayRead(connection){return this.retryTo!==null&&connection===this.retryTo;}
 maySelect(connection){return this.mayRead(connection)&&this.retryAck!==null;}
 complete(){
  if(this.committed)return;
  const d=this.driver,row=this.row;
  if(!row||!this.retryAck||this.retryTo===null||d.capture.data.admissions.length!==2||d.capture.data.admissions.at(-1).connection!==this.retryTo)throw Error('Recovery cannot complete before actual owned-A readmission');
  const cleanup=row.cleanup;
  const transfer={from:row.from,to:row.to,endpoint:{...row.endpoint},character:{...row.character},transmittedSha256:row.transmittedSha256,originReleased:row.originReleased,originHandoffReady:row.originHandoffReady,stages:row.stages.slice(),retireBoundary:{...row.retireBoundary}};
  d.capture.transfer(transfer);
  const recovery={stage:'retire',sourceWorldRetired:this.retryAck.sourceWorldRetired,destinationClosed:cleanup?.closed===true,privateCharacterWiped:cleanup?.characterNull===true&&cleanup?.releasedBufferWiped===true,identityDisposed:cleanup?.identityDisposed===true,peerClosed:cleanup?.peerClosed===true,joinWhileClosing:row.retireBoundary.canJoin,menuUsable:this.retryAck.menuUsable,backPointer:this.retryAck.backPointer,retryPointer:this.retryAck.directPointer&&this.retryAck.confirmPointer,cancelPointer:d.scenario==='cancel'&&this.cancelAck?.pointerClick===true,abortObserved:d.scenario==='cancel'&&this.hold?.signal.aborted===true,destinationConnectCalls:row.connectCalls,destinationDisconnectCalls:row.disconnectCalls,destinationStopped:this.destinationStopped,error:this.errorAtRecovery??'',retryFrom:this.retryFrom,retryTo:this.retryTo};
  recovery.success=recovery.sourceWorldRetired&&recovery.destinationClosed&&recovery.privateCharacterWiped&&recovery.identityDisposed&&recovery.peerClosed&&recovery.joinWhileClosing===false&&recovery.menuUsable&&recovery.backPointer&&recovery.retryPointer&&(d.scenario==='cancel'?recovery.cancelPointer&&recovery.abortObserved&&recovery.destinationConnectCalls===0&&recovery.error==='':recovery.destinationStopped&&recovery.destinationConnectCalls===1&&recovery.error.length>0);
  d.capture.recovery(recovery);
  this.committed=true;
 }
 snapshot(){const row=this.row;return{scenario:this.driver.scenario,stage:'retire',hold:Boolean(this.hold),abortObserved:this.hold?.signal.aborted===true,sourceReady:row?.character?{kind:row.character.kind,bytes:row.character.bytes,sha256:row.character.sha256,parsedOriginal:row.character.parsedOriginal,semanticSha256:row.character.character?.semanticSha256??null}:null,retireBoundary:row?.retireBoundary?{...row.retireBoundary}:null,destinationLifecycle:row?{connectCalls:row.connectCalls,disconnectCalls:row.disconnectCalls,cleanup:row.cleanup?{...row.cleanup}:null,stages:row.stages.slice()}:null,cancelInput:this.cancelInput?{connection:this.cancelInput.connection}:null,cancelAck:this.cancelAck?{...this.cancelAck}:null,retryFrom:this.retryFrom,retryTo:this.retryTo,retrySent:this.retrySent,retryAck:this.retryAck?{...this.retryAck}:null,destinationStopped:this.destinationStopped,committed:this.committed};}
 close(){
  this.closed=true;this.hold?.cancelRelease?.();
  for(const entry of this.wrappers){const session=entry.ref.deref();if(session?.connect===entry.connectWrapper)session.connect=entry.connect;if(session?.disconnect===entry.disconnectWrapper)session.disconnect=entry.disconnect;}
  this.wrappers=[];
 }
}
module.exports={NativeDirectHandoffRecovery};
