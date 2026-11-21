import test from 'node:test';
import assert from 'node:assert/strict';
import { PathInformation } from '../src/path_information.js';
import { plotPath,plotPathInArea,plotBlockedPath,flipPathEndpoints } from '../src/path_plot.js';

const f=Math.fround;
function fixture(){
  const path=new PathInformation(0x80000001),area={id:0x80000002},calls=[];
  for(const [offset,value] of [[0x4c,10],[0x50,0],[0x54,0],[0x64,0],[0x68,0],[0x6c,0]])path.raw.setFloat32(offset,value,true);
  path.raw.setUint32(0x60,area.id,true);path.raw.setUint32(0x70,area.id,true);
  const p={area:id=>id===area.id?area:null,directLine:(...args)=>{calls.push(args);return 1;},markAI:value=>calls.push(['AI',value]),
    resetInterTile:path=>path.resetInterTile(),resetGrid:path=>path.resetGrid()};
  return{path,area,p,calls};
}
test('native direct plot stops at desired radius and retains owner/target and ordered native XY allocation',async()=>{
  const {path,area,p,calls}=fixture();path.raw.setFloat32(0x58,2,true);path.field28=0x80000003;
  assert.equal(await plotPathInArea(path,1000,p),2);
  assert.deepEqual([...path.allocations.get(0x80)],[0,0,8,0]);assert.equal(area.nativePathInfo280,path);
  assert.equal(path.raw.getInt32(0x7c,true),4);assert.equal(path.field28,0x80000003);
  assert.deepEqual(calls[0].slice(1),[[0,0,-0],[8,0,-0],f(.6),.5,1]);
  assert.equal(path.raw.getInt32(0x1a4,true),1);
  p.directLine=()=>assert.fail('retry must use cached direct result');assert.equal(await plotPathInArea(path,1000,p),2);
});
test('stop radius uses full 3D length; matching XY skips query and does not overwrite cached result',async()=>{
  const {path,p}=fixture();path.raw.setFloat32(0x54,10,true);path.raw.setFloat32(0x58,20,true);path.raw.setInt32(0x1a4,-3,true);
  p.directLine=()=>assert.fail('already within stop radius');assert.equal(await plotPathInArea(path,1000,p),2);
  assert.deepEqual([...path.allocations.get(0x80)],[0,0,0,0]);assert.equal(path.raw.getInt32(0x1a4,true),-3);
});
test('fractional plot searches from latest successful point and clears only its native temporary flags',async()=>{
  const {path,p,calls}=fixture();path.raw.setInt32(0x1a0,1,true);path.field19c=1;
  p.directLine=(area,start,end)=>{calls.push([start.slice(),end.slice()]);return Number(end[0]<=6);};
  assert.equal(await plotPathInArea(path,1000,p),2);
  assert.deepEqual(calls.map(c=>[c[0][0],c[1][0]]),[[0,10],[0,5],[5,7.5],[5,6.25],[5,5.625],[5.625,5.9375],[5.9375,6.09375]]);
  assert.deepEqual([...path.allocations.get(0x80)],[0,0,5.9375,0]);assert.equal(path.field19c,0);assert.equal(path.raw.getInt32(0x1a0,true),0);
});
test('blocked plot requires actual search owner; no route is fabricated on resource/provider failure',async()=>{
  const {path,p}=fixture();p.directLine=()=>-1;
  await assert.rejects(plotPathInArea(path,1000,p),/provider creature/);assert.equal(path.allocations.has(0x80),false);
  assert.equal(path.raw.getInt32(0x78,true),1); // Constructor value, not a new completion write.
});

function blockedFixture(direct=-1){
  const v=fixture();v.path.raw.setInt32(0,1,true);v.path.raw.setInt32(0x2c,1,true);
  v.p={...v.p,creature:()=>({nativeAILevel7c:2}),aiLevel:o=>o.nativeAILevel7c,client:()=>null,
    areaPlot:(_area,_path,budget)=>{v.calls.push(['tile',budget]);return 3;},
    gridPlot:(_area,_path,budget,force)=>{v.calls.push(['grid',budget,force]);return 1;}};
  v.context={area:v.area,start:[0,0,-0],end:[10,0,-0],radius:v.path.field4,height:v.path.fieldC,direct};return v;
}
test('tile search failure within twenty units schedules grid search, preserving the exact threshold boundary',async()=>{
  const {path,p,context,calls}=blockedFixture();
  assert.equal(await plotBlockedPath(path,321,context,p),1);assert.equal(path.field19c,1);assert.deepEqual(calls,[['tile',321]]);
  assert.equal(await plotBlockedPath(path,321,context,p),1);assert.deepEqual(calls.at(-1),['grid',321,false]);
  path.field19c=0;context.end=[20,0,-0];assert.equal(await plotBlockedPath(path,321,context,p),3);
  assert.equal(path.field19c,0,'squared distance exactly 400 does not request a grid retry');
});
test('player pathfinding level chooses native budget/threshold; pending becomes failure only above threshold',async()=>{
  for(const [level,budget,threshold] of [[0,1000,100],[1,7000,10],[2,12000,5],[3,50000,1],[255,321,100]]){
    const {path,p,context,calls}=blockedFixture(-3);p.client=()=>({});p.pathfindingLevel=()=>level;
    path.raw.setInt32(0x2c,threshold,true);
    assert.equal(await plotBlockedPath(path,321,context,p),1);assert.deepEqual(calls.at(-1),['grid',budget,true]);
    path.raw.setInt32(0x2c,threshold+1,true);assert.equal(await plotBlockedPath(path,321,context,p),3);
  }
});
test('forced grid search keeps fractional flag false for other direct failures and unsupported direct codes skip tile search',async()=>{
  for(const direct of [-2,-1,0,2,-5]){
    const {path,p,context,calls}=blockedFixture(direct);context.end=[30,0,-0];
    assert.equal(await plotBlockedPath(path,10,context,p),3);
    assert.equal(calls.length,[-2,-1].includes(direct)?1:0);
    path.field19c=1;assert.equal(await plotBlockedPath(path,10,context,p),1);assert.deepEqual(calls.at(-1),['grid',10,false]);
  }
});
test('very-low-AI actor skips search and native type-zero fallback builds partial route from latest success',async()=>{
  const {path,p,context,calls}=blockedFixture();p.aiLevel=()=>0;path.raw.setInt32(0,0,true);path.raw.setInt32(0x74,1,true);
  p.directLine=(_area,start,end)=>{calls.push([start[0],end[0]]);return Number(end[0]<=6);};
  assert.equal(await plotBlockedPath(path,10,context,p),2);
  assert.deepEqual(calls,[[0,5],[5,7.5],[5,6.25],[5,5.625],[5.625,5.9375],[5.9375,6.09375]]);
  assert.deepEqual([...path.allocations.get(0x80)],[0,0,5.9375,0]);assert.equal(path.raw.getInt32(0x74,true),0);
  assert.equal(path.field19c,0);
});
test('reverse plot swaps complete endpoints/areas and reverses waypoint pairs without numerical conversion',async()=>{
  const {path,p}=fixture();path.raw.setInt32(0x74,1,true);
  assert.equal(await plotPathInArea(path,1000,p),2);assert.deepEqual([...path.allocations.get(0x80)],[10,0,0,0]);
  assert.equal(path.raw.getFloat32(0x4c,true),0);assert.equal(path.raw.getFloat32(0x64,true),10);assert.equal(path.raw.getInt32(0x74,true),0);
  path.raw.setUint32(0x4c,0x7fc00017,true);path.raw.setUint32(0x64,0x80000000,true);flipPathEndpoints(path);
  assert.equal(path.raw.getUint32(0x64,true),0x7fc00017);assert.equal(path.raw.getUint32(0x4c,true),0x80000000);
});
test('module plot preserves completed early return; new same-area path owns one canonical route ID',async()=>{
  const {path,area,p,calls}=fixture();assert.equal(await plotPath(path,1000,p),2);assert.deepEqual(calls,[]);
  path.raw.setInt32(0x48,1,true);path.raw.setInt32(0x78,0,true);assert.equal(await plotPath(path,1000,p),2);
  assert.deepEqual([...path.allocations.get(0xa8)],[area.id]);assert.equal(path.raw.getInt32(0xa4,true),1);assert.deepEqual(calls[0],['AI',1]);
  path.raw.setUint32(0x60,0x80000004,true);path.raw.setInt32(0x78,0,true);await assert.rejects(plotPath(path,1000,p),/provider interArea/);
});
test('native grid tolerance and independent resets preserve other route and goal fields',()=>{
  const {path}=fixture();path.raw.setFloat32(0x58,1.5,true);path.computeGridTolerance();assert.equal(path.raw.getInt32(0x5c,true),15);
  path.field4=.8;path.computeGridTolerance();assert.equal(path.raw.getInt32(0x5c,true),1);
  for(const offset of [0xd0,0xd8,0xe8,0xf0,0x120,0x190,0x1b0,0x170,0x1e0,0x1d0,0x80])path.allocations.set(offset,new Uint8Array(8));
  path.field19c=7;path.resetInterTile();assert.equal(path.allocations.has(0xd0),false);assert.equal(path.allocations.has(0x190),true);
  path.resetGrid();assert.equal(path.allocations.has(0x190),false);assert.equal(path.allocations.has(0x80),true);
  assert.equal(path.raw.getFloat32(0x4c,true),10);assert.equal(path.field19c,7);
});
