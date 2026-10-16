import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {placeableUsePoint} from '../src/interaction_range.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-world-placement-v1.json',report={placeables:[],door:null,displacement:[],mapUpdates:[]},f=Math.fround,native=v=>[f(v[0]),f(-v[2]),f(v[1])];
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const start=runtimeDiagnostics.records.length,actor=s.player,identity=actor.id,original=[...actor.position],stats=actor.stats,area=s.currentArea;
 const update=s.automap.update.bind(s.automap);s.automap.update=async(o,id)=>{report.mapUpdates.push({actorId:o.id,id});return update(o,id);};
 for(const p of s.registry.objects.values())if(p.objectType===9){
  const out={point:[0,0,0],range:0};assert.equal(await s.combat.useRange(actor,p.id,out),1);assert.deepEqual(out.point,placeableUsePoint(actor,p));
  report.placeables.push({id:p.id,appearance:p.nativeMessageFields[0x32c],points:structuredClone(p.nativePlaceableActionPoints550),use:out,slot:p.nativeCollisionSlot});
 }
 assert.ok(report.placeables.some(p=>p.points.some(point=>point.some(v=>v!==0))),'Installed PWKs must exercise actual authored points');
 const placement=s.encounters.placementProviders(),safe=()=>placement.safePoint(area,native(actor.position),actor.nativePathInfo,0),doors=area.objects.map(id=>s.registry.get(id)).filter(o=>o?.objectType===10&&o.nativeDoorField498!==0&&o.nativeDoorSurface?.states[0].vertices.length);
 let doorSuccess=false;
 for(const door of doors){
  const old=door.animationState;await s.setNativeDoorOpenState(door,1);s.setPosition(actor,[...door.position],0);const before=[...actor.position];
  await s.setNativeDoorOpenState(door,0);const after=[...actor.position],result=await safe();report.displacement.push({kind:'door-close',doorId:door.id,before,after,safe:result,bounds:door.nativeDoorBounds4c8});
  await s.setNativeDoorOpenState(door,old);if(result===1&&after.some((v,i)=>v!==before[i])){report.door={id:door.id,tag:door.tag,before,after,safe:result};doorSuccess=true;break;}
 }
 assert.ok(doorSuccess,'A real door close must displace the canonical player from blocked space');
 let placeableSuccess=false;
 for(const object of area.objects.map(id=>s.registry.get(id)).filter(o=>o?.objectType===9&&o.nativeCollisionSlot>=0)){
  const bounds=area.nativeGeometry.objects.store.getBounds(object.nativeCollisionSlot);s.setPosition(actor,[...object.position],0);const before=[...actor.position],unsafe=await safe();
  if(unsafe!==0)continue;
  await s.lifecycle.budgeCreatures(area,native(object.position),...bounds,object.id,0);const after=[...actor.position],result=await safe();report.displacement.push({kind:'placeable',id:object.id,before,after,safe:result,bounds});
  if(result===1&&after.some((v,i)=>v!==before[i])){placeableSuccess=true;break;}
 }
 assert.ok(placeableSuccess,'A real PWK blocker must move the canonical player through shared displacement');
 s.setPosition(actor,original,0);assert.equal(s.registry.get(identity),actor);assert.equal(actor.stats,stats);assert.ok(area.nativeSpatial.view().includes(identity));
 if(area.flags&3)assert.ok(report.mapUpdates.some(e=>e.actorId===identity&&e.id===identity));
 report.areaFlags=area.flags;report.playerId=identity;report.identityPreserved=true;report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
 report.limits='Installed Prelude PWK points and canonical use-range/UI point selection; actual door SetOpenState, closed-door and placeable collision, safe placement, sorted spatial update and player automap owner. Positioning at blockers is a test setup; no manual or rendered input, general AI/startup, dynamic creation, campaign or protocol completion claim. All load failures/warnings retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({placeables:report.placeables.length,active:report.placeables.filter(p=>p.points.some(v=>v.some(n=>n!==0))).length,door:report.door,displacement:report.displacement,mapUpdates:report.mapUpdates,failure:report.failure}));if(report.failure)process.exitCode=1;
