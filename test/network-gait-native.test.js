import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {clientGaitSpeed} from '../src/network_gait.js';import {NetworkMotion} from '../src/network_motion.js';
test('2916 complete original gait calls agree on rate, script factor, creep stride, acceleration and visual scales',()=>{
 const o=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-gait-observations.json',import.meta.url)));assert.equal(o.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.cases.length,2916);
 for(const row of o.cases){const c=row.case,speed=clientGaitSpeed({...c,acceleration:row.acceleration},{distance:c.distance,clipSeconds:c.clipMs/1000,scale:c.scale,scale2:c.scale});assert.equal(row.draws.length,1);assert.ok(Math.abs(speed-row.draws[0].speed)<.00001,JSON.stringify({c,speed,expected:row.draws[0].speed}));}
});
test('server movement factor changes gait rate along with travel, retaining the final-frame descriptor and authority',()=>{
 const object={id:1,replicated:{position:[0,0,0],orientation:[1,0,0],animation:4,walkRate:2200,runRate:4400}},m=new NetworkMotion();m.observe(object,{path:[[20,0]],field8F4:1,field8EC:.5});m.update(.1);const a=m.objects.get(1);assert.equal(clientGaitSpeed(a.gait,{distance:2,clipSeconds:1}),Math.fround(1.1));assert.ok(Math.abs(a.position[0]-.22)<.00001);m.observe(object,{path:[[20,0]],field8F4:1,field8EC:2});m.update(.1);assert.equal(clientGaitSpeed(a.gait,{distance:2,clipSeconds:1}),Math.fround(4.4));assert.deepEqual(object.replicated.position,[0,0,0]);
});
