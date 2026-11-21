// Installed script queries, active physical tables and canonical identity.
// Fresh local session only; no original game/project/install writes.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {corpseBagAppearance} from '../src/corpse_inventory.js';
import {intEntry} from '../src/combat_stats.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath,area]=process.argv.slice(2);
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
await s.enterArea(area,[72.8,0.00001,-104.8]);const begin=runtimeDiagnostics.records.length,observations=[];
const table=await s.items.table('bodybag');assert.ok(table);const valid=table.orderedRows.findIndex((_,n)=>intEntry(table,n,'Appearance').found);assert.ok(valid>=0);
const p={entry:async(name,row,col)=>intEntry(await s.items.table(name),row,col),appearance:o=>(o.creatureData??o.authored)[o.objectType===5?'Appearance_Type':'Appearance']};
for(const o of [s.player,[...s.registry.objects.values()].find(o=>o.objectType===9&&o.areaId===s.player.areaId)]){
  assert.ok(o);const before=s.commands.GetBodyBag([o.id]);
  await s.commands.SetBodyBag([o.id,valid]);assert.equal(s.commands.GetBodyBag([o.id]),valid&255);
  await s.commands.SetBodyBag([o.id,-1]);assert.equal(s.commands.GetBodyBag([o.id]),valid&255);
  observations.push({id:o.id,type:o.objectType,before,after:s.commands.GetBodyBag([o.id]),appearance:await corpseBagAppearance(o,p)});
}
const errors=[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))];assert.deepEqual(errors,[]);
console.log(JSON.stringify({validation:'PASS',observations,errors,limits:'Installed metadata/script query integration only; no live bag creation, transfer or cleanup claim.'}));
