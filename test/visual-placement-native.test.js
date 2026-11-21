import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {placeVisualModels} from '../src/visual_placement.js';
test('complete visual placement matches583 original executions with native names, parent flags and rotation resets',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-placement-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,583);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=Array.from({length:7},(_,id)=>({id}));if(c.alias)models[2]=models[0];
  const e={target54:123,updateProgramD8:c.updated,attached114:7,orient120:c.orient,programPhaseFa:c.phase,programsD0:[10,20,30],models88:models.slice(0,3).map((v,i)=>c.models[i]?v:null),proceduralB8:c.procedural?models[3]:null,extraModelsA0:models.slice(4).map(v=>c.extra?v:null)};
  const p={gameObjectRegistry:()=>{calls.push(['registry']);return c.registry?{}:null;},gameObject:(_registry,id)=>{calls.push(['object',id]);return{success:!!c.object,value:{}};},renderObject:()=>{calls.push(['render']);return{};},modelHandle:(_render,...args)=>{calls.push(['modelHandle',...args]);return{id:9};},prefixViewA0:()=>{calls.push(['viewA']);return c.first?{prefix1e0:c.prefixA}:null;},prefixView28:()=>{calls.push(['viewB']);return c.second?{prefix1c8:c.prefixB}:null;},setParent:(model,parent,...args)=>calls.push(['parent',model.id,parent.id,...args]),nodePose:(model,name)=>{calls.push(['pose',model.id,name]);return{position:[model.id+.25,model.id+.5,model.id+.75],quaternion:[.5,.5,.5,.5]};},setNodePose:(model,...args)=>calls.push(['setPose',model.id,...args]),startProgram:(_e,id)=>calls.push(['startProgram',id]),applyModelState:(_e,_render,model)=>{calls.push(['apply',model.id]);if(c.mutateApply&&model.id===3)e.models88[1]=null;}};
  const result=placeVisualModels(e,c.force,p);assert.deepEqual({calls,result,updated:e.updateProgramD8,attached:e.attached114,models:e.models88.map(model=>model?.id??null)},{calls:row.calls,result:row.result,updated:row.updated,attached:row.attached,models:row.models},JSON.stringify(c));
 }
});
