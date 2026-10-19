import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveObjectState,saveGameEffect,saveScriptVariables,saveObjectActions,saveObjectTransition,saveLocalLocation,loadObjectTransition} from '../src/object_state_save.js';
import {gffField,writeGff} from '../src/gff_writer.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';
import {createObjectActionState,createObjectAction,setActionParameter} from '../src/object_actions.js';
import {encodeGffText} from '../src/gff_text.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-state-save-observations.json',import.meta.url)));
const normalize=value=>JSON.parse(JSON.stringify(value,(_key,v)=>typeof v==='bigint'?v.toString():v));
function fixture(c){
 const object={id:0x80000123,objectType:c.type,effects:structuredClone(c.effects),actions:createObjectActionState()},calls=[];
 for(const a of c.actions){const node=createObjectAction(a.actionId,a.groupId);a.parameters.forEach(([type,value],i)=>setActionParameter(node,i,type,type===4?encodeGffText(value):value));object.actions.list.insert(node);}
 const vp={engineEmpty:(kind,value)=>{calls.push(['empty',kind,value]);return value===null;},saveEngine:(kind,value,root)=>{calls.push(['engine',kind,value]);root.fields.EngineMarker=gffField(5,value);}};
 const ap={client:o=>{calls.push(['client',o.id]);return c.client===null?null:{field:c.client};},clientFieldD4:client=>client.field,actions:o=>o.actions,scriptSituation:(value,root)=>{calls.push(['situation',value]);root.fields.SituationMarker=gffField(5,value);}};
 const p={effects:o=>o.effects,effect:saveGameEffect,variables:(_o,root)=>saveScriptVariables(c.variables,vp,root),actionsSave:(o,root)=>saveObjectActions(o,ap,root),transition:(_o,root)=>saveObjectTransition(c.transition,root)};
 return{object,p,calls};
}
test('complete object/effect/variable/action/transition save owners match original typed fields and call order',async()=>{
 assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls:expected}of observations.cases){const {object,p,calls}=fixture(c),actual=await saveObjectState(object,p);assert.deepEqual(normalize(actual),output,c.name);assert.deepEqual(calls,expected,c.name);}
});
test('effect save retains all64 ID bits, DWORD object IDs and native packed subtype',()=>{
 const effect=observations.cases.find(x=>x.case.name==='id-18446744073709551615').case.effects[0];
 const root=parseGff(writeGff('UTC ',saveGameEffect(effect)),'UTC ').root;
 assert.equal(root.Id,0xffffffffffffffffn);assert.equal(getGffFieldTypes(root).Id,6);assert.equal(root.CreatorId,0x80000001);
 assert.equal(root.SubType,effect.subtype|effect.durationType);assert.equal(root.SkipOnLoad,1);assert.ok(!('IntList'in root));
 assert.equal(root.StringList[2].Value,'nul\0tail');assert.equal(getGffStructType(root.VectorList[0]),7);
});
test('an item with only filtered effects still writes an empty EffectList and both state lists',async()=>{
 const c=observations.cases.find(x=>x.case.name==='all-filtered-item').case,{object,p}=fixture(c),root=parseGff(writeGff('UTI ',await saveObjectState(object,p)),'UTI ').root;
 assert.deepEqual(root.EffectList,[]);assert.deepEqual(root.VarTable,[]);assert.deepEqual(root.ActionList,[]);assert.equal(root.Transition.TargetObjectId,0x7f000000);
});
test('local locations preserve stored native coordinates without area lookup or normalization',()=>{
 const location={areaId:0xffffffff,position:[1.25,2,3],nativeOrientation:[7,8,9]},root=parseGff(writeGff('UTC ',saveLocalLocation(location)),'UTC ').root;
 assert.equal(root.Area,0xffffffff);assert.equal(root.OrientationY,8);assert.equal(root.PositionZ,3);
});

test('transition load matches original Win64 fallback arguments for missing and mistyped fields',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-transition-load-observations.json',import.meta.url)));
 for(const {case:c,output}of native.cases){
  const data=parseGff(writeGff('UTI ',c.data),'UTI ').root,current=structuredClone(c.initial);
  assert.deepEqual(loadObjectTransition(current,data),output);
 }
});
