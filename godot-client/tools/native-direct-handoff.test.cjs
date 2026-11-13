const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {DirectHandoffCapture,evaluate,opaqueInt64Id}=require('./native-direct-handoff-capture.cjs');
const {options}=require('./native-direct-handoff-mode.cjs');
const fixture={descriptorSha256:'d'.repeat(64),servers:[{label:'A',module:'NativeHandA1',port:5129,sha256:'a'.repeat(64)},{label:'B',module:'NativeHandB1',port:5130,sha256:'b'.repeat(64)}]};
function mock(scenario='roundtrip'){
 const c=new DirectHandoffCapture(fixture,scenario),round=scenario==='roundtrip',connections=round?[1,2,3]:[1,scenario==='cancel'?4:3];
 for(const[i,connection]of connections.entries()){
  const s=fixture.servers[round&&i===1?1:0],scope={connection,generation:1,areaId:91+i},source={id:42,objectType:5,nativeLifetime:10+i,knownLifetime:20+i};
  const catalogInstance=(-9223372036854774808n+BigInt(i)).toString();
  c.admission({connection,endpoint:{host:'127.0.0.1',port:s.port},module:s.module,phase:'playing',confirmed:true,areaId:scope.areaId,generation:1,source,catalog:{ready:true,instance:catalogInstance,module:s.module,archiveSha256:s.sha256},waypointRequests:1,waypointRemaining:'',position:[52,40,0],native:{success:true,failures:[],scope,source,worldReady:true,guiOwned:true,catalogInstance,worldInstance:String(200+i),gameplayInstance:String(300+i),retiredAlive:0}});
 }
 c.readCharacter({connection:1,key:'installed:wizard.bic',sha256:'e'.repeat(64)});
 if(!round)c.readCharacter({connection:connections.at(-1),key:'installed:wizard.bic',sha256:'e'.repeat(64)});
 for(let i=0;i<(round?2:1);i++)c.transfer({from:i+1,to:i+2,endpoint:{host:'127.0.0.1',port:i===0?5130:5129},character:{kind:'bic',bytes:40275,sha256:'c'.repeat(64)},transmittedSha256:round?'c'.repeat(64):null,originReleased:true,originHandoffReady:true,stages:round?['prepared','adopting','installed']:scenario==='cancel'?['prepared','adopting']:['prepared','adopting','installed','failed'],...(!round?{retireBoundary:{stage:'retire',nullLobby:true,sourceClosed:true,sourceHandoffReady:true,canJoin:false,connection:2}}:{})});
 if(!round)c.recovery({success:true,stage:'retire',sourceWorldRetired:true,destinationClosed:true,privateCharacterWiped:true,identityDisposed:true,peerClosed:true,joinWhileClosing:false,menuUsable:true,backPointer:true,retryPointer:true,cancelPointer:scenario==='cancel',abortObserved:scenario==='cancel',destinationConnectCalls:scenario==='cancel'?0:1,destinationDisconnectCalls:1,destinationStopped:scenario==='failure',retryFrom:connections.at(-1)-1,retryTo:connections.at(-1),error:scenario==='cancel'?'':'Original destination unavailable'});
 c.finalExport({kind:'bic',bytes:40275,sha256:'f'.repeat(64),connection:connections.at(-1),parsedOriginal:true});c.terminal({nativeExit:0,disconnected:true,workersRemaining:0,forcedStop:false});return c;
}
test('exclusive direct opt-in cannot authorize legacy/graphical/public routes',()=>{
 const args=['--direct-handoff-check','--native-headless','--native-runtime=editor','--run=native-direct-handoff-unit-v1','--direct-handoff-directory=C:/owned','--direct-handoff-scenario=roundtrip','--private-login-pipe=private-mock'];assert.equal(options(args).enabled,true);
 for(const flag of ['--public-servers','--portal-handoff-smoke','--script-floating-check','--native-screen=0','--action-check'])assert.throws(()=>options([...args,flag]));
 for(const prefix of ['--native-headless','--private-login-pipe=','--direct-handoff-directory='])assert.throws(()=>options(args.filter(a=>!a.startsWith(prefix))));
 assert.throws(()=>options([...args,'--direct-handoff-scenario=cancel']));assert.throws(()=>options(args.map(a=>a==='--native-runtime=editor'?'--native-runtime=release':a)));
 assert.throws(()=>options(['--direct-handoff-scenario=roundtrip']));
});
test('debugger is explicit and cannot relax the exclusive headless direct route',async()=>{
 const args=['--direct-handoff-check','--native-headless','--native-runtime=editor','--run=native-direct-handoff-unit-v1','--direct-handoff-directory=C:/owned','--direct-handoff-scenario=roundtrip','--private-login-pipe=private-mock'];
 assert.equal(options([...args,'--native-debugger']).enabled,true);
 for(const flag of ['--public-servers','--native-screen=0','--script-floating-visual'])assert.throws(()=>options([...args,'--native-debugger',flag]));
 assert.throws(()=>options([...args.filter(a=>a!=='--native-headless'),'--native-debugger']));assert.throws(()=>options([...args,'--native-debugger','--native-debugger']));
 const fs=require('node:fs/promises'),wrapper=await fs.readFile(path.join(__dirname,'test-native-direct-handoff.ps1'),'utf8');assert.ok(wrapper.includes('[switch]$Debugger'));assert.ok(wrapper.includes("if($Debugger){$directClientStart.ArgumentList.Add('-Debugger')}"));assert.equal(wrapper.split("ArgumentList.Add('-Debugger')").length-1,1);
});
test('strict mock roundtrip requires current direct catalogs, character and scope evidence',()=>{
 const c=mock();assert.equal(c.evaluate().success,true);assert.equal(Object.keys(c.evaluate().checks).length,22);
 for(const change of [r=>r.route='local-host',r=>r.admissions[1].catalog.archiveSha256=r.admissions[0].catalog.archiveSha256,r=>r.admissions[1].catalog.instance=r.admissions[0].catalog.instance,r=>r.admissions[1].native.source.knownLifetime++,r=>r.transfers[0].originReleased=false,r=>r.transfers[0].transmittedSha256='0'.repeat(64),r=>r.admissions[2].position=[60,40,0],r=>r.admissions[1].native.retiredAlive=1,r=>r.characterReads.push({...r.characterReads[0],connection:2}),r=>r.terminal.nativeExit=1]){const r=c.snapshot();change(r);assert.equal(evaluate(r).success,false);}
});
test('engine instance IDs require exact nonzero canonical signed64 strings',()=>{
 for(const value of ['1','-1','9223372036854775807','-9223372036854775808','-9223371583802833123'])assert.equal(opaqueInt64Id(value),true,value);
 for(const value of [1,Number.MAX_SAFE_INTEGER,Number('-9223371583802833123'),0n,null,'0','-0','01','-01','+1',' 1','1\n','1.0','1e3','9223372036854775808','-9223372036854775809','NaN',''])assert.equal(opaqueInt64Id(value),false,String(value));
 const exact=mock().snapshot();assert.equal(evaluate(JSON.parse(JSON.stringify(exact))).success,true);assert.notEqual(exact.admissions[0].catalog.instance,exact.admissions[1].catalog.instance);
 for(const value of [101,Number('-9223371583802833123'),'9223372036854775808','0','01']){const r=mock().snapshot();r.admissions[1].catalog.instance=value;r.admissions[1].native.catalogInstance=value;assert.equal(evaluate(r).success,false,String(value));}
 for(const key of ['worldInstance','gameplayInstance']){const r=mock().snapshot();r.admissions[1].native[key]=Number.MAX_SAFE_INTEGER;assert.equal(evaluate(r).success,false,key);}
 const reused=mock().snapshot();reused.admissions[1].catalog.instance=reused.admissions[0].catalog.instance;reused.admissions[1].native.catalogInstance=reused.admissions[0].catalog.instance;assert.equal(evaluate(reused).success,false);
});
test('mock recovery keeps cancellation distinct from an actually attempted unavailable destination',()=>{
 for(const scenario of ['cancel','failure']){const c=mock(scenario);assert.equal(c.evaluate().success,true);const r=c.snapshot();r.recovery.destinationConnectCalls=scenario==='cancel'?1:0;assert.equal(evaluate(r).success,false);}
 const r=mock('failure').snapshot();r.recovery.privateCharacterWiped=false;assert.equal(evaluate(r).success,false);
 for(const change of [r=>r.transfers[0].retireBoundary.nullLobby=false,r=>r.recovery.identityDisposed=false,r=>r.recovery.backPointer=false,r=>r.recovery.abortObserved=false,r=>r.transfers[0].stages.push('installed'),r=>r.transfers[0].transmittedSha256=r.transfers[0].character.sha256]){const r=mock('cancel').snapshot();change(r);assert.equal(evaluate(r).success,false);}
});
test('capture is detached, bounded and never accepts private key/BIC payload objects',()=>{
 const c=mock(),r=c.snapshot();r.admissions[0].source.id=999;assert.equal(c.snapshot().admissions[0].source.id,42);
 assert.throws(()=>c.bounded({password:'not-a-real-password'}));assert.throws(()=>c.bounded({bicBytes:[1,2,3]}));assert.throws(()=>c.bounded({text:'x'.repeat(32769)}));
 assert.throws(()=>c.terminal({nativeExit:0}));
});
test('actual authored baseline builds distinct original-API A/B modules without touching AREs',async()=>{
 const fs=require('node:fs/promises'),{pathToFileURL}=require('node:url'),root=path.resolve(__dirname,'../..');
 const {buildModules,owned}=await import(pathToFileURL(path.join(__dirname,'native-direct-handoff-fixture.mjs')));
 const {parseErf,decodeResourceText}=await import(pathToFileURL(path.join(root,'src/resource_archive.js'))),{parseGff,getGffFieldTypes}=await import(pathToFileURL(path.join(root,'src/gff.js'))),{parseScriptApi}=await import(pathToFileURL(path.join(root,'src/ncs.js'))),{openServerResourceContext}=await import(pathToFileURL(path.join(root,'electron/server_resource_context.mjs')));
 const {initializeModuleExperience}=await import(pathToFileURL(path.join(root,'src/combat_experience.js'))),{NativeMessageWriter}=await import(pathToFileURL(path.join(root,'src/native_message.js'))),{decodeServerGameMessage}=await import(pathToFileURL(path.join(root,'src/network_game_messages.js'))),{resolveServerResources}=await import(pathToFileURL(path.join(root,'src/network_resources.js')));
 const source=await fs.readFile(path.join(root,'runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod')),resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),modules=buildModules(source,api),baseline=parseErf(source).entries;
 assert.equal(modules.length,2);assert.notEqual(modules[0].sha256,modules[1].sha256);
 for(const m of modules){const e=parseErf(m.bytes).entries;assert.equal(m.preservedResources,11);assert.deepEqual(e.get('dense_a:2012'),baseline.get('dense_a:2012'));assert.deepEqual(e.get('dense_b:2012'),baseline.get('dense_b:2012'));const ifo=parseGff(e.get('module:2014')).root;assert.equal(ifo.Mod_Entry_Area,m.entry);assert.equal(ifo.Mod_Tag,m.module);assert.equal(ifo.Mod_IsNWMFile,1);assert.equal(getGffFieldTypes(ifo).Mod_IsNWMFile,0);assert.equal(ifo.Mod_NWMResName,m.module);assert.equal(getGffFieldTypes(ifo).Mod_NWMResName,10);assert.ok(Buffer.from(e.get('godot_chat:2010')).includes(Buffer.from('127.0.0.1:'+m.destination)));const wp=parseGff(e.get(m.entry+':2023')).root.WaypointList.at(-1);assert.equal(wp.Tag,m.waypoint);assert.equal(wp.XPosition,52);assert.equal(wp.YPosition,40);
  // Authored packet through the real codec/resolver, not native-writer evidence.
  const state={};initializeModuleExperience(state,ifo);assert.equal(state.nativeNWMName450,m.module);const absent={};initializeModuleExperience(absent,{...ifo,Mod_IsNWMFile:0});assert.equal(absent.nativeNWMName450,'');
  const writer=new NativeMessageWriter(1);writer.create(128,0xffffffff,1);const string=s=>{const bytes=Buffer.from(s,'ascii');writer.writeCExoString({bytes,length:bytes.length});};string('');writer.writeBool(0);string('');string(state.nativeNWMName450);writer.writeByte(0);writer.setPrefix(Uint8Array.of(80,1,3));const received=decodeServerGameMessage(Uint8Array.from(writer.getWriteMessage().data));assert.equal(received.requirements.nwmResourceName,m.module);const calls=[];const result=await resolveServerResources(received.requirements,{findFile:async(kind,name,extension)=>{calls.push({kind,name,extension});return m.module+'.nwm';}});assert.equal(result.ready,true);assert.deepEqual(calls,[{kind:'nwm',name:m.module,extension:'nwm'}]);assert.equal(result.resolved[0].kind,'nwm');
 }
 assert.throws(()=>owned(path.join(root,'runtime-logs/unsafe')));assert.throws(()=>buildModules(Buffer.from('not-a-module'),api));
});
