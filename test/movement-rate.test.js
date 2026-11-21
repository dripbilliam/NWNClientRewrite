import test from 'node:test';
import assert from 'node:assert/strict';
import { loadMovementRate,setMovementRate,movementRate,movementRateFactor,initialMovementFactor } from '../src/movement_rate.js';
import { parse2da } from '../src/area.js';

function fixture(){
  const rules={creaturespeed:parse2da('2DA V2.0\nDEFAULT: 0.125\n2DAName WALKRATE RUNRATE\n90 NORMAL 2.5 4.5\n72 NONE 0 0\n12 FAST 3 6\n'),
    appearance:parse2da('2DA V2.0\n\nMOVERATE\n90 fAsT\n'),ruleset:null};
  const actor={creatureData:{Appearance_Type:0,ClassList:[]},nativeMovementFlags8d4:65535,nativeMovementFactor8e8:1,nativeCollisionFlag788:0,nativeHaste308:0};
  const feats=new Set(),p={hasFeat:(o,id)=>Number(feats.has(id)),monkAbilities:()=>1};return{actor,rules,p,feats};
}
test('native movement category uses physical appearance/speed rows and case-insensitive names, retaining disabled movement bit',()=>{
  const {actor,rules}=fixture();setMovementRate(actor,7,rules);
  assert.equal(actor.nativeMovementRate,2);assert.equal(actor.nativeWalkRate,3);assert.equal(actor.nativeRunRate,6);
  setMovementRate(actor,1,rules);assert.equal(actor.nativeMovementFlags8d4,65533);
  setMovementRate(actor,2,rules);assert.equal(actor.nativeMovementFlags8d4,65533);
  rules.appearance.orderedRows[0].MOVERATE='missing';setMovementRate(actor,7,rules);assert.equal(actor.nativeMovementRate,0);assert.equal(actor.nativeRunRate,4.5);
  setMovementRate(actor,99,rules);assert.equal(actor.nativeWalkRate,.125);assert.equal(actor.nativeRunRate,.125);
});
test('GFF movement BYTE overrides old INT WalkRate; omitted fields retain native category0',()=>{
  const {actor,rules}=fixture();actor.creatureData.WalkRate=2;loadMovementRate(actor,rules);assert.equal(actor.nativeMovementRate,2);
  actor.creatureData.MovementRate=257;loadMovementRate(actor,rules);assert.equal(actor.nativeMovementRate,1);
  delete actor.creatureData.MovementRate;delete actor.creatureData.WalkRate;loadMovementRate(actor,rules);assert.equal(actor.nativeMovementRate,0);
});
test('native movement factor combines barbarian speed, resets it for monk, applies lower/default/monk caps and collision override',async()=>{
  const {actor,rules,p,feats}=fixture();feats.add(194);assert.equal(await movementRateFactor(actor,rules,p),Math.fround(1.1));
  feats.add(207);actor.creatureData.ClassList=[{Class:5,ClassLevel:9}];assert.equal(await movementRateFactor(actor,rules,p),Math.fround(1.3));
  actor.nativeMovementFactor8e8=4;assert.equal(await movementRateFactor(actor,rules,p),3);
  feats.delete(207);assert.equal(await movementRateFactor(actor,rules,p),1.5);
  actor.nativeHaste308=1;assert.equal(await movementRateFactor(actor,rules,p),Math.fround(Math.fround(4)+Math.fround(.1)));
  actor.nativeMovementFactor8e8=-2;assert.equal(await movementRateFactor(actor,rules,p),.125);
  actor.nativeCollisionFlag788=1;actor.nativeMovementFactor78c=8;assert.equal(await movementRateFactor(actor,rules,p),8);
});
test('movement uses active ruleset caps/bonuses and cached base rates, preserving native multiplication order',async()=>{
  const {actor,rules,p,feats}=fixture();rules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 BARBARIAN_ENDURANCE_BONUS .2\n1 MOVEMENT_SPEED_BONUS_DEFAULT_CAP 1.1\n2 MOVEMENT_SPEED_PENALTY_CAP 1.05\n');
  assert.equal(initialMovementFactor(rules),Math.fround(1.05));feats.add(194);loadMovementRate(actor,rules);
  assert.equal(await movementRate(actor,1,rules,p),4950);assert.equal(await movementRate(actor,0,rules,p),2750);
  // SetMovementRate owns cache refresh; changes to the table alone do not.
  rules.creaturespeed.orderedRows[0].RUNRATE='100';assert.equal(await movementRate(actor,1,rules,p),4950);
  setMovementRate(actor,0,rules);assert.equal(await movementRate(actor,1,rules,p),110000);
});
