import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {startType4Visual,stopType4Visual} from '../src/visual_type4.js';
test('Type4 start uses native output widths, view equality, live model pointer and callback order',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-type4-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');const rows=oracle.rows.filter(row=>row.case.mode==='start');assert.equal(rows.length,388);
 for(const row of rows){
  const c=row.case,calls=[],models=[{id:0},{id:1}],context={},other={},e={target54:123,proceduralB8:c.procedural?models[0]:null,field110:7,scope10c:8,shadow108:9};
  const p={clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},view58:()=>{calls.push(['view58']);return c.creature?context:null;},view1406ac1a0:()=>{calls.push(['view1406ac1a0']);return[null,context,other][c.selected];},controlledClient:()=>{calls.push(['controlledClient']);return{videoF8:c.video?{gui248:{}}:null};},registerGuiD8:(_gui,model)=>calls.push(['registerGuiD8',model.id]),programAttach14096bbb0:()=>{calls.push(['programAttach14096bbb0']);if(c.replace)e.proceduralB8=models[1];},playAnimation:(model,...args)=>calls.push(['playAnimation',model.id,...args]),shadowing:(model,...args)=>calls.push(['shadowing',model.id,...args]),modelSetting1a0:(model,...args)=>calls.push(['modelSetting1a0',model.id,...args])};
  for(const[name,kind]of[['programString','string'],['programFloat','float'],['programInt','integer']])p[name]=(id,column)=>{calls.push([kind,id,column]);return{found:c.found,value:c.values[column]};};
  startType4Visual(e,302,p);assert.deepEqual({calls,field110:e.field110,scope:e.scope10c,shadow:e.shadow108,procedural:e.proceduralB8?.id??null},{calls:row.calls,field110:row.field110,scope:row.scope,shadow:row.shadow,procedural:row.procedural},JSON.stringify(c));
 }
});

test('Type4 stop preserves missing-target cleanup, selected-view calls and live procedural unparent/scene order',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-type4-observations.json',import.meta.url))),rows=oracle.rows.filter(row=>row.case.mode==='stop');assert.equal(rows.length,770);
 for(const row of rows){
  const c=row.case,calls=[],models=[{id:0},{id:1}],context={id:123,context30:c.context?{}:null},other={id:789},e={target54:123,proceduralB8:c.procedural?models[0]:null,attached114:c.attached,field110:7,scope10c:8,shadow108:9};
  const p={clientObject:id=>{calls.push(['client',id]);return c.client?{}:null;},renderObject:()=>{calls.push(['render']);return c.render?{}:null;},view58:()=>{calls.push(['view58']);return c.creature?context:null;},view1406ac1a0:()=>{calls.push(['view1406ac1a0']);return[null,context,other][c.selected];},controlledClient:()=>{calls.push(['controlledClient']);return{videoF8:c.video?{gui248:{}}:null};},registerGuiD8:(_gui,model)=>calls.push(['registerGuiD8',model?.id??null]),refreshContext1407e9bc0:()=>calls.push(['refreshContext1407e9bc0']),programInt:(id,column)=>{calls.push(['integer',id,column]);return{found:c.found,value:c.values[column]};},setParent:(model,...args)=>{calls.push(['parent',model.id,...args]);if(c.replace)e.proceduralB8=models[1];},setScene:(model,...args)=>calls.push(['scene',model.id,...args])};
  stopType4Visual(e,302,p);assert.deepEqual({calls,field110:e.field110,scope:e.scope10c,shadow:e.shadow108,procedural:e.proceduralB8?.id??null},{calls:row.calls,field110:row.field110,scope:row.scope,shadow:row.shadow,procedural:row.procedural},JSON.stringify(c));
 }
});
