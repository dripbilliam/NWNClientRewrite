import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const library=s.areas.get('m0q1a'),training=s.areas.get('m0q1d'),stock=[...s.registry.objects.values()],door=stock.find(o=>o.objectType===10&&o.areaId===library.id),creature=stock.find(o=>o.objectType===5&&o.id!==s.player.id&&o.areaId===library.id&&o.nativeAILevel7c===0),start=runtimeDiagnostics.records.length,steps=[],calls=[];
assert.ok(door);assert.ok(creature);const original=door.scripts.heartbeat,originalSet=s.aiMaster.setLevel.bind(s.aiMaster);
// A named heartbeat is the native door activation condition. Add only an
// in-memory script-name fixture if this installed room has no authored one;
// AI/scripts stay isolated and the original game files are never changed.
const scriptFixture=!original;if(scriptFixture)door.scripts.heartbeat='activation_fixture';
s.aiMaster.setLevel=(o,n)=>{calls.push({id:o.id,areaId:o.areaId,from:o.nativeAILevel7c,to:n});return originalSet(o,n);};
const snapshot=area=>({areaId:area.id,players:area.nativePlayerCount150,objects:[...area.nativeSpatial.view()].map(id=>{const o=s.registry.get(id);return{id,type:o.objectType,level:o.nativeAILevel7c,static:o.nativeStatic5a0,heartbeat:o.scripts?.heartbeat??''};})});
try{
 for(const [area,spawn]of [[library,[24,0,-14]],[training,[43.72918701171875,0,-106.02880859375]],[library,[24,0,-14]]]){
  const before=[snapshot(library),snapshot(training)],offset=calls.length;await s.enterArea(area.resRef,spawn);s.scheduler.events=[];
  assert.equal(area.nativePlayerCount150,1);assert.equal((area===library?training:library).nativePlayerCount150,0);
  assert.equal(s.registry.get(door.id),door);assert.equal(s.registry.get(creature.id),creature);assert.equal(creature.nativeAILevel7c,1,'Native final-player exit leaves creature level unchanged');
  assert.equal(door.nativeAILevel7c,area===library?1:0,'Heartbeat door promotes on first entry and demotes on last exit');
  steps.push({area:area.resRef,before,after:[snapshot(library),snapshot(training)],calls:calls.slice(offset)});
 }
}finally{door.scripts.heartbeat=original;s.aiMaster.setLevel=originalSet;}
const placeables=stock.filter(o=>o.objectType===9).map(o=>({id:o.id,authoredStatic:o.authored.Static??null,authoredUseable:o.authored.Useable??null,static:o.nativeStatic5a0,usable:o.nativeUseable264}));
assert.ok(placeables.length);assert.ok(placeables.every(o=>[0,1].includes(o.static)&&[0,1].includes(o.usable)));
const diagnostics=runtimeDiagnostics.records.slice(start),report={player:s.player.id,door:door.id,creature:creature.id,scriptFixture,steps,placeables,diagnostics,limits:'Installed area objects, loaded native static state and actual legacy local PC adapter first/last-player ownership. A door script name may be an in-memory fixture; no fixture script is executed. General AI/startup and native ClientArea/PackArea transport remain separate. No campaign-completion or full noncreature AI claim.'};
await fs.writeFile('backups/animations/live-first-client-activation.json',JSON.stringify(report,null,2));console.log(JSON.stringify({player:report.player,door:report.door,creature:report.creature,scriptFixture,transfers:steps.length,placeables:placeables.length,diagnostics,limits:report.limits},null,2));
assert.ok(diagnostics.filter(d=>d.severity==='error').every(d=>d.context.operation==='native-placeable-pwk-missing-empty-mesh'));
