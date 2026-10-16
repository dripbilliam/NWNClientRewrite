import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {loadVisualProgram,loadVisualProgramAsync,clearVisualProgram,cleanupVisualModels,updateVisualProgram} from '../src/visual_program.js';
test('program resource loading, clear/cleanup and frame dispatch match731 complete original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-program-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,731);
 for(const row of oracle.rows){
  const c=row.case,calls=[],models=Array.from({length:8},(_,id)=>({id})),e={target54:123,proceduralB8:c.old?models[6]:null,field104:9.25,models88:models.slice(0,3).map(v=>c.models?v:null),extraModelsA0:models.slice(c.alias?0:3,c.alias?3:6).map(v=>c.extra?v:null)};
  const p={programType:(_e,id)=>{calls.push(['programType',id]);return c.type;},clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},programString:(id,column)=>{calls.push(['string',id,column]);return{found:c.found,value:c.string};},programFloat:(id,column)=>{calls.push(['float',id,column]);return{found:c.found,value:c.float};},loadModel:(...args)=>{calls.push(['load',...args]);return c.load?models[7]:null;},setParent:(model,...args)=>{calls.push(['parent',model.id,...args]);if(c.mutate==='parent')e.proceduralB8=models[7];},setScene:(model,...args)=>{calls.push(['scene',model.id,...args]);if(c.mutate==='scene')e.proceduralB8=null;},destroyModel:(model,...args)=>{calls.push(['destroy',model.id,...args]);if(c.mutate==='destroy'&&model.id===0)e.extraModelsA0[0]=null;},modelSetting1a0:(model,...args)=>{calls.push(['setting',model.id,...args]);if(c.mutate==='setting')e.proceduralB8=null;},update140971e10:(_e,delta)=>calls.push(['update140971e10',delta]),update1409720e0:(_e,delta)=>calls.push(['update1409720e0',delta])};
  let result=null;
  if(c.mode==='load')result=loadVisualProgram(e,c.id,p);
  else if(c.mode==='clear')clearVisualProgram(e,p);
  else if(c.mode==='cleanup')cleanupVisualModels(e,p);
  else updateVisualProgram(e,c.id,c.delta,p);
  assert.deepEqual({calls,result,procedural:e.proceduralB8?.id??null,field104:e.field104,models:e.models88.map(v=>v?.id??null),extra:e.extraModelsA0.map(v=>v?.id??null)},{calls:row.calls,result:row.result,procedural:row.procedural,field104:row.field104,models:row.models,extra:row.extra},JSON.stringify(c));
 }
});

test('async program resource loading keeps the native store and setting after resource completion',async()=>{
 const calls=[],model={},e={proceduralB8:null},p={programType:()=>7,programString:(_id,column)=>{calls.push(column);return{found:true,value:'custom_beam'};},loadModel:async(...args)=>{calls.push(args);await Promise.resolve();assert.equal(e.proceduralB8,null);return model;},modelSetting1a0:(value,mode)=>{assert.equal(e.proceduralB8,model);calls.push([value===model,mode]);}};
 assert.equal(await loadVisualProgramAsync(e,123,p),1);assert.equal(e.proceduralB8,model);assert.deepEqual(calls,['param1',['custom_beam','fxbeam',0],[true,3]]);
});
