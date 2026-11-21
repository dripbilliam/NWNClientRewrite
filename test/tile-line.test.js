import test from 'node:test';
import assert from 'node:assert/strict';
import { clipTileLine,testLineWalkable,testDirectLine } from '../src/tile_line.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(){
  const area={width:2,height:2,nativePathInfo280:new PathInformation(1)},trace=[];
  const p={tile:(a,x,y)=>{trace.push(['tile',x,y]);return{x,y};},
    clippedWalkable:(tile,from,to)=>({...clipTileLine(tile.x,tile.y,from,to),minHeight:0,maxHeight:0}),
    noNonWalkTile:(tile,a,b,low,high,radius,flag)=>{trace.push(['tile-polys',tile.x,tile.y,low,high,radius,flag]);return 1;},
    noNonWalkDetailed:(a,from,to,low,high,radius,id,out,include,list,flag)=>{trace.push(['objects',low,high,radius,id,include,list,flag]);return 1;},
    noCreatures:(a,from,to,path,segment,bump,out,overlap)=>{trace.push(['creatures',segment,bump,out,overlap]);return 1;}};
  return{area,p,trace};
}
test('tile clipping preserves native horizontal/vertical/corner edge order and inclusive endpoints',()=>{
  assert.deepEqual(clipTileLine(1,0,[5,5],[15,5]),{status:1,entry:[10,5],exit:[15,5]});
  assert.deepEqual(clipTileLine(0,1,[5,5],[5,15]),{status:1,entry:[5,10],exit:[5,15]});
  assert.deepEqual(clipTileLine(1,1,[5,5],[15,15]),{status:1,entry:[10,10],exit:[15,15]});
  assert.deepEqual(clipTileLine(0,0,[10,10],[0,0]),{status:1,entry:[10,10],exit:[0,0]});
  assert.equal(clipTileLine(0,0,[-1,11],[11,11]).status,0);
});
test('native tile clip retains infinite edge-line intersections when both endpoints lie outside the same side',()=>{
  assert.deepEqual(clipTileLine(0,0,[-2,5],[-1,5]),{status:1,entry:[0,5],exit:[10,5]});
});
test('walkable traversal visits diagonal neighbor tiles and keeps distinct outside/failure returns',async()=>{
  const {area,p,trace}=fixture();assert.equal(await testLineWalkable(area,[5,5],[15,15],p),1);
  assert.deepEqual(trace,[['tile',0,0],['tile',1,1]]);
  assert.equal(await testLineWalkable(area,[-11,5],[5,5],p),0);
  p.clippedWalkable=()=>({status:0});assert.equal(await testLineWalkable(area,[5,5],[6,5],p),0);
});
test('direct line aggregates height bounds and checks tile/object/creature stages in native order',async()=>{
  const {area,p,trace}=fixture();
  p.clippedWalkable=(tile,from,to)=>({...clipTileLine(tile.x,tile.y,from,to),minHeight:tile.x*2,maxHeight:tile.x*2+1});
  assert.equal(await testDirectLine(area,[5,5],[15,5],0.6,0.5,0,p),1);
  assert.deepEqual(trace.map(a=>a[0]),['tile','tile','tile-polys','tile','tile','tile-polys','objects','creatures']);
  const objects=trace.find(a=>a[0]==='objects');
  assert.equal(objects[1],Math.fround(-Math.fround(0.1)));assert.equal(objects[2],Math.fround(Math.fround(0.5+Math.fround(0.1))+3));
  assert.deepEqual(objects.slice(4),[invalid,1,null,0]);assert.deepEqual(trace.at(-1),['creatures',1,0,null,0]);
});
test('direct-line return0/-1/-2/-3 distinguish bounds, tile, object and creature blockers',async()=>{
  for(const [stage,result] of [['outside',0],['clip',-1],['tile',-1],['objects',-2],['creatures',-3],['radius',-3]]){
    const {area,p}=fixture();let start=[5,5];
    if(stage==='outside')start=[-11,5];if(stage==='clip')p.clippedWalkable=()=>({status:0});
    if(stage==='tile')p.noNonWalkTile=()=>0;if(stage==='objects')p.noNonWalkDetailed=()=>0;if(stage==='creatures')p.noCreatures=()=>0;
    assert.equal(await testDirectLine(area,start,[6,5],stage==='radius'?0:0.6,0.5,0,p),result,stage);
  }
});
test('endpoint radius crossing invokes another walkability traversal and forwards nonzero flag as bump mode',async()=>{
  const {area,p,trace}=fixture();
  assert.equal(await testDirectLine(area,[5,5],[9.8,5],0.6,0.5,7,p),1);
  assert.deepEqual(trace.filter(a=>a[0]==='tile').map(a=>a.slice(1)),[[0,0],[0,0],[0,0],[1,0]]);
  assert.deepEqual(trace.at(-1),['creatures',1,7,null,0]);assert.equal(trace.find(a=>a[0]==='objects')[5],0);
});
test('unavailable surface data is explicit, and a stalled clipped traversal cannot report walkability',async()=>{
  const {area,p}=fixture();delete p.clippedWalkable;
  await assert.rejects(testLineWalkable(area,[5,5],[6,5],p),/clippedWalkable/);
  p.clippedWalkable=()=>({status:1,entry:[5,5],exit:[6,5]});
  await assert.rejects(testLineWalkable(area,[5,5],[15,5],p),/no progress/);
});
