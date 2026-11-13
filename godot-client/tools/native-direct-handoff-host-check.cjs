'use strict';
// NEW opt-in driver. Observes the real direct route; no protocol implementation.
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {DirectHandoffCapture}=require('./native-direct-handoff-capture.cjs');
const {NativeDirectHandoffRecovery}=require('./native-direct-handoff-recovery.cjs');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const progressInteger=(value,min=-1,max=Number.MAX_SAFE_INTEGER)=>Number.isSafeInteger(value)&&value>=min&&value<=max?value:null;
const progressText=value=>typeof value==='string'?value.slice(0,64):null;
function projectNativeProgress(value){
 const output={};
 for(const key of ['connection','epoch','areaId','acceptedRawSerial','rawSerial','rawInFlightCount','rawExpectedCount','pendingBatches','instances','desired','peerStatus','peerAvailableBytes','framePendingBytes','outputQueuedBytes','outputPendingMessages','outputBytesSent','receivedSnapshots','processFrames','ticksMs','beforeConnection','beforeGeneration','beforeSerial','beforeTicksMs','afterConnection','afterGeneration','afterSerial','afterTicksMs','tcpReadErrorCode','tcpReadErrorBytes','tcpReadErrorExpected','tcpReadErrorTicksMs'])output[key]=progressInteger(value?.[key]);
 for(const key of ['pendingFirstByte','pendingLastByte'])output[key]=progressInteger(value?.[key],0,255);
 output.pendingLfIndex=progressInteger(value?.pendingLfIndex,-1,1048575);
 output.pendingLfSearchBytes=progressInteger(value?.pendingLfSearchBytes,0,1048576);
 output.binaryDeclaredLength=output.pendingFirstByte===0x89?progressInteger(value?.binaryDeclaredLength,0,0xffffffff):null;
 for(const key of ['initialized','worldPresent','worldReady','rawInFlight'])output[key]=typeof value?.[key]==='boolean'?value[key]:null;
 for(const key of ['beforeKind','afterKind'])output[key]=progressText(value?.[key]);
 return output;
}
function projectHostTransportProgress(value){
 const output={};
 for(const key of ['socketBytesWritten','socketWritableLength','socketBytesRead','rawFrameConnection','rawFrameGeneration','rawFrameSerial','rawFrameHeaderCount','rawFrameChunkCount','rawFrameEndCount','rawFrameTotalBytes'])output[key]=progressInteger(value?.[key],0);
 for(const key of ['socketDestroyed','rawFrameNewlinePresent'])output[key]=typeof value?.[key]==='boolean'?value[key]:null;
 return output;
}
class NativeDirectHandoffHostCheck{
 #initialReadDigest=null;#retryReadDigest=null;
 constructor({fixture,scenario,send,finish,getScope,characterDigest,rawCombat,compareCharacterChain=null,compareRetryCharacter=null,canonicalCharacterContinuity=false,progressDiagnostics=false,diagnosticClock=()=>performance.now(),diagnosticFs=fs}){
  if(!['roundtrip','cancel','failure'].includes(scenario))throw Error('Unknown direct handoff scenario');
  for(const f of[send,finish,getScope,characterDigest])if(typeof f!=='function')throw Error('Direct handoff driver callback unavailable');
  if(typeof canonicalCharacterContinuity!=='boolean'||compareCharacterChain!==null&&typeof compareCharacterChain!=='function'||compareRetryCharacter!==null&&typeof compareRetryCharacter!=='function'||canonicalCharacterContinuity&&scenario==='roundtrip'&&typeof compareCharacterChain!=='function')throw Error('Configured canonical continuity callback unavailable');
  Object.assign(this,{fixture,scenario,send,finish,getScope,characterDigest,rawCombat,compareCharacterChain,compareRetryCharacter,canonicalCharacterContinuity});this.capture=new DirectHandoffCapture(fixture,scenario,{canonicalCharacterContinuity});this.jobs=new WeakMap();this.rows=[];this.uploads=[];this.probed=new Set();this.commands=[];this.commandAcks=[];this.catalogObservations=[];this.booted=false;this.failed=false;this.closed=false;this.finishSent=false;this.work=null;this.firstConnection=null;this.selecting=false;this.exportOwner=null;this.started=Date.now();
  this.progress={enabled:progressDiagnostics===true,clock:diagnosticClock,fs:diagnosticFs,nextAt:0,lastNow:-1,sequence:0,active:null,pending:null,native:null,published:0,coalesced:0,stale:0,droppedNative:0,error:null};
  this.recovery=scenario==='roundtrip'?null:new NativeDirectHandoffRecovery(this);
  if(this.progress.enabled){const base=path.resolve(__dirname,'../.cache/native-direct-handoff'),directory=path.resolve(fixture.directory??'');if(path.dirname(directory)!==base||!/^native-direct-handoff-[a-z0-9-]+$/.test(path.basename(directory)))throw Error('Diagnostic directory is outside the owned direct fixture');if(typeof diagnosticClock!=='function'||!['writeFile','rename','rm'].every(k=>typeof diagnosticFs[k]==='function'))throw Error('Diagnostic I/O provider unavailable');this.progress.directory=directory;this.progress.file=path.join(directory,'direct-progress.json');}
 }
 diagnosticScope(){const state=this.getScope(),session=state.session;return{state,token:{connection:progressInteger(state.lobby?.connection),generation:progressInteger(session?.areaGeneration),areaId:progressInteger(session?.world?.areaId),session:session&&typeof session==='object'?new WeakRef(session):null}};}
 diagnosticCurrent(token){if(this.closed)return false;const{token:now}=this.diagnosticScope();return now.connection===token.connection&&now.generation===token.generation&&now.areaId===token.areaId&&(token.session?now.session?.deref()===token.session.deref():now.session===null);}
 diagnostic(extra={}){
  const p=this.progress;if(!p.enabled||this.closed)return false;
  try{
   const now=p.clock();if(typeof now!=='number'||!Number.isFinite(now)||now<0||now<p.lastNow||now<p.nextAt)return false;p.lastNow=now;p.nextAt=now+2000;
   const{state,token}=this.diagnosticScope(),session=state.session,lobby=state.lobby,area=session?.world?.registry?.get(session.world.areaId)?.state;
   const native=p.native?.connection===token.connection?p.native:null;
   const record={version:1,sequence:++p.sequence,elapsedMs:Math.floor(now),host:{connection:token.connection,generation:token.generation,areaId:token.areaId,phase:progressText(session?.phase),lobbyPhase:progressText(lobby?.phase),lobbyBusy:typeof lobby?.busy==='boolean'?lobby.busy:null,transferring:typeof lobby?.transferring==='boolean'?lobby.transferring:null,sessionPresent:Boolean(session),sessionClosed:typeof session?.closed==='boolean'?session.closed:null,areaReadySent:typeof session?.areaReadySent==='boolean'?session.areaReadySent:null,hasTiles:area?Array.isArray(area.tiles):null,tilesCount:Array.isArray(area?.tiles)?area.tiles.length:null,catalogReady:typeof state.catalogReady==='boolean'?state.catalogReady:null,rawSerial:progressInteger(state.rawSerial),rawPending:typeof extra.rawPending==='boolean'?extra.rawPending:typeof state.rawPending==='boolean'?state.rawPending:null,rawPendingSerial:progressInteger(extra.rawPendingSerial??state.rawPendingSerial),rawPendingGeneration:progressInteger(extra.rawPendingGeneration??state.rawPendingGeneration),catalogReadyCount:progressInteger(extra.catalogReadyCount),catalogReadyTicks:progressInteger(extra.catalogReadyTicks),pendingCommands:progressInteger(state.pendingCommands,0),lastCommandKind:progressText(state.lastCommandKind),hookPhase:progressText(extra.hookPhase??extra.phase),booted:this.booted,selecting:this.selecting,workPending:Boolean(this.work),finishSent:this.finishSent,failed:this.failed,admissions:this.capture.data.admissions.length,transfers:this.rows.length},native:native?structuredClone(native):null};
   Object.assign(record.host,projectHostTransportProgress(state));
   const text=JSON.stringify(record);if(Buffer.byteLength(text)>4096)throw Error('Diagnostic record exceeds4KiB');const job={token,text,sequence:record.sequence};
   if(p.active){if(p.pending)p.coalesced++;p.pending=job;}else this.startDiagnostic(job);return true;
  }catch(error){p.error=String(error.message).slice(0,256);return false;}
 }
 startDiagnostic(job){
  const p=this.progress;
  p.active=this.writeDiagnostic(job).catch(error=>{p.error=String(error.message).slice(0,256);}).finally(()=>{p.active=null;const next=p.pending;p.pending=null;if(next&&!this.closed)this.startDiagnostic(next);});
 }
 async writeDiagnostic(job){
  const p=this.progress;if(!this.diagnosticCurrent(job.token)){p.stale++;return;}
  const temp=path.join(p.directory,'.direct-progress-'+process.pid+'-'+job.sequence+'.tmp');
  let created=false;
  try{await p.fs.writeFile(temp,job.text,{flag:'wx'});created=true;if(!this.diagnosticCurrent(job.token)){p.stale++;return;}await p.fs.rename(temp,p.file);p.published++;}
  finally{if(created)await p.fs.rm(temp,{force:true}).catch(()=>{});}
 }
 async flushDiagnostics(){while(this.progress.active)await this.progress.active;return this.progressSummary();}
 progressSummary(){const p=this.progress;return{enabled:p.enabled,sequence:p.sequence,published:p.published,coalesced:p.coalesced,stale:p.stale,droppedNative:p.droppedNative,error:p.error,writePending:Boolean(p.active),latestPending:Boolean(p.pending),native:p.native?structuredClone(p.native):null};}
 nativeProgress(message,current,connection){
  const p=this.progress;if(!p.enabled)return;
  const state=this.getScope(),projected=projectNativeProgress(message);
  if(connection!==state.lobby?.connection||projected.connection!==connection||state.session&&state.session!==current||projected.epoch===null){p.droppedNative++;return;}
  p.native=projected;
 }
 fail(reason){if(this.failed||this.closed)return;this.failed=true;this.capture.error(String(reason).slice(0,512));this.finish('Direct handoff test: '+String(reason).slice(0,512));}
 digest(bytes){
  if(!ArrayBuffer.isView(bytes)||bytes.byteLength<1000)throw Error('Actual original BIC bytes unavailable');
  const view=new Uint8Array(bytes.buffer,bytes.byteOffset,bytes.byteLength),value=this.characterDigest(view);
  if(!value||typeof value.then==='function'||value.kind!=='bic'||value.bytes!==view.byteLength||value.sha256!==hash(view)||value.parsedOriginal!==true)throw Error('Synchronous original BIC digest/parse proof differs');
  return{kind:'bic',bytes:value.bytes,sha256:value.sha256,parsedOriginal:true,...(value.character!==undefined?{character:this.capture.bounded(value.character)}:{})};
 }
 current(current,connection){const state=this.getScope();return!this.closed&&!this.failed&&state.session===current&&state.lobby?.session===current&&state.lobby.connection===connection&&!current?.closed;}
 async boot(){
  if(this.booted||this.closed||this.failed)return;this.booted=true;const{session,lobby}=this.getScope();
  if(!lobby||session&&!session.closed||!lobby.snapshot().canJoin)throw Error('Initial direct admission is not available');
  this.send({kind:'browser-closed',connection:lobby.connection});
  await lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:5129,name:'NativeDirectHandoff',credentials:{password:''}}});
  if(lobby.error)throw Error('Initial owned direct admission failed: '+lobby.error);this.firstConnection=lobby.connection;
 }
 readCharacter(current,connection,key,bytes){
  if(!this.current(current,connection)||connection!==(this.firstConnection??connection)&&!this.recovery?.mayRead(connection)||key!=='installed:wizard.bic')throw Error('Direct route attempted stale or destination character selection');
  this.firstConnection??=connection;const digest=this.digest(bytes);this.capture.readCharacter({connection,key,sha256:digest.sha256,...(digest.character!==undefined?{character:digest.character}:{})});
  if(connection===this.firstConnection)this.#initialReadDigest??=this.capture.bounded(digest);else this.#retryReadDigest??=this.capture.bounded(digest);
 }
 semanticSummary(value){return value?{sha256:value.sha256,semanticSha256:value.character?.semanticSha256??null,complete:value.character?.complete??null}:null;}
 completeCharacterContinuity(){
  const capture=this.capture,final=capture.data.finalCharacter,copy=value=>value?capture.bounded(value):null;
  if(!this.recovery){
   const required=this.canonicalCharacterContinuity;
   if(!this.compareCharacterChain){capture.continuity({required,status:'not-configured',result:null});return;}
   try{
    const result=this.compareCharacterChain({downloadA:copy(this.rows[0]?.character),downloadB:copy(this.rows[1]?.character),finalExport:copy(final),initial:copy(this.#initialReadDigest),requireInitial:false});
    if(!result||typeof result.then==='function')throw Error('Canonical comparison must return synchronous evidence');
    capture.continuity({required,status:'compared',result});
   }catch(error){capture.continuity({required,status:'unavailable',reason:String(error.message).slice(0,512),result:null});}
   return;
  }
  const base={required:false,scope:'Fresh retry-installed read to final original A export only; abandoned source download is not this character chain.',abandonedSource:this.semanticSummary(this.rows[0]?.character),initial:this.semanticSummary(this.#initialReadDigest),retry:this.semanticSummary(this.#retryReadDigest),finalExport:this.semanticSummary(final)};
  if(!this.compareRetryCharacter){capture.retryContinuity({...base,status:'not-configured',result:null,initialToRetry:null});return;}
  try{
   if(!this.#retryReadDigest)throw Error('Fresh retry character read proof unavailable');
   const result=this.compareRetryCharacter(copy(this.#retryReadDigest),copy(final)),initialToRetry=this.#initialReadDigest?this.compareRetryCharacter(copy(this.#initialReadDigest),copy(this.#retryReadDigest)):null;
   if(!result||typeof result.then==='function'||initialToRetry&&typeof initialToRetry.then==='function')throw Error('Retry comparison must return synchronous evidence');
   capture.retryContinuity({...base,status:'compared',result,initialToRetry});
  }catch(error){capture.retryContinuity({...base,status:'unavailable',reason:String(error.message).slice(0,512),result:null,initialToRetry:null});}
 }
 preparing({current,connection,next,endpoint}){
  const destination=next.session??next;
  if(!this.current(current,connection)||this.jobs.has(destination)||destination.closed||destination.phase!=='new'||this.rows.length>=2)throw Error('Direct destination preparation scope differs');
  const expected=this.rows.length===0?5130:5129;
  if(endpoint?.host!=='127.0.0.1'||endpoint.port!==expected)throw Error('Direct destination endpoint/order differs');
  const row={from:connection,to:connection+1,endpoint:{host:endpoint.host,port:endpoint.port},character:null,transmittedSha256:null,originReleased:false,originHandoffReady:false,stages:[],committed:false,previous:new WeakRef(current)};
  this.rows.push(row);this.jobs.set(destination,row);
  if(this.recovery)this.recovery.prepare(row,destination);
  const original=destination.uploadCharacter,driver=this;
  if(typeof original!=='function')throw Error('Actual destination upload owner is unavailable');
  const wrapper=async function(...args){
   const willUpload=!this.closed&&this.resourceResult?.ready&&this.resolver&&this.character&&!this.characterUploaded;
   const digest=willUpload?driver.digest(this.character):null;
   const result=await original.apply(this,args);
   if(digest){if(row.transmittedSha256!==null)throw Error('Duplicate actual portal upload');row.transmittedSha256=digest.sha256;}
   return result;
  };
  destination.uploadCharacter=wrapper;this.uploads.push({ref:new WeakRef(destination),original,wrapper});
 }
 ready({previous,next}){
  const destination=next.session??next,row=this.jobs.get(destination);
  if(!row||row.previous.deref()!==previous||!previous.closed||previous.portalHandoffReady!==true||destination.closed)throw Error('Actual original portal-ready owner differs');
  row.character=this.digest(destination.character);row.originReleased=true;row.originHandoffReady=true;
 }
 install({previous,next,connection}){
  const destination=next.session??next,row=this.jobs.get(destination);
  if(!row||row.previous.deref()!==previous||row.to!==connection||!row.character||!row.originReleased)throw Error('Actual native destination install differs');
  if(this.scenario==='cancel')throw Error('Cancelled retirement unexpectedly installed a destination');
 }
 retire(context){return this.recovery?this.recovery.retire(context):Promise.resolve();}
 transferevent(event){
  const row=this.rows.find(r=>r.from===event.from&&r.to===event.to);
  if(!row||event.endpoint!==undefined&&(event.endpoint?.host!==row.endpoint.host||event.endpoint.port!==row.endpoint.port))throw Error('Actual direct adoption stage scope differs');
  if(event.stage==='connected')return;
  if(!['prepared','adopting','installed','failed'].includes(event.stage)||row.stages.includes(event.stage))throw Error('Actual direct adoption stage differs');
  row.stages.push(event.stage);if(event.stage==='failed'&&!this.recovery?.event(event))this.fail('Actual direct destination adoption failed');
 }
 commitTransfers(){
  if(this.recovery)return;
  for(const row of this.rows){
   if(row.committed||!row.stages.includes('installed'))continue;
   if(!row.character||row.transmittedSha256!==row.character.sha256)throw Error('Actual original portal character upload did not match');
   const{previous,committed,...dto}=row;this.capture.transfer(dto);row.committed=true;
  }
 }
 command(message,current,connection){
  try{
   if(message.kind==='direct-handoff-progress'){this.nativeProgress(message,current,connection);return true;}
   if(this.recovery?.input(message,current,connection))return true;
   if(message.kind==='browser-ready'){void this.boot().catch(e=>this.fail(e.message));return true;}
   if(message.kind==='chat'&&message.text===this.fixture.command){
    if(!this.current(current,connection)||message.generation!==current.areaGeneration||message.areaId!==current.world.areaId||this.capture.data.admissions.at(-1)?.connection!==connection||this.commands.includes(connection))throw Error('Real portal Chat.submit scope/order differs');
    this.commands.push(connection);return false;
   }
   if(message.kind==='direct-handoff-command'){
    if(!this.current(current,connection)||message.connection!==connection||message.generation!==current.areaGeneration||message.areaId!==current.world.areaId||message.text!==this.fixture.command||!this.commands.includes(connection)||this.commandAcks.includes(connection))throw Error('Native portal command acknowledgement differs');
    this.commandAcks.push(connection);return true;
   }
   if(message.kind==='direct-handoff-observed'){
    if(!this.current(current,connection)||message.connection!==connection||!this.probed.has(connection)||this.work)throw Error('Native direct observation has stale/duplicate scope');
    this.work=this.observed(current,connection,message.result).catch(e=>this.fail(e.message)).finally(()=>{this.work=null;});return true;
   }
   if(message.kind==='direct-handoff-control')throw Error('Recovery control is outside the current roundtrip driver');
  }catch(error){this.fail(error.message);return true;}
  return false;
 }
 async observed(current,connection,native){
  const state=this.getScope(),lobby=state.lobby,world=current.world,actor=world.registry.get(world.localObjectId),expectedPort=!this.recovery&&this.capture.data.admissions.length===1?5130:5129;
  if(native?.success!==true||native.scope?.connection!==connection||native.scope.generation!==current.areaGeneration||native.scope.areaId!==world.areaId||lobby.endpoint?.host!=='127.0.0.1'||lobby.endpoint.port!==expectedPort||current.phase!=='playing'||!current.characterConfirmed||actor?.objectType!==5||actor.replicationRemoved)throw Error('Actual direct world admission differs');
  const source={id:actor.id,objectType:5,nativeLifetime:this.rawCombat.identity(actor),knownLifetime:world.entityDisclosures.token(actor)};
  if(native.source?.id!==source.id||native.source.nativeLifetime!==source.nativeLifetime||native.source.knownLifetime!==source.knownLifetime)throw Error('Native direct controlled lifetime differs');
  const server=this.fixture.servers.find(s=>s.port===expectedPort),resolved=current.resourceResult?.resolved?.find(e=>e.kind==='nwm');
  if(this.catalogObservations.length<3){const text=(v,n)=>typeof v==='string'?v.slice(0,n):null,entries=Array.isArray(current.resourceResult?.resolved)?current.resourceResult.resolved:[];this.catalogObservations.push({connection,generation:current.areaGeneration,areaId:world.areaId,expectedModule:server.module,serverInfoModule:text(current.serverInfo?.moduleName,128),nativeModule:text(native.module,128),ready:current.resourceResult?.ready===true,resolvedCount:entries.length,resolved:entries.slice(0,8).map(e=>({kind:text(e.kind,32),name:text(e.name,128),resourceType:e.resource===null?'null':Array.isArray(e.resource)?'array':typeof e.resource,resource:text(e.resource,512)}))});}
  if(!resolved||typeof resolved.resource!=='string'||current.serverInfo?.moduleName!==server.module||native.module!==server.module)throw Error('Actual destination native module/catalog source differs');
  const archivePath=path.resolve(resolved.resource),ownedPrefix=path.resolve(this.fixture.directory)+path.sep;
  if(!archivePath.toLowerCase().startsWith(ownedPrefix.toLowerCase()))throw Error('Destination catalog is outside the owned fixture');
  const bytes=await fs.readFile(archivePath);if(bytes.length>16*1024*1024||hash(bytes)!==server.sha256||!this.current(current,connection))throw Error('Actual destination archive bytes/current owner differ');
  this.commitTransfers();
  this.capture.admission({connection,endpoint:{host:lobby.endpoint.host,port:lobby.endpoint.port},module:server.module,phase:current.phase,confirmed:current.characterConfirmed,areaId:world.areaId,generation:current.areaGeneration,source,catalog:{ready:state.catalogReady===true,instance:native.catalogInstance,module:server.module,archiveSha256:hash(bytes)},waypointRequests:current.loginWaypointRequests,waypointRemaining:current.loginWaypoint,position:structuredClone(actor.replicated?.position),native});
  if(this.capture.data.admissions.length<(this.recovery?2:3)){this.send({kind:'probe-direct-handoff',connection,mode:'chat',generation:current.areaGeneration,areaId:world.areaId});return;}
  if(this.commands.length!==(this.recovery?1:2)||this.commandAcks.length!==(this.recovery?1:2))throw Error('Actual portal command sequence is incomplete');
  if(this.recovery)this.recovery.complete();
  this.exportOwner={ref:new WeakRef(current),connection};await current.exportCharacter();
  if(!this.current(current,connection)||!this.capture.data.finalCharacter)throw Error('Actual final original export was not observed');
  const proof=this.capture.evaluate({beforeShutdown:true});if(!proof.success)throw Error('Direct roundtrip evidence incomplete: '+Object.entries(proof.checks).filter(([,ok])=>!ok).map(([key])=>key).join(','));
  this.finishSent=true;this.send({kind:'finish'});
 }
 exported(current,connection,bytes){
  if(!this.exportOwner||this.exportOwner.ref.deref()!==current||this.exportOwner.connection!==connection)return false;
  if(!this.current(current,connection))throw Error('Retired final direct export');const digest=this.digest(bytes);this.capture.finalExport({...digest,connection});this.completeCharacterContinuity();this.exportOwner=null;return true;
 }
 tick(){
  this.diagnostic();
  if(this.recovery&&!this.closed&&!this.failed){try{this.recovery.tick();}catch(error){this.fail(error.message);}}
  if(this.closed||this.failed||this.finishSent||!this.booted||this.work)return;
  try{
   if(Date.now()-this.started>360000)throw Error('Bounded direct roundtrip timed out');
   const{session,lobby,catalogReady,rawSerial}=this.getScope();if(!session||session.closed)return;
   if(session.phase==='character-rejected')throw Error('Original server rejected the unchanged installed Wizard');
   if(lobby.snapshot().canSelect&&catalogReady&&!this.selecting){
    if((this.capture.data.admissions.length||lobby.connection!==this.firstConnection)&&!this.recovery?.maySelect(lobby.connection))throw Error('Destination requested a fresh character selection');
    this.selecting=true;const connection=lobby.connection;
    this.work=(async()=>{await lobby.choose({connection,key:'installed:wizard.bic'});if(!this.current(session,connection))throw Error('Initial character preview scope retired');await lobby.play({connection,key:'installed:wizard.bic'});})().catch(e=>this.fail(e.message)).finally(()=>{this.work=null;this.selecting=false;});return;
   }
   if(session.phase==='playing'&&session.characterConfirmed&&catalogReady&&Number.isSafeInteger(rawSerial)&&rawSerial>=0&&!this.probed.has(lobby.connection)){
    this.probed.add(lobby.connection);this.send({kind:'probe-direct-handoff',connection:lobby.connection,mode:'observe',generation:session.areaGeneration,areaId:session.world.areaId});
   }
  }catch(error){this.fail(error.message);}
 }
 terminal(value){this.capture.terminal(value);}
 snapshot(){return{...this.capture.snapshot(),driver:{booted:this.booted,commands:this.commands.slice(),commandAcks:this.commandAcks.slice(),catalogObservations:structuredClone(this.catalogObservations),progress:this.progressSummary(),recovery:this.recovery?.snapshot()??null,finishSent:this.finishSent,failed:this.failed}};}
 evaluate(options){return this.capture.evaluate(options);}
 close(){this.closed=true;this.progress.pending=null;this.recovery?.close();for(const entry of this.uploads){const current=entry.ref.deref();if(current?.uploadCharacter===entry.wrapper)current.uploadCharacter=entry.original;}this.uploads=[];this.exportOwner=null;this.#initialReadDigest=null;this.#retryReadDigest=null;}
}
module.exports={NativeDirectHandoffHostCheck,projectNativeProgress,projectHostTransportProgress};
