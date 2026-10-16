import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-inventory-input-v1.json',report={messages:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,stats=actor.stats,client=s.combat.broadcastProviders().client(actor.id),primary=client.inventoryGUI,alternate=client.alternateInventoryGUI,p=s.lifecycle.inventoryInputProviders();
 const drain=async pending=>{await s.drainPlayerInputs();assert.equal(await pending,1);};
 // Explicit lower-owner fixture setup. This does not establish which native
 // login path initializes primary GUI ownership; its constructor uses INVALID.
 report.constructorOwners=[primary.ownerId,alternate.ownerId];await p.setCharacter(primary,actor.id);assert.equal(primary.ownerId,actor.id);assert.equal(actor.nativeWeightDirty96c,1);
 await drain(s.queuePlayerInventoryStatus(2,OBJECT_INVALID));assert.equal(primary.field8,2);assert.equal(alternate.field8,0);
 for(const gui of [primary,alternate])gui.lastUpdate.list90.push({fixture:1});
 await drain(s.queuePlayerInventoryPanel(1,1));assert.equal(primary.fieldC,1);assert.equal(primary.lastUpdate.list90.length,0);assert.equal(alternate.lastUpdate.list90.length,1);
 await drain(s.queuePlayerInventoryPanel(5,0));assert.equal(alternate.fieldC,5);assert.equal(alternate.lastUpdate.list90.length,0);
 primary.lastUpdate.list90.push({fixture:2});await drain(s.queuePlayerInventoryPanel(6,1));assert.equal(primary.fieldC,1);assert.equal(primary.lastUpdate.list90.length,1);
 const target=[...s.registry.objects.values()].find(o=>o.objectType===9&&o.nativeHasInventory4f8===1&&o.nativeRepository.length===0&&o.areaId===actor.areaId);assert.ok(target);target.scripts.open='';target.scripts.closed='';
 await s.lifecycle.openPlaceableInventory(target,actor.id);assert.equal(target.nativeField508,1);assert.equal(primary.openInventory.id,target.id);primary.lastUpdate.listB8.push({fixture:'retained'});
 await drain(s.queuePlayerInventoryStatus(0,actor.id));assert.equal(target.nativeField508,0);assert.equal(primary.field8,0);assert.equal(primary.openInventory.id,OBJECT_INVALID);assert.equal(primary.lastUpdate.list90.length,0);assert.equal(primary.lastUpdate.listB8.length,1);await s.scheduler.pump();assert.equal(s.commands.GetLastClosedBy([],{self:target.id}),actor.id);
 const absent=s.registry.getGameObject(0x123456).status;assert.notEqual(absent,0);await drain(s.queuePlayerInventoryStatus(1,0x123456));assert.equal(alternate.field8,1);assert.equal(alternate.ownerId,0x123456);assert.equal(primary.field8,0);
 await drain(s.queuePlayerInventoryStatus(0,0x123456));assert.equal(alternate.field8,0);assert.equal(alternate.ownerId,OBJECT_INVALID);
 assert.equal(s.registry.get(actor.id),actor);assert.equal(actor.stats,stats);report.playerId=actor.id;report.containerId=target.id;report.panels=[primary.fieldC,alternate.fieldC];report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed decoded inventory status/page input through normal pending-player-input drain, active repository and canonical GUI reset/observer/script callers. Explicit verified SetOwner primary fixture setup; original login initialization, rendered UI, packet codec, item containers and pickup remain separate gates. AI/startup disabled, all diagnostics retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,playerId:report.playerId,containerId:report.containerId,panels:report.panels,failure:report.failure}));if(report.failure)process.exitCode=1;
