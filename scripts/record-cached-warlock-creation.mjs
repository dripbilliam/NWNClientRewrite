// Final offline evidence index. No runtime, database, key or network access.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const sources={};function bytes(file){const value=fs.readFileSync(path.join(root,file));sources[file]=sha(value);return value;}
function json(file){return JSON.parse(bytes(file));}
const complete='godot-client/.cache/cached-warlock-complete/';
const definitions=[
 ['nativeCatalog524','godot-client/.cache/cached-warlock-catalog/cached-warlock-catalog-v1','proof.json',524],
 ['preSkillDifferential297',complete+'cached-warlock-feat-comparison-v2','runner.json',297],
 ['manual342',complete+'cached-warlock-complete-v5','runner.json',342],
 ...[310,311,312,313,314].map(id=>['automatic'+id,complete+`cached-warlock-recommended-${id}-v${id===310?2:1}`,'runner.json',id===310?340:321])
];
const cases={},bicArtifacts={},producerHashes={};let checks=0;
const important=['systems/native_creation.gd','systems/native_data/creation_rules.gd','systems/native_data/creation_feat_automatic.gd','systems/native_data/creation_tail_provider.gd','systems/native_data/creation_bic.gd'];
for(const[label,directory,proofName,count]of definitions){
 const proof=json(directory+'/'+proofName),result=json(directory+'/result.json');
 assert.ok(proof.success&&result.success&&proof.cleanEngine&&proof.exitCode===0&&!proof.error);
 assert.equal(proof.checks,count);assert.equal(result.checks,count);assert.equal(result.failures.length,0);
 for(const key of ['changedInputs','changedCopy','changedData','changedNative'])assert.equal((proof[key]??[]).length,0);
 assert.equal(proof.serverConnections,0);checks+=count;
 cases[label]={directory,checks:count,cleanEngine:true,sourceInputs:proof.inputs.length,dataInputs:proof.dataInputs.length,proof:proofName,proofSha256:sources[directory+'/'+proofName],resultSha256:sources[directory+'/result.json'],scope:result.scope};
 if(label.startsWith('automatic'))for(const file of important){
  const row=proof.inputs.find(value=>value.path==='godot-client/'+file);assert.ok(row);
  if(producerHashes[file])assert.equal(row.sha256,producerHashes[file]);else producerHashes[file]=row.sha256;
 }
 const bic=directory+'/result.json.bic';if(!fs.existsSync(path.join(root,bic)))continue;
 const data=bytes(bic),record=parseGff(data,'BIC ').root;const observation=result.observations;
 assert.equal(record.ClassList[0].Class,92);assert.equal(record.Race,6);
 assert.equal(record.FirstName.entries[0].text,'CachedWarlock');assert.equal(record.LastName.entries[0].text,'Offline');
 assert.equal(record.SoundSetFile,observation.information.voiceId);
 assert.equal(record.SoundSetFile,observation.initialVoice.firstAdmittedPhysicalId);
 assert.equal(observation.initialVoice.read.ready,true);assert.equal(observation.initialVoice.read.ok,false);assert.equal(observation.initialVoice.read.value,0);
 assert.equal(record.xAppearance_Head,observation.appearance.head);assert.equal(getGffFieldTypes(record).xAppearance_Head,2);
 assert.equal(record.Equip_ItemList[0].EquippedRes,observation.appearance.clothingResRef);assert.deepEqual(Object.keys(record.Equip_ItemList[0]),['EquippedRes']);assert.equal(getGffStructType(record.Equip_ItemList[0]),2);
 assert.equal(Object.hasOwn(record.ClassList[0],'SpellsPerDayList'),false);
 assert.equal(Object.hasOwn(record,'CompanionType'),false);assert.equal(Object.hasOwn(record,'CompanionName'),false);
 if(label.startsWith('automatic')){
  const receipt=observation.automaticReceipt;assert.deepEqual(receipt.selected,[408,945]);assert.equal(receipt.remaining,1);
  assert.equal(receipt.context.packageId,Number(label.slice('automatic'.length)));
  assert.equal(record.FamiliarType,-1);assert.equal(record.FamiliarName,'');
  assert.ok(record.FeatList.some(row=>row.Feat===408)&&record.FeatList.some(row=>row.Feat===945));
 }else{
  assert.equal(record.FamiliarType,observation.familiarAccepted.physicalId);assert.equal(record.FamiliarName,observation.familiarAccepted.name);
  assert.ok(record.FeatList.some(row=>row.Feat===2300));
 }
 assert.equal(observation.privateCaptureGaps.length,0);
 bicArtifacts[label]={file:bic,bytes:data.length,sha256:sha(data),physicalVoice:record.SoundSetFile,headWord:record.xAppearance_Head,outfit:record.Equip_ItemList[0].EquippedRes,outfitStructType:2,familiarType:record.FamiliarType,familiarName:record.FamiliarName,unusedCompanionPairAbsent:true,dailyUseListAbsent:true,startingPackageSerialized:record.StartingPackage,featCount:record.FeatList.length};
}
assert.equal(checks,2787);assert.equal(Object.keys(bicArtifacts).length,6);
const fixturePath='godot-client/.cache/cached-warlock-creation/cached-arelith-warlock-tail-v5/fixture.json';const fixture=json(fixturePath);
assert.ok(fixture.success&&fixture.captureGaps.length===0&&fixture.originalDatabaseMetadataUnchanged&&fixture.extensions.every(value=>value.originalDatabaseMetadataUnchanged));
const reports=['native-cached-warlock-voice-initialization-original-v1.json','native-cached-warlock-automatic-feats-finding-v1.json','native-package-feat-recommendation-source-v1.json'];
for(const file of reports)bytes('godot-client/reports/'+file);
const currentProducerChanges=[];for(const[file,expected]of Object.entries(producerHashes))if(sha(fs.readFileSync(path.join(root,'godot-client',file)))!==expected)currentProducerChanges.push(file);
sources['scripts/record-cached-warlock-creation.mjs']=sha(fs.readFileSync(fileURLToPath(import.meta.url)));
const target=path.join(root,'godot-client/reports/native-cached-warlock-creation-v1-receipt.json');assert.ok(!fs.existsSync(target),'Preserve existing receipt');
const receipt={success:true,createdUtc:new Date().toISOString(),scope:'Offline cached Arelith Warlock actual source controls, real native resources/workers and parsed generated BIC. Creation entry is actual Creator.open; Main/Browser/Picker and public/server admission remain separate scopes.',manifest:fixture.manifest,provenanceLimit:fixture.provenanceLimit,actualData:{classLabel:'Warlock',fixturePhysicalClass:92,fixturePhysicalRace:6,hiddenDefaultPackage:149,visibleAutomaticPackages:[310,311,312,313,314],capturedResources:fixture.resources.length,fullManifestNamespace:true,fullManifestBodyCapture:false,captureGaps:[],originalDatabaseMetadataUnchanged:true},cases,scopedAssertionSum:checks,countingNote:'Scoped assertion sum includes repeated resource/hash checks; it is not a count of unique features or original execution cases.',independentParsedBicArtifacts:bicArtifacts,automatic310ModeRetirement:{onEntry:true,onConfigure:true,onCancel:true,freshAutomaticReplay:true},resolvedFindings:['Original Info ignores failed Soundset getter BOOL and maps known output0 as a visible index to physical voice12.','Original automatic feat recommendation can exhaust preferences with unused bonus1; exact scoped receipt permits that prescription while preserving manual completion.','Original first-level BIC omits spontaneous daily-use list on automatic as well as manual source path.'],automaticProducerHashes:producerHashes,currentProducerChanges,sources,limits:['Hidden package149 is inspected in actual-data policy comparison, never forced into a physical UI choice.','Artwork/fonts publication is controlled; no new rendered-pixel or audible playback claim.','Cached manifest version is not asserted equal to the unpersisted user screenshot session.','No public connection, original server admission or all-race/all-package claim.'],networkConnections:0,protectedProfilesRead:0,userProcessActions:0,nativeBuilds:0,gpu:false};
fs.writeFileSync(target,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({receipt:path.relative(root,target),sha256:sha(fs.readFileSync(target)),checks,fullBicCases:Object.keys(bicArtifacts).length,visibleAutomaticPackages:5,capturedResources:fixture.resources.length,currentProducerChanges}));
