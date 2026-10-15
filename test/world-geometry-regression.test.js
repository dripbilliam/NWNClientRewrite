import test from 'node:test';
import assert from 'node:assert/strict';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {loadAreaWalkmesh} from '../src/area.js';
import {moveOnWalkmesh} from '../src/walkmesh.js';
import {RuntimeDiagnostics} from '../src/runtime_diagnostics.js';
import {WalkmeshNavigator} from '../src/navigation.js';

function combinedMesh() {
  const buffer=new ArrayBuffer(2188),d=new DataView(buffer),u=(o,v)=>d.setUint32(o,v,true),h=(o,v)=>d.setUint16(o,v,true),f=(o,v)=>d.setFloat32(o,v,true);
  u(4,2048);u(8,128);u(84,232);u(88,1);new Uint8Array(buffer).set(new TextEncoder().encode('combined'),20);
  const node=244,base=12,raw=2060;u(node+108,0x21);
  new Uint8Array(buffer).set(new TextEncoder().encode('floor'),node+32);
  u(node+0x78,1100);u(node+0x7c,1);h(base+1100+26,0);h(base+1100+28,1);h(base+1100+30,2);
  u(node+0xdc,1);u(node+0x204,1200);u(node+0x208,2);u(node+0x210,1220);u(node+0x214,2);
  u(base+1200,3);u(base+1204,3);u(base+1220,48);u(base+1224,54);
  u(node+0x21c,0xffffffff);u(node+0x224,3);u(node+0x22c,0);h(node+0x230,4);
  u(node+0x244,0xffffffff);u(node+0x248,0xffffffff);
  [[0,0,0],[2,0,0],[2,2,0],[0,2,0]].flat().forEach((v,i)=>f(raw+i*4,v));
  [0,1,2,0,2,3].forEach((v,i)=>h(raw+48+i*2,v));
  return buffer;
}
test('binary combined meshes render all native draw groups rather than only original MaxFaces',()=>{
  const buffer=combinedMesh(),node=parseBinaryMdl(buffer).nodes[0];
  assert.deepEqual(node.faces.map(f=>f.slice(0,3)),[[0,1,2],[0,2,3]]);
  new DataView(buffer).setUint16(2060+58,4,true);
  assert.throws(()=>parseBinaryMdl(buffer),/draw index outside/);
});
test('binary draw groups reject truncated raw buffers and non-triangle counts',()=>{
  const b=combinedMesh(),d=new DataView(b);d.setUint32(1212,4,true);
  assert.throws(()=>parseBinaryMdl(b),/triangle-list draw count/);
  d.setUint32(1212,3,true);d.setUint32(1232,127,true);
  assert.throws(()=>parseBinaryMdl(b),/exceeds file size/);
});

test('area movement crosses snapped exporter seams for every tile orientation and physical surface row',async()=>{
  // The label is deliberately unrelated to its native row index; Walk is an
  // integer predicate. Node translation leaves a narrow gap without snapping.
  const table='2DA V2.0\n\nWalk\n77 2\n',text=`#MAXWALKMESH ASCII
node aabb floor
position 0.000037 -0.000028 0
verts 4
-5 -5 0
5 -5 0
5 5 0
-5 5 0
faces 2
0 1 2 0 0 0 0 0
0 2 3 0 0 0 0 0
endnode
`;
  for(let orientation=0;orientation<4;orientation++){
    const area={resRef:'custom',width:2,tileHeight:5,tiles:Array.from({length:4},()=>({model:'custom',orientation,height:1}))};
    const result=await loadAreaWalkmesh(area,{getResource:async name=>new TextEncoder().encode(name==='surfacemat'?table:text)});
    assert.equal(result.missing.length,0);assert.equal(result.triangles.length,8);
    assert.deepEqual(moveOnWalkmesh(result.triangles,[5,5,-9],0,-2,.22,.9),[5,5,-11]);
    assert.deepEqual(moveOnWalkmesh(result.triangles,[9,5,-5],2,0,.22,.9),[11,5,-5]);
    assert.deepEqual(new WalkmeshNavigator(result.triangles).path([5,5,-9],[5,5,-11]),[[5,5,-11]]);
    assert.equal(moveOnWalkmesh(result.triangles,[1,5,-5],-2,0,.22,.9),null);
  }
});

test('polling omissions retain exact per-object counts, timing and durable close/export totals',async()=>{
  let time=0;const saved=[],log=new RuntimeDiagnostics({now:()=>time,sink:async records=>saved.push(...records)});
  log.repeat('poll.unimplemented','Missing owner',{objectId:1});
  for(let i=0;i<10000;i++){time++;log.repeat('poll.unimplemented','Missing owner',{objectId:1});}
  log.repeat('poll.unimplemented','Missing owner',{objectId:2});
  log.record('engine.unimplemented','Script call');log.record('engine.unimplemented','Script call');
  await log.flush();
  assert.equal(log.records.length,5);assert.equal(saved.length,5);
  const records=saved.filter(r=>r.code==='poll.unimplemented'&&r.context.objectId===1);
  assert.equal(records.reduce((n,r)=>n+r.context.occurrences,0),10001);
  assert.equal(records.at(-1).context.totalOccurrences,10001);
  assert.equal(records.at(-1).context.firstOccurrence,'1970-01-01T00:00:00.000Z');
  assert.equal(records.at(-1).context.lastOccurrence,'1970-01-01T00:00:10.000Z');
  log.repeat('poll.unimplemented','Missing owner',{objectId:1});
  const exported=log.jsonl().trim().split('\n').map(JSON.parse);
  assert.equal(exported.at(-1).context.occurrences,1);assert.equal(exported.at(-1).context.totalOccurrences,10002);
  await log.flush();assert.equal(saved.length,6);
});
