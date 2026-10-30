// Scoped preservation evidence only. Customize UI and full parity stay open.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[];
const hash=b=>createHash('sha256').update(b).digest('hex');
async function read(file){const b=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(b)});return JSON.parse(b);}
let nativeChecks=0,main;
for(const[name,count]of [['native-customization-preservation-final-v2',190],['native-customization-gff-final-v2',25],['native-customization-catalog-final-v2',61]]){
 const r=await read('reports/'+name+'.json'),d=await read('reports/'+name+'.debugger.json');
 assert.equal(r.success,true);assert.deepEqual(r.failures,[]);assert.equal(r.checks,count);assert.equal(r.publicConnections,0);
 for(const k of ['success','sourceUnchanged','armed'])assert.equal(d[k],true,k);
 for(const k of ['exception','engineOrLifetimeError'])assert.equal(d[k],false,k);
 assert.equal(d.debuggerExit,0);
 for(const[file,digest]of Object.entries(d.sourceSha256))assert.equal(hash(await fs.readFile(path.join(home,file))),digest,file+' changed since test');
 nativeChecks+=count;if(count===190)main=r;
}
assert.equal(main.customizeUiImplemented,false);assert.equal(main.originalPolicyCasesCompared,80);assert.equal(main.originalAllocationFailureCases,40);assert.equal(main.corpus.length,39);
const install=path.resolve(home,'../../FullDecomp/NwnRootInstall');
for(const row of main.corpus){assert.match(row.file,/^[a-z0-9_]+\.bic$/i);const bytes=await fs.readFile(path.join(install,'data/lcv',row.file));assert.equal(bytes.length,row.bytes);assert.equal(hash(bytes),row.sha256);}
const original=await read('../backups/animations/native-customization-wordbyte-v1.json'),source=await read('../backups/animations/rea-native-character-customization-v1.json');
const binary='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';assert.equal(original.binarySha256,binary);assert.equal(source.binarySha256,binary);assert.equal(hash(await fs.readFile(path.join(install,'bin/win32/nwmain.exe'))),binary);
assert.equal(original.cases.length,120);assert.equal(original.cases.filter(v=>v.success).length,80);
for(const row of original.cases){assert.equal(row.byte,row.value<256?row.value:0);assert.equal(row.extended,('x'+row.label).slice(0,16));assert.equal(row.word,row.success?row.value:0);assert.equal(row.success,row.mode!=='add-failed');}
const calls=[...source.rows.customizeSave1.normalized_result.pseudocode.matchAll(/CResGFF::WriteField([A-Za-z]+)[\s\S]*?"([A-Za-z0-9_]+)"[^;]*;/g)];assert.equal(calls.length,36);assert.equal(calls.filter(v=>v[1]==='WORDandBYTE').length,19);
for(const key of ['customize0','customize_portrait_callback','customizeFlow0','customizeSave1','customizeWordByte','customizeAttach_portrait','customizeAttach_appearance','customizeAttach_info'])assert.ok(source.rows[key].normalized_result.pseudocode.length>100,key);
const failed=await read('reports/native-customization-preservation-v1.json');assert.equal(failed.success,false);
const archive='backups/native-customization-preservation-v1.zip',checkpoint=await read(archive+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file+' changed since checkpoint');}
const result={success:true,goalComplete:false,fullUiParity:false,customizeUiImplemented:false,customizeStorageImplemented:false,nativeChecks,originalInstructionObservations:120,nativeSuccessfulPolicyComparisons:80,readOnlyInstalledBics:39,publicGameplayConnections:0,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,limits:'Byte preparation and original flow evidence only. Native editor, aliases/atomic storage/catalog refresh, full save/cancel lifecycle, graphical/role/scale/audio acceptance and saved-copy original-server admission remain open.'};
await fs.writeFile(path.join(home,'reports/native-customization-preservation-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...result,evidence:undefined}));
