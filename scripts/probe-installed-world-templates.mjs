import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {localizedMessageValue} from '../src/native_message_text.js';
import {moduleTagKey} from '../src/module_tag_lookup.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-world-templates-v1.json',report={created:[]};
const F=gffField,R=gffRecord,f=Math.fround,native=v=>[v[0],f(-v[2]),v[1]],empty={strRef:0xffffffff,entries:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,area=s.currentArea,other=[...s.areas.values()].find(a=>a!==area);assert.ok(other);
 const construct=()=>s.register('waypoint',`runtime:waypoint:${s.registry.nextObjectId[0]}`,{tag:'',areaId:OBJECT_INVALID,position:[0,0,0],authored:{},deferTagLookup:true});
 const resources=[...s.resolver.key.resources.values()].filter(r=>r.resourceType===2058).slice(0,3);assert.ok(resources.length,'Installed UTW templates are required');
 for(const resource of resources){
  const o=construct(),id=o.id,tag=`ActiveUTW_${id}`,data=parseGff(await s.resolver.getResource(resource.resref,2058),'UTW ').root;
  assert.deepEqual(o.nativeName320,empty);assert.equal(await s.worldTemplates.load('waypoint',o,resource.resref,tag),1);assert.equal(o.id,id);assert.equal(o.areaId,OBJECT_INVALID);assert.equal(o.tag,tag);assert.equal(o.templateResRef,resource.resref);
  assert.deepEqual(o.nativeName320,localizedMessageValue(data.LocalizedName??empty));assert.equal(s.commands.GetWaypointByTag([tag]),id);
  await s.lifecycle.addWaypointArea(o,area,23,14,0,1);assert.equal(o.areaId,area.id);assert.deepEqual(native(o.position),[23,14,0]);assert.equal(area.nativeSpatial.view().filter(x=>x===id).length,1);assert.equal(area.objects.filter(x=>x===id).length,1);
  for(const level of s.aiMaster.levels)assert.ok(!level.view().includes(id));
  await s.lifecycle.addWaypointArea(o,other,3,4,0,1);assert.ok(!area.nativeSpatial.view().includes(id));assert.ok(!area.objects.includes(id));assert.equal(other.nativeSpatial.view().filter(x=>x===id).length,1);
  report.created.push({id,reference:resource.resref,tag,from:area.id,to:other.id});
  await s.lifecycle.destroy(o);assert.equal(s.registry.get(id),undefined);assert.ok(!other.nativeSpatial.view().includes(id));assert.ok(!other.objects.includes(id));assert.equal(s.commands.GetWaypointByTag([tag]),OBJECT_INVALID);assert.equal(o.nativeName320,null);assert.equal(o.nativeMapNote310,null);
 }
 // All special fields below are in-memory GFF fixtures behind the same active
 // resolver interface. Original install/resources and authored callbacks stay intact.
 const get=s.resolver.getResource.bind(s.resolver),overrides=new Map();s.resolver.getResource=(name,type)=>overrides.has(`${String(name).toLowerCase()}:${type}`)?Promise.resolve(overrides.get(`${String(name).toLowerCase()}:${type}`)):get(name,type);
 const fixture='wp_owner_probe',tag='Waypoint Owner\0tail',uuid='01234567-89ab-cdef-0123-456789abcdef',name={strRef:0xffffffff,entries:[{languageId:0,text:'Waypoint fixture'}]},note={strRef:123,entries:[{languageId:0,text:'Map note'},{languageId:1,text:'Replaced note'}]};
 const record=()=>R({Tag:F(10,'AuthoredTag'),LocalizedName:F(12,name),TemplateResRef:F(11,'authored_origin'),XPosition:F(8,2.25),YPosition:F(8,3.5),ZPosition:F(8,.125),XOrientation:F(8,0),YOrientation:F(8,2),ZOrientation:F(8,0),HasMapNote:F(0,2),MapNoteEnabled:F(0,2),MapNote:F(12,note),UUID:F(10,uuid),VarTable:F(15,[R({Name:F(10,'WaypointMarker'),Type:F(4,1),Value:F(5,7)})])});
 overrides.set(`${fixture}:2058`,writeGff('UTW ',record()));
 const a=construct(),b=construct();assert.equal(await s.worldTemplates.load('waypoint',a,fixture,tag),1);assert.equal(a.templateResRef,fixture);assert.deepEqual(native(a.position),[2.25,3.5,.125]);assert.deepEqual(native(a.orientation),[0,1,0]);assert.deepEqual(a.nativeName320,localizedMessageValue(name));assert.deepEqual(a.nativeMapNote310,localizedMessageValue(note));assert.deepEqual([a.nativeMessageFields[0x308],a.nativeMessageFields[0x30c]],[1,1]);assert.equal(a.locals.getInt('WaypointMarker'),7);assert.equal(s.uuids.lookup(uuid),a.id);
 assert.equal(await s.worldTemplates.load('waypoint',b,fixture,tag.replace('tail','else')),1);assert.equal(b.nativeUUID.value,'');assert.equal(b.locals.getInt('WaypointMarker'),7);assert.equal(b.templateResRef,fixture);assert.deepEqual(s.tags.get(moduleTagKey(tag)),[b.id,a.id]);assert.equal(s.commands.GetObjectByTag([tag,0]),b.id);assert.equal(s.commands.GetObjectByTag([tag,1]),a.id);
 const savedNote=structuredClone(a.nativeMapNote310),reload=record();reload.fields.HasMapNote=F(4,1);delete reload.fields.UUID;overrides.set(`${fixture}:2058`,writeGff('UTW ',reload));
 assert.equal(await s.worldTemplates.load('waypoint',a,fixture,'Reloaded'),1);assert.deepEqual(a.nativeMapNote310,savedNote);assert.equal(s.uuids.lookup(uuid),a.id);assert.equal(a.templateResRef,fixture);
 await s.lifecycle.addWaypointArea(a,area,25,15,0,1);await s.lifecycle.addWaypointArea(a,null,1,2,3,1);assert.equal(a.areaId,OBJECT_INVALID);assert.deepEqual(native(a.position),[0,0,0]);assert.ok(!area.nativeSpatial.view().includes(a.id));
 await s.lifecycle.destroy(a);await s.lifecycle.destroy(b);assert.equal(s.uuids.lookup(uuid),OBJECT_INVALID);assert.equal(s.commands.GetObjectByTag([tag]),a.id);assert.equal(s.commands.GetWaypointByTag([tag]),OBJECT_INVALID);
 report.fixture={firstId:a.id,secondId:b.id,uuidCollisionIgnored:true,mapNoteRetained:true};
 const c=construct();c.locals.setString('InitialNul','old');overrides.set(`${fixture}:2058`,writeGff('UTW ',R({Tag:F(10,'\0tag'),UUID:F(10,'\0uuid'),VarTable:F(15,[R({Name:F(10,'InitialNul'),Type:F(4,3),Value:F(10,'\0tail')})])})));
 assert.equal(await s.worldTemplates.load('waypoint',c,fixture,''),1);assert.equal(c.tag,'');assert.equal(c.nativeUUID.value,'');assert.equal(c.locals.getString('InitialNul'),'');assert.equal(c.locals.entries.has('InitialNul'),false);assert.equal(s.commands.GetObjectByTag(['']),OBJECT_INVALID);assert.equal(s.commands.GetWaypointByTag(['']),c.id);await s.lifecycle.destroy(c);report.initialNulId=c.id;
 report.beforeMissing=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.beforeMissing.filter(r=>r.severity==='error'),[]);assert.equal(report.beforeMissing.filter(r=>r.code==='object.uuid-warning').length,1);
 const missing=construct();assert.equal(await s.worldTemplates.load('waypoint',missing,'zz_absent_utw',''),0);assert.equal(missing.areaId,OBJECT_INVALID);assert.deepEqual(missing.nativeName320,empty);await s.lifecycle.destroy(missing);assert.equal(s.registry.get(missing.id),undefined);
 report.missingId=missing.id;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.equal(report.diagnostics.filter(r=>r.code==='object.template-warning').length,1);assert.equal(report.diagnostics.filter(r=>r.severity==='error').length,1);
 report.limits='Active UTW templates loaded into canonical waypoint records; concrete native template/data/variable/UUID providers and area add/move/remove/destruction. Special fields use in-memory typed GFF resolver fixtures. Startup/AI disabled. Checks requested-template override, tag truncation/NUL/duplicate order, localized storage, normalized orientation, typed notes/reload, UUID failure ignored, locals and missing-resource cleanup. This does not bind CreateObject243, create placeables/stores, send map-pin messages, or prove map UI/campaign progress.';report.validation='PASS';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,created:report.created,fixture:report.fixture,missingId:report.missingId,failure:report.failure}));if(report.failure)process.exitCode=1;
