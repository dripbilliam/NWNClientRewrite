import test from 'node:test';
import assert from 'node:assert/strict';
import { noCreaturesOnLine } from '../src/creature_line.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(){
  const owner={id:1,position:[0,0,0],pc:1},target={id:2,position:[4,0,0]},blocker={id:0x80000003,position:[2,10,0]},area={};
  const objects=new Map([[owner.id,owner],[target.id,target],[blocker.id,blocker]]),path=new PathInformation(owner.id);path.field28=target.id;
  const list=()=>[...objects.values()].sort((a,b)=>a.position[0]-b.position[0]).map(o=>o.id);
  const p={creature:id=>objects.get(id),areaIds:list,firstByX:(a,x)=>{const i=list().findIndex(id=>objects.get(id).position[0]>=x);return i<0?null:i;},
    dm:o=>o.dm??0,dmBody:o=>o.dmBody??0,collision788:o=>o.collision788??0,ghost:o=>o.ghost??0,
    pc:o=>o.pc??0,possessedFamiliar:()=>0,visibility:()=>1,radius:o=>o.radius??0.6,dead:o=>o.dead??0};
  const query=(segment=1,bump=0,out=null,overlap=0)=>noCreaturesOnLine(area,0,0,4,0,path,segment,bump,out,overlap,p);
  return{owner,target,blocker,area,objects,path,p,query};
}
test('native creature line excludes canonical owner/target IDs and uses horizontal collision without a height test',async()=>{
  const {query,objects,blocker}=fixture();assert.equal(await query(),0);
  objects.delete(blocker.id);assert.equal(await query(),1);
});
test('zero-length point succeeds without path, other missing path fails; optional blocker resets to INVALID',async()=>{
  const out={id:3};assert.equal(await noCreaturesOnLine({},1,2,1,2,null,0,0,out,0,{}),1);assert.equal(out.id,invalid);
  assert.equal(await noCreaturesOnLine({},0,0,1,2,null,1,0,out,0,{}),0);
});
test('owner DM/ghost exact-one bypasses, candidates require zero; dead and invisible candidates are excluded',async()=>{
  const {owner,blocker,query,p}=fixture();owner.ghost=1;assert.equal(await query(),1);
  owner.ghost=2;assert.equal(await query(),0);blocker.ghost=2;assert.equal(await query(),1);
  blocker.ghost=0;blocker.dead=1;assert.equal(await query(),1);
  blocker.dead=0;p.visibility=()=>null;assert.equal(await query(),1);
  p.visibility=()=>2;assert.equal(await query(),0);owner.dm=1;assert.equal(await query(),1);
  owner.dmBody=1;assert.equal(await query(),0);
});
test('exact tangent passes strict bounding gates; a slightly overlapping creature blocks and point mode centers on destination',async()=>{
  const {blocker,query}=fixture();blocker.radius=0.4;blocker.position=[2,0,-1];
  assert.equal(await query(),1);blocker.position[2]=-0.999;assert.equal(await query(),0);
  assert.equal(await query(0),1);blocker.position=[3.5,0,0];assert.equal(await query(0),0);
});
test('nearest optional blocker uses from-distance and last equal-distance candidate wins',async()=>{
  const {blocker,objects,query}=fixture();const out={};
  objects.set(4,{id:4,position:[1,0,0]});assert.equal(await query(1,0,out),0);assert.equal(out.id,4);
  objects.set(5,{id:5,position:[1,0,0]});await query(1,0,out);assert.equal(out.id,5);
  blocker.position=[2,0,0];
});
test('target-overlap exemption and bumpability query apply only after intersection, retaining explicit unknown dependencies',async()=>{
  const {blocker,target,query,p}=fixture();blocker.position=target.position.slice();
  assert.equal(await query(1,0,null,1),1);blocker.position=[2,0,0];
  await assert.rejects(query(1,1),/bumpability/);p.bumpable=()=>1;assert.equal(await query(1,1),1);
});
test('far NPC query shortcut and visibility radius depend on owner state and path search flag',async()=>{
  const {owner,path,query,p}=fixture();owner.pc=0;owner.position=[30,0,0];assert.equal(await query(),1);
  owner.position=[0,0,0];p.visibility=()=>0;assert.equal(await query(),1);
  path.raw.setUint32(0x19c,1,true);assert.equal(await query(),0);
});
