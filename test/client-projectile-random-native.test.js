import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeClientProjectileNode} from '../src/client_projectile_path.js';
import {initializeRandomClientProjectile} from '../src/client_projectile_random.js';
import {NativeRandom} from '../src/native_random.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-random-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const canonical=b=>(b&0x7f800000)===0x7f800000&&(b&0x7fffff)?'NaN':b,bits=v=>{view.setFloat32(0,v,true);return canonical(view.getUint32(0,true));};
for(const kind of [4,9,12])test(`native random projectile kind${kind}: exact CRT draws/global toggle, normalized orientation, velocity and acceleration`,()=>{
 const rows=capture.rows.filter(r=>r.case.kind===kind);assert.equal(rows.length,867);
 for(const row of rows){
  const c=row.case,calls=[],random=new NativeRandom(c.seed),state={node:{kind,point:[4,5,6]},position:[...c.position],orientation:[...c.orientation],endpoint:[8,9,10],velocity:[2,3,4],acceleration:[5,6,7],targetId:c.targetId,remaining:c.remaining,impactNode:'impact',auxiliaryModel:null},argument=c.alias?state.orientation:[...state.orientation],randomState={angleSide:c.angleSide},p={
   randomState,random:()=>{const n=random.next();calls.push(['random',n]);return n;},getObject:id=>{calls.push(['getObject',id]);return{status:c.lookup,object:{objectType:5,position:[21,22,23]}};},model:()=>{calls.push(['model']);return{};},nodePose:(_m,_n,point)=>{calls.push(['nodePose']);if(c.pose)point.splice(0,3,10,11,12);return c.pose;},linkRandomModel:()=>{calls.push(['newRef','ref','']);return null;}
  };
  p.initializeSpecial=(...args)=>initializeRandomClientProjectile(...args,p);initializeClientProjectileNode(state,argument,p);
  const context=JSON.stringify(c);assert.deepEqual(calls,row.calls,context+' calls');assert.equal(random.state,row.seed,context+' seed');assert.equal(randomState.angleSide,row.angleSide,context+' shared side');
  for(const [actual,expected,label]of[[argument,row.argument,'argument'],[state.orientation,row.orientation,'orientation'],[state.velocity,row.velocity,'velocity'],[state.acceleration,row.acceleration,'acceleration']])assert.deepEqual(actual.map(bits),expected.map(canonical),context+' '+label);
  assert.equal(Boolean(state.auxiliaryModel),row.auxiliary);
 }
});
