import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {inspectDenseBenchmarkSource,buildDenseBenchmarkFixture} from './native-dense-benchmark-fixture.mjs';
const root=fileURLToPath(new URL('../.cache/loading-benchmark-worlds/arelith-archive-v1',import.meta.url));
const hash=b=>createHash('sha256').update(b).digest('hex');
const source=await inspectDenseBenchmarkSource(root),before=JSON.stringify(source);
const fixture=buildDenseBenchmarkFixture(source);
const header=fixture.records.find(r=>r.value?.kind==='raw-world-begin').value;
const rows=fixture.records.filter(r=>r.value?.kind==='raw-world-chunk').flatMap(r=>r.value.objects);
const same=(a,b)=>assert.deepEqual(a,b);

test('actual sealed source: initial685 static/light rows and completed stationary captured PC',()=>{
 assert.equal(source.seals.timelineSha256,'d955e6fef37015dc189ab480a76bb03b0cc2f44482bdee5a55b45561a23715ee');
 assert.equal(source.seals.catalogSha256,'47068e372f33bbc0f21c1b5c23834ce63a4df2cf8522883083cdac8c7b25195e');
 assert.equal(source.cohort.length,703);assert.equal(source.cohort.filter(r=>r.objectType===9).length,685);
 assert.equal(source.completed.header.serial,258);assert.equal(source.completed.controlled.id,4294965485);
 assert.equal(source.completed.controlled.objectType,5);same(source.completed.controlled.replicated.path,[]);
 assert.equal(source.first.header.data.controlledId,0x7f000000,'pre-PC first snapshot is not silently claimed controlled-ready');
 assert.equal(source.seals.talks[0].sha256,'1d6da70e0659e411012b44f956a093cc8fb61aed3b9355198ba42eb17e0649c9');
});
test('exact bounded2x2 raw layout contains one PC,2740 static/light records,192 original tiles',()=>{
 assert.equal(fixture.summary.objects,2813);assert.equal(rows.length,2813);
 assert.equal(rows.filter(r=>r.objectType===5).length,1);
 assert.equal(rows.filter(r=>r.objectType===9).length,2740);
 assert.equal(fixture.summary.staticModels,2724);assert.equal(fixture.summary.lightOnly,16);
 same([header.data.area.width,header.data.area.height,header.data.area.tiles.length],[16,12,192]);
 same(fixture.summary.offsets,[[0,0,0],[80,0,0],[0,60,0],[80,60,0]]);
 assert.equal(fixture.summary.renderingPrepared,false);assert.equal(fixture.summary.nativeValidated,false);
});
test('IDs preserve base copy and actor, remain external/unique, and remap embedded identities only',()=>{
 same(rows.slice(0,703),source.cohort);
 same(rows.at(-1),source.completed.controlled);
 assert.equal(new Set(rows.map(r=>r.id)).size,rows.length);
 assert.ok(rows.every(r=>r.id>=0x80000000&&r.id<=0xffffffff&&r.areaId===header.data.area.id));
 const originalIds=new Set(source.sourceIds);
 assert.ok(rows.slice(703,-1).every(r=>!originalIds.has(r.id)));
 for(const row of rows.slice(0,-1))for(const key of ['staticState','lightState','mapPin','state'])if(row[key])assert.equal(row[key].id,row.id);
 const retrySource=structuredClone(source);retrySource.sourceIds.push(0x90000000);
 const retry=buildDenseBenchmarkFixture(retrySource);const firstClone=retry.records.find(r=>r.value?.kind==='raw-world-chunk'&&r.value.objects.some(x=>x.id>=0x90000000)).value.objects.find(r=>r.id>=0x90000000);
 assert.notEqual(firstClone.id,0x90000000);
});
test('positions translate in native XY, preserving exact Z/orientation and all raw sound/light properties',()=>{
 for(let c=0;c<4;c++)for(let i=0;i<703;i++){
  const original=source.cohort[i],row=rows[c*703+i],offset=fixture.summary.offsets[c];
  for(const key of ['staticState','lightState','mapPin','state'])if(original[key]){
   same(row[key].position,original[key].position.map((x,n)=>x+offset[n]));
   const rest={...row[key],id:original[key].id,position:original[key].position};same(rest,original[key]);
  }
  assert.equal(row.nativeLifetime,original.nativeLifetime);
 }
});
test('tile grid is expanded in physical row-major order, not repeated whole tile arrays',()=>{
 const old=source.first.header.data.area;
 for(let y=0;y<12;y++)for(let x=0;x<16;x++)same(header.data.area.tiles[y*16+x],old.tiles[(y%6)*8+x%8]);
 assert.notStrictEqual(header.data.area.tiles[0],header.data.area.tiles[8]);
});
test('area static/light/sound/pin lists exactly match cloned raw owner IDs and data',()=>{
 const byId=new Map(rows.map(r=>[r.id,r]));
 for(const [key,field,count]of [['staticPlaceables','staticState',2724],['placeableLights','lightState',32],['mapPins','mapPin',20],['sounds','state',52]]){
  assert.equal(header.data.area[key].length,count);
  assert.equal(new Set(header.data.area[key].map(r=>r.id)).size,count);
  for(const entry of header.data.area[key])same(byId.get(entry.id)[field],entry);
 }
 same(header.data.area.playerMapPins,[]);
});
test('transport fresh full base/order/chunk bounds and exact timeline seals are deterministic',()=>{
 assert.equal(header.count,rows.length);assert.equal(header.serial,1);assert.equal(header.generation,1);
 assert.equal(header.data.bridgeMode,'full');assert.equal(header.data.bridgeBaseSerial,-1);same(header.data.removedObjectIds,[]);
 assert.ok(fixture.records.every((r,i)=>r.sequence===i+1&&r.at===0));
 assert.ok(fixture.records.filter(r=>r.value?.kind==='raw-world-chunk').every(r=>r.value.objects.length<=64));
 for(const row of fixture.records)assert.ok(Buffer.byteLength(JSON.stringify(row))<=1024*1024+4096);
 assert.equal(fixture.recording.timelineSha256,hash(fixture.timeline));assert.equal(fixture.recording.events,fixture.records.length);
 assert.equal(fixture.timeline,buildDenseBenchmarkFixture(source).timeline);
 same(fixture.recording.catalogs,source.recording.catalogs);
});
test('one captured camera and PC/global inventory/UI remain distinct from cloned scenery',()=>{
 const views=fixture.records.filter(r=>r.kind==='view');assert.equal(views.length,1);
 same(views[0].value.camera_state,source.view.camera_state);
 assert.equal(views[0].value.particles,true);assert.equal(views[0].value.particle_collision,true);
 same(header.data.inventory,source.completed.header.data.inventory);same(header.data.ui,source.completed.header.data.ui);
 same(header.data.entry,source.completed.header.data.entry);
 assert.match(fixture.records.find(r=>r.value?.kind==='setup').value.serverLabel,/OFFLINE SYNTHETIC/);
 assert.ok(!fixture.records.some(r=>r.value?.kind==='movement'));
});
test('captured absent/error/unrecorded resource status stays explicit and never becomes completed',()=>{
 assert.equal(fixture.summary.sourceResourceCoverage.namespaceEntries,348244);
 assert.equal(fixture.summary.sourceResourceCoverage.recordedResources,2927);
 assert.equal(fixture.summary.sourceResourceCoverage.nativeActiveClosureValidated,false);
 assert.equal(fixture.summary.sourceResourceCoverage.knownErrors.length,3);
 assert.ok(fixture.summary.sourceResourceCoverage.knownErrors.some(r=>r.resource==='alc_chunk_s01:2002'));
 assert.equal(fixture.summary.sourceResourceCoverage.unrecordedOrFailed,345320);
 assert.equal(fixture.recording.complete,true,'container completeness only, explicitly separated from native validation');
 assert.match(fixture.recording.policy,/not asset\/render completion/);
});
test('bounded single copy is an exact raw static/control source without clone namespace allocations',()=>{
 const single=buildDenseBenchmarkFixture(source,{copiesX:1,copiesY:1,particles:false,particleCollision:false});
 const all=single.records.filter(r=>r.value?.kind==='raw-world-chunk').flatMap(r=>r.value.objects);
 same(all,[...source.cohort,source.completed.controlled]);
 assert.equal(single.summary.tiles,48);assert.equal(single.summary.objects,704);
});
test('unsupported scale, hidden new provenance, duplicate source IDs or unmatched list references reject',()=>{
 for(const args of [{copiesX:3},{copiesY:0},{copiesX:'2'},{particles:1}])assert.throws(()=>buildDenseBenchmarkFixture(source,args));
 const duplicate=structuredClone(source);duplicate.cohort[1].id=duplicate.cohort[0].id;
 assert.throws(()=>buildDenseBenchmarkFixture(duplicate),/Duplicate/);
 const injected=structuredClone(source);injected.cohort[0].nativeClockOwner={physicalToken:99};
 assert.throws(()=>buildDenseBenchmarkFixture(injected),/unsupported fields/);
 const badList=structuredClone(source);badList.first.header.data.area.mapPins[0].id=0x9000ffff;
 assert.throws(()=>buildDenseBenchmarkFixture(badList),/no raw clone source/);
 const pins=structuredClone(source);pins.first.header.data.area.playerMapPins.push({position:[0,0,0]});
 assert.throws(()=>buildDenseBenchmarkFixture(pins),/Player map pins/);
});
test('returned fixture edits cannot mutate inspected source or a subsequent fixture',()=>{
 const changed=buildDenseBenchmarkFixture(source);changed.records.find(r=>r.value?.kind==='raw-world-begin').value.data.area.tiles[0].fields['14']=-1;
 const second=buildDenseBenchmarkFixture(source);
 assert.notEqual(second.records.find(r=>r.value?.kind==='raw-world-begin').value.data.area.tiles[0].fields['14'],-1);
 assert.equal(JSON.stringify(source),before);
});
test('sealed original metadata stays unchanged after all transforms',async()=>{
 assert.equal(hash(await fs.readFile(root+'/recording.json')),source.seals.recordingSha256);
 assert.equal(hash(await fs.readFile(root+'/catalog-1/manifest.json')),source.seals.catalogSha256);
});
