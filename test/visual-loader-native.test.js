import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {loadVisualEffect,loadVisualEffectAsync} from '../src/visual_loader.js';

test('visual loader matches767 complete original executions, including anchors, variants, failed resources and program suppression',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-loader-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,767);
 for(const row of oracle.rows){
  const c=row.case,calls=[],e={models88:[null,null,null],programsD0:[0,0,0],sourceAnchor28:'',targetAnchor38:'',orient120:0,durationFc:0,programRemainingCc:0,closedEc:0,retiredDc:[0,0,0]};let copied=0,consumed=0;
  const p={clientObject:id=>{calls.push(['client',id]);return id===123&&c.client||id===789&&c.source?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},settings:()=>{calls.push(['settings']);return{quality64:c.quality,violence40:c.violence};},visualString:(id,column)=>{calls.push(['string',id,column]);const value=(id===c.visual?c.strings:id===789?c.alternateStrings:{})[column]??'';return{found:value!=='',value};},visualInt:(id,column)=>{calls.push(['integer',id,column]);return{found:Object.hasOwn(c.ints,column),value:c.ints[column]??0};},creatureView58:()=>{calls.push(['view',88]);return c.creature?{appearanceCc:42}:null;},appearanceInt:(id,column)=>{calls.push(['integer',id,column]);return{found:c.sizeFound,value:c.size};},prefixViewA0:()=>{calls.push(['view',160]);return c.first?{prefix1e0:'plc'}:null;},prefixView28:()=>{calls.push(['view',40]);return c.second?{prefix1c8:'door'}:null;},modelHandle:(_r,...args)=>{calls.push(['modelHandle',...args]);return c.host?{}:null;},findNode:(_model,name)=>{calls.push(['node',name]);return!!c.anchor;},loadModel:(name,alias,flags)=>{calls.push(['load',name,alias,flags]);return c.failModels.includes(alias)?null:{name,alias};},modelSetting1a0:(model,value)=>calls.push(['modelSetting',model.alias,value]),warning:(...args)=>calls.push(['warning',...args]),copyControllers:()=>copied++,consumeControllers:()=>consumed++};
  const result=loadVisualEffect(e,{visual:c.visual,target:123,source:c.source?789:0x7f000000,sourcePart:c.sourcePart,targetPart:c.targetPart,instant:c.instant,point:[1.25,-2,3.5],controllers:{}},p);
  assert.deepEqual({calls,result,models:e.models88,programs:e.programsD0,anchors:[e.sourceAnchor28,e.targetAnchor38],orient:e.orient120,duration:e.durationFc,remaining:e.programRemainingCc,closed:e.closedEc,retired:e.retiredDc},{calls:row.calls,result:row.result,models:row.models,programs:row.programs,anchors:row.anchors,orient:row.orient,duration:row.duration,remaining:row.remaining,closed:row.closed,retired:row.retired},JSON.stringify(c));
  assert.equal(consumed,1);assert.equal(copied,result);assert.equal(e.target54,123);assert.equal(e.source58,c.source?789:0x7f000000);
  if(result)assert.deepEqual(e.point48,[1.25,-2,3.5]);
 }
});

test('async visual resources preserve one native selection pass and sequential load/settings/warning ownership',async()=>{
 const calls=[],e={models88:[null,null,null]},strings={Imp_HeadCon_Node:'head',Imp_Impact_Node:'impact',Imp_Root_M_Node:'ground'};
 const p={clientObject:id=>{calls.push(['client',id]);return{};},renderObject:()=>({}),visualInt:()=>({found:false,value:0}),visualString:(_id,column)=>({found:!!strings[column],value:strings[column]??''}),settings:()=>({quality64:1,violence40:2}),creatureView58:()=>null,prefixViewA0:()=>null,prefixView28:()=>null,modelHandle:()=>null,loadModel:async(name,alias)=>{calls.push(['load',name,alias]);await Promise.resolve();calls.push(['loaded',name]);return name==='impact'?null:{name};},modelSetting1a0:model=>calls.push(['setting',model.name]),warning:(_line,message)=>calls.push(['warning',message]),copyControllers:()=>calls.push(['copy']),consumeControllers:()=>calls.push(['consume'])};
 assert.equal(await loadVisualEffectAsync(e,{visual:456,target:123,source:789,sourcePart:0,targetPart:0,instant:0,point:[0,0,0],controllers:{}},p),1);
 assert.deepEqual(calls,[['client',123],['client',789],['load','ground','fxground'],['loaded','ground'],['setting','ground'],['load','impact','fximpact'],['loaded','impact'],['warning','CNWCVisualEffectOnObject::LoadVisualEffect: Failed to load impact node visual.'],['load','head','fxhead'],['loaded','head'],['setting','head'],['copy'],['consume']]);
 assert.deepEqual(e.models88,[{name:'ground'},null,{name:'head'}]);assert.deepEqual(e.retiredDc,[0,1,0]);
});
