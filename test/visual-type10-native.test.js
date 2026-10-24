import fs from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';
import {startType10Visual,type10ProjectileTime} from '../src/visual_type10.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-type10-observations.json',import.meta.url)));
test('680 whole native Type10 starts match admission, active parameters, model fallback, endpoint, flags, timing and callback order',()=>{
 assert.equal(native.rows.length,680);assert.deepEqual(native.comparisonStrings,['log','linear2']);
 for(const row of native.rows){const c=row.case,calls=[],objects=new Map([[123,{id:123,position:c.toPoint}],[456,{id:456,position:c.fromPoint,orientation:c.orientation}]]);let projectile=null;
  const p={clientObject:id=>{calls.push(['client',id]);return c[id===123?'target':'source']?objects.get(id):null;},renderObject:o=>{calls.push(['render',o.id]);return c[o.id===123?'targetRender':'sourceRender']?o:null;},
   programString:(id,col)=>{const value=c.values[col]??null;calls.push(['string',id,col,value]);return{found:value!==null,value:value??''};},programInt:(id,col)=>{const value=c.values[col]??null;calls.push(['integer',id,col,value]);return{found:value!==null,value:value??0};},
   constructProjectile:()=>{calls.push(['construct']);return projectile={endpoint:[0,0,0]};},configureSpell:(_p,id)=>calls.push(['configureSpell',id>>>0]),
   loadProjectileModel:(_p,name,part,flags)=>{calls.push(['loadModel',name,part,flags]);return c.load;},destroyProjectile:()=>calls.push(['destroy']),
   sourceModel:()=>{calls.push(['model']);return c.sourceModel?{}:null;},sourceNodePose:(_m,name,pos)=>{calls.push(['nodePose',name]);pos.splice(0,3,...c.hand);return c.pose;},
   projectilePosition:(_p,pos)=>calls.push(['position',pos]),projectileOrientation:(_p,orientation)=>calls.push(['orientation',orientation]),
   controlledClient:()=>{calls.push(['controlledClient']);return c.client?{videoF8:c.video?{gui248:{}}:null}:null;},projectileScene:()=>calls.push(['scene']),
   projectileStage:(_p,stage)=>calls.push(['stage',stage]),projectileTarget:(_p,id,node)=>calls.push(['target',id,node]),projectileTime:(_p,time)=>calls.push(['time',time]),projectilePath:(_p,path)=>calls.push(['path',path>>>0])};
  startType10Visual({target54:123,source58:456,point48:c.point},900,p);assert.equal(row.error,null);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(projectile?.endpoint??null,row.endpoint);assert.equal(projectile?.facing??null,row.facing);
 }
});
test('unresolved CPU timing disagreement remains explicit rather than selecting a guessed native branch',()=>{assert.throws(()=>type10ProjectileTime('log',[0,0,0],[10,0,0],[0,0,1],{logBranches:()=>[0,100]}),/different/);});
