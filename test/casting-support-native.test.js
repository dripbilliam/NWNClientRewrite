import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {triggerFacingPosition} from '../src/facing_actions.js';
import {startSpellRound,removeSpellActions} from '../src/spell_round.js';
import {createCombatRound} from '../src/combat_round.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-casting-support-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');

test('trigger cached polygon midpoint matches 30 executions of original GetFacingPosition',async()=>{
  for(const row of oracle.rows.filter(row=>row.case.mode==='trigger')){
    const c=row.case,o={geometry:c.vertices,nativeFacingBounds:c.bounds.map(Math.fround)},trace=[];
    const point=await triggerFacingPosition(o,async(_,p)=>{trace.push(['area'],['height',...p]);return c.height;});
    assert.deepEqual(point,row.point,JSON.stringify(c));assert.deepEqual(o.nativeFacingBounds,row.bounds);
    assert.deepEqual(trace,row.calls);
  }
});
test('cast round start matches original unsigned length, signed overlap/bleed, flags and replacement action',()=>{
  for(const row of oracle.rows.filter(row=>row.case.mode==='start')){
    const c=row.case,round={...createCombatRound(),overlap:c.overlap,bleed:c.bleed,actions:c.actions.map(nativeActionType=>({nativeActionType}))};
    startSpellRound(round,c.length);
    assert.deepEqual([Number(round.started),Number(round.paused),round.timer,round.length,round.overlap>>>0,round.bleed>>>0,Number(round.spellCastRound),round.pausedBy,round.pauseTimer],row.round,JSON.stringify(c));
    const a=round.actions[0];assert.equal(round.actions.length,1);
    assert.deepEqual(['add',a.time,a.animation,a.duration,a.count,a.nativeActionType,a.targetId,a.followTarget,0,OBJECT_INVALID,65535],row.calls.at(-1));
    assert.deepEqual(row.calls.slice(0,-1),c.actions.flatMap((_,i)=>[['remove-head',i],['free',i]]));
  }
});
test('spell round cleanup matches original full-list traversal and BYTE action types',()=>{
  for(const row of oracle.rows.filter(row=>row.case.mode==='remove')){
    const c=row.case,actions=c.actions.map((nativeActionType,i)=>({nativeActionType,time:i*10000})),round={actions:[...actions]};
    removeSpellActions(round);
    assert.deepEqual(round.actions,row.remaining.map(i=>actions[i]),JSON.stringify(c));
  }
});
