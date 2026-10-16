import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F,typedGff} from '../src/gff_writer.js';
import {nativeObjectTag} from '../src/object_tag.js';
import {objectTemplateResRef} from '../src/create_object.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-placeable-templates-v1.json',report={created:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,area=s.currentArea,other=[...s.areas.values()].find(a=>a!==area);
 const construct=()=>s.register('placeable',`runtime:utp:${s.registry.nextObjectId[0]}`,{tag:'',areaId:OBJECT_INVALID,position:[0,0,0],authored:{},deferTagLookup:true});
 const resources=[...s.resolver.key.resources.values()].filter(r=>r.resourceType===2044).slice(0,5);assert.equal(resources.length,5);
 for(const resource of resources){
  const data=parseGff(await s.resolver.getResource(resource.resref,2044),'UTP ').root,o=construct(),id=o.id,tag=`ActiveUTP_${id}`;
  assert.equal(await s.worldTemplates.load('placeable',o,resource.resref,tag),1);assert.equal(s.registry.get(id),o);assert.equal(o.areaId,OBJECT_INVALID);assert.equal(o.tag,tag);assert.equal(o.templateResRef,objectTemplateResRef(data.TemplateResRef??''));assert.equal(s.commands.GetObjectByTag([tag]),id);
  assert.equal(o.nativeStatic5a0,0);assert.equal(o.nativeGroundPile368,1);assert.equal(o.factionId,(data.Faction??0)>>>0);assert.equal(o.nativeTrapFaction3d8,(data.TrapFaction??0)>>>0);
  const childIds=[...o.nativeRepository.ids()];for(const childId of childIds){const item=s.registry.get(childId);assert.equal(item.objectType,6);assert.equal(item.possessorId,id);assert.equal(item.nativeItemFromGffLoaded,true);}
  await s.lifecycle.addPlaceableArea(o,area,24,20,0,1);assert.equal(o.areaId,area.id);assert.ok(area.objects.includes(id));assert.ok(area.nativeGeometry.objects.snapshots.has(id));
  await s.lifecycle.addPlaceableArea(o,other,24,20,0,1);assert.equal(o.areaId,other.id);assert.ok(!area.objects.includes(id));assert.ok(!area.nativeGeometry.objects.snapshots.has(id));assert.ok(other.nativeGeometry.objects.snapshots.has(id));
  const next=s.registry.nextObjectId[0];await s.lifecycle.destroy(o);assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);assert.ok(!other.objects.includes(id));assert.ok(!other.nativeGeometry.objects.snapshots.has(id));for(const childId of childIds)assert.equal(s.registry.get(childId),undefined);
  report.created.push({id,reference:resource.resref,authoredTemplate:o.templateResRef,childIds,from:area.id,to:other.id});
 }
 // Typed fixtures remain in RAM behind the normal resolver. Use an installed
 // UTI through the original template-reference path, plus an embedded copy.
 let itemData,reference;
 for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=parseGff(await s.resolver.getResource(resource.resref,2025),'UTI ').root;
  if(s.items.baseInfo({baseItem:data.BaseItem})?.container===0){itemData=data;reference=resource.resref;break;}
 }
 assert.ok(itemData);const embedded=typedGff(itemData,0);embedded.fields.Tag=F(10,'Embedded Item!');embedded.fields.ObjectId=F(4,0x12000);embedded.fields.Repos_PosX=F(2,0);embedded.fields.Repos_Posy=F(2,0);
 const templateRow=R({InventoryRes:F(11,reference),ObjectId:F(4,0x12001),Dropable:F(0,2),Pickpocketable:F(0,2),Repos_PosX:F(2,2),Repos_Posy:F(2,0)}),uuid='01234567-89ab-cdef-0123-456789abcdef',name='utp_owner_probe';
 let fixture=writeGff('UTP ',R({Tag:F(10,'UTP bad tag!'),TemplateResRef:F(11,'AuthoredUTP'),Useable:F(0,1),HasInventory:F(0,1),ItemList:F(15,[embedded,templateRow]),UUID:F(10,uuid),VarTable:F(15,[R({Name:F(10,'Loaded'),Type:F(4,1),Value:F(5,7)})])}));
 const get=s.resolver.getResource.bind(s.resolver);s.resolver.getResource=(ref,type)=>ref===name&&type===2044?Promise.resolve(fixture):get(ref,type);
 const o=construct();assert.equal(await s.worldTemplates.load('placeable',o,name),1);assert.equal(o.tag,nativeObjectTag('UTP bad tag!'));assert.equal(o.templateResRef,'AuthoredUTP');assert.equal(o.locals.getInt('Loaded'),7);assert.equal(s.uuids.lookup(uuid),o.id);
 const first=[...o.nativeRepository.ids()];assert.equal(first.length,2);assert.ok(first.every(id=>id!==0x12000&&id!==0x12001));const templated=s.registry.get(first.find(id=>s.registry.get(id).tag!=='EmbeddedItem'));assert.equal(templated.droppable,1);assert.equal(templated.pickpocketable,1);
 assert.equal(await s.worldTemplates.load('placeable',o,name,'Reloaded'),1);assert.equal(o.nativeRepository.length,4);assert.ok(first.every(id=>[...o.nativeRepository.ids()].includes(id)));const children=[...o.nativeRepository.ids()],next=s.registry.nextObjectId[0];await s.lifecycle.destroy(o);for(const id of children)assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);assert.equal(s.uuids.lookup(uuid),OBJECT_INVALID);
 report.fixture={reference,itemIds:children,savedIdsIgnoredWhenLoadingZero:true,reloadAppends:true,uuidReleased:true};report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);
 report.validation='PASS';report.limits='Five installed UTPs loaded through full native template/data/locals/UUID adapters into canonical placeables, inserted/moved/removed with installed geometry, recursively destroyed. In-memory UTP fixture loads installed UTI references and embedded items and reloads without clearing the repository. Startup/AI disabled. No CreateObject243 binding, store adapter, saved effect/action import, scoped transform draw or campaign completion claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,created:report.created,fixture:report.fixture,failure:report.failure}));if(report.failure)process.exitCode=1;
