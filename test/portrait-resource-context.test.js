import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {ResourceResolver,decodeResourceText,INSTALLED_PORTRAIT_TYPES} from '../src/resource_archive.js';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
const encode=s=>new TextEncoder().encode(s),file=(name,value,reads=[])=>({name:name.split('/').at(-1),webkitRelativePath:name,arrayBuffer:async()=>{reads.push(name);return encode(value).buffer;}});
const layer=(name,entries)=>({name,catalog:new Map(entries),hasResource:(ref,type)=>entries.some(([key])=>key===ref.toLowerCase()+':'+type),getResource:async(ref,type)=>encode(entries.find(([key])=>key===ref.toLowerCase()+':'+type)[1]).buffer});
const resolver=files=>new ResourceResolver({entries:new Map()},{resources:new Map(),bifNames:[],sources:[]},files);
test('installed portrait file indexing is lazy, flat, case-insensitive and image-only',async()=>{
 const reads=[],r=resolver([file('Install/data/prt/Po_Test_M.TGA','portrait',reads),file('data/prt/po_test_h.dds','huge',reads),file('data/prt/classes.2da','never rules',reads),file('data/prt/nested/po_nested_m.tga','not a flat entry',reads)]);
 assert.deepEqual(reads,[]);assert.deepEqual(r.portraitNames().sort(),['po_test_h','po_test_m']);assert.equal(r.hasResource('classes',2017),false);assert.equal(r.hasResource('po_nested_m',3),false);assert.equal(r.resourceLocation('PO_TEST_M',3),2);assert.equal(decodeResourceText(await r.getResource('PO_TEST_M',3)),'portrait');assert.equal(reads.length,1);
});
test('native installed90M portraits win over server40M images; user91M portraits win over installed images',async()=>{
 const r=resolver([file('data/prt/po_same_m.tga','install')]);r.layers=[layer('server',[['po_same_m:3','server'],['classes:2017','server rules']])];r.haks=[{entries:new Map([['po_same_m:3',encode('hak')]])}];r.module.entries.set('po_same_m:3',encode('module'));
 assert.equal(decodeResourceText(await r.getResource('po_same_m',3)),'install');assert.equal((await r.getTextureResource('po_same_m')).type,3);
 r.priorityLayers.unshift({...layer('user',[['po_same_m:3','user']]),resourceKeys:()=>['po_same_m:3'],nativePriority:91000000});assert.equal(decodeResourceText(await r.getResource('po_same_m',3)),'user');assert.equal(decodeResourceText(await r.getResource('classes',2017)),'server rules');
});
test('selected high-priority portrait read failure does not fall through to a server image',async()=>{
 const r=resolver([{name:'broken.tga',webkitRelativePath:'data/prt/po_bad_m.tga',arrayBuffer:async()=>{throw Error('Selected portrait read failed');}}]);let lowerReads=0;r.layers=[{hasResource:()=>true,getResource:async()=>{lowerReads++;return encode('lower').buffer;}}];await assert.rejects(r.getResource('po_bad_m',3),/Selected portrait read failed/);assert.equal(lowerReads,0);
});
test('separate selected server contexts retain their own rules while mounting installed/user portraits at native image priorities',async()=>{
 const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-portrait-resources-')),install=path.join(temporary,'install'),userDirectory=path.join(temporary,'profile');
 try{
  const key=new Uint8Array(64),view=new DataView(key.buffer);key.set(encode('KEY V1  '));view.setUint32(16,64,true);view.setUint32(20,64,true);
  for(const p of[path.join(install,'data','prt'),path.join(userDirectory,'portraits')])await fs.mkdir(p,{recursive:true});await fs.writeFile(path.join(install,'data','nwn_base.key'),key);
  await fs.writeFile(path.join(install,'data','prt','po_same_m.tga'),'installed');await fs.writeFile(path.join(install,'data','prt','po_install_m.dds'),'installed-only');await fs.writeFile(path.join(userDirectory,'portraits','po_same_m.tga'),'user');await fs.writeFile(path.join(userDirectory,'portraits','leaked.2da'),'not rules');
  const a=await openServerResourceContext({install,userDirectory,resolved:[{kind:'nwsync',name:'A',resource:layer('A',[['classes:2017','A rules'],['a_only:2017','A only'],['po_same_m:3','A image']])}]}),b=await openServerResourceContext({install,userDirectory,resolved:[{kind:'nwsync',name:'B',resource:layer('B',[['classes:2017','B rules'],['po_same_m:3','B image']])}]});
  assert.deepEqual(a.priorityLayers.map(l=>l.nativePriority),[91000000,90000000]);assert.equal(decodeResourceText(await a.getResource('classes',2017)),'A rules');assert.equal(decodeResourceText(await b.getResource('classes',2017)),'B rules');assert.equal(b.hasResource('a_only',2017),false);assert.equal(b.hasResource('leaked',2017),false);
  for(const r of[a,b]){assert.equal(decodeResourceText(await r.getResource('po_same_m',3)),'user');assert.ok(r.portraitNames().includes('po_install_m'));assert.ok(r.resourceNames(2033).includes('po_install_m'));}
 }finally{const resolved=path.resolve(temporary),expected=path.resolve(os.tmpdir());assert.equal(path.dirname(resolved).toLowerCase(),expected.toLowerCase());assert.ok(path.basename(resolved).startsWith('nwn-portrait-resources-'));await fs.rm(resolved,{recursive:true,force:true});}
});
test('installed portrait type admission matches the complete original ushort callback domain',async()=>{
 const original=JSON.parse(await fs.readFile(new URL('../backups/animations/native-installed-portrait-filter-v1.json',import.meta.url),'utf8'));assert.equal(original.typesTested,65536);assert.deepEqual(original.accepted,[...INSTALLED_PORTRAIT_TYPES]);
});
