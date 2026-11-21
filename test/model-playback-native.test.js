import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {playModelAnimation} from '../src/model_playback.js';
test('native animation start/reuse/stack ordering and reverse initialization match2173 original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-playback-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,2173);
 for(const row of oracle.rows){
  const c=row.case,calls=[],clips=new Map(['base:impact','base:duration','base:cessation','override:impact'].map(key=>[key,{key,name:key.split(':')[1],length90:c.length,transition94:c.transition}]));let allocation=100;
  const gob={model68:'base',model80:c.override?'override':null,runsE0:c.initial.map((r,id)=>({id,clip0:clips.get(`base:${r.name}`),speed8:.75,flagsC:r.flags,previous10:.125,time14:.375,weight18:.625,transition1c:.25,scale20:1.5,done24:1}))};
  const p={findAnimation:(model,name)=>{calls.push(['findAnimation',model,name]);return clips.get(`${model}:${name.toLowerCase()}`)??null;},animationScale:(model,clip)=>{calls.push(['animationScale',model,clip?.key??null]);return c.animationScale;},playbackScale:()=>{calls.push(['playbackScale']);return c.playbackScale;},createRun:()=>{const id=allocation++;calls.push(['createRun',id]);return{id};},destroyRun:(r,bytes)=>calls.push(['destroyRun',r.id,bytes]),event:(...args)=>calls.push(['event',...args])};
  const frames=c.requests.map(r=>{const result=playModelAnimation(gob,r.name==='<null>'?null:r.name,r.speed,r.flags,r.start,p);return{result,runs:gob.runsE0.map(({clip0,...data})=>({id:data.id,clip:clip0.key,...Object.fromEntries(Object.entries(data).filter(([k])=>k!=='id'))}))};});
  assert.deepEqual({calls,frames},{calls:row.calls,frames:row.frames},JSON.stringify(c));
 }
});
