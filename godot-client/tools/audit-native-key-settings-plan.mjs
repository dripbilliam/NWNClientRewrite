// Read-only scoped data-plan acceptance. No app launch, keyboard or connection.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),receipts=[],evidence=[];
const sha=b=>createHash('sha256').update(b).digest('hex');
async function bytes(file){const value=await fs.readFile(path.join(home,file));evidence.push({file,sha256:sha(value),bytes:value.length});return value;}
async function read(file){return JSON.parse(await bytes(file));}
async function kernel(run,count){
 const r=await read('reports/'+run+'.json'),p=await read('reports/'+run+'.debugger.json');
 assert.equal(r.success,true);assert.equal(r.checks,count);assert.deepEqual(r.failures,[]);
 for(const k of ['success','armed','normalHeap','sourceUnchanged'])assert.equal(p[k],true,run+'/'+k);
 for(const k of ['exception','engineOrLifetimeError'])assert.equal(p[k],false,run+'/'+k);
 assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);
 const entries=Object.entries(p.sourceSha256);assert.ok(entries.length>100);
 for(const[f,d]of entries)assert.equal(sha(await fs.readFile(path.join(home,f))),d,f+' changed after test');
 receipts.push({run,checks:count,sourceEntries:entries.length});return r;
}
const data=await kernel('native-keymap-plan-data-final-v1',3447),layout=await kernel('native-keymap-plan-layout-final-v1',31),tables=await kernel('native-keymap-plan-tables-final-v1',43),catalog=await kernel('native-keymap-plan-catalog-final-v1',1);
await kernel('native-keymap-plan-desktop-final-v1',41);await kernel('native-keymap-plan-barter-final-v1',38);
assert.equal(data.fullKeySettingsParity,false);assert.equal(layout.fullKeySettingsParity,false);
assert.equal(data.initial.rows.length,51);assert.equal(data.defaults.rows.length,51);
assert.equal(catalog.rows.length,72);assert.equal(catalog.sha256,data.keymapSha256);
assert.equal(tables.samples.length,13);
const original='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
const captureBytes=await bytes('../backups/animations/native-key-capture-observations-v1.json'),capture=JSON.parse(captureBytes);
assert.equal(sha(captureBytes),data.oracleSha256);assert.equal(capture.binarySha256,original);
assert.equal(capture.captures.length,3072);assert.equal(capture.remappable.length,256);assert.equal(capture.labels.length,67);assert.equal(capture.special.length,4);
const populationBytes=await bytes('../backups/animations/native-key-population-observations-v1.json'),population=JSON.parse(populationBytes);
assert.equal(sha(populationBytes),data.populationOracleSha256);assert.equal(population.binarySha256,original);assert.equal(population.installedKeymapSha256,data.keymapSha256);assert.equal(population.rows.length,26);
for(const[file,count]of [['rea-native-key-settings-v1.json',21],['rea-native-key-settings-followup-v1.json',10],['rea-native-key-tabs-v1.json',1]]){
 const d=await read('../backups/animations/'+file);assert.equal(d.dossiers.length,count);
 assert.ok(d.dossiers.every(v=>v.subject.digest.sha256===original&&(v.name==='vtable'?v.result.complete&&v.result.returned_bytes>0:v.result.pseudocode&&v.result.assembly.length)));
}
const baseline=await bytes('reports/keymap-baseline-v1/systems/native_data/two_da.gd');assert.equal(sha(baseline),tables.baseline_tokenizer_sha256);
const previous=await read('backups/native-video-options-v1.zip.verified.json');assert.equal(previous.verified,true);
assert.equal(previous.manifest.find(v=>v.file==='systems/native_data/two_da.gd').sha256,sha(baseline));
assert.equal(sha(await fs.readFile(path.join(home,'backups/native-video-options-v1.zip'))),previous.sha256);
const failed=await read('reports/native-keymap-rules-v1.debugger.json');assert.equal(failed.success,false);assert.equal(failed.engineOrLifetimeError,true);
const numbers=await read('reports/native-keymap-rules-v3.json');assert.equal(numbers.success,false);assert.equal(numbers.failures.length,26);
const archive='backups/native-key-settings-plan-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);
assert.equal(sha(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const row of checkpoint.manifest){const file=row.sourceScope==='workspace'?path.join(home,'..',row.source):path.join(home,row.file);assert.equal(sha(await fs.readFile(file)),row.sha256,row.file+' changed after checkpoint');}
for(const file of ['systems/native_data/two_da.gd','systems/native_data/keymap_rules.gd','systems/native_data/key_settings_layout.gd','tests/native_keymap_rules_test.gd','tests/native_key_settings_layout_test.gd','__workspace__/scripts/inspect-native-key-capture.py','__workspace__/scripts/inspect-native-key-population.py'])assert.ok(checkpoint.manifest.some(v=>v.file===file),'Missing checkpoint source: '+file);
const checks=receipts.reduce((sum,row)=>sum+row.checks,0);assert.equal(checks,3601);
const output='reports/native-key-settings-plan-acceptance-v1.json';
const result={success:true,checks,goalComplete:false,namedRowMetadataAccepted:true,keyRulesAndLayoutDataAccepted:true,visibleKeySettingsAccepted:false,inputRemappingAccepted:false,hotbarRebindingAccepted:false,persistenceAccepted:false,fullKeySettingsParity:false,publicConnections:0,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},receipts,evidence,limits:'Scoped native data and original instruction observations, source geometry, existing table-field preservation and UI regressions. No visible key editor, actual input routing, persistent rebinding, hotbar rebinding or complete UI acceptance. User-requested editable36-slot hotbar extension remains required.'};
await fs.writeFile(path.join(home,output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,checks,report:output,checkpoint:result.checkpoint}));
