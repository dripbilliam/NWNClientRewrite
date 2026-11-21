import test from 'node:test';
import assert from 'node:assert/strict';
import {bumpFriends,projectBumpLine} from '../src/bump_friends.js';
const f=Math.fround;
function fixture(){
  const actor={position:[2,0,-1],nativePathInfo:{field8:f(.4)}},blocker={position:[3,0,-1],nativePathInfo:{field8:f(.3),field4:f(.25),fieldC:f(1.8)}},trace=[];
  const from=[2,0,0],to=[4,0,0],area={};
  const p={bumpable:()=>1,area:o=>{assert.equal(o,actor);return area;},safePoint:(a,point,path,flag)=>{
    assert.equal(a,area);assert.equal(path,blocker.nativePathInfo);assert.equal(flag,0);trace.push(['safe',point,actor.position.slice()]);return 1;},
    polygons:(...args)=>{trace.push(['polygons',...args.slice(1)]);return 1;},
    setPosition:(o,point,flag)=>{assert.equal(o,blocker);assert.equal(flag,0);trace.push(['position',point,actor.position.slice()]);o.position=point;}};
  return{actor,blocker,trace,p,from,to};
}
test('native bump line projection is infinite, preserves height and uses the zero-length origin',()=>{
  assert.deepEqual(projectBumpLine([1,0,0],[2,0,0],[4,8,-3]),[4,0,-0]);
  assert.deepEqual(projectBumpLine([1,2,-3],[1,2,-3],[10,20,-30]),[1,2,-3]);
  assert.deepEqual(projectBumpLine([0,0,0],[2,2,-2],[3,0,-3]),[2,2,-2]);
});
test('native bumpability veto performs no geometry query or mutation',async()=>{
  const {actor,blocker,p,from,to,trace}=fixture();p.bumpable=()=>0;
  assert.equal(await bumpFriends(actor,blocker,from,to,p),0);assert.deepEqual(actor.position,[2,0,-1]);assert.deepEqual(trace,[]);
});
test('friend moves to f32 clearance from projection; geometry sees the temporary actor position and storage is restored',async()=>{
  const {actor,blocker,p,from,to,trace}=fixture(),storage=actor.position,clearance=f(f(f(.4)+f(.1))+f(.3));
  assert.equal(await bumpFriends(actor,blocker,from,to,p),1);
  assert.equal(actor.position,storage);assert.deepEqual(actor.position,[2,0,-1]);assert.deepEqual(blocker.position,[3,0,-clearance]);
  assert.deepEqual(trace[0],['safe',[3,0,-clearance],[3,0,-0]]);
  assert.equal(trace[1][0],'polygons');assert.deepEqual(trace[1].slice(1,5),[[3,-1],[3,-clearance],f(-.1),f(f(f(1.8))+f(.1))]);
  assert.deepEqual(trace[2],['position',[3,0,-clearance],[3,0,-0]]);
});
test('failed safety/direction searches preserve native forward/reverse/translated order and return0 after restoring the mover',async()=>{
  const {actor,blocker,p,from,to,trace}=fixture();p.safePoint=()=>0;p.polygons=()=>assert.fail('unsafe direct point skips polygon test');
  const searches=[];p.safeDirection=(area,origin,direction,start,end,path,flag,out)=>{searches.push({origin,direction,start,end,path,flag});return 0;};
  assert.equal(await bumpFriends(actor,blocker,from,to,p),0);assert.equal(searches.length,3);
  const clearance=f(f(f(.4)+f(.1))+f(.3));
  assert.deepEqual(searches.map(v=>v.origin),[[3,0,-0],[3,0,-0],[2,0,-2]]);
  assert.deepEqual(searches.map(v=>v.end),[f(clearance+1),f(clearance+f(.5)),f(clearance+f(.5))]);
  assert.equal(searches[0].path,blocker.nativePathInfo);assert.equal(searches[0].flag,1);
  assert.deepEqual(actor.position,[2,0,-1]);assert.deepEqual(blocker.position,[3,0,-1]);assert.deepEqual(trace,[]);
});
test('only exact1 direction search succeeds; displacement uses its output and failures restore canonical actor storage',async()=>{
  const {actor,blocker,p,from,to}=fixture();p.polygons=()=>0;let count=0;
  p.safeDirection=(area,origin,direction,start,end,path,flag,out)=>{out.point=[5,2,-4];return ++count===1?2:1;};
  assert.equal(await bumpFriends(actor,blocker,from,to,p),1);assert.equal(count,2);assert.deepEqual(blocker.position,[5,2,-4]);assert.deepEqual(actor.position,[2,0,-1]);
  p.safePoint=()=>{throw new Error('Geometry unavailable');};await assert.rejects(bumpFriends(actor,blocker,from,to,p),/Geometry unavailable/);
  assert.deepEqual(actor.position,[2,0,-1]);
});
test('missing directional search is explicit, and restores the actor instead of reporting displacement success',async()=>{
  const {actor,blocker,p,from,to}=fixture();p.safePoint=()=>0;
  await assert.rejects(bumpFriends(actor,blocker,from,to,p),/provider safeDirection/);assert.deepEqual(actor.position,[2,0,-1]);
});
