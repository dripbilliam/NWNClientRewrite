'use strict';
// Strict test evidence only; never implements or repairs a production transfer.
const sha=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const integer=value=>Number.isSafeInteger(value)&&value>=0;
const endpoint=(value,port)=>value?.host==='127.0.0.1'&&value.port===port;
const bic=value=>value?.kind==='bic'&&Number.isSafeInteger(value.bytes)&&value.bytes>=1000&&sha(value.sha256);
const clone=value=>structuredClone(value);
function opaqueInt64Id(value){
 if(typeof value!=='string'||value.length>20||!/^\-?[1-9][0-9]*$/.test(value))return false;
 const id=BigInt(value);return id>=-9223372036854775808n&&id<=9223372036854775807n&&id.toString()===value;
}
function canonicalChainAccepted(report){
 const envelope=report?.characterContinuity,result=envelope?.result,transfers=report?.transfers??[],final=report?.finalCharacter;
 if(report?.semantic?.configured!==true||envelope?.status!=='compared'||envelope.required!==true||result?.version!==1||result.source!=='native-handoff-character-v1'||result.success!==true||!Array.isArray(result.comparisons)||result.comparisons.length!==2||transfers.length!==2)return false;
 const edges=[['downloadA','downloadB',transfers[0].character,transfers[1].character],['downloadB','finalExport',transfers[1].character,final]];
 return edges.every(([from,to,before,after],i)=>{const value=result.comparisons[i];return before?.character?.complete===true&&after?.character?.complete===true&&value.from===from&&value.to===to&&value.success===true&&value.complete===true&&value.differenceCount===0&&Array.isArray(value.differences)&&value.differences.length===0&&value.beforeSha256===before.character.semanticSha256&&sha(value.beforeSha256)&&value.afterSha256===after.character.semanticSha256&&sha(value.afterSha256)&&value.coverage?.before&&value.coverage?.after;});
}
function evaluate(report,{beforeShutdown=false,canonicalCharacterContinuity=report?.semantic?.configured===true}={}){
 const scenario=report?.scenario,recovery=scenario==='cancel'||scenario==='failure',roundtrip=scenario==='roundtrip';
 const admissions=report?.admissions??[],transfers=report?.transfers??[],fixture=report?.fixture,servers=fixture?.servers??[];
 const expected=roundtrip?[5129,5130,5129]:[5129,5129],connections=admissions.map(a=>a.connection);
 const checks={
  directRoute:report?.route==='native-session-host'&&report?.version===1,
  scenario:roundtrip||recovery,
  fixture:sha(fixture?.descriptorSha256)&&servers.length===2&&servers[0].label==='A'&&servers[0].port===5129&&servers[1].label==='B'&&servers[1].port===5130&&servers.every(s=>sha(s.sha256)),
  noCaptureFailure:report?.captureFailure===null,
  admissionCount:admissions.length===expected.length,
  endpointOrder:admissions.length===expected.length&&admissions.every((a,i)=>endpoint(a.endpoint,expected[i])),
  connectionOrder:connections.every((c,i)=>integer(c)&&c>0&&(!i||c>connections[i-1])),
  receivedAdmission:admissions.every(a=>a.phase==='playing'&&a.confirmed===true&&integer(a.areaId)&&integer(a.generation)&&a.source?.objectType===5&&integer(a.source.id)&&integer(a.source.nativeLifetime)&&a.source.nativeLifetime>0&&integer(a.source.knownLifetime)&&a.source.knownLifetime>0),
  actualNativeScope:admissions.every(a=>a.native?.success===true&&a.native.failures?.length===0&&a.native.scope?.connection===a.connection&&a.native.scope.generation===a.generation&&a.native.scope.areaId===a.areaId&&a.native.source?.id===a.source.id&&a.native.source.nativeLifetime===a.source.nativeLifetime&&a.native.source.knownLifetime===a.source.knownLifetime&&a.native.worldReady===true&&a.native.guiOwned===true&&opaqueInt64Id(a.native.worldInstance)&&opaqueInt64Id(a.native.gameplayInstance)),
  freshCatalog:admissions.every((a,i)=>{const s=servers.find(s=>s.port===a.endpoint?.port);return a.catalog?.ready===true&&opaqueInt64Id(a.catalog.instance)&&a.catalog.module===s?.module&&a.catalog.archiveSha256===s?.sha256&&a.native?.catalogInstance===a.catalog.instance&&(!i||a.catalog.instance!==admissions[i-1].catalog.instance);}),
  retiredNativeOwners:admissions.every(a=>a.native?.retiredAlive===0),
  initialCharacterOnly:Array.isArray(report?.characterReads)&&report.characterReads.length>=(roundtrip?1:2)&&report.characterReads.length<=(roundtrip?4:8)&&report.characterReads.every(r=>r.key==='installed:wizard.bic'&&(r.connection===connections[0]||recovery&&r.connection===connections.at(-1))&&sha(r.sha256))&&(!recovery||report.characterReads.some(r=>r.connection===connections.at(-1))),
  transferCount:transfers.length===(roundtrip?2:1),
  originalCharacterTransfer:transfers.every(t=>bic(t.character)&&(roundtrip?t.transmittedSha256===t.character.sha256:t.transmittedSha256===null)&&t.originReleased===true&&t.originHandoffReady===true),
  transferScopes:transfers.every((t,i)=>t.from===connections[i]&&integer(t.to)&&t.to>t.from&&endpoint(t.endpoint,i===0?5130:5129)&&(roundtrip?t.to===connections[i+1]:true)),
  transferStages:transfers.every(t=>Array.isArray(t.stages)&&t.stages.indexOf('prepared')>=0&&t.stages.indexOf('adopting')>t.stages.indexOf('prepared')&&(!roundtrip||t.stages.indexOf('installed')>t.stages.indexOf('adopting'))),
  arrivalWaypoint:admissions.every((a,i)=>!roundtrip||i===0||a.waypointRequests>=1&&a.waypointRemaining===''&&Array.isArray(a.position)&&a.position.length===3&&a.position.every(Number.isFinite)&&Math.hypot(a.position[0]-52,a.position[1]-40)<=1),
  finalOriginalExport:bic(report?.finalCharacter)&&report.finalCharacter.connection===connections.at(-1)&&report.finalCharacter.parsedOriginal===true,
  recovery:!recovery||report?.recovery?.success===true&&report.recovery.sourceWorldRetired===true&&report.recovery.destinationClosed===true&&report.recovery.privateCharacterWiped===true&&report.recovery.joinWhileClosing===false&&report.recovery.menuUsable===true&&report.recovery.retryPointer===true&&(scenario==='cancel'?report.recovery.cancelPointer===true&&report.recovery.destinationConnectCalls===0&&report.recovery.error==='':report.recovery.destinationConnectCalls===1&&report.recovery.destinationStopped===true&&typeof report.recovery.error==='string'&&report.recovery.error.length>0),
  actualRetireRecovery:!recovery||transfers.length===1&&transfers[0].retireBoundary?.stage==='retire'&&transfers[0].retireBoundary.nullLobby===true&&transfers[0].retireBoundary.sourceClosed===true&&transfers[0].retireBoundary.sourceHandoffReady===true&&transfers[0].retireBoundary.canJoin===false&&transfers[0].retireBoundary.connection===transfers[0].to&&report.recovery?.stage==='retire'&&report.recovery.identityDisposed===true&&report.recovery.peerClosed===true&&Number.isSafeInteger(report.recovery.destinationDisconnectCalls)&&report.recovery.destinationDisconnectCalls>=1&&report.recovery.destinationDisconnectCalls<=4&&report.recovery.backPointer===true&&report.recovery.retryTo===connections.at(-1)&&report.recovery.retryTo===report.recovery.retryFrom+1&&(scenario==='cancel'?report.recovery.abortObserved===true&&!transfers[0].stages.includes('installed')&&!transfers[0].stages.includes('failed'):transfers[0].stages.indexOf('installed')>transfers[0].stages.indexOf('adopting')&&transfers[0].stages.indexOf('failed')>transfers[0].stages.indexOf('installed')),
  noProtocolErrors:Array.isArray(report?.protocolErrors)&&report.protocolErrors.length===0,
  shutdown:beforeShutdown?true:report?.terminal?.nativeExit===0&&report.terminal.disconnected===true&&report.terminal.workersRemaining===0&&report.terminal.forcedStop===false,
 };
 if(roundtrip&&canonicalCharacterContinuity)checks.canonicalCharacterContinuity=canonicalChainAccepted(report);
 return{success:Object.values(checks).every(Boolean),checks,semanticCriteria:roundtrip?(canonicalCharacterContinuity?'required':'not-configured'):'retry-diagnostic-only',scope:'Current native-session-host direct-route evidence only; mock unit tests are not original-server, gameplay or pixel acceptance.'};
}
class DirectHandoffCapture{
 constructor(fixture,scenario,{canonicalCharacterContinuity=false}={}){
  if(!['roundtrip','cancel','failure'].includes(scenario))throw Error('Unknown scenario');
  if(typeof canonicalCharacterContinuity!=='boolean')throw Error('Canonical continuity configuration must be explicit boolean');this.canonicalCharacterContinuity=canonicalCharacterContinuity;
  this.data={version:1,route:'native-session-host',scenario,fixture:{descriptorSha256:fixture.descriptorSha256,servers:fixture.servers.map(({label,module,port,sha256})=>({label,module,port,sha256}))},admissions:[],transfers:[],characterReads:[],recovery:null,finalCharacter:null,semantic:{configured:canonicalCharacterContinuity,required:scenario==='roundtrip'&&canonicalCharacterContinuity},characterContinuity:null,retryCharacterContinuity:null,terminal:null,protocolErrors:[],captureFailure:null};
 }
 bounded(value){const bytes=JSON.stringify(value);if(bytes.length>32768||/"(?:privateKey|password|bicBytes|characterBytes)"\s*:/.test(bytes))throw Error('Direct handoff evidence exceeds or violates scalar boundary');return JSON.parse(bytes);}
 admission(value){if(this.data.admissions.length>=3)throw Error('Too many admissions');this.data.admissions.push(this.bounded(value));}
 transfer(value){if(this.data.transfers.length>=2)throw Error('Too many transfers');this.data.transfers.push(this.bounded(value));}
 readCharacter(value){if(this.data.characterReads.length>=8)throw Error('Unexpected fresh character read');this.data.characterReads.push(this.bounded(value));}
 recovery(value){if(this.data.recovery)throw Error('Duplicate recovery');this.data.recovery=this.bounded(value);}
 finalExport(value){if(this.data.finalCharacter)throw Error('Duplicate final export');this.data.finalCharacter=this.bounded(value);}
 continuity(value){if(this.data.characterContinuity)throw Error('Duplicate canonical chain result');this.data.characterContinuity=this.bounded(value);}
 retryContinuity(value){if(this.data.retryCharacterContinuity)throw Error('Duplicate retry continuity result');this.data.retryCharacterContinuity=this.bounded(value);}
 terminal(value){if(this.data.terminal)throw Error('Duplicate terminal');this.data.terminal=this.bounded(value);}
 error(value){if(this.data.protocolErrors.length>=16)throw Error('Too many errors');this.data.protocolErrors.push(String(value).slice(0,512));}
 snapshot(){return clone(this.data);}
 evaluate(options){return evaluate(this.data,{...options,canonicalCharacterContinuity:this.canonicalCharacterContinuity});}
}
module.exports={DirectHandoffCapture,evaluate,opaqueInt64Id,canonicalChainAccepted};
