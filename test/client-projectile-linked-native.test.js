import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeLinkedClientProjectile,linkRandomClientProjectile,destroyClientProjectileAuxiliary} from '../src/client_projectile_linked.js';
import {initializeRandomClientProjectile} from '../src/client_projectile_random.js';
import {initializeClientProjectileNode} from '../src/client_projectile_path.js';
import {NativeRandom} from '../src/native_random.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-linked-projectile-observations.json',import.meta.url)));
test('linked7 and random-linked12 initializer model/PQ/scene branches match complete original code',()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],random=new NativeRandom(c.seed),state={node:{kind:c.kind,point:[4,5,6]},position:[1.25,-2,3.5],orientation:[.5,.25,.75],endpoint:[8,9,10],velocity:[2,3,4],acceleration:[5,6,7],targetId:c.targetId,remaining:1000,impactNode:'impact',auxiliaryModel:null},target={objectType:5,position:[21,22,23]},model={position:[2,3,4],q:[.5,.5,.5,.5]},aux={position:[0,0,0],q:[0,0,0,0]},scene={},who=o=>o===state?'actor':o===target?'target':o===model?'model':'aux';
  const p={randomState:{angleSide:0},random:()=>random.next(),getObject:id=>{calls.push(['getObject',id]);return{status:c.lookup,object:target};},model:o=>{calls.push(['model',who(o)]);return(o===state?c.ownModel:c.targetModel)?model:null;},
   nodePose:(_m,name,point)=>{calls.push(['nodePose',name]);if(c.pose)point.splice(0,3,10,11,12);return c.pose;},clientArray:()=>{calls.push(['clientArray']);return c.array;},
   createAuxiliary:(_s,resource,name)=>{calls.push(['newRef',resource,name]);return c.aux?aux:null;},reattach:(_m,to,name)=>calls.push(['reattach',who(to),name]),
   modelPosition:()=>{calls.push(['modelPosition']);return model.position;},setModelPosition:(o,v)=>{calls.push(['setModelPosition',who(o),v.slice()]);o.position=v.slice();},
   modelOrientation:()=>{calls.push(['modelOrientation']);return model.q;},setModelOrientation:(o,q)=>{calls.push(['setModelOrientation',who(o),q.slice()]);o.q=q.slice();},modelScene:()=>{calls.push(['modelScene']);return scene;},setModelScene:o=>calls.push(['setModelScene',who(o)]),
  };
  p.initializeSpecial=(s,o,d,t)=>c.kind===7?initializeLinkedClientProjectile(s,p):initializeRandomClientProjectile(s,o,d,t,p);p.linkRandomModel=s=>linkRandomClientProjectile(s,p);
  initializeClientProjectileNode(state,[...state.orientation],p);
  assert.deepEqual({calls,auxiliary:!!state.auxiliaryModel,modelPosition:model.position,auxPosition:aux.position,auxOrientation:aux.q,velocity:state.velocity,acceleration:state.acceleration},{calls:row.calls,auxiliary:row.auxiliary,modelPosition:row.modelPosition,auxPosition:row.auxPosition,auxOrientation:row.auxOrientation,velocity:row.velocity,acceleration:row.acceleration},JSON.stringify(c));
 }
 assert.equal(native.rows.length,97);
});
test('auxiliary detach/scene/delete/clear order precedes the native main-model destructor',()=>{
 for(const row of native.deletions){const calls=[],state={auxiliaryModel:row.present?{}:null};destroyClientProjectileAuxiliary(state,{attachAuxiliary:(_m,a,b,f)=>calls.push(['detachAuxiliary',a??0,b??0,f]),setModelScene:()=>calls.push(['setModelScene','aux']),destroyAuxiliary:(_m,f)=>calls.push(['destroyAuxiliary',f])});if(row.main)calls.push(['clearMain'],['destroyMain',1]);assert.deepEqual(calls,row.calls);assert.equal(!!state.auxiliaryModel,row.auxiliary);}
 assert.equal(native.deletions.length,4);
});
