import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff,getGffFieldTypes} from '../src/gff.js';
import {writeGff,gffRecord,gffField,typedGff} from '../src/gff_writer.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-variable-load-v1.json',report={};
const F=gffField,R=gffRecord;
const row=(type,value,valueType,name='Shared')=>R({Name:F(10,name),Type:F(4,type),...(valueType!==undefined?{Value:F(valueType,value)}:{})});
const data=rows=>parseGff(writeGff('UTW ',R({VarTable:F(15,rows)}))).root;
function query(name,objectId,api,command){
 const id=api.findIndex(s=>s?.name===command);assert.ok(id>=0);
 const text=Buffer.from(name,'latin1'),oid=Buffer.alloc(4);const code=[4,5,text.length>>>8,text.length&255,...text,4,6,...oid,5,0,id>>>8,id&255,2,0x20,0],bytes=Buffer.alloc(13+code.length);
 bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(code,13);return parseNcs(bytes,'variable_load_query_fixture');
}
try{
 const character=await fs.readFile(`${root}/data/lcv/wizard.bic`);
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a'],{character});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();report.loadDiagnostics=[...runtimeDiagnostics.records];
 const begin=runtimeDiagnostics.records.length,o=[...s.registry.objects.values()].find(o=>o.objectType===12),before=[...s.registry.nextObjectId];assert.ok(o);report.source={id:o.id,tag:o.tag,areaId:o.areaId};
 report.authoredVariables=[...s.registry.objects.values()].reduce((n,o)=>n+(Array.isArray(o.authored?.VarTable)?o.authored.VarTable.filter(v=>getGffFieldTypes(v)).length:0),0);
 // Discover an actual active blueprint carrying primitive/location locals;
 // do not select a campaign-specific resref or invent authored variable data.
 let scanned=0;
 for(const resource of s.resolver.key.resources.values()){
  if(![2025,2027,2044,2058].includes(resource.resourceType))continue;
  const authored=parseGff(await s.resolver.getResource(resource.resref,resource.resourceType)).root;scanned++;
  const rows=authored.VarTable;
  if(Array.isArray(rows)&&rows.length&&rows.every(v=>v.Type>=1&&v.Type<=5&&getGffFieldTypes(v))){s.loadNativeVariables(o,authored);report.activeVariableSource={resRef:resource.resref,type:resource.resourceType,rows:rows.length};break;}
  if(scanned===1000)break;
 }
 report.scannedBlueprints=scanned;
 const calls=[],old=o.locals.onSetInt;o.locals.onSetInt=(name,value,loading)=>{calls.push({name,value,loading});old(name,value,loading);};
 const location=R({Area:F(4,OBJECT_INVALID),PositionX:F(8,12.5),PositionY:F(8,-3.25),OrientationY:F(8,.75)});
 s.loadNativeVariables(o,data([row(1,7,5),row(2,1.25,8),row(3,'value\0tail',10),row(4,s.player.id,4),row(5,location,14)]));
 const get=async(command,name='Shared')=>{const result=await s.vm.run(query(name,o.id,s.vm.api,command),o.id);assert.equal(result.stack.length,1);return result.stack[0].value;};
 assert.equal(await get('GetLocalInt'),7);assert.equal(await get('GetLocalFloat'),1.25);assert.equal(await get('GetLocalString'),'value\0tail');assert.equal(await get('GetLocalObject'),s.player.id);
 assert.deepEqual(await get('GetLocalLocation'),{areaId:OBJECT_INVALID,position:[12.5,-3.25,0],nativeOrientation:[0,.75,0]});
 s.loadNativeVariableRows(o,data([row(5,location,14,'OriginalLoc'),row(5,undefined,undefined,'RetainedStruct')]).VarTable);
 assert.deepEqual(await get('GetLocalLocation','RetainedStruct'),{areaId:OBJECT_INVALID,position:[12.5,-3.25,0],nativeOrientation:[0,.75,0]});
 const empty=await get('GetLocalLocation','missing');assert.deepEqual(empty,{areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});empty.position[0]=90;assert.equal((await get('GetLocalLocation','missing')).position[0],0);
 assert.deepEqual(calls,[{name:'Shared',value:7,loading:1}]);
 // A wrong INT field and missing OBJECT field use native0 defaults. Only
 // the addressed typed cell changes; the name's float/string/location survive.
 s.loadNativeVariables(o,data([row(1,9,4),row(4)]));assert.equal(await get('GetLocalInt'),0);assert.equal(await get('GetLocalObject'),0);assert.equal(await get('GetLocalFloat'),1.25);assert.equal(await get('GetLocalString'),'value\0tail');
 s.loadNativeVariables(o,data([row(5,R({Area:F(4,OBJECT_INVALID)}),14)]));assert.deepEqual(await get('GetLocalLocation'),{areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});
 report.identityPreserved=[...s.registry.nextObjectId];assert.deepEqual(s.registry.nextObjectId,before);
 report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);
 // Deliberately exercise both currently-unbound structured providers and
 // verify each failure is retained instead of silently dropping serialized data.
 const expected=[];
 for(const type of [6,7]){try{s.loadNativeVariables(o,data([row(type,R({}),14,'Structured')]));assert.fail('A missing structured loader must not silently succeed');}catch(error){assert.match(error.message,/engine-structure load is unavailable/);expected.push(error.message);}}
 try{s.loadNativeVariables(o,data([row(5,undefined,undefined,'Uninitialized')]));assert.fail('A first failed struct read must be diagnosed');}catch(error){assert.match(error.message,/uninitialized native storage/);expected.push(error.message);}
 report.expectedUnsupported=expected;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.equal(report.diagnostics.filter(r=>r.context.operation==='native-script-variable-load').length,3);
 // BIC saved area IDs must not alias unrelated freshly allocated module areas.
 // An in-memory inventory local intentionally points at the numeric area ID1.
 const bic=typedGff(parseGff(character,'BIC ').root),items=bic.fields.ItemList.value;assert.ok(items.length);
 items[0].fields.VarTable=F(15,[row(5,R({Area:F(4,1),PositionX:F(8,8)}),14,'SavedImportLocation')]);
 const bicBegin=runtimeDiagnostics.records.length,saved=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a'],{character:writeGff('BIC ',bic)});
 const item=[...saved.registry.objects.values()].find(o=>o.objectType===6&&o.authored?.VarTable?.some(v=>v.Name==='SavedImportLocation'));assert.ok(item);assert.equal(saved.registry.get(1)?.objectType,4);assert.deepEqual(saved.commands.GetLocalLocation([item.id,'SavedImportLocation']),{areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});
 report.bicLocation={itemId:item.id,unrelatedModuleAreaId:1,diagnostics:runtimeDiagnostics.records.slice(bicBegin)};assert.ok(report.bicLocation.diagnostics.some(r=>r.message.includes('BIC local location SavedImportLocation')));
 report.limits='Installed Prelude and wizard import use typed variable loading for fresh serialized objects. A real waypoint receives in-memory typed GFF fixtures; all five local query APIs execute through NCS/installed API/VM. Covers shared-name cells, loading flag1, float/string/object IDs, wrong widths, default0 object, invalid-area nonzero location retention and empty getter copies; canonical allocator unchanged. Startup/AI disabled. Cassowary/JSON import failures deliberately diagnosed; their lower operations and BIC object/location remapping remain separate work.';
 report.validation='PASS';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,source:report.source,authoredVariables:report.authoredVariables,activeVariableSource:report.activeVariableSource,scannedBlueprints:report.scannedBlueprints,expectedUnsupported:report.expectedUnsupported,failure:report.failure}));if(report.failure)process.exitCode=1;
