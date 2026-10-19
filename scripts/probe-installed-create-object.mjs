import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-create-object-v1.json',report={created:[],failed:[]},f=Math.fround;
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const area=s.currentArea;await area.nativeGeometry.objects.load();
 const ordinal=s.vm.api.findIndex(api=>api?.name==='CreateObject');assert.equal(ordinal,243);
 const invoke=async args=>{const bytes=Buffer.alloc(20);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(20,9);bytes.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);const program=parseNcs(bytes,'create_object_probe'),frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const result=await s.vm.run(program,s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.equal(result.stack.length,1);assert.equal(result.stack[0].type,6);return result.stack[0].value;};
 const resources=[...s.resolver.key.resources.values()],first=type=>resources.find(r=>r.resourceType===type)?.resref;let placeable,store;
 for(const resource of resources){
  if(resource.resourceType!==2044)continue;const data=parseGff(await s.resolver.getResource(resource.resref,2044),'UTP ').root;
  try{const entry=await s.geometryResources.placeableMesh((data.Appearance??0)&65535);if(entry?.mesh?.vertices.length){placeable=resource.resref;break;}}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
 }
 for(const resource of resources){if(resource.resourceType!==2051)continue;const data=parseGff(await s.resolver.getResource(resource.resref,2051),'UTM ').root;if(data.StoreList?.some(row=>row.ItemList?.length)){store=resource.resref;break;}}
 assert.ok(placeable);assert.ok(store);report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length;
 const location={areaId:area.id,position:[24,20,0],nativeOrientation:[0,1,0]},source=structuredClone(location),created=[];
 for(const[type,kind,reference]of[[1,'creature',first(2027)],[2,'item',first(2025)],[32,'waypoint',first(2058)],[64,'placeable',placeable],[128,'store',store]]){
  assert.ok(reference);const tag=`Create_${kind}`,before=s.registry.nextObjectId[0],id=await invoke([type,reference,location,0,tag]),o=s.registry.get(id);assert.equal(id,before);assert.equal(o.kind,kind);assert.equal(o.tag,tag);assert.equal(o.areaId,area.id);assert.ok(area.objects.includes(id));assert.ok(area.nativeSpatial.view().includes(id));assert.equal(s.commands.GetObjectByTag([tag]),id);assert.deepEqual(location,source);
  if(kind==='creature')assert.equal(o.nativeSpawnState548,0,'The creation command does not directly execute OnSpawn');
  if(kind==='placeable'){
   assert.ok(o.nativeCollisionSlot>=0);const geometry=area.nativeGeometry.objects,slot=o.nativeCollisionSlot;let replacements=0;const replace=geometry.store.replace.bind(geometry.store);geometry.store.replace=(...args)=>{replacements++;return replace(...args);};
   await s.lifecycle.setOrientation(o,[1,0,0]);assert.equal(replacements,1);assert.equal(o.nativeCollisionSlot,slot);
   await s.lifecycle.setOrientation(o,[1,.0001,0]);assert.equal(replacements,1,'Native dot threshold retains existing collision');await geometry.load();geometry.preparePlaceableOrientation(o);
   await s.commands.SetFacing([90,o.id],{self:s.player.id});assert.ok(replacements>=2);geometry.store.replace=replace;report.orientation={id,slot,replacements,final:[...o.nativeOrientation]};
   const location=s.commands.GetLocation([o.id]);assert.deepEqual(location.nativeOrientation,o.nativeOrientation);
  }
  created.push(o);report.created.push({type,kind,reference,id,position:[...o.position],orientation:[...o.nativeOrientation],children:[...o.inventory],next:s.registry.nextObjectId[0]});
 }
 // Appearance effect is queued through the original owner, not played as an
 // idle animation. The omitted optional arguments take the command defaults.
 const appeared=await invoke([1,first(2027),location,1,'AppearCreated']);assert.ok(s.registry.get(appeared));assert.ok(s.registry.get(appeared).objectActionState.list.count>0);created.push(s.registry.get(appeared));report.appearId=appeared;
 const minimal=await invoke([32,first(2058),location]);created.push(s.registry.get(minimal));report.defaultArgumentId=minimal;
 for(const type of[1,2,32,64,128]){const before=s.registry.nextObjectId[0];assert.equal(await invoke([type,'zz_missing_obj',location]),OBJECT_INVALID);assert.equal(s.registry.get(before),undefined);assert.equal(s.registry.nextObjectId[0],before+1);report.failed.push({type,id:before});}
 let before=s.registry.nextObjectId[0];assert.equal(await invoke([8,placeable,location]),OBJECT_INVALID);assert.equal(s.registry.nextObjectId[0],before);assert.equal(await invoke([64,placeable,{...location,areaId:OBJECT_INVALID}]),OBJECT_INVALID);assert.equal(s.registry.nextObjectId[0],before);
 for(const o of created){const children=[...o.inventory],next=s.registry.nextObjectId[0],slot=o.nativeCollisionSlot;await s.lifecycle.destroy(o);assert.equal(s.registry.get(o.id),undefined);assert.ok(!area.objects.includes(o.id));assert.ok(!area.nativeSpatial.view().includes(o.id));assert.equal(s.registry.nextObjectId[0],next);for(const id of children)assert.equal(s.registry.get(id),undefined);if(slot>=0)assert.ok(!area.nativeGeometry.objects.snapshots.has(o.id));}
 report.diagnostics=runtimeDiagnostics.records.slice(begin);const errors=report.diagnostics.filter(r=>r.severity==='error');assert.equal(errors.length,5);assert.ok(errors.every(r=>r.context.resource==='zz_missing_obj'));report.validation='PASS';report.limits='Parsed NCS ACTION243 through typed VM frames and installed resources; all five creation types, canonical IDs/tags/area/spatial ownership, PWK rotation/threshold guard and SetFacing, appearance action, default arguments, missing resources consuming IDs, recursive destruction. Script arguments are supplied in the owned test VM frame. Native AI/startup isolated. Map pins now have a separately probed in-process native-body delivery; map-panel presentation, network transport and ground-item rendering remain gaps. This does not prove all spell scripts or campaign progress.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,created:report.created.map(({kind,reference,id,children})=>({kind,reference,id,children:children.length})),orientation:report.orientation,appearId:report.appearId,failed:report.failed,failure:report.failure}));if(report.failure)process.exitCode=1;
