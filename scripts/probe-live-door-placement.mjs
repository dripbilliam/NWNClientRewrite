import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {addObjectAction} from '../src/object_actions.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {doorActionPoint} from '../src/door_action_point.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
const start=runtimeDiagnostics.records.length,doors=[...s.registry.objects.values()].filter(o=>o.objectType===10),rows=[];
assert.ok(doors.length>=3);
for(const door of doors){
 const area=s.registry.get(door.areaId);await area.nativeGeometry.objects.load();
 const from=door.nativePosition.map((v,i)=>Math.fround(v-door.nativeOrientation[i])),positions=[];
 for(const animation of [22,50,51])for(const side of [0,1]){
  const point=doorActionPoint(door,animation,side);assert.ok(point.every(Number.isFinite));positions.push({animation,side,point,walkable:await area.nativeGeometry.positionWalkable(point)});
 }
 const closed=await area.nativeGeometry.objects.nearestActionPoint(door,from,1),use={point:[0,0,0],range:0};
 assert.equal(await s.combat.useRange(s.player,door.id,use),1);assert.ok(use.point.every(Number.isFinite));
 rows.push({id:door.id,tag:door.tag,animation:door.nativeAnimationD8,state:door.animationState,visible:door.nativeDoorField498,positions,closed,use});
}
const jump=[];for(const door of doors.slice(0,3)){
 const area=s.registry.get(door.areaId),actor=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.id!==s.player.id&&o.areaId===area.id&&!s.isDead(o));assert.ok(actor);
 await s.combat.clearActions(actor);const before=[...actor.position];addObjectAction(actor.objectActionState,48,65,[{type:3,value:door.id},{type:1,value:1}]);
 const returned=await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));
 assert.equal(actor.areaId,area.id);assert.equal(actor.nativeField8f8,1);assert.ok(actor.position.every(Number.isFinite));
 assert.ok(Math.hypot(...actor.position.map((v,i)=>v-door.position[i]))<5);
 const queued=[...door.objectActionState.list].map(n=>({id:n.actionId,group:n.groupId,types:[...n.parameterTypes].slice(0,n.parameterCount),data:n.parameterData.slice(0,n.parameterCount)}));
 assert.ok(queued.some(n=>n.id===20&&n.data[0]===(door.id|0)),'Closed door receives its own open action before safe landing');
 jump.push({actorId:actor.id,doorId:door.id,before,after:[...actor.position],queued,returned});
}
const diagnostics=runtimeDiagnostics.records.slice(start),report={rows,jump,diagnostics,limits:'Installed Prelude DWK/surfacemat, actual safe placement and native queued jump to three doors. Startup/general AI isolated; this does not establish player cross-area handshake, radial door approach/automap/Budge or continuous campaign play.'};
await fs.writeFile('backups/animations/live-door-placement.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
const errors=diagnostics.filter(d=>d.severity==='error');assert.equal(errors.length,1);assert.equal(errors[0].context.operation,'native-placeable-pwk-missing-empty-mesh');assert.equal(errors[0].message,'Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.');
