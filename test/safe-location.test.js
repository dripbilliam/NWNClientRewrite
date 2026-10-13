import test from 'node:test';
import assert from 'node:assert/strict';
import { testSafeLocationPoint } from '../src/safe_location.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(){
  const area={width:2,height:1},path=new PathInformation(1),tiles=[{x:0,y:0},{x:1,y:0}],calls=[];path.field28=0x80000001;
  const p={tileAt:(a,point)=>point[0]>=0&&point[0]<20&&point[1]>=0&&point[1]<10?tiles[Math.floor(point[0]/10)]:null,
    clippedWalkable:(tile,from,to)=>({status:1,entry:[Math.max(from[0],tile.x*10),from[1]],exit:[Math.min(to[0],tile.x*10+10),to[1]],minHeight:2,maxHeight:3}),
    noNonWalkTile:(...args)=>{calls.push(['tile',...args]);return 1;},polygons:(...args)=>{calls.push(['polygons',...args]);return 1;},
    creatureLine:(...args)=>{calls.push(['creatures',...args.slice(1,3),path.field28,...args.slice(4)]);return 1;}};
  return{area,path,p,calls};
}
test('safe point queries diameter tile heights, polygons then point-mode creatures while temporarily excluding tracking ID',async()=>{
  const {area,path,p,calls}=fixture();assert.equal(await testSafeLocationPoint(area,[5,5,9],path,0,p),1);
  assert.equal(area.nativePathInfo280,path);assert.deepEqual(calls.map(c=>c[0]),['tile','polygons','creatures']);
  assert.equal(calls[0].at(-1),1);assert.deepEqual(calls[2],['creatures',[Math.fround(5-Math.fround(.001)),5],[5,5],invalid,0,0,null,0]);
  assert.equal(path.field28,0x80000001);assert.equal(calls[1][4],Math.fround(9-Math.fround(.1)));
});
test('safe point traverses adjacent tiles with original diameter and .001 increments, preserving target when flag byte nonzero',async()=>{
  const {area,path,p,calls}=fixture();assert.equal(await testSafeLocationPoint(area,[10,5,0],path,257,p),1);
  assert.deepEqual(calls.filter(c=>c[0]==='tile').map(c=>c[1].x),[0,1]);assert.equal(calls.at(-1)[3],0x80000001);
});
test('safe point rejects outside diameter or denied face before object/creature query and restores target after provider failure',async()=>{
  const {area,path,p,calls}=fixture();assert.equal(await testSafeLocationPoint(area,[0,5,0],path,0,p),0);assert.deepEqual(calls,[]);
  p.noNonWalkTile=()=>0;assert.equal(await testSafeLocationPoint(area,[5,5,0],path,0,p),0);assert.deepEqual(calls,[]);
  p.noNonWalkTile=()=>1;p.creatureLine=()=>{throw new Error('unavailable candidate radius');};await assert.rejects(testSafeLocationPoint(area,[5,5,0],path,0,p),/candidate radius/);
  assert.equal(path.field28,0x80000001);
});
