import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {addObjectAction} from '../src/object_actions.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',rows=[];
const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}})
 .initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];const actor=s.player;
for(const animation of [-1,1,2,99]){
 const start=runtimeDiagnostics.records.length,wait=addObjectAction(actor.objectActionState,30,65535,[]),effect=s.commands.EffectAppear([animation],{self:actor.id});
 assert.equal(s.commands.GetEffectType([effect,0]),0);assert.equal(s.commands.GetEffectType([effect,1]),91);
 await s.effects.apply(0,effect,actor.id);assert.ok(![...actor.objectActionState.list].includes(wait));
 const node=actor.objectActionState.list.head.action;assert.equal(node.actionId,52);assert.equal(node.nativeField9c,0);assert.equal(node.parameterData[0],animation===2?95:63);
 await s.combat.clearActions(actor);assert.equal(actor.objectActionState.list.head.action,node,'Appear group must veto cancellation');
 const animations=[];let elapsed=0;
 while(actor.objectActionState.list.count&&elapsed<3000){s.scheduler.advance(100);s.worldTimer.snapshot();await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));animations.push(actor.animationState);elapsed+=100;}
 assert.equal(elapsed,2100);assert.equal(actor.objectActionState.list.count,0);assert.equal(actor.nativeAnimationSpeedDC,1);assert.ok(animations.includes(animation===2?95:63));assert.ok([0,1].includes(actor.animationState));assert.ok(!actor.effects.some(e=>e.type===81));
 const errors=runtimeDiagnostics.records.slice(start).filter(d=>d.severity==='error');assert.deepEqual(errors,[]);rows.push({animation,elapsed,animations:[...new Set(animations)],effectType:81,diagnostics:runtimeDiagnostics.records.slice(start)});
}
actor.nativeFieldEc=0;const wait=addObjectAction(actor.objectActionState,30,65535,[]);await s.effects.apply(0,s.commands.EffectAppear([],{self:actor.id}),actor.id);assert.equal(actor.objectActionState.list.head.action,wait);actor.nativeFieldEc=1;await s.combat.clearActions(actor);
const report={rows,uncommandablePreservesQueue:true,limits:'Live installed character and local effect/action scheduler, cancellation and resource state. Startup/general AI disabled. No rendered animation or original-process/network acceptance claim.'};
await fs.writeFile('backups/animations/live-appear.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
