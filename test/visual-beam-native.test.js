import fs from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';
import {attachBeamVisual,startBeamVisual,stopBeamVisual} from '../src/visual_beam.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-beam-observations.json',import.meta.url)));
test('complete original beam attachment and Type7 start/stop branches preserve native order, Param6 and callback replacement',()=>{
 assert.equal(native.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(native.rows.length,1418);
 for(const row of native.rows){
  const c=row.case,calls=[],models=[{index:0},{index:1}],target={who:'target'},source={who:'source'},e={target54:123,source58:789,proceduralB8:c.model?models[0]:null,sourceAnchor28:c.sourceAnchor,targetAnchor38:c.targetAnchor,updateProgramD8:c.enabled};
  const p={clientObject:id=>{calls.push(['object',id]);return id===123?(c.target?target:null):(c.source?source:null);},renderObject:o=>{calls.push(['render',o.who]);return c[o.who+'Render']?o:null;},modelHandle:(o,part,mode)=>{calls.push(['handle',o.who,part,mode]);return c[o.who+'Handle']?o.who:null;},setParent:(model,parent,name,flags)=>{calls.push(['parent',model.index,parent||null,name||'',flags]);if(c.replace)e.proceduralB8=models[1];},reattachReferences:(model,parent,name)=>calls.push(['reattach',model.index,parent,name]),programString:(id,column)=>{calls.push(['string',id,column]);return{found:c.found,value:c.animation};},playAnimation:(model,name,speed,flags,time)=>calls.push(['play',model.index,name,speed,flags,time]),setScene:(model,scene)=>calls.push(['scene',model.index,scene])};
  if(c.mode==='attach')attachBeamVisual(e,p);else{if(c.enabled)calls.push(['type',c.program&65535]);if(c.mode==='start')startBeamVisual(e,c.program,p);else stopBeamVisual(e,p);}
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(e.proceduralB8?.index??null,row.model,JSON.stringify(c));
 }
});
