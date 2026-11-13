// NEW offline functional-parity helpers. Importing does not stage or launch.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {workspace,project,inside,record,sha,slash} from './native-startup-experiment-lib.mjs';
export {workspace,project,inside,record,sha,slash};
export const parityRoot=path.join(project,'.cache/release-functional-parity');
export const fixtureDirectory=path.join(project,'.cache/cached-warlock-creation/cached-arelith-warlock-tail-v5');
export const cases=[
 {name:'pregame',script:'tests/native_pregame_flow_test.gd',bic:false,args:[]},
 {name:'warlock-manual',script:'tests/native_cached_warlock_complete_test.gd',bic:true,args:[]},
 {name:'warlock-recommended310',script:'tests/native_cached_warlock_recommended_test.gd',bic:true,args:['--package=310']}
];
export function sourceInventory(){
 const result=[];
 function scan(folder){for(const item of fs.readdirSync(folder,{withFileTypes:true})){
  if(['.cache','.godot','.tools','reports','backups','node_modules','.git'].includes(item.name))continue;
  const file=path.join(folder,item.name);assert.ok(!item.isSymbolicLink(),'Never traverse source links');
  if(item.isDirectory())scan(file);
  else if(/\.(gd|gdshader|gdshaderinc|tscn|tres|svg|json|gdextension|uid)$/.test(item.name))result.push(record(file));
 }}
 scan(project);
 for(const file of ['project.godot','native/window_modes.c','tools/build-window-modes.ps1'])result.push(record(path.join(project,file)));
 return [...new Map(result.map(row=>[row.path,row])).values()].sort((a,b)=>a.path.localeCompare(b.path));
}
export function verifiedFixture(){
 const receiptFile=path.join(project,'reports/native-cached-warlock-creation-v1-receipt.json');
 assert.equal(record(receiptFile).sha256,'631683374da8a6a5f1f62292b7fee4462621992dd4253f47a307e3c48ae41682','Use the accepted immutable captured-data provenance');
 const receipt=JSON.parse(fs.readFileSync(receiptFile)),caseInfo=receipt.cases.manual342;
 const proofFile=path.join(workspace,caseInfo.directory,caseInfo.proof);assert.equal(record(proofFile).sha256,caseInfo.proofSha256);
 const proof=JSON.parse(fs.readFileSync(proofFile));assert.equal(proof.success,true);assert.equal(path.resolve(proof.fixture),fixtureDirectory);
 const metadata=JSON.parse(fs.readFileSync(path.join(fixtureDirectory,'fixture.json')));
 assert.equal(metadata.success,true);assert.deepEqual(metadata.captureGaps,[]);assert.equal(metadata.manifest,'7e0898127f44bd44f13bdab852ae85bb9badfd6b');
 assert.equal(metadata.privateNwsyncCatalog?.helperless,true);assert.equal(metadata.privateNwsyncCatalog?.fullNamespace,true);
 assert.equal(metadata.privateNwsyncCatalog?.manifest,metadata.manifest);assert.equal(metadata.privateNwsyncCatalog?.fullBodyCapture,false);assert.equal(metadata.resources.length,257);
 const files=proof.dataInputs.map(row=>{
  const actual=inside(fixtureDirectory,row.file);const current=record(actual);assert.equal(current.sha256,row.sha256,'Captured data changed: '+actual);
  return{...current,relative:slash(path.relative(fixtureDirectory,actual))};
 });
 const names=new Set(files.map(row=>row.relative));
 assert.ok(names.has('fixture.json'));assert.ok(names.has('nwsync/manifests/'+metadata.manifest));
 assert.equal(files.find(row=>row.relative==='nwsync/manifests/'+metadata.manifest).sha256,metadata.manifestSha256);
 for(const resource of metadata.resources){
  assert.ok(names.has(resource.file));assert.ok(names.has('nwsync/objects/'+resource.sha1));
  assert.equal(files.find(row=>row.relative===resource.file).sha256,resource.sha256);
 }
 return{metadata,files,provenance:[record(receiptFile),record(proofFile)],sourceDirectory:fixtureDirectory};
}
export function canonical(value){
 if(Array.isArray(value))return value.map(canonical);
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])]));
 return value;
}
export function normalizePregame(value){
 assert.equal(value.success,true);assert.equal(value.publicConnections,0);assert.equal(value.gameServerConnections,0);
 assert.ok(Array.isArray(value.recorded_intents)&&value.recorded_intents.length>0);
 return canonical({checks:value.checks,failures:value.failures,recorded_intents:value.recorded_intents});
}
// Preserve the complete independent GFF value/type/struct tree. Only the two
// actual source-generated associate names can differ across fresh processes;
// each must still equal that run's native draft and pass its existing fixture.
export function bicSemantics(root,getTypes,getStruct){
 function visit(value,atRoot=false){
  if(ArrayBuffer.isView(value))return{bytes:Buffer.from(value.buffer,value.byteOffset,value.byteLength).toString('hex')};
  if(Array.isArray(value))return value.map(entry=>visit(entry));
  if(value&&typeof value==='object'){
   const types=getTypes(value)??{};return{structType:getStruct(value)??null,fields:Object.fromEntries(Object.keys(value).sort().map(key=>{
    let field=value[key];if(atRoot&&['FamiliarName','CompanionName'].includes(key)){assert.equal(typeof field,'string');field={sourceGeneratedAssociateName:true};}
    return[key,{type:types[key]??null,value:visit(field)}];
   }))};
  }
  return value;
 }
 return visit(root,true);
}
export function validateBic(root,fixture,getTypes,getStruct){
 assert.equal(fixture.success,true);assert.equal(fixture.gpu,false);assert.equal(fixture.serverConnections,0);
 const draft=fixture.observations.final.draft,appearance=fixture.observations.appearance,info=fixture.observations.information;
 assert.equal(root.ClassList[0].Class,92);assert.equal(root.Race,6);assert.equal(root.FirstName.entries[0].text,'CachedWarlock');assert.equal(root.LastName.entries[0].text,'Offline');
 assert.equal(root.xAppearance_Head,appearance.head);assert.equal(getTypes(root).xAppearance_Head,2);assert.equal(getTypes(root).Appearance_Head,0);
 assert.equal(root.Appearance_Head,Number(appearance.head)&255);assert.equal(root.SoundSetFile,info.voiceId);
 assert.ok(!Object.hasOwn(root.ClassList[0],'SpellsPerDayList'));
 assert.equal(root.Equip_ItemList.length,1);assert.deepEqual(Object.keys(root.Equip_ItemList[0]),['EquippedRes']);
 assert.equal(getStruct(root.Equip_ItemList[0]),2);assert.equal(getTypes(root.Equip_ItemList[0]).EquippedRes,11);assert.equal(root.Equip_ItemList[0].EquippedRes,appearance.clothingResRef);
 for(const [field,draftKey]of [['FamiliarName','familiarName'],['CompanionName','companionName']]){
  if(Object.hasOwn(root,field))assert.equal(root[field],draft[draftKey],'Independent BIC name must match native accepted draft');
 }
 const tree=bicSemantics(root,getTypes,getStruct);
 return{success:true,semanticSha256:sha(JSON.stringify(tree)),tree,observations:{classId:root.ClassList[0].Class,race:root.Race,first:root.FirstName.entries[0].text,last:root.LastName.entries[0].text,head:root.xAppearance_Head,headType:getTypes(root).xAppearance_Head,voice:root.SoundSetFile,outfit:root.Equip_ItemList[0].EquippedRes,feats:root.FeatList.map(row=>row.Feat)}};
}
export function normalReleaseArguments(script,report,log,install,fixture,args=[]){
 assert.ok(script.startsWith('tests/')&&script.endsWith('.gd'));
 return['--headless','--log-file',log,'--','--release-entry=res://'+script,'--report='+report,'--install='+install,'--fixture='+fixture,'--entity-api-rest=false',...args];
}
