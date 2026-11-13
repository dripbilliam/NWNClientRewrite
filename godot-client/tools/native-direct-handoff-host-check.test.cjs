const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {NativeDirectHandoffHostCheck}=require('./native-direct-handoff-host-check.cjs');
const digest=data=>({kind:'bic',bytes:data.byteLength,sha256:crypto.createHash('sha256').update(data).digest('hex'),parsedOriginal:true});
async function setup(){
 const directory=path.resolve(__dirname,'../.cache/native-direct-handoff/native-direct-handoff-roundtrip-v1'),fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));fixture.descriptorSha256=crypto.createHash('sha256').update(await fs.readFile(path.join(directory,'fixture.json'))).digest('hex');
 const sent=[],failures=[],context={session:null,catalogReady:false,rawSerial:-1,lobby:null},blob=Uint8Array.from({length:1200},(_,i)=>i&255);let driver;
 function session(server,connection){const actor={id:42,objectType:5,replicationRemoved:false,replicated:{position:[52,40,0]},nativeLife:connection,knownLife:connection+10};return{closed:false,phase:'new',characterConfirmed:false,resourceResult:{ready:true,resolved:[{kind:'nwm',resource:server.clientModule}]},resolver:{},serverInfo:{moduleName:server.module},areaGeneration:1,world:{areaId:90+connection,localObjectId:42,registry:{get:id=>id===42?actor:null},entityDisclosures:{token:a=>a.knownLife}},loginWaypointRequests:1,loginWaypoint:'',async uploadCharacter(){this.character=null;this.characterUploaded=true;},async exportCharacter(){driver.exported(this,connection,blob);return{kind:'mock-save'};}};}
 const first=session(fixture.servers[0],1);
 const lobby={connection:0,session:null,endpoint:null,error:'',selected:null,preview:null,snapshot(){return{canJoin:!this.session,canSelect:this.session?.phase==='character-selection'};},async join(message){assert.equal(message.details.host,'127.0.0.1');assert.equal(message.details.port,5129);this.connection=1;this.endpoint={host:'127.0.0.1',port:5129};this.session=first;context.session=first;first.phase='character-selection';},async choose(message){assert.equal(message.key,'installed:wizard.bic');driver.readCharacter(first,1,message.key,blob);this.selected=message.key;this.preview={sha256:digest(blob).sha256};},async play(message){assert.equal(message.key,this.selected);driver.readCharacter(first,1,message.key,blob);first.phase='playing';first.characterConfirmed=true;}};
 context.lobby=lobby;driver=new NativeDirectHandoffHostCheck({fixture,scenario:'roundtrip',send:v=>sent.push(structuredClone(v)),finish:v=>failures.push(v),getScope:()=>context,characterDigest:digest,rawCombat:{identity:a=>a.nativeLife}});
 const settle=async()=>{if(driver.work)await driver.work;};
 function native(current,connection,catalogInstance){const a=current.world.registry.get(42);return{success:true,failures:[],scope:{connection,generation:1,areaId:current.world.areaId},source:{id:42,objectType:5,nativeLifetime:a.nativeLife,knownLifetime:a.knownLife},worldReady:true,guiOwned:true,catalogInstance,worldInstance:String(200+connection),gameplayInstance:String(300+connection),module:current.serverInfo.moduleName,retiredAlive:0,position:[52,40,0]};}
 async function observe(current,connection,catalog){driver.tick();assert.equal(sent.at(-1).mode,'observe');assert.equal(driver.command({kind:'direct-handoff-observed',connection,result:native(current,connection,catalog)},current,connection),true);await settle();}
 function chat(current,connection){const base={connection,generation:1,areaId:current.world.areaId,text:fixture.command};assert.equal(driver.command({...base,kind:'chat'},current,connection),false);assert.equal(driver.command({...base,kind:'direct-handoff-command'},current,connection),true);}
 async function transfer(previous,from,label){
  const server=fixture.servers.find(s=>s.label===label),nextSession=session(server,from+1),next={session:nextSession},endpoint={host:'127.0.0.1',port:server.port};
  driver.preparing({current:previous,connection:from,next,endpoint});const event={from,to:from+1};driver.transferevent({...event,stage:'prepared'});previous.closed=true;previous.portalHandoffReady=true;nextSession.character=Uint8Array.from(blob);driver.ready({previous,next});driver.transferevent({...event,stage:'adopting'});
  lobby.connection=from+1;lobby.session=context.session=nextSession;lobby.endpoint=endpoint;driver.install({previous,next,connection:from+1});driver.transferevent({...event,stage:'installed'});driver.transferevent({...event,stage:'connected'});await nextSession.uploadCharacter();nextSession.phase='playing';nextSession.characterConfirmed=true;return nextSession;
 }
 return{driver,sent,failures,context,first,lobby,blob,settle,observe,chat,transfer};
}
test('mock direct driver uses real method boundaries in order and finishes only after export',async()=>{
 const t=await setup();await t.driver.boot();t.context.catalogReady=true;t.driver.tick();await t.settle();assert.equal(t.driver.capture.data.characterReads.length,2);assert.equal(t.first.phase,'playing');t.context.rawSerial=1;
 await t.observe(t.first,1,'-9223372036854774808');t.chat(t.first,1);const b=await t.transfer(t.first,1,'B');await t.observe(b,2,'-9223372036854774807');t.chat(b,2);const a=await t.transfer(b,2,'A');await t.observe(a,3,'-9223372036854774806');
 assert.deepEqual(t.failures,[]);assert.equal(t.sent.at(-1).kind,'finish');assert.equal(t.driver.evaluate({beforeShutdown:true}).success,true);assert.equal(t.driver.evaluate().success,false);
 t.driver.terminal({nativeExit:0,disconnected:true,workersRemaining:0,forcedStop:false});assert.equal(t.driver.evaluate().success,true);assert.equal(t.driver.exported(a,3,t.blob),false,'later unrelated save does not repeat final export');
 const wrapped=b.uploadCharacter;t.driver.close();assert.notEqual(b.uploadCharacter,wrapped,'owned test wrapper restored');
});
test('portal ready is synchronous and rejects original release before character availability',async()=>{
 const t=await setup();await t.driver.boot();const destination={closed:false,phase:'new',uploadCharacter:async()=>{}};const next={session:destination};t.driver.preparing({current:t.first,connection:1,next,endpoint:{host:'127.0.0.1',port:5130}});
 assert.throws(()=>t.driver.transferevent({stage:'prepared',from:1,to:2,endpoint:{host:'127.0.0.1',port:5129}}),/scope/);
 assert.throws(()=>t.driver.ready({previous:t.first,next}),/portal-ready/);t.first.closed=true;t.first.portalHandoffReady=true;assert.throws(()=>t.driver.ready({previous:t.first,next}),/BIC bytes/);
 destination.character=Uint8Array.from(t.blob);assert.equal(t.driver.ready({previous:t.first,next}),undefined);assert.equal(t.driver.rows[0].character.sha256,digest(t.blob).sha256);destination.character.fill(0);assert.equal(t.driver.rows[0].character.sha256,digest(t.blob).sha256);t.driver.close();
});
test('stale observations fail closed and cannot request another command/export',async()=>{
 const t=await setup();await t.driver.boot();t.context.catalogReady=true;t.driver.tick();await t.settle();t.context.rawSerial=1;t.driver.tick();
 assert.equal(t.driver.command({kind:'direct-handoff-observed',connection:0,result:{}},t.first,1),true);assert.equal(t.failures.length,1);assert.equal(t.driver.finishSent,false);assert.equal(t.driver.capture.data.admissions.length,0);t.driver.close();
});
test('recovery requires real callback owners and asynchronous digest providers are not silently accepted',async()=>{
 const t=await setup();assert.throws(()=>new NativeDirectHandoffHostCheck({fixture:t.driver.fixture,scenario:'cancel'}),/callback unavailable/);
 t.driver.characterDigest=async bytes=>digest(bytes);assert.throws(()=>t.driver.digest(t.blob),/Synchronous/);t.driver.close();
});
test('missing advertised NWM remains rejected with bounded actual catalog diagnostics',async()=>{
 const t=await setup();await t.driver.boot();t.context.catalogReady=true;t.driver.tick();await t.settle();t.context.rawSerial=1;t.first.resourceResult.resolved=[];await t.observe(t.first,1,'-9223372036854774808');
 assert.equal(t.failures.length,1);assert.match(t.failures[0],/native module\/catalog/);const evidence=t.driver.snapshot().driver.catalogObservations;assert.equal(evidence.length,1);assert.deepEqual(evidence[0],{connection:1,generation:1,areaId:91,expectedModule:'NativeHandA1',serverInfoModule:'NativeHandA1',nativeModule:'NativeHandA1',ready:true,resolvedCount:0,resolved:[]});evidence[0].expectedModule='mutated';assert.equal(t.driver.snapshot().driver.catalogObservations[0].expectedModule,'NativeHandA1');assert.equal(t.driver.capture.data.admissions.length,0);t.driver.close();
});
test('provider canonical character proof stays detached through read, handoff-ready and final export',async()=>{
 const t=await setup(),proof={version:1,source:'native-handoff-character-v1',complete:true,semanticSha256:'a'.repeat(64),canonical:{classes:[{id:10,level:1}]},coverage:['authored provider pass-through'],omitted:[]};
 t.driver.characterDigest=bytes=>({...digest(bytes),character:proof});await t.driver.boot();t.driver.readCharacter(t.first,1,'installed:wizard.bic',t.blob);
 const destination={closed:false,phase:'new',uploadCharacter:async()=>{}},next={session:destination};t.driver.preparing({current:t.first,connection:1,next,endpoint:{host:'127.0.0.1',port:5130}});t.first.closed=true;t.first.portalHandoffReady=true;destination.character=Uint8Array.from(t.blob);t.driver.ready({previous:t.first,next});
 const first=t.driver.capture.data.characterReads[0].character,transferred=t.driver.rows[0].character.character;proof.canonical.classes[0].level=99;assert.equal('canonical'in first,false);assert.equal(transferred.canonical.classes[0].level,1);
 let compared=false;t.driver.compareCharacterChain=({initial,downloadA,finalExport})=>{assert.equal(initial.character.canonical.classes[0].level,1);assert.equal(downloadA.character.canonical.classes[0].level,1);assert.equal(finalExport.character.canonical.classes[0].level,99);compared=true;return{success:true};};
 t.first.closed=false;t.driver.exportOwner={ref:new WeakRef(t.first),connection:1};t.driver.exported(t.first,1,t.blob);const exported=t.driver.capture.data.finalCharacter.character;proof.canonical.classes[0].level=100;assert.equal(compared,true);assert.equal('canonical'in exported,false);assert.equal(exported.semanticSha256,'a'.repeat(64));t.driver.close();
});
