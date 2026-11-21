import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {portraitCandidates} from '../src/portrait_resource.js';
import {loadRasterTexture} from '../src/raster_texture.js';
import {ResourceResolver} from '../src/resource_archive.js';

test('portrait candidate size order/admission matches every original TGA/DDS availability mask',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-portrait-candidates-v1.json',import.meta.url)));
 assert.equal(report.cases.length,6144);
 for(const r of report.cases){
  const candidates=portraitCandidates('portrait_',r.size),calls=[];let selected;
  if(!r.size)selected=candidates[0];else for(const name of candidates){const index='tsmlh'.indexOf(name.at(-1));calls.push([name,3]);if(r.tgaMask&(1<<index)){selected=name;break;}calls.push([name,2033]);if(r.ddsMask&(1<<index)){selected=name;break;}}
  // Native suffix literals are uppercase; resource names are case-insensitive.
  assert.deepEqual(calls,r.calls.map(([name,type])=>[name.toLowerCase(),type]));assert.equal(selected??'portrait_'+'tsmlh'[r.size-1],r.result.toLowerCase());
 }
 assert.deepEqual(portraitCandidates('p',1),['pt','ps','pm','pl','ph']);assert.deepEqual(portraitCandidates('p',5),['ph','pl','pm','ps','pt']);
});
function tga(){const b=new Uint8Array(22);b[2]=2;b[12]=b[14]=1;b[16]=32;b[17]=0x20;b.set([0,255,0,255],18);return b.buffer;}
function dds(){const b=new Uint8Array(136),v=new DataView(b.buffer);for(const[o,n]of[[0,0x20534444],[4,124],[8,0x1007],[12,4],[16,4],[28,1],[76,32],[80,4],[84,0x31545844],[108,0x1000]])v.setUint32(o,n,true);v.setUint16(128,0xf800,true);return b.buffer;}
function fixture(type){const r=new ResourceResolver({entries:new Map()},{resources:new Map([['portrait:3',{}]])},[]),calls=[];r.layers=[{hasResource:(_n,t)=>t===type,getResource:async()=>dds()}];r.getResource=async(n,t)=>{calls.push([n,t]);return t===3?tga():dds();};return{r,calls};}
test('UI decoding honors selected server DDS instead of installed TGA and never crosses resolver owners',async()=>{
 const a=fixture(2033),b=fixture(3),ta=await loadRasterTexture(a.r,'portrait'),tb=await loadRasterTexture(b.r,'portrait');
 try{assert.equal(ta.isCompressedTexture,true);assert.equal(ta.image.width,4);assert.equal(tb.isDataTexture,true);assert.equal(tb.image.width,1);assert.deepEqual(a.calls,[['portrait',2033]]);assert.deepEqual(b.calls,[['portrait',3]]);}finally{ta.dispose();tb.dispose();}
});
test('UI selected resource failure propagates without reading a lower image',async()=>{
 const calls=[],resolver={getTextureResource:async()=>{throw Error('Corrupt selected DDS');},getResource:async(...args)=>calls.push(args)};await assert.rejects(loadRasterTexture(resolver,'portrait'),/Corrupt selected DDS/);assert.deepEqual(calls,[]);
});
test('malformed KTX is rejected before becoming a blank UI texture',async()=>{
 await assert.rejects(loadRasterTexture({getTextureResource:async()=>({type:2073,bytes:new ArrayBuffer(8)})},'portrait'),/KTX image header/);
});
