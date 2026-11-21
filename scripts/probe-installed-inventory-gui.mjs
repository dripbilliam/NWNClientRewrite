import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-inventory-gui-v1.json',report={messages:[],events:[]};
function markerProgram(api,variable){
 const id=api.findIndex(row=>row.name==='SetLocalInt');assert.ok(id>=0);const name=Buffer.from(variable,'ascii'),body=Buffer.alloc(6+4+name.length+6+5+2);let at=0;
 body[at++]=4;body[at++]=3;body.writeInt32BE(1,at);at+=4;body[at++]=4;body[at++]=5;body.writeUInt16BE(name.length,at);at+=2;body.set(name,at);at+=name.length;body[at++]=4;body[at++]=6;body.writeUInt32BE(0,at);at+=4;body[at++]=5;body[at++]=0;body.writeUInt16BE(id,at);at+=2;body[at++]=3;body[at++]=0x20;body[at++]=0;
 const bytes=Buffer.alloc(13+body.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);body.copy(bytes,13);return parseNcs(bytes,variable);
}
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,player=s.player,client=s.combat.broadcastProviders().client(player.id),gui=client.inventoryGUI,luo=gui.lastUpdate;
 const [first,second]=[...s.registry.objects.values()].filter(o=>o.objectType===9&&o.nativeHasInventory4f8===1&&o.nativeRepository.length===0&&o.areaId===s.currentArea.id);assert.ok(first&&second);
 for(const name of ['g_ui_open','g_ui_closed'])s.programs.set(name,Promise.resolve(markerProgram(s.vm.api,name)));
 for(const object of [first,second]){object.scripts.open='g_ui_open';object.scripts.closed='g_ui_closed';}
 const events=()=>s.scheduler.events.filter(e=>e.event.eventId===10&&[22,23].includes(e.event.payload?.type)).map(e=>({targetId:e.targetId,type:e.event.payload.type,callerId:e.event.callerId}));
 luo.listA0.push({probe:'old-update'});await s.lifecycle.openPlaceableInventory(first,player.id);assert.equal(first.nativeField508,1);assert.equal(first.nativeAnimationD8,75);assert.equal(gui.openInventory.id,first.id);assert.equal(gui.openInventory.field4,1);assert.equal(gui.field8,1);assert.equal(luo.listA0.length,0);report.events.push(...events());await s.scheduler.pump();
 assert.equal(first.locals.getInt('g_ui_open'),1);assert.equal(s.commands.GetLastOpenedBy([],{self:first.id}),player.id);await s.lifecycle.openPlaceableInventory(first,player.id);assert.equal(first.nativeField508,1);assert.deepEqual(events(),[]);
 for(const name of ['list90','listA0','listB0','listB8'])luo[name].push({probe:name});luo.items.fill(first.id);luo.itemFields.fill(7);
 await s.lifecycle.closePlaceableInventoryForPlayer(first,player.id,1);report.events.push(...events());await s.scheduler.pump();assert.equal(first.nativeField508,0);assert.equal(first.nativeAnimationD8,76);assert.equal(first.locals.getInt('g_ui_closed'),1);assert.equal(s.commands.GetLastClosedBy([],{self:first.id}),player.id);assert.equal(gui.field8,0);assert.equal(gui.openInventory.id,OBJECT_INVALID);
 assert.ok(luo.items.every(id=>id===OBJECT_INVALID));assert.ok(luo.itemFields.every(n=>n===-1));for(const name of ['list90','listA0','listB0'])assert.equal(luo[name].length,0);assert.equal(luo.listB8.length,1);
 await s.lifecycle.openPlaceableInventory(first,player.id);await s.scheduler.pump();await s.lifecycle.openPlaceableInventory(second,player.id);
 assert.equal(first.nativeField508,0);assert.equal(second.nativeField508,1);assert.equal(gui.openInventory.id,second.id);assert.equal(gui.openInventory.field4,0);assert.equal(gui.field8,1);assert.deepEqual(events().map(e=>e.type),[23,22]);report.events.push(...events());await s.scheduler.pump();assert.equal(second.locals.getInt('g_ui_open'),1);
 await s.lifecycle.closePlaceableInventoryForPlayer(second,player.id,1);report.events.push(...events());await s.scheduler.pump();assert.equal(second.nativeField508,0);assert.equal(second.locals.getInt('g_ui_closed'),1);assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(gui.field8,1,'Closing a container opened inside an existing inventory leaves that inventory open');
 await s.lifecycle.inventoryGUIProviders().setOpen(gui,0,1);await s.lifecycle.openPlaceableInventory(first,player.id);await s.scheduler.pump();assert.equal(gui.openInventory.field4,1);
 await s.commands.DestroyObject([first.id,0],{self:player.id});await s.scheduler.pump();assert.equal(s.registry.get(first.id),undefined);assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(gui.field8,0);assert.equal(first.nativeField508,0);assert.equal(luo.listB8.length,1);
 assert.equal(s.registry.get(player.id),player);report.playerId=player.id;report.firstId=first.id;report.secondId=second.id;report.retainedListB8=luo.listB8;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed canonical placeables/local client with actual inventory/LUO owners, observer first/last events, ordinary VM dispatch of in-memory NCS marker fixtures, repeated-open and container-switch behavior, retained-list reset and open-object destruction. Direct lifecycle entry, no rendered loot window, native UseObject action or player pickup claim. AI/startup disabled and all diagnostics retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,playerId:report.playerId,firstId:report.firstId,secondId:report.secondId,events:report.events,failure:report.failure}));if(report.failure)process.exitCode=1;
