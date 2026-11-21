import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {playClientAttack,clientAttackHit,advanceClientAnimationCountdown} from '../src/client_attack_playback.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-attack-playback-observations.json',import.meta.url)));
test('1310 original PlayAnimation/hit owners agree on deferral, reactions, barks and linked hit advancement',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,1310);
 for(const row of fixture.cases){
  const c=row.case,actor={id:0xffffffff,objectType:5},target={id:0x80000012,objectType:c.targetType},commands=[];let drawIndex=0;
  const make=()=>({type:1,sourceId:actor.id,targetId:target.id,duration:916,damage:24,result:c.result,reactionDelay:15,reaction:14,reactionDuration:250,attackType:0,ranged:c.ranged,killingBlow:c.killingBlow??1,weaponAttackType:1,next:null});
  const head=make(),next=make(),pending={type:0,sourceId:0,targetId:0,duration:0,damage:0,result:0,reactionDelay:0,reaction:0,reactionDuration:0,attackType:0,ranged:0,killingBlow:0,weaponAttackType:0,next:null};if(c.next)head.next=next;
  const label=o=>o===actor?'source':o===target?'target':o===head?'head':o===next?'next':o===pending?'pending':null;
  const p={
   object:id=>id===actor.id&&!c.missingSource?actor:id===target.id&&!c.missingTarget?target:null,
   currentAnimation:o=>o===actor?c.current:c.targetCurrent,bodyType:()=>c.body,
   prepareWeapon:o=>commands.push({kind:'prepare',object:label(o)}),stopModelMotion:()=>commands.push({kind:'stop-motion',object:'source'}),pendingAttack:(_o,r)=>Object.assign(pending,r),
   selectAttack:(o,r)=>{commands.push({kind:'select',object:label(o)});r.reaction=c.selectedReaction;r.reactionDelay=c.selectedDelay;return c.selected;},animationLength:o=>o===actor?1200:700,
   insert:(o,q)=>commands.push({kind:'insert',object:label(o),...q,record:label(q.record)}),random:()=>{const draws=c.draws??[1];return draws[Math.min(drawIndex++,draws.length-1)];},bark:(o,value)=>commands.push({kind:'bark',object:label(o),value}),
   isDoorOrPlaceable:o=>[9,10].includes(o.objectType),hitPoints:()=>c.hp??0,unhandled:()=>{throw new Error('Unexpected missing lower boundary');},
   playReaction:(o,animation)=>commands.push({kind:'play',object:label(o),animation,record:null}),
   sound:(o,r,flag)=>commands.push({kind:'sound',object:label(o),record:label(r),flag}),
   abortOnParry:()=>c.abort??0,weaponEffect:(o,value)=>commands.push({kind:'weapon-effect',object:label(o),value}),hasModel:()=>c.parryModel??false,
   endAnimation:o=>commands.push({kind:'base',object:label(o),animation:o===actor?1:0}),hasParryWeapon:()=>false,
   parryEffect:o=>commands.push({kind:'effect',object:label(o),impact:0,record:null}),impactEffect:(o,_a,r)=>commands.push({kind:'effect',object:label(o),impact:1,record:label(r)}),
   playAttack:(o,r)=>commands.push({kind:'play',object:label(o),animation:9,record:label(r)})
  };
  if(c.mode==='play')playClientAttack(actor,head,p);else clientAttackHit(head,p);
  assert.deepEqual(commands,row.commands,JSON.stringify(c));assert.deepEqual({...head,next:label(head.next)},row.record,JSON.stringify(c));assert.deepEqual({...pending,next:label(pending.next)},row.pending,JSON.stringify(c));assert.equal(drawIndex,row.draws,JSON.stringify(c));
 }
});

test('64 complete original placeable updates verify signed countdown expiry and UINT queue-to-INT storage',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-animation-countdown-observations.json',import.meta.url)));assert.equal(f.target,fixture.target);assert.equal(f.cases.length,64);
 for(const r of f.cases){const c=advanceClientAnimationCountdown(r.case.remaining,r.case.elapsed);assert.equal(r.remaining,c.expired&&r.case.queued?-14:c.remaining);assert.equal(r.animation,c.expired&&!r.case.queued?72:214);assert.deepEqual(r.calls,c.expired?['destroy','base','next',...(r.case.queued?['play','remove']:[])]:[]);}
});
