import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {shouldLoadManifest,resolveServerResources,readResourceAdvertisement} from '../src/network_resources.js';
import {satisfiesNativeBuild} from '../src/network_build.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-resource-observations.json',import.meta.url)));

test('server resources decode native status/advertisement/TLK/NWM/HAK branches',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of native.cases){
  const c=row.case,decoded=decodeServerGameMessage(Buffer.from(row.packet,'hex'));
  if(c.serverMode!==2){assert.equal(decoded.kind,c.serverMode===0?'server-unavailable':'server-loading');continue;}
  assert.equal(decoded.kind,'server-resources');const expectedHaks=c.advertisement&&!c.forceLegacy?[]:c.haks;
  const ad=c.advertisement?{...c.advertisement,version:1,manifests:c.advertisement.manifests.map(m=>({...m,hash:m.hash||null}))}:null;
  assert.deepEqual(decoded.requirements,{reserved:'',advertisement:ad,customTlk:c.customTlk,nwmResourceName:c.nwmResourceName,haks:expectedHaks});
 }
 assert.equal(native.cases.length,9);
});

test('real native resource reply imports campaign resource name without a module-specific branch',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-transport-v9.json',import.meta.url)));
 const frame=Buffer.from(capture.transport.applicationFrames[0],'hex');
 assert.deepEqual(decodeServerGameMessage(frame.subarray(12)),{kind:'server-resources',major:1,minor:3,requirements:{reserved:'',advertisement:null,customTlk:'',nwmResourceName:'Prelude',haks:[]}});
 const wire=Buffer.from(native.cases[0].packet,'hex');for(let n=3;n<wire.length;n++)assert.throws(()=>decodeServerGameMessage(wire.subarray(0,n)),/native|message|stream/i);
});

test('manifest language selection and resource gate require actual providers before admission',async()=>{
 assert.equal(shouldLoadManifest({language:255}),true);assert.equal(shouldLoadManifest({language:2}),false);assert.equal(shouldLoadManifest({language:2},2),true);assert.equal(shouldLoadManifest({language:2},258),false);
 const requirements=decodeServerGameMessage(Buffer.from(native.cases.find(r=>r.case.advertisement&&r.case.forceLegacy&&r.case.haks.length).packet,'hex')).requirements;
 const calls=[],diagnostics=[];
 const blocked=await resolveServerResources(requirements,{onDiagnostic:d=>diagnostics.push(d)});assert.equal(blocked.ready,false);assert.ok(blocked.missing.length>=2);assert.equal(blocked.missing.length,diagnostics.length);
 const resolved=await resolveServerResources(requirements,{findManifest:async hash=>{calls.push(['manifest',hash]);return{hash};},findFile:async(kind,name,extension)=>{calls.push(['file',kind,name,extension]);return{name};}});
 assert.equal(resolved.ready,true);assert.equal(resolved.missing.length,0);assert.ok(calls.some(c=>c[0]==='file'&&c[1]==='hak'));
 // Language2's empty additional hash becomes a reported missing requirement
 // only when that manifest belongs to the native language selection.
 const invalid=await resolveServerResources(requirements,{language:2,findManifest:async()=>({}),findFile:async()=>({})});assert.equal(invalid.ready,false);assert.ok(invalid.missing.some(m=>m.kind==='nwsync'&&m.name===null));
});

test('native hash-prefix, talk-table availability and build predicates match original execution',()=>{
 for(const row of native.hashCases){
  const fields=[row.value,''];let byte=0;
  const decoded=readResourceAdvertisement({readBool:()=>1,readCExoString:()=>({bytes:Buffer.from(fields.shift(),'latin1')}),readByte:()=>byte++===0?1:0});
  assert.equal(decoded.hash,row.hash,JSON.stringify(row));
 }
 for(const row of native.languageCases)assert.equal(Number(shouldLoadManifest({language:row.language},row.present?row.nativeLanguage:null)),row.result);
 for(const row of native.buildCases)assert.equal(Number(satisfiesNativeBuild(row,{number:8193,revision:34,postfix:0},row)),row.result,JSON.stringify(row));
});
