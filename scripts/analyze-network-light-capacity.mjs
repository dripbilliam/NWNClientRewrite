// Analyze one sealed capture per process; never retain whole live reports in a
// long-running REPL. Only gameplay, presentation and public identity metadata.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {NativeMessageReader} from '../src/native_message.js';
import {openLocalModule} from './local-module.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),cap=path.join(root,'backups/animations'),version=process.argv[2];
if(!/^v\d+$/.test(version))throw Error('Expected sealed capture version');
const stem=process.argv[3]??'light-capacity';if(!['light-capacity','model-preparation'].includes(stem))throw Error('Invalid sealed capture family');
const file='local-network-'+stem+'-'+version+'.json',bytes=await fs.readFile(path.join(cap,file)),sha256=crypto.createHash('sha256').update(bytes).digest('hex'),report=JSON.parse(bytes);
if(report.states.at(-1)?.phase!=='closed')throw Error('Capture is not sealed');
const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),rules=await loadNetworkObjectRules(resolver),build={number:8193,revision:37,postfix:17},areas=[],playerEffects=[],playerCasts=[];
for(const [index,hex]of report.wireMessages.entries()){
 const data=Buffer.from(hex,'hex');if(data[0]!==80||!(data[1]===4||data[1]===5&&data[2]===3||data[1]===18&&data[2]===8))continue;
 const message=decodeServerGameMessage(data,{clientBuild:build,serverBuild:build,objectRules:rules}),at=report.wireTimes[index];
 if(message.kind==='client-area')areas.push({index,at,id:message.area.id,resRef:message.area.resRef,position:message.position});
 else if(message.sourceId===0xffffffff){if(message.kind==='object-visual')playerEffects.push({index,at,visualId:message.visualId,targetId:message.targetId});else if(message.kind==='spell-feedback')playerCasts.push({index,at,spellId:message.spellId,casting:message.casting});}
}
const requests=(report.gameplayRequests??[]).map(row=>{
 const packet=Buffer.from(row.packet,'hex'),result={at:row.at,major:packet[1],minor:packet[2]};
 if(result.major===6&&result.minor===1){const body=packet.subarray(3),reader=new NativeMessageReader(1);reader.setReadMessage(body,body.length,0,1);Object.assign(result,{areaId:reader.readObjectIdClient(),position:[reader.readFloat(1,32),reader.readFloat(1,32),reader.readFloat(1,32)],sequence:reader.readByte(),run:reader.readBool(),clientPath:reader.readBool(),fractional:reader.readByte(),targetId:reader.readObjectIdClient()});}
 return result;
});
const diagnostics=(await fs.readFile(report.runtimeLog,'utf8')).trim().split('\n').filter(Boolean).map(line=>JSON.parse(line));
const events=report.samples.flatMap(s=>s.projectiles?.events??[]),starts=[...new Map(events.filter(e=>e.kind==='procedural'&&e.sourceId===0xffffffff).map(e=>[e.id,e])).values()];
const summary={file,sha256,bytes:bytes.length,finalPhase:report.states.at(-1).phase,wireMessages:report.wireMessages.length,samples:report.samples.length,driverFailure:report.sampleFailure??null,failure:report.failure??null,areas,requests,playerEffects,playerCasts,
 playerLifetimes:starts.map(e=>({...e,loaded:events.some(v=>v.id===e.id&&v.kind==='loaded'),impacted:events.some(v=>v.id===e.id&&v.kind==='stage'&&v.stage===2),destroyed:events.some(v=>v.id===e.id&&v.kind==='destroy')})),
 lightProfiles:Object.values(report.samples.filter(s=>s.state?.phase==='playing'&&s.rendererLighting?.slots?.point&&s.scene?.areaId===s.state.world.areaId).reduce((all,s)=>{const key=s.scene.resRef,p=s.rendererLighting.slots.point,r=all[key]??={area:key,minActual:p.actual,maxActual:p.actual,minCapacity:p.capacity,maxCapacity:p.capacity};r.minActual=Math.min(r.minActual,p.actual);r.maxActual=Math.max(r.maxActual,p.actual);r.minCapacity=Math.min(r.minCapacity,p.capacity);r.maxCapacity=Math.max(r.maxCapacity,p.capacity);return all;},{})),
 maxProjectileFailures:Math.max(0,...report.samples.map(s=>s.projectiles?.failed??0)),
 lightChanges:diagnostics.filter(r=>r.code==='renderer.light-capacity-changed').map(r=>({at:r.timestamp,...r.context})),
 longDraws:diagnostics.filter(r=>r.code==='renderer.frame-stall'&&r.context.renderMs>1000).map(r=>({at:r.timestamp,...r.context})),
 entryPreparations:diagnostics.filter(r=>r.code==='renderer.area-shaders-prepared').map(r=>({at:r.timestamp,...r.context})),
 assetPreparations:diagnostics.filter(r=>r.code==='renderer.asset-shaders-prepared').map(r=>({at:r.timestamp,...r.context})),
 preparationFailures:diagnostics.filter(r=>/renderer\.asset-preparation.*failed/.test(r.code)).map(r=>({code:r.code,...r.context})),
 modelPreparation:report.samples.filter(s=>s.rendererLighting?.models).at(-1)?.rendererLighting.models??null,
 runtimeErrors:diagnostics.filter(r=>r.severity==='error').map(r=>({code:r.code,message:r.message})),
 bothPlayers:report.samples.find(s=>s.party?.members?.length===2)?.party.members.map(m=>({id:m.id,health:m.health})),
 limitations:'Bounded renderer event/sample rings can omit intermediate lifetimes. Native packets prove delivery, not every rendered frame. Connected original identity is not active shared combat.'};
await fs.writeFile(path.join(cap,'network-'+stem+'-observation-'+version+'.json'),JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify({version,finalPhase:summary.finalPhase,areas:areas.map(a=>a.resRef),playerEffects:playerEffects.length,playerStarts:starts.length,longDraws:summary.longDraws.length,lightChanges:summary.lightChanges.length,errors:summary.runtimeErrors.length,driverFailure:summary.driverFailure}));
