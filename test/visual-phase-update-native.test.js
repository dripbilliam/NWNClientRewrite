import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {updateVisualPhases} from '../src/visual_phase_update.js';
test('complete visual phase countdown/update matches326 original executions with explicit lower services',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-phase-update-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,326);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=Array.from({length:3},(_,id)=>({id}));if(c.alias)models[2]=models[0];
  const e={target54:123,programPhaseFa:c.phase,durationFc:c.duration,programRemainingCc:c.programRemaining,updateProgramD8:c.updateProgram,attached114:c.attached,programType10d:99,finishedF4:7,retiringE8:c.retiring,sound118:c.sound?{}:null,models88:models,modelRemaining5c:c.modelRemaining.slice(),modelStates68:c.states.slice(),programsD0:[10,20,30],retireRemainingC0:c.retireRemaining.slice(),retiredDc:c.retired.slice()};
  const p={clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{position38:[1.25,-2,3.5]}:null;},playAnimation:(model,...args)=>{calls.push(['play',model.id,...args]);return c.play;},stopProgram:(_e,id)=>calls.push(['stopProgram',id]),clearProgram:()=>calls.push(['clearProgram']),programType:(_e,id)=>{calls.push(['programType',id]);return c.type;},loadProgram:(_e,id)=>calls.push(['loadProgram',id]),startProgram:(_e,id)=>calls.push(['startProgram',id]),detach:()=>calls.push(['detach']),currentProgram:()=>{calls.push(['currentProgram']);return c.current;},updateProgram:(_e,id,delta)=>calls.push(['updateProgram',id,delta]),updateSound:(_sound,...args)=>calls.push(['sound',...args])};
  updateVisualPhases(e,c.delta,p);const actual={calls,phase:e.programPhaseFa,type:e.programType10d,programRemaining:e.programRemainingCc,modelRemaining:e.modelRemaining5c,states:e.modelStates68,retireRemaining:e.retireRemainingC0,retired:e.retiredDc,finished:e.finishedF4,retiring:e.retiringE8};
  const {case:_case,...expected}=row;assert.deepEqual(actual,expected,JSON.stringify(c));
 }
});
