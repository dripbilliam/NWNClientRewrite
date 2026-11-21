import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {actionParameter} from '../src/object_actions.js';
import {gffRecord,writeGff} from '../src/gff_writer.js';
import {parseGff} from '../src/gff.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-vm-engine-values-v1.json',report={};
async function invoke(s,name,args){const id=s.vm.api.findIndex(r=>r.name===name),spec=s.vm.api[id],frame={stack:[]};assert.ok(id>=0,name);for(let i=args.length-1;i>=0;i--)s.vm.push(frame,spec.args[i].type,args[i]);const bytes=Buffer.alloc(20);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(20,9);bytes.set([5,0,id>>>8,id&255,args.length,0x20,0],13);return s.vm.run(parseNcs(bytes,'engine_value_'+name),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});}
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const area=[...s.registry.objects.values()].find(o=>o.objectType===4);assert.ok(area);
 const values=[];for(const [name,args]of [['EventUserDefined',[321]],['Location',[area.id,[1.25,2.5,3.75],45]],['TalentSpell',[0]],['ItemPropertyEnhancementBonus',[1]],['EffectHaste',[]]])values.push((await invoke(s,name,args)).stack[0]);
 const [event,location,talent,property,haste]=values.map(v=>v.value);assert.equal(event.type,11);assert.equal(event.integers[0],321);const ids=[...s.registry.objects.keys()],cursor=[...s.registry.nextObjectId],next=s.effects.nextId;
 const code=[],u16=v=>code.push(v>>>8&255,v&255),i32=v=>code.push(v>>>24&255,v>>>16&255,v>>>8&255,v&255),action=(name,argc)=>{const id=s.vm.api.findIndex(r=>r.name===name);assert.ok(id>=0);code.push(5,0);u16(id);code.push(argc);};
 const store=code.length;code.push(0x2c,0);i32(0);i32(20);action('ActionDoCommand',1);const jump=code.length;code.push(0x1d,0);i32(0);const body=code.length;
 const seconds=Buffer.alloc(4);seconds.writeFloatBE(60);code.push(4,4,...seconds);code.push(4,6);i32(0);code.push(3,1);i32(-12);u16(4);code.push(4,3);i32(1);action('ApplyEffectToObject',4);code.push(0x1b,0);i32(-20);code.push(0x20,0);const exit=code.length;code.push(0x1b,0);i32(-28);code.push(0x20,0);code[store+1]=body-store;
 const bytes=Buffer.alloc(13+code.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(code,13);bytes.writeInt32BE(exit-jump,13+jump+2);
 await s.vm.run(parseNcs(bytes,'engine_value_capture'),s.player.id,{situation:{pc:13,bp:0,stack:[{type:3,value:91},{type:3,value:92},...values]}});
 const original=actionParameter(s.player.objectActionState.list.head.action,0);assert.equal(original.nativeStackSize,7);assert.equal(original.stack.length,5);assert.equal(original.nativeStackCapacity,21);
 const full=await s.objectState.save(s.player),data=parseGff(writeGff('UTC ',gffRecord({ActionList:full.fields.ActionList})),'UTC ').root;await s.combat.clearActions(s.player);assert.equal(original.disposed,true);await s.objectState.load(s.player,data);
 const restored=actionParameter(s.player.objectActionState.list.head.action,0),v=restored.stack.map(c=>c.value);assert.equal(s.effects.nextId,next+2n);assert.equal(v[0].type,11);assert.deepEqual(v[0].integers,[321]);assert.deepEqual(v[1].position,location.position);assert.deepEqual(v[1].nativeOrientation,location.nativeOrientation);assert.equal(v[1].areaId,location.areaId);assert.deepEqual(v[2],talent);assert.equal(v[3].id,property.id);assert.equal(v[4].id,haste.id);assert.deepEqual(v[3].integers,property.integers);
 const again=parseGff(writeGff('UTC ',gffRecord({ActionList:(await s.objectState.save(s.player)).fields.ActionList})),'UTC ').root;assert.deepEqual(again,data);
 report.restored={types:restored.stack.map(c=>c.type),sourceStackSize:restored.nativeStackSize,cells:restored.stack.length,capacity:restored.nativeStackCapacity,effectId:v[4].id,itemPropertyId:v[3].id,nativeConstructorAllocations:2,fullSavedIdsPreserved:true,eventNumber:v[0].integers[0],locationArea:v[1].areaId,resaveEqual:true};
 await s.combat.runActions(s.player,1,500,0n,{microseconds:()=>0n});const applied=s.player.effects.find(e=>e.id===haste.id);assert.ok(applied);assert.equal(applied.type,haste.type);assert.equal(applied.durationType,1);assert.equal(restored.disposed,true);assert.equal(s.player.objectActionState.list.count,0);
 await s.effects.updateObject(s.player,{day:applied.expiryDay,time:applied.expiryTime+1});assert.ok(!s.player.effects.some(e=>e.id===haste.id));assert.deepEqual([...s.registry.objects.keys()],ids);assert.deepEqual(s.registry.nextObjectId,cursor);
 report.execution={restoredEffectAppliedByNcs:true,temporaryExpiryAndRemoval:true,disposed:true,objectIdsUnchanged:true};report.ok=true;
}catch(error){report.ok=false;report.error=error.stack;process.exitCode=1;}
report.diagnostics=[...runtimeDiagnostics.records];await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({ok:report.ok,restored:report.restored,execution:report.execution,error:report.error}));
