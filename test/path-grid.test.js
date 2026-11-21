import test from 'node:test';
import assert from 'node:assert/strict';
import { PathInformation } from '../src/path_information.js';
import { pathInt as i,setPathInt as si,gridStepSize,nativeFastRsqrt,createGridPath,gridPathInfo,
  gridPathPoints,gridPointSearched,addGridPoint } from '../src/path_grid_storage.js';
import { plotGridPath,gridSearchPath,gridSearchDirection } from '../src/path_grid.js';
import { smoothPath,smoothSelectNodes,computeBestCorner } from '../src/path_smoothing.js';
const f=Math.fround;
function fixture(){
  const path=new PathInformation(0x80000000),area={},calls=[];
  for(const [offset,value] of [[0x60,1],[0x70,1]])si(path,offset,value);
  for(const [offset,value] of [[0x64,4],[0x68,5],[0x4c,6],[0x50,5]])path.raw.setFloat32(offset,value,true);
  const p={markGridAI:value=>calls.push(['AI',value]),microseconds:()=>0n,
    directLine:(_area,a,b)=>{calls.push([a.slice(),b.slice()]);return 1;},
    smooth:(area,path)=>smoothPath(area,path,p)};
  return {path,area,p,calls};
}
function storage(){
  const path=new PathInformation(1);si(path,0x17c,64);si(path,0x198,10000);
  path.allocations.set(0x1e0,new DataView(new ArrayBuffer(0x300)));path.allocations.set(0x1d0,Array(32));
  path.allocations.set(0x190,new Int32Array(128));path.allocations.set(0x1b0,new Uint8Array(40000));
  si(path,0x1b8,64);si(path,0x1bc,64);return path;
}
test('native grid records preserve value-copy semantics, strict best distance and the thirty-two-path cap',()=>{
  const path=storage(),index=createGridPath(path),info=gridPathInfo(path,index);
  assert.equal(info.getInt32(0,true),1000000);info.setInt32(0,123,true);
  assert.equal(gridPathInfo(path,index).getInt32(0,true),1000000);
  addGridPoint(path,index,2,3,1);const points=gridPathPoints(path,index);
  assert.deepEqual([...points.slice(0,2)],[2,3]);assert.equal(gridPointSearched(path,2,3),true);
  assert.equal(i(path,0x198),13);assert.equal(i(path,0x188),1);
  addGridPoint(path,index,-2,-3,4);assert.equal(i(path,0x188),1,'equal squared distance retains earlier best');
  const record=gridPathInfo(path,index);assert.equal(record.getInt32(4,true),2);assert.equal(record.getInt32(8,true),5);
  for(let n=1;n<32;n++)assert.equal(createGridPath(path),n);assert.equal(createGridPath(path),-1);
  assert.equal(i(path,0x1d8),32);
});
test('native grid spacing selects tenth-unit special radii and fast inverse root preserves its single refinement',()=>{
  const path=new PathInformation(1);
  for(const [radius,step] of [[0,.1],[.1,.1],[.6,.1],[.65,.1],[.66,.66]]){path.field4=radius;assert.equal(gridStepSize(path),f(step));}
  assert.equal(nativeFastRsqrt(1),f(.9983071684837341));assert.notEqual(nativeFastRsqrt(4),.5);
});
test('grid plot skips another area after marking grid AI; clear goal produces native XY waypoints and frees search owners',async()=>{
  const {path,area,p,calls}=fixture();si(path,0x70,2);assert.equal(await plotGridPath(area,path,1000,false,p),3);
  assert.deepEqual(calls,[['AI',1]]);si(path,0x70,1);calls.length=0;
  assert.equal(await plotGridPath(area,path,1000,false,p),2);
  assert.equal(i(path,0x7c),4);assert.deepEqual([...path.allocations.get(0x80)],[4,5,6,5]);
  assert.equal(i(path,0x1d8),0);assert.equal(path.allocations.has(0x1b0),false);assert.equal(area.nativeGridStopped2b4,0);
  assert.ok(calls.some(c=>Array.isArray(c[0])&&c[1][0]===6));
});
test('grid search alternates preferred sides and creates a branch from original record, leaving closed flag unchanged',async()=>{
  const path=storage(),area={nativeGridStopped2b4:0,nativeGridProbes2b8:0},calls=[];
  si(path,0x150,10);createGridPath(path);addGridPoint(path,0,0,10,1);
  path.raw.setFloat32(0x15c,1,true);path.raw.setFloat32(0x168,1,true);
  const p={microseconds:()=>0n,directLine:(_area,a,b)=>{calls.push([a.slice(),b.slice()]);return b[0]!==0?1:0;}};
  await gridSearchPath(area,path,0,p);
  assert.equal(i(path,0x1d8),2);
  assert.deepEqual([...gridPathPoints(path,0).slice(0,4)],[0,10,1,9]);
  assert.deepEqual([...gridPathPoints(path,1).slice(0,4)],[0,10,-1,9]);
  assert.deepEqual(calls.slice(0,3).map(c=>[c[1][0],-c[1][2]]),[[0,9],[1,9],[-1,9]]);
  assert.equal(gridPathInfo(path,0).getUint8(20),0);assert.equal(gridPathInfo(path,1).getInt32(4,true),2);
});
test('grid direction failure leaves original output; long probe bisects integer coordinates and ignores stationary candidates',async()=>{
  const {path,area}=fixture();path.raw.setFloat32(0x15c,1,true);path.raw.setFloat32(0x168,1,true);
  const out=[99,99],calls=[],p={directLine:(_area,a,b)=>{calls.push([a[0],b[0]]);return Number(b[0]>=4);}};
  assert.equal(await gridSearchDirection(area,path,1,8,0,-1,0,true,out,p),true);assert.deepEqual(out,[4,0]);
  assert.deepEqual(calls,[[8,0],[8,4],[4,2],[4,3],[4,4],[4,4],[4,4]]);
  p.directLine=()=>-2;assert.equal(await gridSearchDirection(area,path,1,8,0,-1,0,false,out,p),false);assert.deepEqual(out,[8,0]);
});
test('grid probes obey strict budget boundary after each twenty directions and retain pending allocations',async()=>{
  const {path,area,p}=fixture();let ticks=0n;p.microseconds=()=>ticks;
  p.directLine=(_area,a,b)=>{ticks++;return b[2]===-5?0:1;};
  assert.equal(await plotGridPath(area,path,0,false,p),1);
  assert.equal(area.nativeGridProbes2b8,20);assert.equal(area.nativeGridStopped2b4,1);
  assert.ok(i(path,0x1d8)>0);assert.ok(path.allocations.has(0x1b0));assert.equal(path.allocations.has(0x80),false);
  p.directLine=()=>1;ticks=0n;assert.equal(await plotGridPath(area,path,1000,false,p),2);
  assert.equal(path.allocations.has(0x1b0),false);assert.equal(i(path,0x1d8),0);
});
test('blocked grid cannot fabricate a successful path and does not retain exhausted searches',async()=>{
  const {path,area,p}=fixture();p.directLine=()=>0;
  assert.equal(await plotGridPath(area,path,1000,false,p),3);
  assert.equal(path.allocations.has(0x80),false);assert.equal(i(path,0x1d8),0);
});
test('smoothing direct-copy mode retains raw signed zero and NaN payload, replacing prior waypoints',async()=>{
  const {path,area,p}=fixture(),source=new Float32Array(4),words=new Uint32Array(source.buffer);
  words.set([0x80000000,0x7fc00017,0x3f800000,0]);path.allocations.set(0x90,source);
  path.allocations.set(0x80,new Float32Array([99,99]));si(path,0x88,4);si(path,0x14,1);
  assert.equal(await smoothPath(area,path,p),1);assert.deepEqual([...new Uint32Array(path.allocations.get(0x80).buffer)],[...words]);
});
test('native selection subdivides before LOS shortening and probes farthest then half above four',async()=>{
  const {path,area}=fixture(),source=new Float32Array([0,0,4,0]);
  assert.deepEqual([...await smoothSelectNodes(area,path,source,4,1,0,{})],[0,0,1,0,2,0,3,0,4,0]);
  const calls=[],points=new Float32Array(Array.from({length:20},(_,n)=>n%2?0:n/2));
  const result=await smoothSelectNodes(area,path,points,20,0,1,{directLine:(_area,a,b)=>{calls.push([a[0],b[0]]);return Number(b[0]-a[0]<=2);}});
  assert.deepEqual(calls.slice(0,4),[[0,9],[0,4],[0,3],[0,2]]);
  assert.deepEqual([...result],[0,0,2,0,4,0,6,0,8,0,9,0]);
});
test('corner smoothing skips straight or tiny segments; right angle records two rounded corner points',async()=>{
  const {path,area,p}=fixture();assert.equal(await computeBestCorner(area,path,[0,0],[1,0],[2,0],p),null);
  assert.equal(await computeBestCorner(area,path,[0,0],[0.00001,0],[.00001,1],p),null);
  assert.deepEqual(await computeBestCorner(area,path,[0,0],[2,0],[2,2],p),[[.25,0],[2,1.75]]);
});
