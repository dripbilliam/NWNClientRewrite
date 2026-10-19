import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {readNativeGff} from '../src/native_gff_fields.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-henchmen-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'henchmen_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
 const master=s.player,target=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==master&&o.nativeField89c===0&&o.associateType===0&&o.effects.length===0&&s.factionManager.get(o.originalFactionId));assert.ok(target);
 const authored=readNativeGff(s.ifo,'Mod_MaxHenchmen',5,1).value;assert.equal(await invoke('GetMaxHenchmen',[]),authored);report.checks.push({check:'typed-module-cap',value:authored});
 await invoke('SetMaxHenchmen',[0]);assert.equal(await invoke('GetMaxHenchmen',[]),1);
 await invoke('AddHenchman',[master.id,target.id]);assert.equal(target.masterId,master.id);assert.equal(target.associateType,1);assert.equal(await invoke('GetHenchman',[master.id,1]),target.id);assert.equal(target.factionId,master.factionId);report.checks.push({check:'add-and-query',owner:master.id,target:target.id});
 const list=master.associateIds.slice();await invoke('AddHenchman',[master.id,target.id]);assert.deepEqual(master.associateIds,list);assert.equal(target.associateType,1);report.checks.push({check:'existing-target-cap-gate',count:list.length});
 await invoke('RemoveHenchman',[target.id,target.id]);assert.equal(target.associateType,1);
 await invoke('RemoveHenchman',[master.id]);assert.equal(target.associateType,1);
 await invoke('RemoveHenchman',[master.id,target.id]);assert.equal(target.masterId,OBJECT_INVALID);assert.equal(target.associateType,0);assert.equal(await invoke('GetHenchman',[master.id,1]),OBJECT_INVALID);assert.equal(target.factionId,target.originalFactionId);report.checks.push({check:'remove-and-restore',faction:target.factionId});
 await invoke('SetMaxHenchmen',[101]);assert.equal(await invoke('GetMaxHenchmen',[]),100);await invoke('SetMaxHenchmen',[-1]);assert.equal(await invoke('GetMaxHenchmen',[]),1);
 await invoke('AddHenchman',[master.id,master.id]);assert.equal(master.associateType,0);assert.equal(master.masterId,OBJECT_INVALID);assert.equal(s.registry.nextObjectId[0],cursor);
 report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed Prelude typed module cap, NPC import and actual NCS add/query/re-add/foreign/omitted/remove/clamp dispatch; canonical IDs and faction restoration. No combat-invisibility effects on selected NPC. Separate original-code oracle captures guards/lower ownership; not full henchman AI, remote client DM/possession, saves or campaign completion.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED HENCHMAN OWNERSHIP/NCS PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
