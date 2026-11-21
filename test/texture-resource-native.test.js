import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {ResourceResolver} from '../src/resource_archive.js';
import {nativeCompressedTextureType,resolveTextureResource} from '../src/texture_resource.js';

test('compressed format admission matches 625 original GetCompressedRaster branches',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-texture-format-selection-v1.json',import.meta.url)));
 assert.equal(data.cases.length,625);
 for(const row of data.cases)assert.equal(nativeCompressedTextureType(row.locations),row.selected,JSON.stringify(row.locations));
});
const bytes=new Uint8Array([1,2,3]);
const layer=(type,fail=false)=>({hasResource:(_name,t)=>type===t,getResource:async()=>{if(fail)throw Error('Corrupt winning resource');return bytes.buffer;}});
const resolver=()=>new ResourceResolver({entries:new Map()},{resources:new Map(),bifNames:[]},[]);
test('format selection retains server TGA over installed DDS and uses server DDS on equal location',async()=>{
 const r=resolver();r.key.resources.set('stone:2033',{});r.layers=[layer(3)];
 assert.equal((await r.getTextureResource('stone')).type,3);
 r.layers=[layer(3),layer(2033)];assert.equal((await r.getTextureResource('stone')).type,2033);
 r.layers=[layer(2033)];r.fallbackLayers=[layer(3)];assert.equal((await r.getTextureResource('stone')).type,3);
});
test('a selected resource read failure cannot silently use a lower source or format',async()=>{
 const r=resolver();r.layers=[layer(2033,true),layer(3)];
 await assert.rejects(resolveTextureResource(r,'stone'),/Corrupt winning resource/);
});
test('fresh resolver never inherits another server texture selection',async()=>{
 const a=resolver(),b=resolver();a.layers=[layer(2033)];b.layers=[layer(3)];
 assert.equal((await resolveTextureResource(a,'stone')).type,2033);
 assert.equal((await resolveTextureResource(b,'stone')).type,3);
});
test('a preferred unsupported native16-bit image is diagnosed instead of substituting a lower texture',async()=>{
 const r=resolver();r.layers=[layer(2059)];r.key.resources.set('stone:3',{});
 await assert.rejects(r.getTextureResource('stone'),/unsupported decoder/);
});
