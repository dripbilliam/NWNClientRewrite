import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadObjectActions} from '../src/object_action_load.js';
import {createObjectActionState} from '../src/object_actions.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {decodeGffText} from '../src/gff_text.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-action-load-observations.json',import.meta.url)));
const decode=data=>parseGff(writeGff('UTI ',data),'UTI ').root;
const snapshot=state=>({nextGroup:state.nextGroup,lastGroup:state.lastGroup,nodes:[...state.list].map(n=>({actionId:n.actionId,groupId:n.groupId,parameterCount:n.parameterCount,nativeField9c:n.nativeField9c,parameters:Array.from({length:n.parameterCount},(_,i)=>({type:n.parameterTypes[i],value:n.parameterTypes[i]===4?decodeGffText(n.parameterData[i]):n.parameterData[i]}))}))});
test('whole action loader and AddAction match original group state and owned parameters',async()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls}of native.cases){
  const state=createObjectActionState(),trace=[];state.nextGroup=c.nextGroup;state.lastGroup=c.lastGroup;
  const p={scriptSituation:r=>{trace.push(['situation',r.Marker??0]);return{marker:r.Marker??0};}};
  if(c.seed)await loadObjectActions(state,decode(c.seed),p);
  await loadObjectActions(state,decode(c.data),p);assert.deepEqual(snapshot(state),output,c.name);assert.deepEqual(trace,calls,c.name);
 }
});
test('saved action stack overflow and first failed list/struct reads remain diagnosed',async()=>{
 const load=row=>loadObjectActions(createObjectActionState(),decode(gffRecord({ActionList:gffField(15,[gffRecord(row)])})));
 await assert.rejects(load({NumParams:gffField(2,13)}),/exceeds temporary/);
 await assert.rejects(load({NumParams:gffField(2,1)}),/parameter list is uninitialized/);
 await assert.rejects(load({NumParams:gffField(2,1),Paramaters:gffField(15,[])}),/parameter struct is uninitialized/);
 await assert.rejects(load({NumParams:gffField(2,1),Paramaters:gffField(15,[gffRecord({Type:gffField(4,5)})])}),/script-situation struct is uninitialized/);
});
