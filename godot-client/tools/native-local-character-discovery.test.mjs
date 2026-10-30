import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {discoverLocalCharacterFiles} from './native-local-character-discovery.mjs';
async function fixture(){
 const root=await fs.mkdtemp(fileURLToPath(new URL('../reports/vault-discovery-',import.meta.url))),written=[],directories=new Set([root]);
 const install=path.join(root,'install'),profileDirectory=path.join(root,'profile'),modsDirectory=path.join(root,'workshop/content/704450');
 async function write(relative,bytes='opaque raw bytes'){
  const file=path.join(root,relative);let dir=path.dirname(file);
  while(dir!==root){directories.add(dir);dir=path.dirname(dir);}
  await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,bytes);written.push(file);return file;
 }
 return{root,options:{install,profileDirectory,modsDirectory},write,async close(){
  for(const file of written)await fs.unlink(file);
  for(const dir of [...directories].sort((a,b)=>b.length-a.length)){assert.ok(dir===root||dir.startsWith(root+path.sep));await fs.rmdir(dir);}
 }};
}
test('Catalog appends install, profile and enabled Workshop rows without interpreting BIC bytes',async()=>{
 const f=await fixture();try{
  await f.write('install/data/lcv/base.bic');await f.write('profile/localvault/hero12.BIC');await f.write('profile/localvault/nested/ignored.bic');await f.write('profile/localvault/readme.txt');
  await f.write('workshop/content/704450/11/localvault/mod.bic');await f.write('workshop/content/704450/22/localvault/disabled.bic');
  const found=await discoverLocalCharacterFiles({...f.options,disabledMods:['22']});
  assert.deepEqual(found.rows.map(v=>[v.source,v.catalogStem]),[['installed','base'],['local','hero12'],['workshop','mod']]);
  assert.deepEqual(found.rows.slice(0,2).map(v=>v.key),['installed:base.bic','local:hero12.BIC']);assert.match(found.rows[2].key,/^workshop:[a-f0-9]{64}$/);
  assert.equal(found.roots.length,3);assert.ok(found.rows.every(v=>v.file.startsWith(f.root+path.sep)&&v.nativeFile===undefined));
  assert.deepEqual(await discoverLocalCharacterFiles({...f.options,disabledMods:['22']}),found);
 }finally{await f.close();}
});
test('Duplicate rows retain enumeration identity while byte lookup follows Workshop, profile, installed precedence',async()=>{
 const f=await fixture();try{
  await f.write('install/data/lcv/shared.bic','installed');await f.write('profile/localvault/shared.bic','profile');
  const first=await f.write('workshop/content/704450/22/localvault/SHARED.BIC','first Workshop');await f.write('workshop/content/704450/11/localvault/shared.bic','second Workshop');
  await f.write('workshop/appworkshop_704450.acf','"AppWorkshop"\n{\n"WorkshopItemsInstalled"\n{\n"22"\n{\n}\n"11"\n{\n}\n}\n}');
  const all=await discoverLocalCharacterFiles(f.options);assert.equal(all.rows.length,4);assert.equal(new Set(all.rows.map(v=>v.key)).size,4);assert.ok(all.rows.every(v=>v.file===first&&v.storageSource==='workshop'));
  const local=await discoverLocalCharacterFiles({...f.options,disabledMods:['11','22']});assert.equal(local.rows.length,2);assert.ok(local.rows.every(v=>v.file===path.join(f.options.profileDirectory,'localvault/shared.bic')&&v.storageSource==='local'));
  assert.equal(await fs.readFile(path.join(f.options.install,'data/lcv/shared.bic'),'utf8'),'installed');
 }finally{await f.close();}
});
test('Selected root containing only localvault is an enabled local mod and missing vaults are empty',async()=>{
 const f=await fixture();try{
  assert.deepEqual((await discoverLocalCharacterFiles(f.options)).rows,[]);
  await f.write('workshop/content/704450/localvault/root.bic');
  assert.equal((await discoverLocalCharacterFiles(f.options)).rows[0].source,'workshop');
  assert.deepEqual((await discoverLocalCharacterFiles({...f.options,disabledMods:['local']})).rows,[]);
 }finally{await f.close();}
});
