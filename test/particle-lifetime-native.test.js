import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { checkParticleLife } from '../src/particle_lifetime.js';

test('particle age/death/recycle order matches290 complete original owner executions',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-lifetime-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,290);
  for(const row of oracle.rows){
    const c=row.case,particles=c.ages.map((age,id)=>({id,age:Math.fround(age),field48:100+id,chunk78:id%2===0?{id}:null})),calls=[];
    const e={lifeExp:c.life,chunkName:c.chunk?'synthetic_chunk':'',active188:{records:[...particles]},free130:{records:Array.from({length:c.freeCount},()=>({id:-1})),capacity:c.capacity}};
    checkParticleLife(e,c.delta,{reserveFree:n=>calls.push(['reserve',n]),detachChunk:(chunk,flag)=>{calls.push(['detach',chunk.id,flag]);if(c.detachLife!==undefined)e.lifeExp=c.detachLife;}});
    const out={calls,active:e.active188.records.map(p=>p.id),retired:e.free130.records.slice(c.freeCount).map(p=>p.id),capacity:e.free130.capacity,ages:particles.map(p=>p.age),fields48:particles.map(p=>p.field48)};
    const {case:_case,...expected}=row;assert.deepEqual(out,expected,JSON.stringify(c));
  }
});

test('a particle crossing its lifetime survives that step and retires on the next call',()=>{
  const particle={age:Math.fround(.9),field48:4,chunk78:null},e={lifeExp:1,chunkName:'',active188:{records:[particle]},free130:{records:[],capacity:0}},p={reserveFree:()=>{}};
  checkParticleLife(e,.5,p);assert.equal(e.active188.records.length,1);assert.ok(particle.age>1);
  checkParticleLife(e,0,p);assert.equal(e.active188.records.length,0);assert.equal(e.free130.records[0],particle);assert.equal(particle.field48,4);
});
