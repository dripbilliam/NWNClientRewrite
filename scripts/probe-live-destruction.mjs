import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall';
const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}})
 .initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const actors=[...s.registry.objects.values()].filter(o=>o.objectType===5&&!o.isPC&&o.nativeInventoryImported&&o.stats.currentHP>0&&o.inventory.length&&o.nativeField948===0x7f000000).slice(0,2);assert.equal(actors.length,2);
const rows=[];
for(const [n,actor]of actors.entries()){
 s.scheduler.events=[];const start=runtimeDiagnostics.records.length,area=s.registry.get(actor.areaId),ids=[...actor.inventory],sources=[actor,...ids.map(id=>s.registry.get(id))].map(o=>o.sourceKey),before=[...s.registry.nextObjectId],actorId=actor.id;
 for(const id of ids)assert.ok(s.registry.get(id));
 if(n===0)await s.lifecycle.destroy(actor);else await s.combat.dispatchEvent(actor,{eventId:11,callerId:s.player.id,payload:null});
 assert.equal(s.registry.get(actorId),undefined);for(const id of ids)assert.equal(s.registry.get(id),undefined);for(const key of sources)assert.equal(s.sources.has(key),false);
 assert.equal(area.nativeSpatial.indexOf(actorId),-1);assert.ok(!area.objects.includes(actorId));assert.deepEqual([...s.registry.nextObjectId],before);
 assert.ok(!s.aiMaster.levels.some(list=>list.indexOf(actorId)>=0));assert.ok(![...s.tags.values()].some(values=>values.includes(actorId)));
 const errors=runtimeDiagnostics.records.slice(start).filter(r=>r.severity==='error');assert.deepEqual(errors,[]);
 rows.push({path:n===0?'direct-destructor':'native-event11',actorId,itemIds:ids,areaId:area.id,remainingEvents:s.scheduler.events.map(e=>({targetId:e.targetId,...e.event})),diagnostics:runtimeDiagnostics.records.slice(start)});
}
const report={rows,limits:'Actual installed creatures/items and canonical area, AI, tags, registry and event11 owners. Startup/general AI disabled; queued area scripts retained and inspected, not pumped. No death/bodybag, active barter/dialog or multiplayer acceptance claim.'};
await fs.writeFile('backups/animations/live-destruction.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
