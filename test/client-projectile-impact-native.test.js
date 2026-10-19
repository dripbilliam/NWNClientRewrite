import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {attachClientProjectileImpact} from '../src/client_projectile_impact.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-projectile-impact-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const bits=value=>{view.setFloat32(0,value,true);return view.getUint32(0,true);};
test('native impact body/shield admission, pose, random draw and duration match original branch',()=>{
 for(const row of capture.rows){
  const c=row.case,calls=[],target={},s={targetId:0x80000063,result:c.result,impactNode:'authored_impact',impactDuration:c.duration,remaining:0,orientation:c.vector},p={
   getObject:id=>{calls.push(['lookup',id]);return{status:c.lookup,object:target};},modelHandle:()=>c.handle,field28:()=>c.field28,
   model:(o,part,flags)=>{calls.push([o===s?'projectileModel':'targetModel',part,flags]);return(o===s?c.model:c.anchor)?{}:null;},
   creature:()=>{calls.push(['creature']);return c.creature?{}:null;},equipped:(_o,slot)=>{calls.push(['equipped',slot]);return 0x80000077;},item:id=>{calls.push(['item',id]);return c.item?{}:null;},weaponType:()=>{calls.push(['baseItem',42]);return c.weaponType;},
   itemModel:(_o,part,flags)=>{calls.push(['targetModel',part,flags]);return c.anchor?{}:null;},random:()=>{calls.push(['random']);return c.random;},
   attach:(_model,_anchor,name,flags)=>{calls.push(['attach',name,flags]);return c.attach;},nodePose:(_m,name,pos,q)=>{calls.push(['getPose',name]);if(c.pose){pos.splice(0,3,7,8,9);q.splice(0,4,.5,.5,.5,.5);}return c.pose;},
   setNodePose:(_m,name,pos,q)=>calls.push(['setPose',name,pos.map(bits),q.map(bits)])
  };
  attachClientProjectileImpact(s,p);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(s.impactDuration>>>0,row.duration);assert.equal(s.remaining,row.remaining);
 }
 assert.equal(capture.rows.length,2472);
});
