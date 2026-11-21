import test from 'node:test';
import assert from 'node:assert/strict';
import {computeSafeLocationInDirection as search} from '../src/safe_direction.js';
const f=Math.fround;
function fixture(){
  const area={},path={field4:.25,fieldC:2},out={point:[99,99,99]},trace=[];
  const p={height:(a,point)=>{trace.push(['height',point.slice()]);return 3;},safePoint:(a,point)=>{trace.push(['safe',point.slice()]);return 0;},
    lineWalkable:(a,from,to)=>{trace.push(['line',from,to]);return 1;},polygons:(...args)=>{trace.push(['polys',...args.slice(1)]);return 1;},warning:m=>trace.push(['warning',m])};
  return{area,path,out,trace,p};
}
test('safe-direction returns height-adjusted origin before requested interval or line queries and binds the path pointer',async()=>{
  const {area,path,out,trace,p}=fixture();p.safePoint=()=>1;
  assert.equal(await search(area,[5,6,9],[0,1,77],1,2,path,1,out,p),1);
  assert.deepEqual(out.point,[5,6,3]);assert.equal(area.nativePathInfo280,path);assert.deepEqual(trace.map(c=>c[0]),['height']);
});
test('safe-direction scans forward then alternating perpendicular offsets in native f32 order, ignores direction Z',async()=>{
  const {area,path,out,trace,p}=fixture();let count=0;p.safePoint=(a,point)=>{trace.push(['safe',point.slice()]);return ++count===5?1:0;};
  assert.equal(await search(area,[5,6,9],[1,0,77],.2,.2,path,0,out,p),1);
  const step=f(f(.2)/f(10)),n=Math.trunc(f(f(f(.2)+f(.01))/step)),forward=f(f(step*f(n))+5);
  assert.deepEqual(trace.filter(c=>c[0]==='safe').map(c=>c[1]),[
    [5,6,3],[forward,6,3],[forward,f(f(-step)+6),3],[forward,f(step+6),3],[forward,f(f(f(-step)*2)+6),3]]);
  assert.deepEqual(out.point,trace.filter(c=>c[0]==='safe').at(-1)[1]);
});
test('safe-direction keeps output on failure and requires exact1 for candidate point/line/polygons',async()=>{
  const {area,path,out,trace,p}=fixture();p.safePoint=()=>2;
  assert.equal(await search(area,[5,6,9],[1,0,0],.1,.1,path,1,out,p),0);assert.deepEqual(out.point,[99,99,99]);
  let count=0;p.safePoint=()=>++count===1?0:1;p.lineWalkable=()=>2;
  assert.equal(await search(area,[5,6,9],[1,0,0],.1,.1,path,1,out,p),0);
  assert.ok(trace.some(c=>c[0]==='polys'));assert.deepEqual(out.point,[99,99,99]);
});
test('safe-direction limits end/10 scan spacing by personal space with the native .1 minimum in that branch',async()=>{
  for(const [radius,end,expected] of [[.05,2,.1],[.25,4,.25],[.25,1,.1]]){
    const {area,path,out,p}=fixture();path.field4=radius;let count=0;
    p.safePoint=()=>++count===3?1:0;
    assert.equal(await search(area,[0,0,0],[1,0,900],expected,end,path,0,out,p),1);
    assert.equal(out.point[0],f(expected));assert.equal(out.point[1],f(-f(expected)));
  }
});
test('unsafe origin disables straight-line requirement and uses original Z for initial polygon height bounds',async()=>{
  const {area,path,out,trace,p}=fixture();let count=0;p.safePoint=()=>++count===1?0:1;p.polygons=(...args)=>{trace.push(['polys',...args.slice(1)]);return 0;};
  assert.equal(await search(area,[5,6,9],[1,0,0],.1,.1,path,1,out,p),1);
  assert.equal(trace.filter(c=>c[0]==='line').length,1);assert.equal(trace.filter(c=>c[0]==='polys').length,1);
  const polygon=trace.find(c=>c[0]==='polys');assert.equal(polygon[3],f(9-f(.1)));assert.equal(polygon[4],f(f(9+2)+f(.1)));
  assert.ok(trace.some(c=>c[0]==='warning'));
});
test('safe-direction null/nonpositive radius emits native warnings; failed providers retain output and canonical path pointer',async()=>{
  const {area,path,out,trace,p}=fixture();assert.equal(await search(area,[],[],0,0,null,0,out,p),0);
  path.field4=0;assert.equal(await search(area,[],[],0,0,path,0,out,p),0);assert.equal(area.nativePathInfo280,path);
  path.field4=.25;p.height=()=>{throw new Error('Missing terrain');};
  await assert.rejects(search(area,[5,6,0],[1,0,0],0,1,path,0,out,p),/Missing terrain/);assert.deepEqual(out.point,[99,99,99]);assert.equal(trace.length,2);
});
