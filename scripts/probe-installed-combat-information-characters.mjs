// All installed local character presets, active Prelude tables/equipment.
// Reuse immutable archive caches, never mutate the installed BICs/resources.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-combat-information-characters-v1.json',report={rows:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),names=(await fs.readdir(`${install}/data/lcv`)).filter(n=>/\.bic$/i.test(n)).sort();assert.ok(names.length);
 for(const name of names){
  const begin=runtimeDiagnostics.records.length,s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/${name}`)}),actor=s.player,cursor=s.registry.nextObjectId[0],equipment=[...actor.nativeEquipment.ids],old=actor.nativeCombatInformationD70;
  const calculationBegin=runtimeDiagnostics.records.length,loadDiagnostics=runtimeDiagnostics.records.slice(begin),cache=s.updateNativeCombatInformation(actor);assert.equal(old.disposed,true);assert.equal(cache,actor.nativeCombatInformationD70);assert.equal(cache.scalars[5],s.commands.GetSpellResistance([actor.id]));assert.equal(cache.scalars[6],s.commands.GetArcaneSpellFailure([actor.id]));assert.equal(cache.weaponIds[0],s.equipmentSlot(actor,16)?.id??0x7f000000);assert.equal(s.registry.get(actor.id),actor);assert.equal(s.registry.nextObjectId[0],cursor);assert.deepEqual([...actor.nativeEquipment.ids],equipment);
  const diagnostics=runtimeDiagnostics.records.slice(calculationBegin);assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
  report.rows.push({name,playerId:actor.id,scalars:[...cache.scalars],weaponIds:cache.weaponIds,attackNodes:cache.attackNodes.map(n=>[...n]),damageNodes:cache.damageNodes.map(n=>[...n]),diagnostics,loadDiagnostics,loadFailures:loadDiagnostics.filter(d=>d.severity==='error')});
 }
 report.cacheValidation='PASS';report.loadFailures=report.rows.flatMap(r=>r.loadFailures.map(d=>({name:r.name,code:d.code,message:d.message})));report.validation=report.loadFailures.length?'CACHE_PASS_LOAD_FAILURES_RETAINED':'PASS';report.limits='All installed local presets, active Prelude resolver, real canonical equipment/class/feat/rules providers and shared cache owner. Unchanged canonical player/equipment/cursor and cache resistance/failure/weapon getters. All load failures remain failures, recorded separately from cache calculation. Startup/general AI off; internal consistency checks do not prove clean import, independent native parity for every lower stat getter, all encounters/UI/wire/campaign.';if(report.loadFailures.length)process.exitCode=1;
}catch(error){report.validation='FAIL';report.error=error.stack;process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,cacheValidation:report.cacheValidation,characters:report.rows.length,loadFailures:report.loadFailures,error:report.error}));
