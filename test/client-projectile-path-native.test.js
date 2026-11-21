import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {configureClientProjectilePath,initializeClientProjectileNode,updateClientProjectilePath,buildClientProjectilePath,nextClientProjectileNode} from '../src/client_projectile_path.js';
import {stepClientProjectileMotion} from '../src/client_projectile_motion.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-path-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const bits=value=>{view.setFloat32(0,value,true);const b=view.getUint32(0,true);return(b&0x7f800000)===0x7f800000&&(b&0x7fffff)?'NaN':b;};
const canonical=b=>(b&0x7f800000)===0x7f800000&&(b&0x7fffff)?'NaN':b;
const node=n=>n?{...n,point:n.point.map(bits),attachment:n.attachment.map(bits)}:null;
const snapshot=s=>Object.fromEntries([...['position','orientation','endpoint','velocity','acceleration','previousPosition'].map(k=>[k,s[k].map(bits)]),...['remaining','elapsed','totalTime','path','spiralSide','stage'].map(k=>[k,s[k]>>>0]),['node',node(s.node)],['nodes',s.nodes.map(node)]]);
const normalizeExpected=s=>({...s,...Object.fromEntries(['position','orientation','endpoint','velocity','acceleration','previousPosition'].map(k=>[k,s[k].map(canonical)]))});
function run(c){
 const state={...structuredClone(c),path:c.oldPath,node:c.hasNode?structuredClone(c.node):null,nodes:c.mode==='next'?structuredClone(c.nextNodes):c.mode==='configure'?Array.from({length:c.oldNodes},()=>structuredClone(c.node)):[]},calls=[],object={position:c.objectPosition,objectType:c.objectType};let lookup=0,result=null;
 const p={
  getObject:id=>{calls.push(['getObject',id]);return{status:++lookup<2?c.lookup:c.secondLookup??c.lookup,object};},
  clientObject:id=>{calls.push(['clientObject',id]);return c.clientObject?object:null;},
  model:()=>{calls.push(['model']);return c.model?{}:null;},
  nodePose:(_model,_name,point)=>{calls.push(['nodePose']);if(c.pose)point.splice(0,3,...c.posePoint);return c.pose;},
  allocateNode:()=>calls.push(['allocate',48]),destroyNode:n=>calls.push(['destroy',node(n)]),random:()=>{calls.push(['random']);return c.random;},
  buildPath:(s,path)=>{calls.push(['build',path]);s.nodes.push(structuredClone(c.generated));},
  initializeNode:(_s,orientation)=>calls.push(['initialize',orientation.map(bits)]),
  setStage:(_s,stage)=>{calls.push(['stage',stage]);return c.animateResult;},animateExternal:()=>calls.push(['animateExternal']),
  setPosition:(s,point)=>{calls.push(['position',point.map(bits)]);s.position=[...point];},
  nextNode:s=>{calls.push(['next',s.remaining>>>0,s.elapsed>>>0]);if(c.advance){s.node=c.advance===1?(s.generatedNode??=structuredClone(c.generated)):null;s.remaining=777;}return c.nextResult;},
  basicMotion:s=>{calls.push(['basic']);s.position=[6,7,8];s.velocity=[9,10,11];},
  spiralMotion:s=>{calls.push(['spiral']);s.position=[6,7,8];s.velocity=[9,10,11];}
 };
 if(c.mode==='flow'){
  p.buildPath=(s,path)=>buildClientProjectilePath(s,path,p);
  p.initializeNode=(s,orientation)=>initializeClientProjectileNode(s,orientation,p);
  p.nextNode=s=>nextClientProjectileNode(s,p);
  const move=(s,kind)=>{
   const result=stepClientProjectileMotion({...s,attachment:s.node.attachment},kind);s.velocity=result.velocity;
   if(result.orientation){calls.push(['orientation',result.orientation.map(bits)]);s.orientation=result.orientation;}
   p.setPosition(s,result.position);
  };
  p.basicMotion=s=>move(s,'basic');p.spiralMotion=s=>move(s,'spiral');
  configureClientProjectilePath(state,c.path,p);const observations=[{state:snapshot(state),calls:[...calls]}];calls.length=0;
  for(let i=0;i<c.maxSteps;i++){
   state.elapsed=c.step;updateClientProjectilePath(state,p);observations.push({state:snapshot(state),calls:[...calls]});calls.length=0;
   if(state.remaining===0)break;
  }
  return{observations};
 }
 if(c.mode==='configure')configureClientProjectilePath(state,c.path,p);
 else if(c.mode==='initialize')initializeClientProjectileNode(state,state.orientation,p);
 else if(c.mode==='build')buildClientProjectilePath(state,c.path,p);
 else if(c.mode==='next')result=nextClientProjectileNode(state,p);
 else updateClientProjectilePath(state,p);
 return{calls,state:snapshot(state),result};
}
for(const mode of ['configure','initialize','update','build','next'])test(`native projectile ${mode}: ownership, attachment/target failure, timer/radius admission and dispatch`,()=>{
 for(const row of native.rows.filter(r=>r.case.mode===mode)){
  const actual=run(row.case),context=JSON.stringify(row.case);
  assert.deepEqual(actual.calls,row.calls,context+' calls');assert.deepEqual(actual.state,normalizeExpected(row.state),context+' state');assert.equal(actual.result,row.result,context+' result');
 }
});
test('native full path trajectories compose configuration, initialization, target following, advancement and actual motion',()=>{
 const rows=native.rows.filter(r=>r.case.mode==='flow');assert.equal(rows.length,240);
 for(const row of rows){
  assert.ok(row.observations.length>1);
  const actual=run(row.case).observations;assert.equal(actual.length,row.observations.length,JSON.stringify(row.case));
  for(const [i,expected]of row.observations.entries()){
   const context=JSON.stringify({case:row.case,step:i});assert.deepEqual(actual[i].calls,expected.calls,context+' callbacks');assert.deepEqual(actual[i].state,normalizeExpected(expected.state),context+' state');
  }
 }
});
test('unimplemented native path services cannot silently substitute a fake path',()=>{
 const c=native.rows.find(r=>r.case.mode==='configure'&&r.case.path===3).case,state={...structuredClone(c),nodes:[],orientation:[0,0,0]};
 assert.throws(()=>configureClientProjectilePath(state,3,{getObject:()=>({status:1})}),/buildPath/);
 const s={...structuredClone(c),node:{...c.node,kind:4},targetId:0x7f000000,position:[1,2,3]};
 assert.throws(()=>initializeClientProjectileNode(s,[0,0,0],{}),/initializeSpecial/);
 assert.throws(()=>buildClientProjectilePath({...s,nodes:[]},8,{}),/builder 8/);
 assert.throws(()=>nextClientProjectileNode({...s,node:null,nodes:[{...c.node,kind:1,spawnCount:1}]},{}),/spawnNodeChildren/);
 assert.equal(native.rows.length,17518);
});
